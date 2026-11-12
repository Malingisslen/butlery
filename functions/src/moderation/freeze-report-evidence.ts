/**
 * BUT-2329: a moderator keeps a report's text copy longer in a serious case.
 *
 * Malin's calls, 2026-11-12: one year from the freeze, extended one year at a
 * time with the reason chosen again, at most three years from the first
 * freeze; the copy outlives the case closing and either person's erasure, but
 * not the facts on it that point at the reporter. A fixed list of reasons, no
 * free text (the BUT-2353 principle).
 *
 * A frozen copy is kept only to be disclosed in the case: nothing but the
 * admin-only moderator view reads it.
 *
 * Every action writes an `audit_logs` row. Those expire before a freeze can,
 * so the `frozen` map on the copy is the lasting record of who froze it, why
 * and until when.
 *
 * Region: inherits europe-west1 via `setGlobalOptions` in index.ts.
 */

import { onCall, CallableRequest, HttpsError } from "firebase-functions/v2/https";
import { logger } from "firebase-functions/logger";
import * as admin from "firebase-admin";
import { enforceRateLimit } from "../middleware/rate_limiter";
import { requireAdmin } from "../shared/require-admin";
import { WEB_CALLABLE_ORIGINS } from "../shared/web-origins";
import { isSafeDocId } from "./appeals";
import { stageModerationAudit } from "./decision-revision";
import {
  EVIDENCE_RETENTION_DAYS,
  evidenceShouldGo,
  isFrozenEvidence,
  REPORT_EVIDENCE,
  REPORTER_FACTS,
} from "./report-evidence";
import { REPORTS } from "./report-status";

export const RATE_LIMIT_KEY = "freezeReportEvidence";

export const FREEZE_REASONS = ["police", "threat", "legal_claim"] as const;
export type FreezeReason = typeof FREEZE_REASONS[number];

export const FREEZE_ACTIONS = ["freeze", "extend", "release"] as const;
export type FreezeAction = typeof FREEZE_ACTIONS[number];

export const FREEZE_PERIOD_DAYS = 365;
export const FREEZE_MAX_DAYS = 3 * 365;

const DAY_MS = 24 * 60 * 60 * 1000;

/** Why an action was refused; the app names each one. */
export type FreezeBlock = "no_copy" | "not_captured" | "already_frozen" | "not_frozen" | "at_cap";

export interface FreezeRequest {
  reportId: string;
  action: FreezeAction;
  reason: FreezeReason | null;
}

export function parseFreezeRequest(data: unknown): FreezeRequest {
  const raw = (data ?? {}) as Record<string, unknown>;
  if (!isSafeDocId(raw.reportId)) throw new HttpsError("invalid-argument", "invalid_report_id");
  if (!(FREEZE_ACTIONS as readonly unknown[]).includes(raw.action)) {
    throw new HttpsError("invalid-argument", "invalid_action");
  }
  const action = raw.action as FreezeAction;
  if (action === "release") return { reportId: raw.reportId, action, reason: null };
  if (!(FREEZE_REASONS as readonly unknown[]).includes(raw.reason)) {
    throw new HttpsError("invalid-argument", "invalid_reason");
  }
  return { reportId: raw.reportId, action, reason: raw.reason as FreezeReason };
}

/** The latest a copy first frozen at [firstFrozenAt] may be kept. */
export function freezeCap(firstFrozenAt: Date): Date {
  return new Date(firstFrozenAt.getTime() + FREEZE_MAX_DAYS * DAY_MS);
}

/** One more period from [now], never past the cap. */
export function nextUntil(now: Date, firstFrozenAt: Date): Date {
  const want = now.getTime() + FREEZE_PERIOD_DAYS * DAY_MS;
  return new Date(Math.min(want, freezeCap(firstFrozenAt).getTime()));
}

function toDate(value: unknown): Date | null {
  return value instanceof admin.firestore.Timestamp ? value.toDate() : null;
}

export type FreezeOutcome =
  | { action: "freeze" | "extend"; until: string }
  | { action: "release"; deleted: boolean };

/** Test seam — accepts an injected Firestore and clock. */
export async function runFreezeWithDb(
  db: admin.firestore.Firestore,
  adminUid: string,
  req: FreezeRequest,
  now: Date = new Date(),
): Promise<FreezeOutcome> {
  const evidenceRef = db.collection(REPORT_EVIDENCE).doc(req.reportId);
  const reportRef = db.collection(REPORTS).doc(req.reportId);
  const ts = admin.firestore.Timestamp.fromDate;

  return db.runTransaction(async (tx): Promise<FreezeOutcome> => {
    const [evidence, report] = await Promise.all([tx.get(evidenceRef), tx.get(reportRef)]);
    const block = (b: FreezeBlock): never => {
      throw new HttpsError("failed-precondition", b);
    };
    if (!evidence.exists) block("no_copy");
    // Past its TTL but not swept yet: the copy is already due to go.
    const expireAt = toDate(evidence.get("expireAt"));
    if (expireAt && expireAt.getTime() <= now.getTime()) block("no_copy");
    // The lifecycle strips reporter facts only on the write where the reporter
    // leaves; a reporter who left before the freeze is caught here instead.
    const reporterId = report.get("reporterId");
    const reporterGone = !report.exists || typeof reporterId !== "string" || reporterId.length === 0;
    const stripFacts = reporterGone
      ? Object.fromEntries(REPORTER_FACTS.map((f) => [f, admin.firestore.FieldValue.delete()]))
      : {};
    const frozen = evidence.get("frozen") as admin.firestore.DocumentData | undefined;
    const audit = (operation: "moderation_evidence_frozen" | "moderation_evidence_extended" |
      "moderation_evidence_released", metadata: Record<string, unknown>) =>
      stageModerationAudit(db, tx, { actorUid: adminUid, operation, reportId: req.reportId, metadata });

    if (req.action === "freeze") {
      if (isFrozenEvidence(evidence.data())) block("already_frozen");
      if (evidence.get("outcome") !== "captured") block("not_captured");
      const until = nextUntil(now, now);
      tx.update(evidenceRef, {
        frozen: {
          reason: req.reason, frozenAt: ts(now), frozenBy: adminUid,
          firstFrozenAt: ts(now), until: ts(until), extensions: 0,
        },
        expireAt: ts(until),
        ...stripFacts,
      });
      audit("moderation_evidence_frozen", { reason: req.reason, until: until.toISOString() });
      return { action: "freeze", until: until.toISOString() };
    }

    if (!isFrozenEvidence(evidence.data())) block("not_frozen");
    const first = toDate(frozen?.firstFrozenAt) ?? toDate(frozen?.frozenAt) ?? now;

    if (req.action === "extend") {
      const current = toDate(frozen?.until);
      const until = nextUntil(now, first);
      if (current && until.getTime() <= current.getTime()) block("at_cap");
      tx.update(evidenceRef, {
        "frozen.reason": req.reason,
        "frozen.frozenAt": ts(now),
        "frozen.frozenBy": adminUid,
        "frozen.until": ts(until),
        "frozen.extensions": admin.firestore.FieldValue.increment(1),
        expireAt: ts(until),
        ...stripFacts,
      });
      audit("moderation_evidence_extended", { reason: req.reason, until: until.toISOString() });
      return { action: "extend", until: until.toISOString() };
    }

    // Release: back to the BUT-1842 rules. If any of them would already have
    // deleted the copy, it goes now. `before` is the report as the copy was
    // captured against, so an owner the erasure has since nulled counts as a
    // change.
    const captured = toDate(evidence.get("capturedAt")) ?? now;
    const plainExpiry = new Date(captured.getTime() + EVIDENCE_RETENTION_DAYS * DAY_MS);
    const wouldHaveGone = !report.exists ||
      evidenceShouldGo(
        { status: "open", contentOwnerId: evidence.get("contentOwnerId") },
        report.data(),
      ) ||
      plainExpiry.getTime() <= now.getTime();
    if (wouldHaveGone) {
      tx.delete(evidenceRef);
    } else {
      tx.update(evidenceRef, {
        frozen: admin.firestore.FieldValue.delete(),
        expireAt: ts(plainExpiry),
      });
    }
    audit("moderation_evidence_released", { deleted: wouldHaveGone });
    return { action: "release", deleted: wouldHaveGone };
  });
}

export interface FreezeDeps {
  rateLimit: (uid: string, operation: string) => Promise<void>;
  run: (adminUid: string, req: FreezeRequest) => Promise<FreezeOutcome>;
}

export async function handleFreezeReportEvidence(
  request: CallableRequest<unknown>,
  deps: FreezeDeps,
): Promise<FreezeOutcome> {
  requireAdmin(request);
  const adminUid = request.auth!.uid;
  const req = parseFreezeRequest(request.data);
  await deps.rateLimit(adminUid, RATE_LIMIT_KEY);
  const outcome = await deps.run(adminUid, req);
  logger.info("report_evidence_freeze", {
    report_prefix: req.reportId.slice(0, 6),
    action: req.action,
    reason: req.reason,
  });
  return outcome;
}

export const freezeReportEvidence = onCall(
  {
    timeoutSeconds: 30,
    cors: WEB_CALLABLE_ORIGINS,
    enforceAppCheck: true,
  },
  (request) => {
    const db = admin.firestore();
    return handleFreezeReportEvidence(request, {
      rateLimit: (uid, operation) => enforceRateLimit(uid, operation),
      run: (adminUid, req) => runFreezeWithDb(db, adminUid, req),
    });
  },
);

/** The `resourceType` a frozen copy's `RetainedRecord` carries. */
export const FROZEN_EVIDENCE_RESOURCE = REPORT_EVIDENCE;

/**
 * Frozen copies of [uid]'s content, as one record for the erasure's Art. 12(4)
 * notice and its audit row, or null when there are none. `holdUntil` is the
 * latest three-year cap among them, so "at the latest" stays true whatever the
 * moderator extends later.
 *
 * Reads every copy naming [uid]: an unfrozen one goes with its report.
 */
export async function frozenEvidenceRetained(
  db: admin.firestore.Firestore,
  uid: string,
): Promise<{ resourceType: string; legalBasis: string; holdUntil: admin.firestore.Timestamp;
  provisional: boolean } | null> {
  const snap = await db.collection(REPORT_EVIDENCE).where("contentOwnerId", "==", uid).get();
  let latest: Date | null = null;
  const bases = new Set<string>();
  for (const doc of snap.docs) {
    if (!isFrozenEvidence(doc.data())) continue;
    const frozen = doc.get("frozen") as admin.firestore.DocumentData;
    const first = toDate(frozen.firstFrozenAt) ?? toDate(frozen.frozenAt);
    if (!first) continue;
    const cap = freezeCap(first);
    if (!latest || cap > latest) latest = cap;
    bases.add(frozen.reason === "legal_claim" ? "GDPR Art. 17(3)(e)" : "GDPR Art. 17(1)(c), 21(1)");
  }
  if (!latest) return null;
  return {
    resourceType: FROZEN_EVIDENCE_RESOURCE,
    legalBasis: [...bases].sort().join("; "),
    holdUntil: admin.firestore.Timestamp.fromDate(latest),
    provisional: false,
  };
}
