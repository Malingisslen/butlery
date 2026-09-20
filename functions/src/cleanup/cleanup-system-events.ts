/**
 * `system_events` retention — the `rate_limit_violation` rows only.
 *
 * `system_events` is the internal ops log and has never had a retention
 * policy. Most of its writers append one row per run or per event (cleanup
 * receipts, moderation rows, a mail failure), so their volume is bounded by how
 * often those things happen. `middleware/rate_limiter.ts` is the exception: it
 * writes one row per THROTTLED CALL, so its rows grow with traffic rather than
 * with time.
 *
 * This job prunes that one type and nothing else. The scope is the decision,
 * not an increment: `content_report` and `moderation_threshold_reached` can sit
 * under a legal hold (`erasure_holds/{uid}`, case `status != 'closed'`) and are
 * owned by `account-deletion-cascade.ts` and `moderation/reporter-retention.ts`;
 * the run receipts are what the admin ops-log tab displays. A predicate that
 * names the type can never reach a row type it does not name, which is why this
 * is a job rather than a collection-wide TTL — and the rows also have no common
 * timestamp field for a TTL to key on: some carry `executedAt`, some `timestamp`,
 * and `cleanup_expired_social_requests` is a RECEIPT carrying `timestamp`, so an
 * age-only prune would delete it.
 *
 * A `rate_limit_violation` row carries `userIdHash`, never `details.userId`,
 * `details.reporterId` or `details.contentOwnerId`. That field shape is what
 * puts it structurally out of reach of both the legal-hold predicate and the
 * account-deletion cascade's `system_events` sweep, and therefore what makes
 * deleting it on a clock safe outside the erasure path.
 */

import { onSchedule } from "firebase-functions/v2/scheduler";
import { logger } from "firebase-functions/logger";
import * as admin from "firebase-admin";

const SYSTEM_EVENTS = "system_events";

/** The one row type this job is allowed to touch. */
const PRUNED_TYPE = "rate_limit_violation";

/**
 * Retention window. Matches the 90 days `cleanup-rate-limits.ts` applies to
 * `system_rate_limits`: the bucket state and the violation record describe the
 * same event, and two windows that agree are one decision to defend rather than
 * two.
 */
export const RATE_LIMIT_VIOLATION_RETENTION_DAYS = 90;

const BATCH_SIZE = 500; // Firestore maximum per batch commit

/**
 * Self-budget. Exported so a test can compare it against the `timeoutSeconds`
 * the wrapper declares, rather than re-typing the same arithmetic — a test that
 * re-types it stays green when this constant is raised past the platform
 * timeout, which is the one thing it exists to catch.
 */
export const MAX_EXECUTION_TIME_MS = 8 * 60 * 1000;

/**
 * Delete `rate_limit_violation` rows older than the retention window.
 *
 * `now` is injectable so a test can pin the cutoff without pinning the clock.
 *
 * Needs the composite index on (`type` ASC, `timestamp` ASC) — an equality and
 * a range on different fields is not served by the automatic single-field
 * indexes. Before this, `system_events` had no index entries at all.
 */
export async function pruneRateLimitViolations(
  db: admin.firestore.Firestore,
  now: admin.firestore.Timestamp = admin.firestore.Timestamp.now()
): Promise<number> {
  const startTime = Date.now();
  const cutoffDate = new Date(now.toMillis());
  cutoffDate.setDate(
    cutoffDate.getDate() - RATE_LIMIT_VIOLATION_RETENTION_DAYS
  );
  const cutoff = admin.firestore.Timestamp.fromDate(cutoffDate);

  logger.info(
    `Starting system_events retention: deleting ${PRUNED_TYPE} rows older ` +
      `than ${cutoffDate.toISOString()}`
  );

  let deletedCount = 0;

  // Delete-by-query, the `cleanup-rate-limits.ts` shape: each page selects up
  // to BATCH_SIZE matching rows, deletes them, then re-queries. Deleted rows
  // stop matching, so the result set shrinks each pass and no cursor is needed.
  while (true) {
    // Stop before the function timeout. Truncating is safe here — deletes are
    // durable and the next weekly run resumes from the same predicate; there is
    // no cursor to lose. This is the opposite of the probing sweeps in the
    // erasure path, which must DECLINE above their cap rather than truncate,
    // because a truncated sweep would report a clean erasure over rows it never
    // looked at. Nothing here reports completeness.
    if (Date.now() - startTime > MAX_EXECUTION_TIME_MS) {
      logger.warn(
        `system_events retention: stopping after ${deletedCount} deletes to ` +
          `stay inside the function timeout; the next run continues.`
      );
      break;
    }

    const snapshot = await db
      .collection(SYSTEM_EVENTS)
      .where("type", "==", PRUNED_TYPE)
      .where("timestamp", "<", cutoff)
      .limit(BATCH_SIZE)
      .get();

    if (snapshot.empty) break;

    const batch = db.batch();
    for (const doc of snapshot.docs) {
      batch.delete(doc.ref);
    }
    await batch.commit();
    deletedCount += snapshot.size;
    logger.debug(`Committed batch of ${snapshot.size} ${PRUNED_TYPE} deletes`);

    // A short page means the expired set is drained.
    if (snapshot.size < BATCH_SIZE) break;
  }

  const elapsedMs = Date.now() - startTime;
  logger.info(
    `system_events retention complete: deleted ${deletedCount} ${PRUNED_TYPE} ` +
      `rows in ${(elapsedMs / 1000).toFixed(1)}s`
  );

  return deletedCount;
}

/**
 * Prune, then write the run receipt. This is the whole job.
 *
 * Extracted from the `onSchedule` wrapper for one reason: an `onSchedule`
 * callback cannot be invoked from a unit test, so a receipt written inside it
 * is pinned by nothing — a test that re-types the same object literal asserts
 * its own literal and stays green through any rename in production. The sibling
 * split is `cleanupOldRateLimitsCore` in `cleanup-rate-limits.ts`.
 *
 * `executedAt` and `totalDeleted` are not free naming: `runOpsSnapshot` sums
 * `totalDeleted ?? deletionAuditDeletedCount`, and both it and the admin
 * ops-log tab order on `executedAt`. A row spelled any other way is invisible
 * to both with no error anywhere.
 *
 * A run that throws mid-prune writes no receipt, so that week under-reports in
 * the ops log even though the rows it did delete are gone for good. Same shape
 * as `audit_logs/purge-expired.ts`.
 */
export async function runSystemEventsCleanup(
  db: admin.firestore.Firestore,
  now: admin.firestore.Timestamp = admin.firestore.Timestamp.now()
): Promise<number> {
  const totalDeleted = await pruneRateLimitViolations(db, now);

  await db.collection(SYSTEM_EVENTS).add({
    type: "system_events_cleanup",
    totalDeleted,
    executedAt: admin.firestore.FieldValue.serverTimestamp(),
  });

  return totalDeleted;
}

/**
 * Weekly `system_events` retention.
 *
 * Schedule: 0 4 * * 0 (Sunday 04:00 UTC). The boundary that fixes this is
 * `opsSnapshot`, which reads the current UTC day's `system_events` at 06:00 and
 * needs every writer settled before it — `maintenance-dispatchers.ts` states
 * that constraint and names 05:00 Sunday as the day's latest writer.
 *
 * `timeoutSeconds` is DECLARED rather than defaulted. The v2 default is 60s,
 * and `cleanup-rate-limits.ts` and `cleanup-shared-content-metadata.ts` each
 * carry an 8-minute self-budget that has therefore never been reachable. This
 * job's budget is real because of this line.
 */
export const cleanupOldSystemEvents = onSchedule(
  { schedule: "0 4 * * 0", timeZone: "UTC", timeoutSeconds: 540 },
  async () => {
    try {
      await runSystemEventsCleanup(admin.firestore());
    } catch (e) {
      logger.error("system_events retention failed", e);
      throw e;
    }
  }
);
