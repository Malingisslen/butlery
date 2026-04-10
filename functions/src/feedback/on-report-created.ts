/**
 * BP1: Content moderation pipeline entry point.
 *
 * Triggered when a user submits a report (content moderation report).
 * - Logs the report
 * - Increments a strike counter on the reported user
 * - Sends notification to admin (via system_events for now)
 *
 * Apple App Store requires moderation for UGC apps. This function ensures
 * reports are logged and flagged for review.
 */

import { onDocumentCreated } from "firebase-functions/v2/firestore";
import { logger } from "firebase-functions/logger";
import * as admin from "firebase-admin";

const db = admin.firestore();

export const onReportCreated = onDocumentCreated(
  "reports/{reportId}",
  async (event) => {
    const reportData = event.data?.data();
    if (!reportData) return;
    const reportId = event.params.reportId;

    const reportedUserId = reportData.reportedUserId as string;
    const reporterUserId = reportData.reporterUserId as string;
    const reason = reportData.reason as string;
    const contentType = reportData.contentType as string;
    const contentId = reportData.contentId as string;

    logger.info(
      `New report ${reportId}: ${reporterUserId} reported ${reportedUserId} ` +
      `for ${reason} on ${contentType}/${contentId}`
    );

    try {
      // Increment strike counter on reported user's moderation record
      const moderationRef = db.collection("user_moderation").doc(reportedUserId);
      await moderationRef.set(
        {
          totalReports: admin.firestore.FieldValue.increment(1),
          lastReportedAt: admin.firestore.FieldValue.serverTimestamp(),
          reportHistory: admin.firestore.FieldValue.arrayUnion({
            reportId,
            reporterUserId,
            reason,
            contentType,
            contentId,
            createdAt: admin.firestore.Timestamp.now(),
          }),
        },
        { merge: true }
      );

      // Create admin notification event
      await db.collection("system_events").add({
        type: "content_report",
        severity: "warning",
        timestamp: admin.firestore.FieldValue.serverTimestamp(),
        details: {
          reportId,
          reportedUserId,
          reporterUserId,
          reason,
          contentType,
          contentId,
          requiresReview: true,
        },
      });

      // Check if user has reached a strike threshold
      const moderationDoc = await moderationRef.get();
      const totalReports = moderationDoc.data()?.totalReports ?? 0;

      if (totalReports >= 5) {
        logger.warn(
          `User ${reportedUserId} has ${totalReports} reports — ` +
          `flagged for review`
        );

        await db.collection("system_events").add({
          type: "moderation_threshold_reached",
          severity: "critical",
          timestamp: admin.firestore.FieldValue.serverTimestamp(),
          details: {
            userId: reportedUserId,
            totalReports,
            action: "review_required",
          },
        });
      }

      logger.info(`Report ${reportId} processed successfully`);
    } catch (error) {
      logger.error(`Failed to process report ${reportId}:`, error);
      throw error; // Retry
    }
  }
);
