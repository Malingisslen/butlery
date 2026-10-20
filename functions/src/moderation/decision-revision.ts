/**
 * BUT-1528: a closed report can be reopened and decided again. This module
 * holds what a later round changes; `report-decision.ts` calls it from the
 * close.
 *
 * Malin's calls, 2026-10-20: a reopen only moves the case back to the queue;
 * the action stands until the moderator decides otherwise. A strike follows
 * the decision: it stays only while something was done to the owner's content
 * (K1), and a changed decision tells both people (K3). A decision that has
 * been appealed is never reopened (D1), so an appeal always belongs to the
 * decision it was filed against.
 *
 * Every function here only reads, or only writes, so the caller can do every
 * read of the close's transaction before its first write.
 */

import * as admin from "firebase-admin";
import { applyReversal, readReversal, ReversalPlan } from "./appeal-reversal";
import type { Decision } from "./report-decision";
import { reportCountsAgainstOwner } from "./report-status";

/** The round a report is in. A report never reopened is in round 0. */
export function roundOf(report: admin.firestore.DocumentData | undefined): number {
  const round = report?.reviewRound;
  return typeof round === "number" && Number.isInteger(round) && round > 0 ? round : 0;
}

/** The round a record was written in. */
export function revisionOf(record: admin.firestore.DocumentData | undefined): number {
  return roundOf(record ? { reviewRound: record.revision } : undefined);
}

/** Earlier decisions kept on a record, oldest dropped first. */
export const HISTORY_MAX = 10;

const DAY_MS = 24 * 60 * 60 * 1000;

/** Matches the strike row's retention in `feedback/on-report-created.ts`. */
const STRIKE_RETENTION_DAYS = 180;

/** The fields of a record that move into `history` when the decision changes. */
export function historyEntry(record: admin.firestore.DocumentData): Record<string, unknown> {
  return {
    decision: record.decision ?? null,
    rule: record.rule ?? null,
    motivation: record.motivation ?? null,
    decidedAt: record.decidedAt ?? null,
    moderatorId: record.moderatorId ?? null,
  };
}

export function nextHistory(record: admin.firestore.DocumentData): Record<string, unknown>[] {
  const prior = Array.isArray(record.history) ? record.history : [];
  return [...prior, historyEntry(record)].slice(-HISTORY_MAX);
}

/** Whether [decision] leaves a strike on the owner. */
export function strikes(decision: Decision): boolean {
  return decision !== "no_action";
}

export type StrikePlan =
  | { kind: "remove"; reversal: ReversalPlan }
  | {
      kind: "add";
      historyRef: admin.firestore.DocumentReference;
      moderationRef: admin.firestore.DocumentReference;
      row: Record<string, unknown>;
    };

/**
 * What the strike needs after a close. [previous] is null on the first close,
 * where the strike written at filing is still there.
 *
 * The owner and the reason are read from the STORED report: an erasure that
 * nulled the owner means there is nobody to strike or clear. A strike is
 * re-added only while a row written at filing would still be alive, so a
 * reopen never revives a strike its TTL has removed.
 */
export async function readStrikeFollowUp(
  db: admin.firestore.Firestore,
  tx: admin.firestore.Transaction,
  reportId: string,
  stored: admin.firestore.DocumentData | undefined,
  previous: Decision | null,
  next: Decision,
  now: Date,
): Promise<StrikePlan | null> {
  const ownerId = stored?.contentOwnerId;
  if (typeof ownerId !== "string" || ownerId.length === 0) return null;
  if (!reportCountsAgainstOwner(stored?.reason)) return null;

  const had = previous === null ? true : strikes(previous);
  const wants = strikes(next);
  if (had && !wants) {
    // The previous decision decides what to lift: a hide this report made is
    // lifted with the strike, unless another decision still hides the profile.
    const reversal = await readReversal(db, tx, reportId, ownerId, previous ?? "no_action");
    return { kind: "remove", reversal };
  }
  if (!had && wants) {
    const createdAt = stored?.createdAt;
    if (!(createdAt instanceof admin.firestore.Timestamp)) return null;
    // The reporter writes `createdAt`, so a future value is clamped to now.
    const filedMs = Math.min(createdAt.toMillis(), now.getTime());
    const expireAt = new Date(filedMs + STRIKE_RETENTION_DAYS * DAY_MS);
    if (expireAt <= now) return null;
    const moderationRef = db.collection("user_moderation").doc(ownerId);
    const historyRef = moderationRef.collection("report_history").doc(reportId);
    if ((await tx.get(historyRef)).exists) return null;
    return {
      kind: "add",
      historyRef,
      moderationRef,
      row: {
        reportId,
        reporterId: stored?.reporterId ?? null,
        reason: stored?.reason ?? null,
        contentType: stored?.contentType ?? null,
        contentId: stored?.contentId ?? null,
        expireAt: admin.firestore.Timestamp.fromDate(expireAt),
      },
    };
  }
  return null;
}

export interface StrikeEffects {
  strikeRemoved: boolean;
  strikeAdded: boolean;
  profileUnhidden: boolean;
}

export function applyStrikeFollowUp(
  tx: admin.firestore.Transaction,
  plan: StrikePlan | null,
): StrikeEffects {
  if (!plan) return { strikeRemoved: false, strikeAdded: false, profileUnhidden: false };
  if (plan.kind === "remove") {
    const effects = applyReversal(tx, plan.reversal);
    return { ...effects, strikeAdded: false };
  }
  tx.set(plan.historyRef, plan.row);
  // No `lastReportedAt`: nobody reported anything new.
  tx.set(
    plan.moderationRef,
    { totalReports: admin.firestore.FieldValue.increment(1) },
    { merge: true },
  );
  return { strikeRemoved: false, strikeAdded: true, profileUnhidden: false };
}

export type ModerationAuditOperation =
  | "moderation_decision_recorded"
  | "moderation_decision_changed"
  | "moderation_decision_reconfirmed"
  | "moderation_report_reopened"
  | "moderation_appeal_answered";

/**
 * One `audit_logs` row in the caller's transaction, shaped like the rest of
 * the collection (`analytics/review-learned-alias.ts`). It names the
 * moderator and the report, never the reporter or the reported person.
 */
export function stageModerationAudit(
  db: admin.firestore.Firestore,
  tx: admin.firestore.Transaction,
  entry: {
    actorUid: string | null;
    operation: ModerationAuditOperation;
    reportId: string;
    metadata: Record<string, unknown>;
  },
): void {
  tx.set(db.collection("audit_logs").doc(), {
    userId: entry.actorUid ?? "system",
    operation: entry.operation,
    resourceType: "reports",
    resourceId: entry.reportId,
    granted: true,
    timestamp: admin.firestore.FieldValue.serverTimestamp(),
    metadata: { actor: entry.actorUid ? "admin" : "system", ...entry.metadata },
  });
}
