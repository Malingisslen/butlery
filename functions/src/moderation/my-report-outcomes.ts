/**
 * BUT-2222: tells a reporter what was decided on their reports, so
 * "Mina anmälningar" can say it in words.
 *
 * The decision lives in `moderation_decisions/{reportId}` (BUT-2330), which no
 * client may read: it also names the moderator. This returns the decision, the
 * motivation key, the dates and the reporter's own appeal (BUT-2353), and only
 * for reports whose `reporterId` is the caller. A reporter erased while the
 * case was open has no `reporterId` left, so nobody gets those.
 *
 * Nothing is stored. A record past its 12-month TTL is simply absent, and the
 * app then says only that the case is closed.
 *
 * Region: inherits europe-west1 via `setGlobalOptions` in index.ts.
 */

import { onCall, HttpsError } from "firebase-functions/v2/https";
import * as admin from "firebase-admin";
import { enforceRateLimit } from "../middleware/rate_limiter";
import { isClosedReportStatus, REPORTS } from "./report-status";
import { roundOf } from "./decision-revision";
import { MODERATION_DECISIONS } from "./report-decision";
import { readAppeals } from "./appeals";
import { APPEAL_FIELDS, DECISION_FIELDS, Outcome, outcomeFrom } from "./decision-outcome";
import { WEB_CALLABLE_ORIGINS } from "../shared/web-origins";

export const RATE_LIMIT_KEY = "getMyReportOutcomes";

/** Newest reports looked at; older ones show no outcome. */
export const MAX_REPORTS = 200;

export type ReportOutcome = Outcome;

export interface MyReportOutcomesResponse {
  outcomes: ReportOutcome[];
}

export interface MyReportOutcomesDeps {
  rateLimit: (uid: string, operation: string) => Promise<void>;
  run: (uid: string) => Promise<MyReportOutcomesResponse>;
}

/**
 * The uid is taken from `request.auth` only; `request.data` is never read, so
 * a payload naming another user or report changes nothing.
 */
export async function handleGetMyReportOutcomes(
  request: { auth?: { uid: string } | null },
  deps: MyReportOutcomesDeps,
): Promise<MyReportOutcomesResponse> {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "Sign-in required.");
  }
  const uid = request.auth.uid;
  await deps.rateLimit(uid, RATE_LIMIT_KEY);
  return deps.run(uid);
}

export const getMyReportOutcomes = onCall(
  {
    timeoutSeconds: 30,
    cors: WEB_CALLABLE_ORIGINS,
    enforceAppCheck: true,
  },
  (request) =>
    handleGetMyReportOutcomes(request, {
      rateLimit: (uid, operation) => enforceRateLimit(uid, operation),
      run: (uid) => runGetMyReportOutcomesWithDb(admin.firestore(), uid),
    }),
);

/** Test seam — accepts an injected Firestore. */
export async function runGetMyReportOutcomesWithDb(
  db: admin.firestore.Firestore,
  uid: string,
): Promise<MyReportOutcomesResponse> {
  // Served by the `reporterId, createdAt` composite in firestore.indexes.json.
  const reports = await db
    .collection(REPORTS)
    .where("reporterId", "==", uid)
    .orderBy("createdAt", "desc")
    .select("status", "reviewRound")
    .limit(MAX_REPORTS)
    .get();

  const closed = new Set(
    reports.docs.filter((doc) => isClosedReportStatus(doc.get("status"))).map((doc) => doc.id),
  );
  const closedIds = reports.docs
    // BUT-1528: a reopened case keeps showing the decision it last had.
    .filter((doc) => isClosedReportStatus(doc.get("status")) || roundOf(doc.data()) > 0)
    .map((doc) => doc.id);
  if (closedIds.length === 0) return { outcomes: [] };

  const [decisions, appeals] = await Promise.all([
    db.getAll(...closedIds.map((id) => db.collection(MODERATION_DECISIONS).doc(id)), {
      fieldMask: DECISION_FIELDS,
    }),
    readAppeals(db, closedIds, "reporter", APPEAL_FIELDS),
  ]);

  const outcomes: ReportOutcome[] = [];
  decisions.forEach((snap, i) => {
    const outcome = outcomeFrom(snap, appeals.get(closedIds[i]), {
      role: "reporter",
      closed: closed.has(closedIds[i]),
    });
    if (outcome) outcomes.push(outcome);
  });
  return { outcomes };
}
