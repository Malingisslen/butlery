/**
 * BUT-2353: the moderator answers an appeal. The answer is final in the app.
 *
 * Admin only. The answer, the appellant's inbox row and — for a decision
 * changed in the owner's favour — the strike and the profile hide are undone
 * in one transaction, so a retry can neither half-apply a reversal nor tell
 * the appellant twice. The push is sent after the commit.
 *
 * Region: inherits europe-west1 via `setGlobalOptions` in index.ts.
 */

import { onCall, CallableRequest, HttpsError } from "firebase-functions/v2/https";
import { logger } from "firebase-functions/logger";
import * as admin from "firebase-admin";
import { enforceRateLimit } from "../middleware/rate_limiter";
import { requireAdmin } from "../shared/require-admin";
import { MODERATION_DECISIONS } from "./report-decision";
import {
  APPEAL_OUTCOMES,
  AppealOutcome,
  APPELLANT_ID,
  isAppealRole,
  isSafeDocId,
  MODERATION_APPEALS,
} from "./appeals";
import {
  appealAnsweredNotice,
  defaultPushDeps,
  Notice,
  pushNotices,
  PushDeps,
  stageNotice,
} from "./moderation-notices";
import { applyReversal, readReversal, ReversalEffects } from "./appeal-reversal";
import { stageModerationAudit } from "./decision-revision";

export const RATE_LIMIT_KEY = "answerAppeal";

export interface AnswerAppealInput {
  appealId: string;
  outcome: AppealOutcome;
}

export interface AnswerAppealResult {
  notices: Notice[];
  effects: ReversalEffects;
}

export interface AnswerAppealDeps {
  rateLimit: (uid: string, operation: string) => Promise<void>;
  run: (adminUid: string, input: AnswerAppealInput) => Promise<AnswerAppealResult>;
  push: (notices: Notice[]) => Promise<void>;
}

export function parseAnswerAppeal(data: unknown): AnswerAppealInput {
  const raw = (data ?? {}) as Record<string, unknown>;
  if (!isSafeDocId(raw.appealId) || !/_(reporter|owner)$/.test(raw.appealId)) {
    throw new HttpsError("invalid-argument", "invalid_appeal_id");
  }
  if (!(APPEAL_OUTCOMES as readonly unknown[]).includes(raw.outcome)) {
    throw new HttpsError("invalid-argument", "invalid_outcome");
  }
  return { appealId: raw.appealId, outcome: raw.outcome as AppealOutcome };
}

export async function handleAnswerAppeal(
  request: CallableRequest<unknown>,
  deps: AnswerAppealDeps,
): Promise<{ ok: true }> {
  requireAdmin(request);
  const adminUid = request.auth!.uid;
  const input = parseAnswerAppeal(request.data);
  await deps.rateLimit(adminUid, RATE_LIMIT_KEY);
  const { notices, effects } = await deps.run(adminUid, input);
  logger.info("appeal_answered", {
    appeal_prefix: input.appealId.slice(0, 6),
    outcome: input.outcome,
    notified: notices.length,
    ...effects,
  });
  await deps.push(notices);
  return { ok: true };
}

export const answerAppeal = onCall(
  {
    timeoutSeconds: 30,
    cors: ["https://butlery.app", "https://www.butlery.app"],
    enforceAppCheck: true,
  },
  (request) => {
    const db = admin.firestore();
    const pushDeps: PushDeps = defaultPushDeps(db);
    return handleAnswerAppeal(request, {
      rateLimit: (uid, operation) => enforceRateLimit(uid, operation),
      run: (adminUid, input) => runAnswerAppealWithDb(db, adminUid, input),
      push: (notices) => pushNotices(notices, pushDeps),
    });
  },
);

/** Test seam — accepts an injected Firestore and clock. */
export async function runAnswerAppealWithDb(
  db: admin.firestore.Firestore,
  adminUid: string,
  input: AnswerAppealInput,
  now: Date = new Date(),
): Promise<AnswerAppealResult> {
  const { appealId, outcome } = input;
  const ref = db.collection(MODERATION_APPEALS).doc(appealId);

  return db.runTransaction(async (tx) => {
    const appeal = await tx.get(ref);
    if (!appeal.exists) throw new HttpsError("not-found", "no_appeal");
    if (appeal.get("status") !== "open") {
      throw new HttpsError("failed-precondition", "appeal_not_open");
    }
    const role = appeal.get("role");
    const reportId = appeal.get("reportId");
    if (!isAppealRole(role) || !isSafeDocId(reportId)) {
      throw new HttpsError("failed-precondition", "appeal_malformed");
    }

    // The appellant comes from the appeal, never the report: the reporter's
    // erasure deletes the report while the owner is still here.
    const decision = await tx.get(db.collection(MODERATION_DECISIONS).doc(reportId));
    const stored = appeal.get(APPELLANT_ID);
    const appellant = typeof stored === "string" && stored.length > 0 ? stored : null;
    const plan =
      outcome === "reversed" && role === "owner" && appellant
        ? await readReversal(db, tx, reportId, appellant, decision.get("decision"))
        : null;

    const effects = plan
      ? applyReversal(tx, plan)
      : { strikeRemoved: false, profileUnhidden: false };
    tx.update(ref, {
      status: outcome,
      answeredAt: admin.firestore.Timestamp.fromDate(now),
      answeredBy: adminUid,
    });
    stageModerationAudit(db, tx, {
      actorUid: adminUid,
      operation: "moderation_appeal_answered",
      reportId,
      metadata: { role, outcome, ...effects },
    });
    const notices = appellant ? [appealAnsweredNotice(appealId, reportId, role, appellant)] : [];
    for (const notice of notices) stageNotice(db, tx, notice, now);
    return { notices, effects };
  });
}
