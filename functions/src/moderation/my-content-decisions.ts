/**
 * BUT-2353: tells a person what was decided about THEIR content — the owner's
 * side of "Mina anmälningar", under "Beslut om mitt innehåll".
 *
 * Only reports that name the caller as `contentOwnerId`, are closed, and led
 * to something being done count. A misattribution report is left out: its
 * reporter is the person the dish named, and the sharer is accused of nothing
 * (ADR-0029). The reporter is never part of the answer; the report is read
 * with a `status` projection, so no reporter field is even fetched.
 *
 * Region: inherits europe-west1 via `setGlobalOptions` in index.ts.
 */

import { onCall, HttpsError } from "firebase-functions/v2/https";
import * as admin from "firebase-admin";
import { enforceRateLimit } from "../middleware/rate_limiter";
import { isClosedReportStatus, REPORTS } from "./report-status";
import { MODERATION_DECISIONS } from "./report-decision";
import { readAppeals } from "./appeals";
import { APPEAL_FIELDS, DECISION_FIELDS, Outcome, outcomeFrom } from "./decision-outcome";

export const RATE_LIMIT_KEY = "getMyContentDecisions";

/** Newest reports looked at; older ones show no decision. */
export const MAX_REPORTS = 200;

export interface ContentDecision extends Outcome {
  contentType: string | null;
  /** The report's reason category, as the decision record normalised it. */
  reason: string;
}

export interface MyContentDecisionsResponse {
  decisions: ContentDecision[];
}

export interface MyContentDecisionsDeps {
  rateLimit: (uid: string, operation: string) => Promise<void>;
  run: (uid: string) => Promise<MyContentDecisionsResponse>;
}

/** The uid is taken from `request.auth` only; `request.data` is never read. */
export async function handleGetMyContentDecisions(
  request: { auth?: { uid: string } | null },
  deps: MyContentDecisionsDeps,
): Promise<MyContentDecisionsResponse> {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "Sign-in required.");
  }
  const uid = request.auth.uid;
  await deps.rateLimit(uid, RATE_LIMIT_KEY);
  return deps.run(uid);
}

export const getMyContentDecisions = onCall(
  {
    timeoutSeconds: 30,
    cors: ["https://butlery.app", "https://www.butlery.app"],
    enforceAppCheck: true,
  },
  (request) =>
    handleGetMyContentDecisions(request, {
      rateLimit: (uid, operation) => enforceRateLimit(uid, operation),
      run: (uid) => runGetMyContentDecisionsWithDb(admin.firestore(), uid),
    }),
);

/** Test seam — accepts an injected Firestore. */
export async function runGetMyContentDecisionsWithDb(
  db: admin.firestore.Firestore,
  uid: string,
): Promise<MyContentDecisionsResponse> {
  // Served by the `contentOwnerId, createdAt` composite in firestore.indexes.json.
  const reports = await db
    .collection(REPORTS)
    .where("contentOwnerId", "==", uid)
    .orderBy("createdAt", "desc")
    .select("status")
    .limit(MAX_REPORTS)
    .get();

  const closedIds = reports.docs
    .filter((doc) => isClosedReportStatus(doc.get("status")))
    .map((doc) => doc.id);
  if (closedIds.length === 0) return { decisions: [] };

  const [records, appeals] = await Promise.all([
    db.getAll(...closedIds.map((id) => db.collection(MODERATION_DECISIONS).doc(id)), {
      fieldMask: DECISION_FIELDS,
    }),
    readAppeals(db, closedIds, "owner", APPEAL_FIELDS),
  ]);

  const decisions: ContentDecision[] = [];
  records.forEach((snap, i) => {
    const outcome = outcomeFrom(snap, appeals.get(closedIds[i]));
    if (!outcome || outcome.decision === "no_action") return;
    const rule = snap.get("rule");
    if (rule === "misattribution") return;
    const contentType = snap.get("contentType");
    decisions.push({
      ...outcome,
      contentType: typeof contentType === "string" ? contentType : null,
      reason: typeof rule === "string" ? rule : "other",
    });
  });
  return { decisions };
}
