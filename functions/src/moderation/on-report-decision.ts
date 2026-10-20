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
import { closesReport, recordDecision } from "./report-decision";
import { defaultPushDeps, Notice, pushNotices } from "./moderation-notices";

/** The part of the trigger event the handler reads. */
export interface ReportDecisionEvent {
  data?: {
    before: { data(): admin.firestore.DocumentData | undefined };
    after: { data(): admin.firestore.DocumentData | undefined };
  };
  params: { reportId: string };
  time: string;
  authType?: string;
  authId?: string;
}

export interface ReportDecisionDeps {
  db: admin.firestore.Firestore;
  push: (notices: Notice[]) => Promise<void>;
}

/** Test seam — the trigger body with Firestore and the push injected. */
export async function handleReportDecision(
  event: ReportDecisionEvent,
  deps: ReportDecisionDeps,
): Promise<void> {
  const before = event.data?.before.data();
  const after = event.data?.after.data();
  if (!after || !closesReport(before, after)) return;

  const reportId = event.params.reportId;
  const { outcome, notices } = await recordDecision(deps.db, {
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
    notices: notices.length,
  });
  // BUT-2353: pushed only on the delivery that wrote the rows, so a
  // redelivery never pushes twice.
  await deps.push(notices);
}

// retry:true — without a retry a transient failure would lose the record
// for good.
export const onReportDecision = onDocumentUpdatedWithAuthContext(
  { document: "reports/{reportId}", retry: true },
  (event) => {
    const db = admin.firestore();
    return handleReportDecision(event, {
      db,
      push: (notices) => pushNotices(notices, defaultPushDeps(db)),
    });
  },
);
