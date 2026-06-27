/**
 * Rate Limit Cleanup Cloud Function
 *
 * Scheduled to run weekly on Sundays at 3 AM UTC to delete stale rate-limit
 * buckets from the top-level `system_rate_limits` collection (doc id
 * `{userId}_{operation}`) — the live store written by the rate-limiter
 * middleware. Pre-BUT-1390 this scanned the dead `users/{uid}/rate_limits`
 * subcollection and deleted nothing, so `system_rate_limits` grew unbounded
 * with the user base (a silent FinOps storage-cost leak).
 *
 * Stale = not updated in 90+ days.
 *
 * CRIT-7: Uses batched deletes + delete-by-query paging to prevent timeouts.
 */

import { onSchedule } from "firebase-functions/v2/scheduler";
import { logger } from "firebase-functions/logger";
import * as admin from "firebase-admin";

// CRIT-7: Constants for safe batch processing
const BATCH_SIZE = 500; // Firestore maximum per batch commit
const MAX_EXECUTION_TIME_MS = 8 * 60 * 1000; // 8 minutes (Cloud Functions timeout is 9 min)

/**
 * Weekly cleanup of old rate limit records
 *
 * Schedule: 0 3 * * 0 (Weekly on Sundays at 3 AM UTC)
 *
 * CRIT-7: Processing with safety limits:
 * - Processes users in chunks of 1000
 * - Uses batched deletes (500 per batch)
 * - Has timeout protection (8 minutes)
 *
 * The scheduler wrapper just delegates to `cleanupOldRateLimitsCore` so the
 * logic can be exercised against a real Firestore emulator in integration
 * tests (the `onSchedule` callback can't be invoked directly). Behaviour is a
 * byte-for-byte lift of the former inline body — no logic change.
 */
export const cleanupOldRateLimits = onSchedule(
  { schedule: "0 3 * * 0", timeZone: "UTC" },
  async () => {
    await cleanupOldRateLimitsCore(admin.firestore());
  }
);

/** Summary returned by the testable core so callers/tests can assert effects. */
export interface CleanupRateLimitsResult {
  deletedCount: number;
}

/**
 * Testable core for the rate-limit cleanup. Accepts an injected Firestore so
 * integration tests can point it at the emulator. Returns a small summary.
 *
 * BUT-1390: scans the live top-level `system_rate_limits` collection with a
 * single-field range query on `updatedAt` (served by the automatic index — no
 * composite needed) and deletes stale buckets directly. This replaces the old
 * O(total-users) subcollection walk that read the dead `users/{uid}/rate_limits`
 * path and deleted nothing while `system_rate_limits` grew without bound.
 */
export async function cleanupOldRateLimitsCore(
  db: admin.firestore.Firestore
): Promise<CleanupRateLimitsResult> {
  const startTime = Date.now();
  const cutoffDate = new Date();
  cutoffDate.setDate(cutoffDate.getDate() - 90); // 90 days ago
  const cutoff = admin.firestore.Timestamp.fromDate(cutoffDate);

  logger.info(
    `Starting rate limit cleanup, deleting system_rate_limits buckets ` +
    `not updated since ${cutoffDate.toISOString()}`
  );

  let deletedCount = 0;

  // Delete-by-query: each page selects up to BATCH_SIZE stale buckets, deletes
  // them, then re-queries. Deleted docs no longer match the filter, so the
  // result set shrinks each pass and no pagination cursor is required.
  while (true) {
    // CRIT-7: stop before the 9-min function timeout; the next weekly run (or a
    // manual re-invoke) continues where this left off since deletes are durable.
    if (Date.now() - startTime > MAX_EXECUTION_TIME_MS) {
      logger.warn(
        `CRIT-7: Approaching timeout after ${deletedCount} deletes. ` +
        `Will continue in next scheduled run.`
      );
      break;
    }

    const snapshot = await db
      .collection("system_rate_limits")
      .where("updatedAt", "<", cutoff)
      .limit(BATCH_SIZE)
      .get();

    if (snapshot.empty) break;

    const batch = db.batch();
    for (const doc of snapshot.docs) {
      batch.delete(doc.ref);
    }
    await batch.commit();
    deletedCount += snapshot.size;
    logger.debug(`Committed batch of ${snapshot.size} stale-bucket deletes`);

    // A short page means we've drained the stale set.
    if (snapshot.size < BATCH_SIZE) break;
  }

  const elapsedMs = Date.now() - startTime;
  logger.info(
    `Rate limit cleanup complete: deleted ${deletedCount} stale buckets ` +
    `in ${(elapsedMs / 1000).toFixed(1)}s`
  );

  return { deletedCount };
}
