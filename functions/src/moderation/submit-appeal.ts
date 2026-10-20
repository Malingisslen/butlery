/**
 * BUT-2353: a party to a decision appeals it, once, within six months.
 *
 * The caller's role is checked against the report itself — `reporterId` for
 * the reporter, `contentOwnerId` for the owner — and against nothing in the
 * payload. A report that does not exist and a report that is not the caller's
 * get the same answer, so the callable cannot be used to learn which report
 * ids exist.
 *
 * Region: inherits europe-west1 via `setGlobalOptions` in index.ts.
 */

import { onCall, HttpsError } from "firebase-functions/v2/https";
import * as admin from "firebase-admin";
import { enforceRateLimit } from "../middleware/rate_limiter";
import { isClosedReportStatus, REPORTS, reportCountsAgainstOwner } from "./report-status";
import { DECISION_RETENTION_DAYS, MODERATION_DECISIONS } from "./report-decision";
import { appealAdmits, isDecision } from "./decision-outcome";
import {
  APPEAL_TEXT_MAX,
  APPEAL_TEXT_MIN,
  appealDeadlineFrom,
  appealRef,
  appellantOf,
  AppealRole,
  APPELLANT_ID,
  canHoldAppeal,
  isAppealRole,
  isSafeDocId,
} from "./appeals";

export const RATE_LIMIT_KEY = "submitAppeal";

export interface SubmitAppealInput {
  reportId: string;
  role: AppealRole;
  text: string;
}

export interface SubmitAppealDeps {
  rateLimit: (uid: string, operation: string) => Promise<void>;
  run: (uid: string, input: SubmitAppealInput) => Promise<void>;
}

/**
 * Length is counted in UTF-16 code units after trimming, which is what Dart's
 * `String.length` counts in the app's form.
 */
export function parseSubmitAppeal(data: unknown): SubmitAppealInput {
  const raw = (data ?? {}) as Record<string, unknown>;
  if (!isSafeDocId(raw.reportId)) {
    throw new HttpsError("invalid-argument", "invalid_report_id");
  }
  if (!isAppealRole(raw.role)) {
    throw new HttpsError("invalid-argument", "invalid_role");
  }
  if (!canHoldAppeal(raw.reportId, raw.role)) {
    throw new HttpsError("invalid-argument", "invalid_report_id");
  }
  const text = typeof raw.text === "string" ? raw.text.trim() : "";
  if (text.length < APPEAL_TEXT_MIN || text.length > APPEAL_TEXT_MAX) {
    throw new HttpsError("invalid-argument", "invalid_text_length");
  }
  return { reportId: raw.reportId, role: raw.role, text };
}

export async function handleSubmitAppeal(
  request: { auth?: { uid: string } | null; data?: unknown },
  deps: SubmitAppealDeps,
): Promise<{ ok: true }> {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "Sign-in required.");
  }
  const uid = request.auth.uid;
  const input = parseSubmitAppeal(request.data);
  await deps.rateLimit(uid, RATE_LIMIT_KEY);
  await deps.run(uid, input);
  return { ok: true };
}

export const submitAppeal = onCall(
  {
    timeoutSeconds: 30,
    cors: ["https://butlery.app", "https://www.butlery.app"],
    enforceAppCheck: true,
  },
  (request) =>
    handleSubmitAppeal(request, {
      rateLimit: (uid, operation) => enforceRateLimit(uid, operation),
      run: (uid, input) => runSubmitAppealWithDb(admin.firestore(), uid, input),
    }),
);

/** Test seam — accepts an injected Firestore and clock. */
export async function runSubmitAppealWithDb(
  db: admin.firestore.Firestore,
  uid: string,
  input: SubmitAppealInput,
  now: Date = new Date(),
): Promise<void> {
  const { reportId, role, text } = input;
  const reportRef = db.collection(REPORTS).doc(reportId);
  const decisionRef = db.collection(MODERATION_DECISIONS).doc(reportId);
  const ref = appealRef(db, reportId, role);

  await db.runTransaction(async (tx) => {
    const [report, decision, existing] = await Promise.all([
      tx.get(reportRef),
      tx.get(decisionRef),
      tx.get(ref),
    ]);

    const data = report.data();
    const isParty =
      appellantOf(data, role) === uid &&
      (role === "reporter" || reportCountsAgainstOwner(data?.reason));
    if (!isParty) throw new HttpsError("permission-denied", "not_a_party");

    const decidedAt = decision.get("decidedAt");
    const kind = decision.get("decision");
    if (
      !decision.exists ||
      !(decidedAt instanceof admin.firestore.Timestamp) ||
      !isDecision(kind) ||
      !appealAdmits(role, isClosedReportStatus(data?.status), kind)
    ) {
      throw new HttpsError("not-found", "no_decision");
    }
    if (now.getTime() > appealDeadlineFrom(decidedAt.toDate()).getTime()) {
      throw new HttpsError("failed-precondition", "appeal_window_closed");
    }
    if (existing.exists) throw new HttpsError("already-exists", "appeal_exists");

    tx.create(ref, {
      reportId,
      role,
      [APPELLANT_ID]: uid,
      text,
      createdAt: admin.firestore.Timestamp.fromDate(now),
      status: "open",
      answeredAt: null,
      answeredBy: null,
      expireAt: appealExpireAt(decision.get("expireAt"), decidedAt),
    });
  });
}

/**
 * The appeal goes when its decision does. A record written without
 * `expireAt` falls back to the same 12 months the record itself is given.
 */
function appealExpireAt(
  decisionExpireAt: unknown,
  decidedAt: admin.firestore.Timestamp,
): admin.firestore.Timestamp {
  if (decisionExpireAt instanceof admin.firestore.Timestamp) return decisionExpireAt;
  return admin.firestore.Timestamp.fromMillis(
    decidedAt.toMillis() + DECISION_RETENTION_DAYS * 24 * 60 * 60 * 1000,
  );
}
