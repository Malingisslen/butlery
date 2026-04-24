/**
 * BP1: Content moderation pipeline entry point.
 *
 * Triggered when a user submits a report (content moderation report).
 * - Logs the report to functions logger
 * - Increments a strike counter on the reported user (if known)
 * - Writes an admin system_events entry flagging review required
 * - Sends an email notification to the moderator address when configured
 *
 * Apple App Store guideline 1.2 and Google Play UGC policy require a
 * moderator path with 24-hour action capability. This trigger is the
 * entry point for that pipeline; actioning is performed via the
 * in-app moderator review screen (see lib/views/admin/).
 *
 * Email delivery: reads the moderator address from env var MODERATOR_EMAIL.
 * Actual send is TODO — SendGrid / nodemailer / Firebase extension has not
 * been wired up yet. Until it is, the payload is logged at info level so
 * a human operator can monitor via Cloud Logging. Do NOT block report
 * intake on email-infra choice; this is an async notification channel.
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

    // Field names match the Dart ContentReport model (lib/models/social/content_report.dart).
    const reporterId = reportData.reporterId as string;
    const contentOwnerId = reportData.contentOwnerId as string | undefined;
    const contentType = reportData.contentType as string;
    const contentId = reportData.contentId as string;
    const reason = reportData.reason as string;
    const status = (reportData.status as string) ?? "new";

    logger.info(
      `New report ${reportId}: ${reporterId} reported ${contentType}/${contentId} ` +
      `(owner=${contentOwnerId ?? "unknown"}, reason=${reason}, status=${status})`
    );

    try {
      // Strike counter — only meaningful when we know who owns the content.
      if (contentOwnerId) {
        const moderationRef = db.collection("user_moderation").doc(contentOwnerId);
        await moderationRef.set(
          {
            totalReports: admin.firestore.FieldValue.increment(1),
            lastReportedAt: admin.firestore.FieldValue.serverTimestamp(),
            reportHistory: admin.firestore.FieldValue.arrayUnion({
              reportId,
              reporterId,
              reason,
              contentType,
              contentId,
              createdAt: admin.firestore.Timestamp.now(),
            }),
          },
          { merge: true }
        );

        const moderationDoc = await moderationRef.get();
        const totalReports = moderationDoc.data()?.totalReports ?? 0;
        if (totalReports >= 5) {
          logger.warn(
            `User ${contentOwnerId} has ${totalReports} reports — flagged for review`
          );
          await db.collection("system_events").add({
            type: "moderation_threshold_reached",
            severity: "critical",
            timestamp: admin.firestore.FieldValue.serverTimestamp(),
            details: {
              userId: contentOwnerId,
              totalReports,
              action: "review_required",
            },
          });
        }
      }

      // Admin system event — picked up by the in-app moderator review screen
      // and by any downstream alerting/Ops dashboards.
      await db.collection("system_events").add({
        type: "content_report",
        severity: "warning",
        timestamp: admin.firestore.FieldValue.serverTimestamp(),
        details: {
          reportId,
          reporterId,
          contentOwnerId: contentOwnerId ?? null,
          reason,
          contentType,
          contentId,
          status,
          requiresReview: true,
        },
      });

      // Email notification. Stubbed until email infra lands (SendGrid /
      // nodemailer / Firebase Trigger Email extension). Logging the payload
      // at info level keeps the moderation pipeline functional for now —
      // operators can subscribe to Cloud Logging alerts on this entry.
      const moderatorEmail = process.env.MODERATOR_EMAIL;
      if (moderatorEmail) {
        logger.info(
          `[moderation-email:TODO] would dispatch to ${moderatorEmail} — ` +
          `report=${reportId} type=${contentType} reason=${reason}`
        );
        // TODO(BUT-417): wire actual send (SendGrid / Firebase Trigger Email).
      } else {
        logger.warn(
          `[moderation-email] MODERATOR_EMAIL env var not set; skipping ` +
          `notification for report ${reportId}`
        );
      }

      logger.info(`Report ${reportId} processed successfully`);
    } catch (error) {
      logger.error(`Failed to process report ${reportId}:`, error);
      throw error; // Retry
    }
  }
);
