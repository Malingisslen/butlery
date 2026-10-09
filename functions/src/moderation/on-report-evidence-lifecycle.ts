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

// retry:true — the delete is idempotent, and without a retry a transient
// failure would leave the copy until its TTL.
export const onReportEvidenceLifecycle = onDocumentWritten(
  { document: "reports/{reportId}", retry: true },
  async (event) => {
    const before = event.data?.before.data();
    const after = event.data?.after.data();
    if (!evidenceShouldGo(before, after)) return;

    const reportId = event.params.reportId;
    await deleteReportEvidence(admin.firestore(), reportId);
    logger.info("report_evidence_deleted", {
      report_prefix: reportId.slice(0, 6),
      reason: !after ? "report_deleted" : after.contentOwnerId !== before?.contentOwnerId
        ? "owner_changed" : "report_closed",
    });
  },
);
