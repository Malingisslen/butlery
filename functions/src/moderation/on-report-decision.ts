/**
 * BUT-2330: records the moderator's decision when a report closes
 * (`report-decision.ts`). Its own function rather than a branch in
 * `onReportEvidenceLifecycle`, because only an auth-context trigger names who
 * closed the case, and an existing function cannot change its trigger type in
 * place.
 */

import { onDocumentUpdatedWithAuthContext } from "firebase-functions/v2/firestore";
import { logger } from "firebase-functions/logger";
import * as admin from "firebase-admin";
import { closesReport, recordModerationDecision } from "./report-decision";

// retry:true — the write is create-once, so a redelivery is a no-op, and
// without a retry a transient failure would lose the record for good.
export const onReportDecision = onDocumentUpdatedWithAuthContext(
  { document: "reports/{reportId}", retry: true },
  async (event) => {
    const before = event.data?.before.data();
    const after = event.data?.after.data();
    if (!after || !closesReport(before, after)) return;

    const reportId = event.params.reportId;
    const outcome = await recordModerationDecision(admin.firestore(), {
      reportId,
      report: after,
      decidedAt: new Date(event.time),
      authType: event.authType,
      authId: event.authId,
    });
    logger.info("moderation_decision", {
      report_prefix: reportId.slice(0, 6),
      outcome,
      auth_type: event.authType,
    });
  },
);
