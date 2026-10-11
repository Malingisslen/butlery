/**
 * BUT-2353: what changing a decision in the OWNER's favour undoes.
 *
 * The strike the report put on the owner (`report_history/{reportId}` and the
 * `totalReports` counter beside it, `feedback/on-report-created.ts`) is taken
 * off, and a hidden profile is shown again. Removed content cannot come back:
 * the takedown deletes it outright.
 *
 * Split into a read half and a write half because a Firestore transaction must
 * do every read before its first write.
 */

import * as admin from "firebase-admin";
import { logger } from "firebase-functions/logger";
import { MODERATION_DECISIONS } from "./report-decision";
import { appealRef, canHoldAppeal } from "./appeals";
import { isClosedReportStatus, REPORTS } from "./report-status";

const USER_MODERATION = "user_moderation";
const REPORT_HISTORY = "report_history";
const PUBLIC_PROFILES = "public_profiles";

/**
 * How many of the owner's other profile reports are checked for a hide that
 * still stands. A full page keeps the profile hidden rather than risk showing
 * a profile another decision hid.
 */
export const OTHER_HIDE_PAGE = 50;

export interface ReversalPlan {
  historyRef: admin.firestore.DocumentReference;
  historyExists: boolean;
  moderationRef: admin.firestore.DocumentReference;
  totalReports: number;
  profileRef: admin.firestore.DocumentReference | null;
  unhide: boolean;
}

export interface ReversalEffects {
  strikeRemoved: boolean;
  profileUnhidden: boolean;
}

export async function readReversal(
  db: admin.firestore.Firestore,
  tx: admin.firestore.Transaction,
  reportId: string,
  ownerId: string,
  decision: unknown,
): Promise<ReversalPlan> {
  const moderationRef = db.collection(USER_MODERATION).doc(ownerId);
  const historyRef = moderationRef.collection(REPORT_HISTORY).doc(reportId);
  const [history, moderation] = await Promise.all([tx.get(historyRef), tx.get(moderationRef)]);
  const total = moderation.get("totalReports");

  let profileRef: admin.firestore.DocumentReference | null = null;
  let unhide = false;
  if (decision === "profile_hidden") {
    profileRef = db.collection(PUBLIC_PROFILES).doc(ownerId);
    const [profile, anotherStands] = await Promise.all([
      tx.get(profileRef),
      anotherHideStands(db, tx, reportId, ownerId),
    ]);
    unhide = profile.exists && profile.get("isHidden") === true && !anotherStands;
    if (anotherStands) {
      logger.info("appeal_reversal_profile_kept_hidden", { report_prefix: reportId.slice(0, 6) });
    }
  }

  return {
    historyRef,
    historyExists: history.exists,
    moderationRef,
    totalReports: typeof total === "number" ? total : 0,
    profileRef,
    unhide,
  };
}

/**
 * Fails closed: a hide that cannot be shown to be gone counts as standing. That
 * covers a closed profile report whose decision record is missing, and an open
 * one whose takedown already hid the profile (`moderatorAction`, which the close
 * moves onto the record).
 */
async function anotherHideStands(
  db: admin.firestore.Firestore,
  tx: admin.firestore.Transaction,
  reportId: string,
  ownerId: string,
): Promise<boolean> {
  const others = await tx.get(
    db
      .collection(REPORTS)
      .where("contentOwnerId", "==", ownerId)
      .where("contentType", "==", "profile")
      .limit(OTHER_HIDE_PAGE),
  );
  if (others.size >= OTHER_HIDE_PAGE) return true;
  const rest = others.docs.filter((doc) => doc.id !== reportId);
  if (rest.some((doc) => !isClosedReportStatus(doc.get("status")) &&
    doc.get("moderatorAction") === "profile_hidden")) {
    return true;
  }
  const ids = rest
    .filter((doc) => isClosedReportStatus(doc.get("status")))
    .map((doc) => doc.id);
  if (ids.length === 0) return false;
  const appealable = ids.filter((id) => canHoldAppeal(id, "owner"));
  const [decisions, appeals] = await Promise.all([
    tx.getAll(...ids.map((id) => db.collection(MODERATION_DECISIONS).doc(id))),
    appealable.length > 0
      ? tx.getAll(...appealable.map((id) => appealRef(db, id, "owner")))
      : Promise.resolve([]),
  ]);
  const reversed = new Set(appealable.filter((_, j) => appeals[j].get("status") === "reversed"));
  return decisions.some(
    (snap, i) =>
      (!snap.exists || snap.get("decision") === "profile_hidden") && !reversed.has(ids[i]),
  );
}

export function applyReversal(
  tx: admin.firestore.Transaction,
  plan: ReversalPlan,
): ReversalEffects {
  if (plan.historyExists) {
    tx.delete(plan.historyRef);
    if (plan.totalReports > 0) {
      tx.update(plan.moderationRef, {
        totalReports: admin.firestore.FieldValue.increment(-1),
      });
    }
  }
  if (plan.unhide && plan.profileRef) {
    tx.update(plan.profileRef, { isHidden: false, hiddenAt: null });
  }
  return { strikeRemoved: plan.historyExists, profileUnhidden: plan.unhide && !!plan.profileRef };
}
