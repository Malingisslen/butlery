/**
 * BUT-1528: a moderator opens a closed report again.
 *
 * Admin only. Malin's calls, 2026-10-20: the case goes back to the queue and
 * nothing else changes; the action the decision took is put back on the
 * report, so closing it again keeps that decision unless the moderator
 * changes it. Nobody is told until there is a new decision.
 *
 * Refused when:
 * - the report has an appeal, open or answered (D1): the appeal is the review;
 * - the reporter has erased their account: that report is deleted when its
 *   case closes (ADR-0016), and a reopen would keep it past that;
 * - the reported person is gone from it: there is nobody left to decide about.
 *
 * Moves `closed → actioned` with the Admin SDK; the client rules forbid
 * leaving `closed`. A fresh copy of the content, as it is now, is taken after
 * the commit and deleted again by the next close.
 *
 * Region: inherits europe-west1 via `setGlobalOptions` in index.ts.
 */

import { onCall, CallableRequest, HttpsError } from "firebase-functions/v2/https";
import { logger } from "firebase-functions/logger";
import * as admin from "firebase-admin";
import { enforceRateLimit } from "../middleware/rate_limiter";
import { requireAdmin } from "../shared/require-admin";
import { appealRef, canHoldAppeal, isSafeDocId } from "./appeals";
import { revisionOf, roundOf, stageModerationAudit } from "./decision-revision";
import { MODERATION_DECISIONS, MODERATOR_ACTIONS } from "./report-decision";
import { captureReportEvidence, REPORT_EVIDENCE } from "./report-evidence";
import { isClosedReportStatus, REPORTS } from "./report-status";

export const RATE_LIMIT_KEY = "reopenReport";

/** Why a report cannot be reopened; the app names each one. */
export type ReopenBlock = "report_gone" | "not_closed" | "appealed" | "reporter_erased" |
  "owner_erased" | "no_decision";

export interface ReopenReportDeps {
  rateLimit: (uid: string, operation: string) => Promise<void>;
  run: (adminUid: string, reportId: string) => Promise<{ round: number }>;
  captureEvidence: (reportId: string) => Promise<unknown>;
}

export function parseReopenReport(data: unknown): string {
  const raw = (data ?? {}) as Record<string, unknown>;
  if (!isSafeDocId(raw.reportId)) throw new HttpsError("invalid-argument", "invalid_report_id");
  return raw.reportId;
}

export async function handleReopenReport(
  request: CallableRequest<unknown>,
  deps: ReopenReportDeps,
): Promise<{ ok: true }> {
  requireAdmin(request);
  const adminUid = request.auth!.uid;
  const reportId = parseReopenReport(request.data);
  await deps.rateLimit(adminUid, RATE_LIMIT_KEY);
  const { round } = await deps.run(adminUid, reportId);
  const evidence = await deps.captureEvidence(reportId);
  logger.info("report_reopened", { report_prefix: reportId.slice(0, 6), round, evidence });
  return { ok: true };
}

export const reopenReport = onCall(
  {
    timeoutSeconds: 30,
    cors: ["https://butlery.app", "https://www.butlery.app"],
    enforceAppCheck: true,
  },
  (request) => {
    const db = admin.firestore();
    return handleReopenReport(request, {
      rateLimit: (uid, operation) => enforceRateLimit(uid, operation),
      run: (adminUid, reportId) => runReopenReportWithDb(db, adminUid, reportId),
      captureEvidence: (reportId) => captureReportEvidence(db, reportId),
    });
  },
);

/**
 * The block on reopening [report], or null when it may be reopened. Shared
 * with `listClosedReports`, so the list never offers what this refuses.
 */
export function reopenBlock(
  report: admin.firestore.DocumentSnapshot,
  decision: admin.firestore.DocumentData | undefined,
  appealExists: boolean,
): ReopenBlock | null {
  if (!report.exists) return "report_gone";
  if (!isClosedReportStatus(report.get("status"))) return "not_closed";
  if (appealExists) return "appealed";
  const reporterId = report.get("reporterId");
  if (typeof reporterId !== "string" || reporterId.length === 0) return "reporter_erased";
  const ownerId = report.get("contentOwnerId");
  if (typeof ownerId !== "string" || ownerId.length === 0) return "owner_erased";
  // A record behind the report's round means the last close is not recorded
  // yet; a reopen now would restore the round before it.
  if (!decision || revisionOf(decision) < roundOf(report.data())) return "no_decision";
  return null;
}

/** Test seam — accepts an injected Firestore and clock. */
export async function runReopenReportWithDb(
  db: admin.firestore.Firestore,
  adminUid: string,
  reportId: string,
  now: Date = new Date(),
): Promise<{ round: number }> {
  const reportRef = db.collection(REPORTS).doc(reportId);
  const decisionRef = db.collection(MODERATION_DECISIONS).doc(reportId);
  const appealRefs = (["reporter", "owner"] as const)
    .filter((role) => canHoldAppeal(reportId, role))
    .map((role) => appealRef(db, reportId, role));

  return db.runTransaction(async (tx) => {
    const [report, decision, ...appeals] = await Promise.all([
      tx.get(reportRef),
      tx.get(decisionRef),
      ...appealRefs.map((ref) => tx.get(ref)),
    ]);
    const block = reopenBlock(report, decision.data(), appeals.some((a) => a.exists));
    if (block) throw new HttpsError("failed-precondition", block);

    const round = roundOf(report.data()) + 1;
    const action = decision.get("decision");
    const standing = (MODERATOR_ACTIONS as readonly unknown[]).includes(action);
    tx.update(reportRef, {
      status: "actioned",
      reviewRound: round,
      reopenedAt: admin.firestore.Timestamp.fromDate(now),
      moderatorAction: standing ? action : admin.firestore.FieldValue.delete(),
    });
    // A copy the close has not deleted yet would read as this round's.
    tx.delete(db.collection(REPORT_EVIDENCE).doc(reportId));
    stageModerationAudit(db, tx, {
      actorUid: adminUid,
      operation: "moderation_report_reopened",
      reportId,
      metadata: { decision: typeof action === "string" ? action : null, revision: round },
    });
    return { round };
  });
}
