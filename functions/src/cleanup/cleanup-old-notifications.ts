/**
 * Notification Cleanup Cloud Function
 *
 * Scheduled weekly to delete old notification tracking data (delivery, engagement, history).
 * These collections accumulate per-notification records that are only useful for
 * short-term analytics and deduplication — not needed after 90 days.
 */

import { onSchedule } from "firebase-functions/v2/scheduler";
import { logger } from "firebase-functions/logger";
import * as admin from "firebase-admin";
import { batchDeleteDocs } from "../shared/batch-delete";
import { BATCH_LIMIT } from "../shared/batch-update";

const RETENTION_DAYS = 90;

/**
 * Upper bound on drain passes per collection. The loop normally terminates
 * because each committed delete drops rows out of the `< cutoff` filter, so a
 * healthy drain shrinks the window every pass. This cap is a safety net for the
 * pathological case where a full page keeps coming back without shrinking (a
 * delete that silently fails to remove matching rows) — without it the `for(;;)`
 * loop would spin until the platform timeout, re-issuing the same query and
 * re-committing writes. 20 000 passes × BATCH_LIMIT (500) = 10M docs, far beyond
 * any realistic weekly residue, so a legitimate large drain never hits it; only
 * a non-shrinking page does. On hit we log and stop (partial cleanup is fine —
 * the next weekly run resumes from whatever remains).
 */
const MAX_DRAIN_ITERATIONS = 20000;

interface CleanupResult {
  collection: string;
  deletedCount: number;
}

export async function cleanupCollection(
  db: admin.firestore.Firestore,
  collectionName: string,
  timestampField: string,
  cutoffTimestamp: admin.firestore.Timestamp,
  maxIterations: number = MAX_DRAIN_ITERATIONS,
): Promise<CleanupResult> {
  // Drain every expired doc, not just the first page. Because each page is
  // deleted before the next query runs, the same `timestampField < cutoff`
  // filter returns fresh expired rows each pass (deleted docs no longer match),
  // so a collection with more than one page of residue is fully cleaned instead
  // of being silently truncated at the old 10k cap (same gap class as the
  // BUT-1372 shared-content-metadata fix). No startAfter cursor is needed — the
  // delete itself advances the window, and it would in fact be wrong here since
  // the cursor doc gets deleted. Paging at BATCH_LIMIT keeps at most one write
  // batch's worth of docs in memory; a platform-timeout mid-drain is self-healing
  // because committed deletes drop out of the filter before the next weekly run.
  let deletedCount = 0;
  let iterations = 0;

  for (;;) {
    // Bounded-iteration guard: a non-shrinking full page (deletes not removing
    // matching rows) would otherwise loop until the platform timeout.
    if (iterations >= maxIterations) {
      logger.error(
        `cleanupCollection(${collectionName}): hit max drain iterations ` +
          `(${maxIterations}) — page not shrinking, aborting to avoid an ` +
          `unbounded loop`,
        { deletedCount }
      );
      break;
    }
    iterations++;

    const snapshot = await db
      .collection(collectionName)
      .where(timestampField, "<", cutoffTimestamp)
      .limit(BATCH_LIMIT)
      .get();

    if (snapshot.empty) {
      break;
    }

    deletedCount += await batchDeleteDocs(db, snapshot);

    if (snapshot.size < BATCH_LIMIT) {
      break;
    }
  }

  return { collection: collectionName, deletedCount };
}

/**
 * Weekly cleanup of old notification tracking data
 *
 * Schedule: 0 4 * * 0 (Weekly on Sunday at 4 AM UTC)
 */
export const cleanupOldNotifications = onSchedule(
  { schedule: "0 4 * * 0", timeZone: "UTC" },
  async () => {
    const db = admin.firestore();

    const cutoffDate = new Date();
    cutoffDate.setDate(cutoffDate.getDate() - RETENTION_DAYS);
    const cutoffTimestamp = admin.firestore.Timestamp.fromDate(cutoffDate);

    logger.info(
      `Starting notification cleanup — deleting records older than ${cutoffDate.toISOString()}`
    );

    try {
      const results = await Promise.all([
        cleanupCollection(db, "notification_history", "sentAt", cutoffTimestamp),
        cleanupCollection(db, "notification_delivery", "sentAt", cutoffTimestamp),
        cleanupCollection(db, "notification_engagement", "timestamp", cutoffTimestamp),
      ]);

      const totalDeleted = results.reduce((sum, r) => sum + r.deletedCount, 0);

      if (totalDeleted > 0) {
        await db.collection("system_events").add({
          type: "notification_cleanup",
          results,
          totalDeleted,
          retentionDays: RETENTION_DAYS,
          cutoffDate: cutoffDate.toISOString(),
          executedAt: admin.firestore.FieldValue.serverTimestamp(),
        });
      }

      logger.info(
        `Notification cleanup complete: ${totalDeleted} total records deleted`,
        { results }
      );

    } catch (e) {
      logger.error("Notification cleanup failed", e);
      throw e;
    }
  }
);
