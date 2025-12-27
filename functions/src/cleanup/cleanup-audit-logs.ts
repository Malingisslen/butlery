/**
 * Audit Log Cleanup Cloud Function
 *
 * Scheduled to run weekly on Sunday at 3 AM UTC to delete old audit logs
 * based on the configured retention period.
 *
 * GDPR Compliance Notes:
 * - Most jurisdictions require 1-7 year audit log retention
 * - Default retention: 90 days (configurable via Remote Config)
 * - This function respects GDPR Article 30 requirements while preventing
 *   unbounded storage growth
 *
 * Security:
 * - Only deletes logs older than the retention period
 * - Logs deletion activity for compliance audit trail
 * - Runs with admin privileges (via service account)
 */

import * as functions from "firebase-functions";
import * as admin from "firebase-admin";

// Retention period defaults (can be overridden by Remote Config)
const DEFAULT_RETENTION_DAYS = 90;
const MINIMUM_RETENTION_DAYS = 30; // Safety minimum

/**
 * Weekly cleanup of old audit logs
 *
 * Schedule: 0 3 * * 0 (Weekly on Sunday at 3 AM UTC)
 * Region: europe-west1 (Stockholm) - same region as main functions
 *
 * Batch processing:
 * - Queries logs older than retention period
 * - Deletes in batches of 500 (Firestore limit)
 * - Logs cleanup metrics for monitoring
 */
export const cleanupOldAuditLogs = functions
  .region("europe-west1")
  .pubsub.schedule("0 3 * * 0") // Weekly on Sunday at 3 AM UTC
  .timeZone("UTC")
  .onRun(async () => {
    const db = admin.firestore();
    const auditLogsRef = db.collection("audit_logs");

    functions.logger.info("Starting audit log cleanup...");

    // Get retention days from Remote Config or use default
    let retentionDays = DEFAULT_RETENTION_DAYS;
    try {
      const remoteConfig = admin.remoteConfig();
      const template = await remoteConfig.getTemplate();
      const retentionParam = template.parameters["audit_log_retention_days"];
      if (retentionParam?.defaultValue) {
        const value = (retentionParam.defaultValue as { value: string }).value;
        const parsed = parseInt(value, 10);
        if (!isNaN(parsed) && parsed >= MINIMUM_RETENTION_DAYS) {
          retentionDays = parsed;
        }
      }
    } catch (e) {
      functions.logger.warn(
        `Could not fetch Remote Config, using default retention: ${DEFAULT_RETENTION_DAYS} days`,
        e
      );
    }

    functions.logger.info(`Retention period: ${retentionDays} days`);

    // Calculate cutoff timestamp
    const cutoffDate = new Date();
    cutoffDate.setDate(cutoffDate.getDate() - retentionDays);
    const cutoffTimestamp = admin.firestore.Timestamp.fromDate(cutoffDate);

    functions.logger.info(`Deleting audit logs older than ${cutoffDate.toISOString()}`);

    try {
      // Query old audit logs
      const snapshot = await auditLogsRef
        .where("timestamp", "<", cutoffTimestamp)
        .limit(10000) // Process up to 10k per run
        .get();

      if (snapshot.empty) {
        functions.logger.info("No old audit logs to delete");
        return null;
      }

      let deletedCount = 0;
      let batch = db.batch();
      let batchCount = 0;

      for (const doc of snapshot.docs) {
        batch.delete(doc.ref);
        batchCount++;
        deletedCount++;

        // Commit every 500 operations (Firestore batch limit)
        if (batchCount >= 500) {
          await batch.commit();
          batch = db.batch();
          batchCount = 0;
          functions.logger.info(`Committed batch of 500 deletions`);
        }
      }

      // Commit remaining deletions
      if (batchCount > 0) {
        await batch.commit();
      }

      // Log cleanup for monitoring/alerting
      const cleanupLog = {
        type: "audit_log_cleanup",
        deletedCount,
        totalScanned: snapshot.size,
        retentionDays,
        cutoffDate: cutoffDate.toISOString(),
        executedAt: admin.firestore.FieldValue.serverTimestamp(),
      };

      // Store cleanup event in a separate collection for tracking
      await db.collection("system_events").add(cleanupLog);

      functions.logger.info(
        `Audit log cleanup complete: deleted ${deletedCount} entries older than ${retentionDays} days`
      );

      return null;
    } catch (e) {
      functions.logger.error("Audit log cleanup failed", e);
      throw e; // Let Cloud Functions retry
    }
  });

/**
 * Get audit log statistics (callable for admin dashboard)
 *
 * Returns:
 * - Total audit log count
 * - Oldest log timestamp
 * - Storage estimate
 * - Logs by resource type
 */
export const getAuditLogStats = functions
  .region("europe-west1")
  .https.onCall(async (data, context) => {
    // Verify admin access
    if (!context.auth?.token.admin) {
      throw new functions.https.HttpsError(
        "permission-denied",
        "Admin access required"
      );
    }

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
      functions.logger.error("Failed to get audit log stats", e);
      throw new functions.https.HttpsError("internal", "Failed to get stats");
    }
  });
