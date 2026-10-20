/**
 * BUT-1842: deletes a report's text copy when the report is deleted, closed or
 * loses its `contentOwnerId`. One trigger on the report rather than a delete in
 * each place that closes, deletes or anonymises one, so a new such path needs
 * no change here.
 */

import { onDocumentWritten } from "firebase-functions/v2/firestore";
import { logger } from "firebase-functions/logger";
import * as admin from "firebase-admin";
import { deleteReportEvidence, evidenceShouldGo } from "./report-evidence";
import { isClosedReportStatus, REPORTS } from "./report-status";

/**
 * Deletes the copy when [before] → [after] calls for it, and returns why.
 *
 * BUT-1528: a reopen takes a fresh copy, so a late delivery of the close
 * before it re-reads the report and leaves the copy of a case open again.
 */
export async function runEvidenceLifecycle(
  db: admin.firestore.Firestore,
  reportId: string,
  before: admin.firestore.DocumentData | undefined,
  after: admin.firestore.DocumentData | undefined,
): Promise<string | null> {
  if (!evidenceShouldGo(before, after)) return null;
  const reason = !after ? "report_deleted" : after.contentOwnerId !== before?.contentOwnerId
    ? "owner_changed" : "report_closed";
  if (reason === "report_closed") {
    const stored = await db.collection(REPORTS).doc(reportId).get();
    if (stored.exists && !isClosedReportStatus(stored.get("status"))) return null;
  }
  await deleteReportEvidence(db, reportId);
  return reason;
}

// retry:true — the delete is idempotent, and without a retry a transient
// failure would leave the copy until its TTL.
export const onReportEvidenceLifecycle = onDocumentWritten(
  { document: "reports/{reportId}", retry: true },
  async (event) => {
    const reportId = event.params.reportId;
    const reason = await runEvidenceLifecycle(
      admin.firestore(), reportId, event.data?.before.data(), event.data?.after.data(),
    );
    if (!reason) return;
    logger.info("report_evidence_deleted", { report_prefix: reportId.slice(0, 6), reason });
  },
);
