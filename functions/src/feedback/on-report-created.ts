/**
 * BP1: Content moderation pipeline entry point.
 *
 * Triggered when a user submits a report (content moderation report).
 * - Increments a strike counter on the reported user (if known)
 * - Writes an admin system_events entry flagging review required
 * - Logs a moderator-email payload when MODERATOR_EMAIL is configured
 *
 * Apple App Store guideline 1.2 and Google Play UGC policy require a
 * moderator path with 24-hour action capability. This trigger is the entry
 * point; actioning happens via the in-app moderator review screen.
 *
 * IDEMPOTENCY (pre-release audit WS3): `onDocumentCreated` is at-least-once —
 * the same event can be delivered more than once. The old handler used
 * `increment(1)` + `arrayUnion({..., createdAt: now()})` + `.add()`, all of
 * which double-applied on a retry: inflated `totalReports` (could trip the
 * auto-flag threshold a step early) and duplicate `system_events` rows in the
 * moderator dashboard. This version is idempotent:
 *   - the strike increment is guarded by a per-event marker claimed in the
 *     SAME transaction, so a retried delivery never re-counts;
 *   - `reportHistory` entries are deterministic (no per-run timestamp) so
 *     arrayUnion dedupes;
 *   - system_events use deterministic doc ids + set(merge) so retries
 *     overwrite rather than duplicate.
 * Re-throwing for retry is therefore safe.
 *
 * Email delivery is still stubbed (logged at info) until email infra lands —
 * tracked by BUT-417. Do NOT block report intake on that.
 */

import { onDocumentCreated } from "firebase-functions/v2/firestore";
import { logger } from "firebase-functions/logger";
import * as admin from "firebase-admin";

const db = admin.firestore();

/** Marker TTL — aligns with the 180-day audit-log retention. */
const MARKER_RETENTION_DAYS = 180;

const MODERATION_THRESHOLD = 5;

export interface ReportData {
  reporterId: string;
  contentOwnerId?: string;
  contentType: string;
  contentId: string;
  reason: string;
  status?: string;
}

/**
 * Idempotent core — exposed for tests. Safe to call more than once for the
 * same [eventId]: the strike counter is incremented at most once per event.
 */
export async function processReport(
  database: admin.firestore.Firestore,
  params: { reportId: string; eventId: string; report: ReportData },
): Promise<void> {
  const { reportId, eventId, report } = params;
  const { reporterId, contentOwnerId, contentType, contentId, reason } = report;
  const status = report.status ?? "new";

  let totalReports = 0;

  // Strike counter — only meaningful when we know who owns the content.
  if (contentOwnerId) {
    const moderationRef = database.collection("user_moderation").doc(contentOwnerId);
    const markerRef = database.collection("report_processing_markers").doc(eventId);

    await database.runTransaction(async (tx) => {
      const [markerSnap, modSnap] = await Promise.all([
        tx.get(markerRef),
        tx.get(moderationRef),
      ]);
      const current = (modSnap.data()?.totalReports as number | undefined) ?? 0;

      // Already processed on a prior delivery — read the count for the
      // threshold check below but do NOT re-increment.
      if (markerSnap.exists) {
        totalReports = current;
        return;
      }

      totalReports = current + 1;
      tx.set(
        moderationRef,
        {
          totalReports: admin.firestore.FieldValue.increment(1),
          lastReportedAt: admin.firestore.FieldValue.serverTimestamp(),
          // Deterministic entry (no per-run timestamp) so arrayUnion dedupes
          // even if this ever runs outside the marker guard.
          reportHistory: admin.firestore.FieldValue.arrayUnion({
            reportId,
            reporterId,
            reason,
            contentType,
            contentId,
          }),
        },
        { merge: true },
      );
      tx.set(markerRef, {
        reportId,
        processedAt: admin.firestore.FieldValue.serverTimestamp(),
        expireAt: admin.firestore.Timestamp.fromDate(
          new Date(Date.now() + MARKER_RETENTION_DAYS * 24 * 60 * 60 * 1000),
        ),
      });
    });

    if (totalReports >= MODERATION_THRESHOLD) {
      // Structured + uid-prefix only — never interpolate a full UID (PII) into
      // a log string (lands unredactable in Cloud Logging textPayload).
      logger.warn("moderation_threshold_reached", {
        owner_prefix: contentOwnerId.slice(0, 6),
        totalReports,
      });
      // Deterministic id → retries (or repeated threshold crossings) update one
      // alert doc instead of spamming duplicates.
      await database
        .collection("system_events")
        .doc(`moderation_threshold_${contentOwnerId}`)
        .set(
          {
            type: "moderation_threshold_reached",
            severity: "critical",
            timestamp: admin.firestore.FieldValue.serverTimestamp(),
            details: {
              userId: contentOwnerId,
              totalReports,
              action: "review_required",
            },
          },
          { merge: true },
        );
    }
  }

  // Admin system event — deterministic id so a retried delivery overwrites the
  // same doc rather than duplicating it in the moderator dashboard.
  await database
    .collection("system_events")
    .doc(`content_report_${reportId}`)
    .set(
      {
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
      },
      { merge: true },
    );
}

export const onReportCreated = onDocumentCreated(
  "reports/{reportId}",
  async (event) => {
    const reportData = event.data?.data();
    if (!reportData) return;
    const reportId = event.params.reportId;

    // Field names match the Dart ContentReport model
    // (lib/models/social/content_report.dart).
    const report: ReportData = {
      reporterId: reportData.reporterId as string,
      contentOwnerId: reportData.contentOwnerId as string | undefined,
      contentType: reportData.contentType as string,
      contentId: reportData.contentId as string,
      reason: reportData.reason as string,
      status: (reportData.status as string) ?? "new",
    };

    // Structured log with uid PREFIXES only (reporterId/contentOwnerId are
    // Firebase UIDs = PII; contentId/reason/status are not).
    logger.info("report_received", {
      reportId,
      reporter_prefix: report.reporterId?.slice(0, 6),
      owner_prefix: report.contentOwnerId?.slice(0, 6) ?? "unknown",
      contentType: report.contentType,
      contentId: report.contentId,
      reason: report.reason,
      status: report.status,
    });

    try {
      await processReport(db, { reportId, eventId: event.id, report });

      // Email notification — stubbed until email infra lands (BUT-417).
      const moderatorEmail = process.env.MODERATOR_EMAIL;
      if (moderatorEmail) {
        logger.info(
          `[moderation-email:TODO] would dispatch to ${moderatorEmail} — ` +
            `report=${reportId} type=${report.contentType} reason=${report.reason}`,
        );
      } else {
        logger.warn(
          `[moderation-email] MODERATOR_EMAIL env var not set; skipping ` +
            `notification for report ${reportId}`,
        );
      }

      logger.info(`Report ${reportId} processed successfully`);
    } catch (error) {
      logger.error(`Failed to process report ${reportId}:`, error);
      throw error; // Retry — idempotent, so re-delivery is safe.
    }
  },
);
