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

const RETENTION_DAYS = 90;
const MAX_DOCS_PER_COLLECTION = 10000;

interface CleanupResult {
  collection: string;
  deletedCount: number;
}

async function cleanupCollection(
  db: admin.firestore.Firestore,
  collectionName: string,
  timestampField: string,
  cutoffTimestamp: admin.firestore.Timestamp,
): Promise<CleanupResult> {
  const snapshot = await db
    .collection(collectionName)
    .where(timestampField, "<", cutoffTimestamp)
    .limit(MAX_DOCS_PER_COLLECTION)
    .get();

  if (snapshot.empty) {
    return { collection: collectionName, deletedCount: 0 };
  }

  const deletedCount = await batchDeleteDocs(db, snapshot);
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
