/**
 * BUT-2353: what a party to a decision is told about it, shared by the
 * reporter's list (`my-report-outcomes.ts`) and the owner's
 * (`my-content-decisions.ts`). Keys only; the app owns the text.
 */

import * as admin from "firebase-admin";
import { appealDeadlineFrom, AppealRole, AppealStatus } from "./appeals";
import { Decision, MODERATOR_ACTIONS } from "./report-decision";
import { resolveMotivation } from "./motivation";

export interface AppealView {
  status: AppealStatus;
  text: string;
  submittedAt: string;
  answeredAt: string | null;
}

export interface Outcome {
  reportId: string;
  decision: Decision;
  motivation: string;
  /** ISO-8601. */
  decidedAt: string;
  /** ISO-8601, `APPEAL_WINDOW_DAYS` after `decidedAt`. */
  appealDeadline: string;
  appeal: AppealView | null;
  /** BUT-1528: the decision was changed when the case was reopened. */
  revised: boolean;
  appealable: boolean;
}

/**
 * The part of `submitAppeal`'s admission the lists can know: a reopened case
 * is decided again before anyone appeals, and a dismissed report gives the
 * owner nothing to appeal.
 */
export function appealAdmits(role: AppealRole, closed: boolean, decision: Decision): boolean {
  return closed && !(role === "owner" && decision === "no_action");
}

/** The decision fields an outcome is built from; read with this mask. */
export const DECISION_FIELDS = [
  "decision", "motivation", "rule", "contentType", "decidedAt", "revisedAt",
];
export const APPEAL_FIELDS = ["status", "text", "createdAt", "answeredAt"];

export function isDecision(value: unknown): value is Decision {
  return value === "no_action" || (MODERATOR_ACTIONS as readonly unknown[]).includes(value);
}

function iso(value: unknown): string | null {
  return value instanceof admin.firestore.Timestamp ? value.toDate().toISOString() : null;
}

function appealViewFrom(snap: admin.firestore.DocumentSnapshot | undefined): AppealView | null {
  if (!snap?.exists) return null;
  const status = snap.get("status");
  const submittedAt = iso(snap.get("createdAt"));
  if ((status !== "open" && status !== "upheld" && status !== "reversed") || !submittedAt) {
    return null;
  }
  const text = snap.get("text");
  return {
    status,
    text: typeof text === "string" ? text : "",
    submittedAt,
    answeredAt: iso(snap.get("answeredAt")),
  };
}

/**
 * Null when the record is absent or malformed: the app then says only that
 * the case is closed, as it did before there was a record.
 *
 * A record written before BUT-2353 has no `motivation` and is given its
 * decision's default, through the same function the close uses.
 */
export function outcomeFrom(
  decisionSnap: admin.firestore.DocumentSnapshot,
  appealSnap: admin.firestore.DocumentSnapshot | undefined,
  admission: { role: AppealRole; closed: boolean },
): Outcome | null {
  if (!decisionSnap.exists) return null;
  const decision = decisionSnap.get("decision");
  const decidedAt = decisionSnap.get("decidedAt");
  if (!isDecision(decision) || !(decidedAt instanceof admin.firestore.Timestamp)) return null;
  return {
    reportId: decisionSnap.id,
    decision,
    motivation: resolveMotivation(decision, decisionSnap.get("rule"), decisionSnap.get("motivation")),
    decidedAt: decidedAt.toDate().toISOString(),
    appealDeadline: appealDeadlineFrom(decidedAt.toDate()).toISOString(),
    appeal: appealViewFrom(appealSnap),
    revised: decisionSnap.get("revisedAt") instanceof admin.firestore.Timestamp,
    appealable: appealAdmits(admission.role, admission.closed, decision),
  };
}
