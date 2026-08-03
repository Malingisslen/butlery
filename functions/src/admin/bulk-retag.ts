/**
 * M5: Admin callable function to bulk mark recipes for retagging.
 *
 * When the tag generator version changes, this function can be called to:
 * 1. Query all recipes with an outdated generatorVersion
 * 2. Mark them for client-side retagging by setting generatorVersion to 'outdated'
 *
 * The actual retagging happens client-side when recipes are loaded,
 * as it requires the ingredient lookup database.
 *
 * CRIT-6: Includes rate limiting and audit logging for security.
 */

import { onCall, HttpsError, CallableRequest } from "firebase-functions/v2/https";
import { logger } from "firebase-functions/logger";
import * as admin from "firebase-admin";
import { requireAdmin } from "../shared/require-admin";

// Lazy initialization to avoid calling firestore() before initializeApp()
const getDb = () => admin.firestore();

/**
 * BUT-1781: recipes live ONLY at `users/{uid}/recipes/{recipeId}`. Both
 * callables here read a top-level `recipes` collection that has never existed,
 * so `bulkMarkForRetagging` marked 0 recipes and `getRetagStatus` reported 0 —
 * silently, because "no recipes match" is a legitimate answer. These are the
 * operator escape hatch that DRAINS the `stale-ingredient` / `stale-properties`
 * markers the ingredient cascades write, and those cascades only started
 * producing markers once they were repointed at the collection group. Fixing one
 * consumer of a wrong path does not fix the path.
 *
 * The `core.createdBy` filter needs a COLLECTION_GROUP fieldOverride, declared
 * in firestore.indexes.json alongside the two the cascades use.
 */
const recipesGroup = (): admin.firestore.Query =>
  getDb().collectionGroup("recipes");

// CRIT-6: Rate limit constants
const RATE_LIMIT_PER_DAY = 5;

/**
 * Hard ceiling on the operator-supplied `limit`. One page must fit in function
 * memory; 5 calls/day at this size is the real drain rate.
 */
const MAX_BULK_RETAG_LIMIT = 1000;
const RATE_LIMIT_COLLECTION = "admin_rate_limits";
const AUDIT_LOG_COLLECTION = "admin_audit_logs";

// MED-7: Retry constants for failed operations
const MAX_RETRIES = 3;
const INITIAL_RETRY_DELAY_MS = 100;

/**
 * CRIT-6: Check and update rate limit for an admin user.
 * Returns true if within limit, false if exceeded.
 */
async function checkRateLimit(adminUid: string): Promise<boolean> {
  const today = new Date().toISOString().split("T")[0]; // YYYY-MM-DD
  const db = getDb();
  const rateLimitRef = db
    .collection(RATE_LIMIT_COLLECTION)
    .doc(`${adminUid}_bulkRetag_${today}`);

  return db.runTransaction(async (transaction: admin.firestore.Transaction) => {
    const doc = await transaction.get(rateLimitRef);
    const currentCount = doc.exists ? (doc.data()?.count || 0) : 0;

    if (currentCount >= RATE_LIMIT_PER_DAY) {
      return false; // Rate limit exceeded
    }

    transaction.set(
      rateLimitRef,
      {
        adminUid,
        date: today,
        count: currentCount + 1,
        lastCall: admin.firestore.FieldValue.serverTimestamp(),
      },
      { merge: true }
    );

    return true; // Within rate limit
  });
}

/**
 * CRIT-6: Log admin action for audit trail.
 * H11: Wrapped in try-catch to prevent audit failures from crashing main operation.
 */
async function logAuditEntry(
  adminUid: string,
  action: string,
  details: Record<string, unknown>
): Promise<void> {
  try {
    await getDb().collection(AUDIT_LOG_COLLECTION).add({
      adminUid,
      action,
      details,
      timestamp: admin.firestore.FieldValue.serverTimestamp(),
      ipAddress: null, // Would need to extract from request context if needed
    });
  } catch (error) {
    // H11: Log warning but don't crash the main operation
    logger.warn(
      `H11: Audit logging failed for action "${action}": ${error}`,
      { adminUid, action, details }
    );
  }
}

/**
 * M14: Non-retryable Firestore error codes.
 * These errors should not be retried as they indicate permanent failures.
 */
const NON_RETRYABLE_ERRORS = new Set([
  "permission-denied",
  "invalid-argument",
  "not-found",
  "already-exists",
  "failed-precondition",
  "out-of-range",
  "unimplemented",
  "data-loss",
]);

/**
 * M14: Check if an error is retryable.
 * Firestore transient errors (unavailable, resource-exhausted, etc.) are retryable.
 */
function isRetryableError(error: unknown): boolean {
  if (error instanceof Error) {
    const code = (error as { code?: string }).code;
    if (code && NON_RETRYABLE_ERRORS.has(code)) {
      return false;
    }
    // Check for gRPC error codes in message
    const message = error.message.toLowerCase();
    if (
      message.includes("permission denied") ||
      message.includes("invalid argument") ||
      message.includes("not found")
    ) {
      return false;
    }
  }
  return true; // Default to retryable for unknown errors
}

/**
 * MED-7: Retry an async operation with exponential backoff.
 * M14: Only retries transient/retryable errors, not permanent failures.
 */
async function withRetry<T>(
  operation: () => Promise<T>,
  maxRetries: number = MAX_RETRIES
): Promise<T> {
  let lastError: Error | undefined;

  for (let attempt = 0; attempt <= maxRetries; attempt++) {
    try {
      return await operation();
    } catch (error) {
      lastError = error instanceof Error ? error : new Error(String(error));

      // M14: Don't retry non-retryable errors
      if (!isRetryableError(error)) {
        logger.debug(
          `Non-retryable error, not retrying: ${lastError.message}`
        );
        throw lastError;
      }

      if (attempt < maxRetries) {
        // Exponential backoff: 100ms, 200ms, 400ms
        const delay = INITIAL_RETRY_DELAY_MS * Math.pow(2, attempt);
        await new Promise((resolve) => setTimeout(resolve, delay));
        logger.debug(
          `Retry attempt ${attempt + 1}/${maxRetries} after ${delay}ms`
        );
      }
    }
  }

  throw lastError;
}

interface BulkRetagRequest {
  /** Current/target generator version. Recipes with different versions will be marked. */
  targetVersion: string;
  /** Optional: Maximum number of recipes to process (default: 1000) */
  limit?: number;
  /** Optional: Only process recipes for a specific user */
  userId?: string;
  /** Optional: Dry run - only count affected recipes without updating */
  dryRun?: boolean;
  /**
   * Optional: document path to resume after, from a previous call's
   * `nextCursor`. Without it every call re-reads the same first `limit`
   * documents in `__name__` order and the callable can never drain the
   * backlog — it writes the marker `"outdated"`, which still fails the
   * in-memory `currentVersion !== targetVersion` filter, so the same page
   * matches forever. BUT-1794 makes the cascades actually produce those
   * markers at scale, which turns this from latent into live.
   */
  startAfter?: string;
}

interface BulkRetagResponse {
  success: boolean;
  message: string;
  stats: {
    totalFound: number;
    totalUpdated: number;
    batchesProcessed: number;
  };
  /**
   * Path of the last document this call scanned, to pass back as `startAfter`.
   * Absent when the scan reached the end. Without paging through this the
   * callable re-reads page 1 forever — see `startAfter` on the request.
   */
  nextCursor?: string;
}

/**
 * Callable function for admins to trigger bulk retagging.
 */
export const bulkMarkForRetagging = onCall(
  async (request: CallableRequest<BulkRetagRequest>): Promise<BulkRetagResponse> => {
    // Verify admin access (check for admin custom claim)
    if (!request.auth) {
      throw new HttpsError(
        "unauthenticated",
        "Authentication required"
      );
    }

    // Check for admin claim - adjust based on your auth setup
    const isAdmin = request.auth.token.admin === true ||
                    request.auth.token.role === "admin";
    if (!isAdmin) {
      logger.warn(
        `Non-admin user ${request.auth.uid} attempted bulk retagging`
      );
      throw new HttpsError(
        "permission-denied",
        "Admin access required for bulk retagging"
      );
    }

    const adminUid = request.auth.uid;
    const data = request.data;

    // CRIT-6: Check rate limit before proceeding
    const withinRateLimit = await checkRateLimit(adminUid);
    if (!withinRateLimit) {
      logger.warn(
        `Admin ${adminUid} exceeded bulk retag rate limit`
      );
      throw new HttpsError(
        "resource-exhausted",
        `Rate limit exceeded. Maximum ${RATE_LIMIT_PER_DAY} calls per day.`
      );
    }

    const { targetVersion, userId, dryRun = false, startAfter } = data;
    // Operator-supplied and previously uncapped and untyped: `limit: 500000`
    // was an unbounded `.get()` straight into function memory.
    const requestedLimit = Number(data.limit ?? 1000);
    const limit =
      Number.isFinite(requestedLimit) && requestedLimit > 0
        ? Math.min(Math.floor(requestedLimit), MAX_BULK_RETAG_LIMIT)
        : 1000;

    // CRIT-6: Log audit entry
    await logAuditEntry(adminUid, "bulk_retag_started", {
      targetVersion,
      limit,
      userId: userId || "all",
      dryRun,
    });

    if (!targetVersion) {
      throw new HttpsError(
        "invalid-argument",
        "targetVersion is required"
      );
    }

    logger.info(
      `Bulk retag requested: targetVersion=${targetVersion}, limit=${limit}, userId=${userId || "all"}, dryRun=${dryRun}`
    );

    try {
      // Build query for outdated recipes
      let query: admin.firestore.Query = recipesGroup();

      // Filter by user if specified
      if (userId) {
        query = query.where("core.createdBy", "==", userId);
      }

      // We want recipes that DON'T have the target version
      // Firestore doesn't support != directly with other conditions,
      // so we query all and filter in-memory
      // Ordered + cursored so successive calls advance. `__name__` is the only
      // ordering a collection-group scan gets for free, and it is stable.
      // One field, not whole recipe documents — the sibling `getRetagStatus`
      // already does this. It is what makes MAX_BULK_RETAG_LIMIT actually safe
      // against the default memory limit.
      query = query.select("core.tagResult.generatorVersion");
      query = query.orderBy(admin.firestore.FieldPath.documentId());
      if (typeof startAfter === "string" && startAfter.length > 0) {
        query = query.startAfter(
          await admin.firestore().doc(startAfter).get(),
        );
      }
      query = query.limit(limit);

      const snapshot = await query.get();

      if (snapshot.empty) {
        return {
          success: true,
          message: "No recipes found",
          stats: {
            totalFound: 0,
            totalUpdated: 0,
            batchesProcessed: 0,
          },
        };
      }

      // Filter recipes that need updating
      const recipesToUpdate = snapshot.docs.filter((doc) => {
        const data = doc.data();
        const currentVersion = data.core?.tagResult?.generatorVersion;
        // Update if version is different or missing
        return currentVersion !== targetVersion;
      });

      const totalFound = recipesToUpdate.length;

      // Computed BEFORE the dry-run return. Leaving it below meant `dryRun`
      // could not page either — the very defect this cursor fixes, surviving
      // inside its own fix.
      const lastScanned = snapshot.docs[snapshot.docs.length - 1];
      const reachedEnd = snapshot.size < limit;
      const cursor = reachedEnd ? {} : { nextCursor: lastScanned.ref.path };

      if (dryRun) {
        logger.info(
          `Dry run: Would update ${totalFound} recipes`
        );
        return {
          success: true,
          message: `Dry run complete. Would update ${totalFound} recipes.`,
          stats: {
            totalFound,
            totalUpdated: 0,
            batchesProcessed: 0,
          },
          ...cursor,
        };
      }

      // M4: Process updates in batches with individual error handling
      const batchSize = 500;
      let totalUpdated = 0;
      let totalFailed = 0;
      let batchesProcessed = 0;
      const failedIds: string[] = [];

      for (let i = 0; i < recipesToUpdate.length; i += batchSize) {
        const batchDocs = recipesToUpdate.slice(i, i + batchSize);

        // M4: Use Promise.allSettled to continue on individual failures
        // MED-7: Wrap updates in retry logic with exponential backoff
        const results = await Promise.allSettled(
          batchDocs.map(async (doc) => {
            try {
              await withRetry(async () => {
                await doc.ref.update({
                  "core.tagResult.generatorVersion": "outdated",
                });
              });
              return { id: doc.id, success: true };
            } catch (error) {
              logger.warn(
                `Failed to update recipe ${doc.id} after ${MAX_RETRIES} retries: ${error}`
              );
              return { id: doc.id, success: false, error: String(error) };
            }
          })
        );

        // Count successes and failures
        for (const result of results) {
          if (result.status === "fulfilled" && result.value.success) {
            totalUpdated++;
          } else {
            totalFailed++;
            if (result.status === "fulfilled" && !result.value.success) {
              failedIds.push(result.value.id);
            }
          }
        }

        batchesProcessed++;
        logger.info(
          `Processed batch ${batchesProcessed}: ${batchDocs.length} recipes`
        );
      }

      // M4: Log failures summary
      if (failedIds.length > 0) {
        logger.warn(
          `Bulk retag completed with ${totalFailed} failures. Failed IDs (first 10): ${failedIds.slice(0, 10).join(", ")}`
        );
      }

      logger.info(
        `Bulk retag complete: ${totalUpdated} recipes marked, ${totalFailed} failed`
      );

      // CRIT-6: Log completion audit entry
      await logAuditEntry(adminUid, "bulk_retag_completed", {
        targetVersion,
        totalFound,
        totalUpdated,
        totalFailed,
        batchesProcessed,
        dryRun,
      });

      // `cursor` above is the last document SCANNED, not the last updated — the
      // in-memory version filter drops most of a page, and resuming from an
      // updated doc would silently skip everything between.
      return {
        success: totalFailed === 0,
        message: totalFailed === 0
          ? `Successfully marked ${totalUpdated} recipes for retagging`
          : `Marked ${totalUpdated} recipes, ${totalFailed} failed`,
        stats: {
          totalFound,
          totalUpdated,
          batchesProcessed,
        },
        ...cursor,
      };
    } catch (error) {
      logger.error("Bulk retag failed:", error);
      throw new HttpsError(
        "internal",
        `Bulk retag failed: ${error}`
      );
    }
  }
);

/**
 * HTTP endpoint to check retag status (for monitoring dashboards).
 *
 * Returns count of recipes by generator version.
 *
 * H12: Optimized to only fetch the fields needed (generatorVersion) instead
 * of full documents. Uses pagination to handle large collections.
 */
export const getRetagStatus = onCall(
  async (request: CallableRequest<{ userId?: string }>): Promise<{
    byVersion: { [version: string]: number };
    total: number;
  }> => {
    requireAdmin(request);

    const { userId } = request.data;

    try {
      const byVersion: { [version: string]: number } = {};
      let total = 0;
      let lastDoc: admin.firestore.DocumentSnapshot | null = null;
      const PAGE_SIZE = 1000;

      // H12: Paginate through results to handle large collections
      while (true) {
        let query: admin.firestore.Query = recipesGroup();

        if (userId) {
          query = query.where("core.createdBy", "==", userId);
        }

        // H12: Only select the field we need (reduces data transfer significantly)
        query = query.select("core.tagResult.generatorVersion");
        query = query.limit(PAGE_SIZE);

        if (lastDoc) {
          query = query.startAfter(lastDoc);
        }

        const snapshot = await query.get();

        if (snapshot.empty) {
          break;
        }

        snapshot.docs.forEach((doc) => {
          const data = doc.data();
          const version = data.core?.tagResult?.generatorVersion || "untagged";
          byVersion[version] = (byVersion[version] || 0) + 1;
        });

        total += snapshot.size;
        lastDoc = snapshot.docs[snapshot.docs.length - 1];

        // Safety limit to prevent infinite loops
        if (total >= 50000) {
          logger.warn(
            `H12: Reached safety limit of 50000 recipes, results may be partial`
          );
          break;
        }

        // If we got less than PAGE_SIZE, we've reached the end
        if (snapshot.size < PAGE_SIZE) {
          break;
        }
      }

      return {
        byVersion,
        total,
      };
    } catch (error) {
      logger.error("Get retag status failed:", error);
      throw new HttpsError(
        "internal",
        `Failed to get retag status: ${error}`
      );
    }
  }
);
