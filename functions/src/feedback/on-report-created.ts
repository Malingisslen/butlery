/**
 * BP1: Content moderation pipeline entry point.
 *
 * Triggered when a user submits a report (content moderation report).
 * - Increments a strike counter on the reported user (if known)
 * - Writes an admin system_events entry flagging review required
 * - Logs `moderation_review_needed`, which a Cloud Monitoring alert watches
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
 *   - system_events use deterministic doc ids + set(merge) so retries
 *     overwrite rather than duplicate.
 * Re-throwing for retry is therefore safe.
 *
 * It also keeps a text copy of the reported content (`moderation/report-evidence.ts`).
 *
 * The moderator is notified by a log-based alert policy
 * (`infrastructure/alerting/setup-gcp-alerts.sh`), not by email from here.
 */

import { onDocumentCreated } from "firebase-functions/v2/firestore";
import { logger } from "firebase-functions/logger";
import * as admin from "firebase-admin";
import {
  captureThenWithdraw,
  withdrawReporterCredit,
} from "../moderation/menu-dish-credit";
import { reportCountsAgainstOwner } from "../moderation/report-status";
import {
  checkRateLimit,
  RateLimitCheckResult,
} from "../middleware/rate_limiter";
import { hashUid } from "../shared/hash-uid";

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
  if (contentOwnerId && reportCountsAgainstOwner(reason)) {
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
      // This key set is COUPLED to two other places, and the coupling is not
      // visible from here: `firestore.rules` permits the subject's read only
      // while the document carries nothing but these keys, and the Art. 15 export
      // projects the same two. Adding a third field here makes the whole
      // document unreadable to its subject and turns their export section into
      // a failure envelope until all three are updated together.
      tx.set(
        moderationRef,
        {
          totalReports: admin.firestore.FieldValue.increment(1),
          lastReportedAt: admin.firestore.FieldValue.serverTimestamp(),
        },
        { merge: true },
      );
      // BUT-2046: one ROW per report, not an entry in an array on the parent.
      // The array carried `reporterId` — another person's uid — inside an
      // array of maps, which Firestore cannot query: no erasure path could
      // reach a reporter's uid sitting in somebody else's document, and no
      // query could read it back either. Same move BUT-1832/1835 made with
      // `voterIds`.
      //
      // The document id is the REPORT id, which is what now carries the
      // idempotency the `arrayUnion` used to: a redelivered event rewrites the
      // same row instead of appending a duplicate. It sits inside the
      // `markerSnap.exists` guard as well, so today two independent mechanisms
      // cover it — do not move this write out of the guard on the grounds that
      // the deterministic id is enough, which would thin that to one.
      tx.set(moderationRef.collection("report_history").doc(reportId), {
        reportId,
        reporterId,
        reason,
        contentType,
        contentId,
        // 180 days, the same retention as the audit logs and the marker beside
        // it. Malin's explicit call, 2026-09-08: the purpose these rows were
        // kept for — spotting a person who reports the same target over and
        // over — is deliberately not being built (ADR-0015 / BUT-2046), so
        // keeping them indefinitely would be storage without a purpose.
        expireAt: admin.firestore.Timestamp.fromDate(
          new Date(Date.now() + MARKER_RETENTION_DAYS * 24 * 60 * 60 * 1000),
        ),
      });
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

export const REPORT_RATE_OPERATION = "reportContent";
export const REPORT_CSAM_RATE_OPERATION = "reportContentCsam";
export const REPORT_MISATTRIBUTION_RATE_OPERATION = "reportContentMisattribution";

export interface ReportAdmission {
  /** Run the text copy, the strike and the `system_events` row. */
  process: boolean;
  /** Log `moderation_review_needed`, which pages the moderator. */
  page: boolean;
}

/**
 * BUT-2331: the server-side cap on how many reports one account files. Over
 * the cap a report is left in `reports` for the moderator queue, but costs no
 * text copy, strike or `system_events` row, and pages the moderator only for
 * the first such report of the UTC day.
 *
 * A `csam` report is charged to its own, looser bucket, so a flood of other
 * reports cannot use up the room a child-safety report needs. Every report is
 * processed while the limiter itself is failing: losing a genuine report costs
 * more than a few extra writes.
 */
export async function admitReport(
  database: admin.firestore.Firestore,
  params: { reportId: string; reporterId: string; reason: string },
  check: (
    userId: string,
    operation: string,
  ) => Promise<RateLimitCheckResult> = checkRateLimit,
  now: Date = new Date(),
): Promise<ReportAdmission> {
  const { reportId, reporterId, reason } = params;
  if (!reporterId) return { process: true, page: true };

  const operation =
    reason === "csam"
      ? REPORT_CSAM_RATE_OPERATION
      : reason === "misattribution"
        ? REPORT_MISATTRIBUTION_RATE_OPERATION
        : REPORT_RATE_OPERATION;
  const limit = await check(reporterId, operation);
  if (limit.allowed || limit.unavailable) return { process: true, page: true };

  // Same row shape as the limiter's own `rate_limit_violation`, so the
  // 90-day `system_events` retention removes it. The deterministic id makes
  // `create()` succeed once per reporter per UTC day: that one pages.
  const userIdHash = hashUid(reporterId);
  const dayKey = now.toISOString().slice(0, 10);
  try {
    await database
      .collection("system_events")
      .doc(`report_rate_limited_${userIdHash}_${dayKey}`)
      .create({
        type: "rate_limit_violation",
        userIdHash,
        operationType: operation,
        firstReportId: reportId,
        timestamp: admin.firestore.FieldValue.serverTimestamp(),
      });
    return { process: false, page: true };
  } catch (err) {
    const alreadyPaged = (err as { code?: number }).code === 6; // ALREADY_EXISTS
    if (!alreadyPaged) {
      logger.error("report_rate_limited_record_failed", {
        reportId,
        errCode: (err as { code?: number | string }).code ?? null,
      });
    }
    return { process: false, page: !alreadyPaged };
  }
}

export interface ReportDeps {
  admit: typeof admitReport;
  capture: typeof captureThenWithdraw;
  withdraw: typeof withdrawReporterCredit;
  process: typeof processReport;
  log: Pick<typeof logger, "info" | "warn" | "error">;
}

const defaultDeps: ReportDeps = {
  admit: admitReport,
  capture: captureThenWithdraw,
  withdraw: withdrawReporterCredit,
  process: processReport,
  log: logger,
};

/** The trigger's body after parsing; `deps` is a test seam. */
export async function handleReport(
  database: admin.firestore.Firestore,
  params: { reportId: string; eventId: string; report: ReportData },
  deps: ReportDeps = defaultDeps,
): Promise<void> {
  const { reportId, eventId, report } = params;
  const admission = await deps.admit(database, {
    reportId,
    reporterId: report.reporterId,
    reason: report.reason,
  });

  // The alert policy matches this message exactly; renaming it silences
  // the moderator notification. Logged before processing so a failed strike
  // or system_events write still notifies.
  if (admission.page) {
    deps.log.info("moderation_review_needed", {
      reportId,
      contentType: report.contentType,
      reason: report.reason,
      rateLimited: !admission.process,
    });
  }
  if (!admission.process) {
    deps.log.warn("report_rate_limited", {
      reportId,
      reporter_hash: hashUid(report.reporterId),
    });
    // BUT-2339: the cap drops moderator work, never the reporter's own name
    // coming off a dish; the app has already told them it is removed.
    if (report.contentType === "menu_dish" && report.reason === "misattribution") {
      const credit = await deps.withdraw(database, reportId);
      deps.log.info("report_evidence", { reportId, outcome: "rate_limited", credit });
    }
    return;
  }

  // BUT-1842: the text copy runs beside the strike, not before it, so a slow
  // capture cannot spend the strike's time budget.
  const [evidence, processed] = await Promise.allSettled([
    deps.capture(database, reportId, report),
    deps.process(database, { reportId, eventId, report }),
  ]);
  if (evidence.status === "fulfilled") {
    const { outcome, credit } = evidence.value;
    deps.log.info("report_evidence", { reportId, outcome, credit });
  }

  if (processed.status === "rejected") {
    deps.log.error(`Failed to process report ${reportId}:`, processed.reason);
    throw processed.reason; // Idempotent, so a re-delivery is safe.
  }
  deps.log.info(`Report ${reportId} processed successfully`);
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

    await handleReport(db, { reportId, eventId: event.id, report });
  },
);
