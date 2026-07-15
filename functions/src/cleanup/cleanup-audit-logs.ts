/**
 * BUT-808: Reconciled to single-source retention. The `audit_logs` collection
 * is now exclusively purged by `purgeExpiredAuditLogs` in
 * `audit_logs/purge-expired.ts` (730d for consent_* operations, 180d general).
 * This CF formerly also purged `audit_logs` on a 90d Remote-Config default,
 * which silently DEFEATED the BUT-665 730d consent retention because it ran
 * 2 hours earlier on the same Sunday schedule.
 *
 * What's left here: cleanup of the `deletion_audit_logs` collection via its
 * `expireAt` TTL field (GDPR Art. 5). That collection has its own schema
 * (records of erasure events keyed by deletedUid) and is unrelated to the
 * `audit_logs` actor history.
 *
 * The export name `cleanupOldAuditLogs` is preserved so the deployed
 * scheduler binding doesn't churn (renaming the function changes its
 * resource id, causing a re-deploy gap). The body now only handles
 * `deletion_audit_logs`.
 */

import { onSchedule } from "firebase-functions/v2/scheduler";
import { onCall, CallableRequest, HttpsError } from "firebase-functions/v2/https";
import { logger } from "firebase-functions/logger";
import * as admin from "firebase-admin";
import { batchDeleteDocs } from "../shared/batch-delete";
import { requireAdmin } from "../shared/require-admin";

/**
 * Reap `deletion_audit_logs` entries whose `expireAt` TTL is in the past.
 *
 * GDPR Art. 5: each doc carries an `expireAt` Timestamp set at write time
 * (BUT-1544 stamps it 180 days out); this helper deletes every doc already
 * past that TTL. Extracted from `cleanupOldAuditLogs` so the delete side is
 * unit-testable without the scheduler wrapper. `now` is injectable so a test
 * can pin the cutoff.
 *
 * Returns the number of expired docs deleted.
 */
export async function purgeExpiredDeletionAuditLogs(
  db: admin.firestore.Firestore,
  now: admin.firestore.Timestamp = admin.firestore.Timestamp.now()
): Promise<number> {
  const snapshot = await db
    .collection("deletion_audit_logs")
    .where("expireAt", "<", now)
    .limit(10000)
    .get();

  return snapshot.empty ? 0 : await batchDeleteDocs(db, snapshot);
}

/**
 * Weekly cleanup of expired `deletion_audit_logs` (NOT `audit_logs` — see
 * file docstring for the BUT-808 reconcile).
 *
 * Schedule: 0 3 * * 0 (Sunday 03:00 UTC). Runs 2h before
 * `purgeExpiredAuditLogs` (Sunday 05:00 UTC); the two CFs operate on
 * independent collections so order is irrelevant for correctness.
 */
export const cleanupOldAuditLogs = onSchedule(
  { schedule: "0 3 * * 0", timeZone: "UTC" },
  async () => {
    const db = admin.firestore();

    logger.info("Starting deletion_audit_logs TTL cleanup...");

    try {
      const deletionAuditCount = await purgeExpiredDeletionAuditLogs(db);

      if (deletionAuditCount > 0) {
        logger.info(
          `deletion_audit_logs cleanup: deleted ${deletionAuditCount} expired entries`
        );
      }

      // Observability — one row per run.
      await db.collection("system_events").add({
        type: "deletion_audit_log_cleanup",
        deletionAuditDeletedCount: deletionAuditCount,
        executedAt: admin.firestore.FieldValue.serverTimestamp(),
      });

      logger.info(
        `deletion_audit_logs cleanup complete: deleted ${deletionAuditCount} expired entries`
      );
    } catch (e) {
      logger.error("deletion_audit_logs cleanup failed", e);
      throw e;
    }
  }
);

/**
 * Get audit log statistics (callable for admin dashboard)
 *
 * Returns:
 * - Total audit log count
 * - Oldest log timestamp
 * - Storage estimate
 * - Logs by resource type
 */
export const getAuditLogStats = onCall(
  async (request: CallableRequest) => {
    requireAdmin(request);

    const db = admin.firestore();
    const auditLogsRef = db.collection("audit_logs");

    try {
      // Get total count (limited sampling for performance)
      const countSnapshot = await auditLogsRef.count().get();
      const totalCount = countSnapshot.data().count;

      // Get oldest log
      const oldestSnapshot = await auditLogsRef
        .orderBy("timestamp", "asc")
        .limit(1)
        .get();

      let oldestTimestamp: string | null = null;
      if (!oldestSnapshot.empty) {
        const oldest = oldestSnapshot.docs[0].data();
        oldestTimestamp = oldest.timestamp?.toDate().toISOString() || null;
      }

      // Get breakdown by resource type (sample-based)
      const recentSnapshot = await auditLogsRef
        .orderBy("timestamp", "desc")
        .limit(1000)
        .get();

      const resourceTypeCounts: { [key: string]: number } = {};
      recentSnapshot.docs.forEach((doc) => {
        const resourceType = doc.data().resourceType || "unknown";
        resourceTypeCounts[resourceType] = (resourceTypeCounts[resourceType] || 0) + 1;
      });

      return {
        totalCount,
        oldestTimestamp,
        resourceTypeCounts,
        sampleSize: recentSnapshot.size,
        estimatedStorageMB: Math.round((totalCount * 0.5) / 1024), // ~500 bytes per log
      };
    } catch (e) {
      logger.error("Failed to get audit log stats", e);
      throw new HttpsError("internal", "Failed to get stats");
    }
  }
);
