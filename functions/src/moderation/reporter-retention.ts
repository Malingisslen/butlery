/**
 * Ends the retention of a report whose REPORTER has erased their account.
 *
 * `deleteUserReports` keeps an open case's report with the reporter's uid
 * removed and stamps `reporterRetainUntil`. What is left can still single the
 * reporter out, and their free text is on it, so it is theirs and it must end
 * (Malin, 2026-09-18): when the case CLOSES, or at the latest when
 * `reporterRetainUntil` passes, the report and its two derived rows are
 * deleted — the same outcome as a reporter erasing after the case closed.
 *
 * The reporter's cap wins over a legal hold on the REPORTED person (Malin,
 * 2026-09-18): the rows go on the reporter's date even while that hold stands,
 * and the hold may then lift early. Both notices said "at the latest", so both
 * stay true.
 */

import * as admin from "firebase-admin";
import { logger } from "firebase-functions/logger";
import { isClosedReportStatus, REPORTS } from "./report-status";

const SYSTEM_EVENTS = "system_events";
const USER_MODERATION = "user_moderation";
const REPORT_HISTORY = "report_history";

/**
 * Cap on one run. Declines above it rather than truncating, like every sibling
 * cap in this domain: a truncated read is a run that reports itself clean over
 * rows it never looked at.
 */
export const MAX_RETAINED_REPORT_SWEEP_ROWS = 500;

/**
 * Wall-clock budget, inside `TASK_TIMEOUT_MS`. `runTaskChain` aborts the whole
 * daily chain on a timeout, and this task sits near its head. Stopping early
 * keeps a report one more day, which is the direction this build errs in.
 */
const SWEEP_DEADLINE_MS = 45_000;

export interface RetainedReportSweepResult {
  examined: number;
  deleted: number;
  failed: number;
  declined: boolean;
  deferred: boolean;
}

/** Deletes one retained report and the rows derived from it, atomically. */
async function finishRetainedReport(
  db: admin.firestore.Firestore,
  report: admin.firestore.QueryDocumentSnapshot,
): Promise<void> {
  const reportId = report.id;
  const ownerId = report.get("contentOwnerId") as string | null | undefined;
  const batch = db.batch();

  batch.delete(db.collection(SYSTEM_EVENTS).doc(`content_report_${reportId}`));
  if (ownerId) {
    batch.delete(
      db
        .collection(USER_MODERATION)
        .doc(ownerId)
        .collection(REPORT_HISTORY)
        .doc(reportId),
    );
  }
  batch.delete(report.ref);
  await batch.commit();
}

/**
 * The daily pass. A retained report is finished when its case has closed or
 * its cap has passed; an open one inside its cap is left alone.
 *
 * Selected on `reporterId == null`, not on `reporterRetainUntil`: the `reports`
 * create rule requires `reporterId == request.auth.uid` and the update rule
 * forbids changing it, so only the erasure cascade produces a null. A client
 * can put any field it likes on its own report, and selecting on one of those
 * would let it fill this run's cap and switch the sweep off, or plant a past
 * date and have its report deleted.
 *
 * No `audit_logs` row: the account is gone, so there is no subject uid to file
 * one under. The `cascade_anonymize` row written at the erasure carries the
 * report id.
 */
export async function sweepRetainedReporterReports(
  db: admin.firestore.Firestore,
  now: Date = new Date(),
  /** Injectable so the budget branch is reachable from a test. */
  deadlineMs: number = SWEEP_DEADLINE_MS,
): Promise<RetainedReportSweepResult> {
  const snap = await db
    .collection(REPORTS)
    .where("reporterId", "==", null)
    .limit(MAX_RETAINED_REPORT_SWEEP_ROWS + 1)
    .get();

  if (snap.size > MAX_RETAINED_REPORT_SWEEP_ROWS) {
    logger.error("[reporter-retention] implausible row count; not sweeping", {
      rows: snap.size,
    });
    return { examined: 0, deleted: 0, failed: 0, declined: true, deferred: false };
  }

  let examined = 0;
  let deleted = 0;
  let failed = 0;
  let deferred = false;
  const startedAt = Date.now();

  for (const doc of snap.docs) {
    if (Date.now() - startedAt >= deadlineMs) {
      deferred = true;
      logger.warn("[reporter-retention] out of budget; rest deferred a day", {
        examined,
        remaining: snap.size - examined,
      });
      break;
    }
    examined += 1;

    const until = doc.get("reporterRetainUntil");
    if (!(until instanceof admin.firestore.Timestamp)) {
      logger.error("[reporter-retention] kept report has no cap; skipping", {
        report_prefix: doc.id.slice(0, 6),
      });
      continue;
    }
    const capPassed = until.toDate() <= now;
    if (!capPassed && !isClosedReportStatus(doc.get("status"))) continue;

    // Per-row isolation: one bad row must not stop every row after it, the
    // same page in the same order, every day.
    try {
      await finishRetainedReport(db, doc);
      deleted += 1;
    } catch (err) {
      failed += 1;
      logger.error("[reporter-retention] could not finish one report", {
        report_prefix: doc.id.slice(0, 6),
        errCode: (err as { code?: number | string }).code ?? null,
        errName: err instanceof Error ? err.name : typeof err,
      });
    }
  }

  return { examined, deleted, failed, declined: false, deferred };
}

/**
 * Scheduled seam. `admin.firestore()` is resolved per call so importing this
 * module does not demand an initialised app.
 */
export async function runSweepRetainedReporterReports(): Promise<void> {
  const result = await sweepRetainedReporterReports(admin.firestore());
  logger.info("[reporter-retention] sweep complete", { ...result });
}
