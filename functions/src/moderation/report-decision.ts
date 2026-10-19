/**
 * BUT-2330: when a report closes, the server keeps a minimal record of the
 * moderator's decision, separate from the BUT-1842 text copy that the close
 * deletes.
 *
 * Malin's call, 2026-10-10: the record holds the decision, the rule, the time
 * and the moderator, never the reported content, and is deleted 12 months
 * after the decision.
 *
 * It carries no uid of the reporter or of the reported person and no
 * `contentId`, but it is pseudonymous, not anonymous: its id is the report id,
 * so whoever holds the report can link it to both people for as long as the
 * report exists. An erasure anonymises or deletes the report, which is what
 * breaks that link, so the account cascade does not reach this collection.
 * Clients cannot read or write it: `firestore.rules` has no block for it.
 */

import * as admin from "firebase-admin";
import { isClosedReportStatus, REPORTS, reportCountsAgainstOwner } from "./report-status";
import { resolveMotivation } from "./motivation";
import { Notice, ownerNotice, reporterNotice, stageNotice } from "./moderation-notices";

export const MODERATION_DECISIONS = "moderation_decisions";

/** Malin's cap, counted from the decision. */
export const DECISION_RETENTION_DAYS = 365;

/**
 * What the moderator did. The first two are stamped on the report by the
 * app's takedown, in the same batch as the takedown itself
 * (`ReportService.deleteReportedContent` / `suspendReportedProfile`).
 */
export const MODERATOR_ACTIONS = ["content_removed", "profile_hidden"] as const;
export type Decision = (typeof MODERATOR_ACTIONS)[number] | "no_action";

/**
 * The `reason` values the `reports` create rule admits, plus the dish values
 * BUT-2339 adds there, so a dish case is recorded as itself from whichever
 * change deploys first.
 */
const RULES = [
  "spam", "abuse", "harassment", "csam", "copyright", "misinformation", "other",
  "misattribution",
];

const CONTENT_TYPES = ["recipe", "comment", "message", "profile", "cook_snap", "group", "menu_dish"];

/**
 * Principal kinds that are not a signed-in person. Listed as exclusions rather
 * than matching the end-user value, so the moderator is kept whatever string
 * that value carries and a machine write never names one.
 */
const NON_USER_AUTH = ["service_account", "api_key", "system", "unauthenticated", "unknown"];

/** True when a trigger's `authType` names a signed-in person. */
export function isPersonAuth(authType: string | undefined): boolean {
  return typeof authType === "string" && !NON_USER_AUTH.includes(authType);
}

type Data = admin.firestore.DocumentData;

/** True only on the write that moves a report INTO `closed`. */
export function closesReport(before: Data | undefined, after: Data | undefined): boolean {
  if (!before || !after) return false;
  return isClosedReportStatus(after.status) && !isClosedReportStatus(before.status);
}

export function decisionFrom(report: Data): Decision {
  const action = report.moderatorAction;
  return (MODERATOR_ACTIONS as readonly unknown[]).includes(action)
    ? (action as Decision)
    : "no_action";
}

export interface DecisionInput {
  reportId: string;
  /** The report as the closing write left it. */
  report: Data;
  decidedAt: Date;
  authType: string | undefined;
  authId: string | undefined;
}

export type DecisionOutcome = "recorded" | "already_recorded";

export interface DecisionResult {
  outcome: DecisionOutcome;
  /** Inbox rows written with the record; their pushes are still owed. */
  notices: Notice[];
}

/** Fields the close carries for this function and that it takes off the report. */
const CLOSE_STAMPS = ["moderatorAction", "motivation"];

/**
 * Writes the record for [reportId] once, and takes `moderatorAction` and
 * `motivation` off the report in the same transaction: a closed report has no
 * TTL and names both people, so leaving them there would keep the decision
 * indefinitely beside them.
 *
 * The decision is read from the event's copy of the report, not the stored
 * one, so a redelivery after the fields are gone still records what the close
 * saw. A redelivery that finds the row leaves it: the first close decides.
 *
 * The people told are read from the STORED report: an erasure between the
 * close and this run has nulled or deleted it, and a notice must not put an
 * erased uid back on a new row.
 */
export async function recordDecision(
  db: admin.firestore.Firestore,
  input: DecisionInput,
): Promise<DecisionResult> {
  const { reportId, report, decidedAt, authType, authId } = input;
  const reason = report.reason;
  const contentType = report.contentType;
  const decision = decisionFrom(report);
  const isPerson = isPersonAuth(authType);
  const decisionRef = db.collection(MODERATION_DECISIONS).doc(reportId);
  const reportRef = db.collection(REPORTS).doc(reportId);

  return db.runTransaction(async (tx) => {
    const [existing, stored] = await Promise.all([tx.get(decisionRef), tx.get(reportRef)]);
    const stamps = CLOSE_STAMPS.filter((key) => stored.exists && stored.get(key) !== undefined);
    if (stamps.length > 0) {
      tx.update(
        reportRef,
        Object.fromEntries(stamps.map((key) => [key, admin.firestore.FieldValue.delete()])),
      );
    }
    if (existing.exists) return { outcome: "already_recorded", notices: [] };

    tx.create(decisionRef, {
      decision,
      rule: typeof reason === "string" && RULES.includes(reason) ? reason : "other",
      motivation: resolveMotivation(decision, reason, report.motivation),
      contentType:
        typeof contentType === "string" && CONTENT_TYPES.includes(contentType) ? contentType : null,
      decidedAt: admin.firestore.Timestamp.fromDate(decidedAt),
      moderatorId: isPerson && typeof authId === "string" && authId.length > 0 ? authId : null,
      expireAt: admin.firestore.Timestamp.fromDate(
        new Date(decidedAt.getTime() + DECISION_RETENTION_DAYS * 24 * 60 * 60 * 1000),
      ),
    });

    const notices = noticesFor(reportId, decision, reason, stored.data());
    for (const notice of notices) stageNotice(db, tx, notice, decidedAt);
    return { outcome: "recorded", notices };
  });
}

/**
 * The reporter is always told. The owner is told only when something was done
 * to their content, and never on a misattribution report, whose reporter is
 * the person the dish named (ADR-0029).
 */
function noticesFor(
  reportId: string,
  decision: Decision,
  reason: unknown,
  stored: Data | undefined,
): Notice[] {
  const notices: Notice[] = [];
  const reporterId = stored?.reporterId;
  if (typeof reporterId === "string" && reporterId.length > 0) {
    notices.push(reporterNotice(reportId, reporterId));
  }
  const ownerId = stored?.contentOwnerId;
  if (
    decision !== "no_action" &&
    reportCountsAgainstOwner(reason) &&
    typeof ownerId === "string" &&
    ownerId.length > 0
  ) {
    notices.push(ownerNotice(reportId, ownerId));
  }
  return notices;
}

export async function recordModerationDecision(
  db: admin.firestore.Firestore,
  input: DecisionInput,
): Promise<DecisionOutcome> {
  return (await recordDecision(db, input)).outcome;
}
