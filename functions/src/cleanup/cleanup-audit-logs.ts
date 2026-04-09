/**
 * Audit Log Cleanup Cloud Function
 *
 * Scheduled to run weekly on Sunday at 3 AM UTC to delete old audit logs
 * based on the configured retention period.
 *
 * GDPR Compliance Notes (Articles 5, 17, 30):
 * - Article 5(1)(e): Data should not be kept longer than necessary (data minimization)
 * - Article 17: Right to erasure - audit logs of deleted user data should eventually be cleaned
 * - Article 30: Records of processing must be maintained (but not forever)
 *
 * Retention Recommendations by Data Type:
 * - Security/access logs: 90 days default (sufficient for incident investigation)
 * - User data modification logs: Consider 1-2 years for legal compliance
 * - Financial/transaction logs: May require 7 years depending on jurisdiction
 *
 * Current Settings:
 * - Default: 90 days (configurable via Remote Config 'audit_log_retention_days')
 * - Minimum: 30 days (safety floor)
 *
 * To increase retention for legal compliance, set 'audit_log_retention_days'
 * in Firebase Remote Config. For Swedish law (Bokföringslagen), financial
 * records typically require 7 years (2555 days).
 *
 * Security:
 * - Only deletes logs older than the retention period
 * - Logs deletion activity for compliance audit trail
 * - Runs with admin privileges (via service account)
 */

import * as functions from "firebase-functions";
import * as admin from "firebase-admin";
import { batchDeleteDocs } from "../shared/batch-delete";

// Retention period defaults (can be overridden by Remote Config)
const DEFAULT_RETENTION_DAYS = 90;
const MINIMUM_RETENTION_DAYS = 30; // Safety minimum

/**
 * Weekly cleanup of old audit logs
 *
 * Schedule: 0 3 * * 0 (Weekly on Sunday at 3 AM UTC)
 * Region: europe-west1 (Belgium) - same region as main functions
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

      const deletedCount = await batchDeleteDocs(db, snapshot);

      // Clean up deletion_audit_logs using expireAt TTL field (GDPR Art.5)
      const deletionAuditRef = db.collection("deletion_audit_logs");
      const now = admin.firestore.Timestamp.now();
      const deletionAuditSnapshot = await deletionAuditRef
        .where("expireAt", "<", now)
        .limit(10000)
        .get();

      const deletionAuditCount = deletionAuditSnapshot.empty
        ? 0
        : await batchDeleteDocs(db, deletionAuditSnapshot);

      if (deletionAuditCount > 0) {
        functions.logger.info(
          `Deletion audit log cleanup: deleted ${deletionAuditCount} expired entries`
        );
      }

      // Log cleanup for monitoring/alerting
      const cleanupLog = {
        type: "audit_log_cleanup",
        deletedCount,
        deletionAuditDeletedCount: deletionAuditCount,
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
