/**
 * M5: Admin callable function to bulk mark recipes for retagging.
 *
 * When the tag generator version changes, this function can be called to:
 * 1. Query all recipes with an outdated generatorVersion
 * 2. Mark them for client-side retagging by setting generatorVersion to 'outdated'
 *
 * The actual retagging happens client-side when recipes are loaded,
 * as it requires the ingredient lookup database.
 */

import * as functions from "firebase-functions";
import * as admin from "firebase-admin";

const db = admin.firestore();

interface BulkRetagRequest {
  /** Current/target generator version. Recipes with different versions will be marked. */
  targetVersion: string;
  /** Optional: Maximum number of recipes to process (default: 1000) */
  limit?: number;
  /** Optional: Only process recipes for a specific user */
  userId?: string;
  /** Optional: Dry run - only count affected recipes without updating */
  dryRun?: boolean;
}

interface BulkRetagResponse {
  success: boolean;
  message: string;
  stats: {
    totalFound: number;
    totalUpdated: number;
    batchesProcessed: number;
  };
}

/**
 * Callable function for admins to trigger bulk retagging.
 *
 * Usage:
 *   const result = await functions.httpsCallable('bulkMarkForRetagging')({
 *     targetVersion: 'v1.2.3',
 *     limit: 500,
 *     dryRun: true
 *   });
 */
export const bulkMarkForRetagging = functions.https.onCall(
  async (data: BulkRetagRequest, context): Promise<BulkRetagResponse> => {
    // Verify admin access (check for admin custom claim)
    if (!context.auth) {
      throw new functions.https.HttpsError(
        "unauthenticated",
        "Authentication required"
      );
    }

    // Check for admin claim - adjust based on your auth setup
    const isAdmin = context.auth.token.admin === true ||
                    context.auth.token.role === "admin";
    if (!isAdmin) {
      functions.logger.warn(
        `Non-admin user ${context.auth.uid} attempted bulk retagging`
      );
      throw new functions.https.HttpsError(
        "permission-denied",
        "Admin access required for bulk retagging"
      );
    }

    const { targetVersion, limit = 1000, userId, dryRun = false } = data;

    if (!targetVersion) {
      throw new functions.https.HttpsError(
        "invalid-argument",
        "targetVersion is required"
      );
    }

    functions.logger.info(
      `Bulk retag requested: targetVersion=${targetVersion}, limit=${limit}, userId=${userId || "all"}, dryRun=${dryRun}`
    );

    try {
      // Build query for outdated recipes
      let query: admin.firestore.Query = db.collection("recipes");

      // Filter by user if specified
      if (userId) {
        query = query.where("core.createdBy", "==", userId);
      }

      // We want recipes that DON'T have the target version
      // Firestore doesn't support != directly with other conditions,
      // so we query all and filter in-memory
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

      if (dryRun) {
        functions.logger.info(
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
        };
      }

      // Process updates in batches
      const batchSize = 500;
      let totalUpdated = 0;
      let batchesProcessed = 0;

      for (let i = 0; i < recipesToUpdate.length; i += batchSize) {
        const batch = db.batch();
        const batchDocs = recipesToUpdate.slice(i, i + batchSize);

        for (const doc of batchDocs) {
          batch.update(doc.ref, {
            "core.tagResult.generatorVersion": "outdated",
          });
        }

        await batch.commit();
        totalUpdated += batchDocs.length;
        batchesProcessed++;

        functions.logger.info(
          `Processed batch ${batchesProcessed}: ${batchDocs.length} recipes`
        );
      }

      functions.logger.info(
        `Bulk retag complete: ${totalUpdated} recipes marked for retagging`
      );

      return {
        success: true,
        message: `Successfully marked ${totalUpdated} recipes for retagging`,
        stats: {
          totalFound,
          totalUpdated,
          batchesProcessed,
        },
      };
    } catch (error) {
      functions.logger.error("Bulk retag failed:", error);
      throw new functions.https.HttpsError(
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
 */
export const getRetagStatus = functions.https.onCall(
  async (data: { userId?: string }, context): Promise<{
    byVersion: { [version: string]: number };
    total: number;
  }> => {
    // Require authentication
    if (!context.auth) {
      throw new functions.https.HttpsError(
        "unauthenticated",
        "Authentication required"
      );
    }

    const { userId } = data;

    try {
      let query: admin.firestore.Query = db.collection("recipes");

      if (userId) {
        query = query.where("core.createdBy", "==", userId);
      }

      // Limit to avoid timeout on large collections
      const snapshot = await query.limit(5000).get();

      const byVersion: { [version: string]: number } = {};

      snapshot.docs.forEach((doc) => {
        const data = doc.data();
        const version = data.core?.tagResult?.generatorVersion || "untagged";
        byVersion[version] = (byVersion[version] || 0) + 1;
      });

      return {
        byVersion,
        total: snapshot.size,
      };
    } catch (error) {
      functions.logger.error("Get retag status failed:", error);
      throw new functions.https.HttpsError(
        "internal",
        `Failed to get retag status: ${error}`
      );
    }
  }
);
