/**
 * BUT-2222: tells a reporter what was decided on their closed reports, so
 * "Mina anmälningar" can say it in words.
 *
 * The decision lives in `moderation_decisions/{reportId}` (BUT-2330), which no
 * client may read: it also names the moderator. This returns the `decision`
 * field alone, and only for reports whose `reporterId` is the caller. A
 * reporter erased while the case was open has no `reporterId` left, so nobody
 * gets those.
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
import { Decision, MODERATION_DECISIONS, MODERATOR_ACTIONS } from "./report-decision";

export const RATE_LIMIT_KEY = "getMyReportOutcomes";

/** Newest reports looked at; older ones show no outcome. */
export const MAX_REPORTS = 200;

export interface ReportOutcome {
  reportId: string;
  decision: Decision;
}

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
    cors: ["https://butlery.app", "https://www.butlery.app"],
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
    .select("status")
    .limit(MAX_REPORTS)
    .get();

  const closedIds = reports.docs
    .filter((doc) => isClosedReportStatus(doc.get("status")))
    .map((doc) => doc.id);
  if (closedIds.length === 0) return { outcomes: [] };

  const decisions = await db.getAll(
    ...closedIds.map((id) => db.collection(MODERATION_DECISIONS).doc(id)),
    { fieldMask: ["decision"] },
  );

  const outcomes: ReportOutcome[] = [];
  for (const snap of decisions) {
    if (!snap.exists) continue;
    const decision = snap.get("decision");
    if (decision === "no_action" || (MODERATOR_ACTIONS as readonly unknown[]).includes(decision)) {
      outcomes.push({ reportId: snap.id, decision: decision as Decision });
    }
  }
  return { outcomes };
}
