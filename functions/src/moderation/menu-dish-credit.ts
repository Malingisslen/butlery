/**
 * BUT-2339: "Det här är inte min rätt" takes the reporter's name off the dish
 * at once, without waiting for a moderator (ADR-0029).
 *
 * Only `createdBy` equal to the REPORTER's own uid is removed. That is the
 * person withdrawing their own name, which needs no judgement about anyone
 * else, so it is safe to do on the report alone. Who wrote the dish is not
 * decided here; the case still goes to a moderator.
 *
 * Runs after the evidence copy, which records whether the dish named the
 * reporter; removing the name first would make every copy say it did not.
 */

import * as admin from "firebase-admin";
import { logger } from "firebase-functions/logger";
import { isValidDocId } from "../shared/valid-doc-id";
import { captureReportEvidence } from "./report-evidence";
import { REPORTS } from "./report-status";

type Data = admin.firestore.DocumentData;

export type CreditWithdrawal =
  | "withdrawn"
  | "not_applicable"
  | "not_named"
  | "menu_gone"
  | "failed";

/**
 * [snapshot] with `createdBy` removed from each dish whose `id` is [dishId]
 * and whose `createdBy` is [uid]; null when no dish changed.
 */
export function withoutCredit(snapshot: unknown, dishId: string, uid: string): Data | null {
  if (typeof snapshot !== "object" || snapshot === null || Array.isArray(snapshot)) return null;
  let changed = false;
  const next: Data = {};
  for (const [category, dishes] of Object.entries(snapshot as Data)) {
    if (!Array.isArray(dishes)) {
      next[category] = dishes;
      continue;
    }
    next[category] = dishes.map((dish) => {
      if (
        typeof dish === "object" && dish !== null &&
        (dish as Data).id === dishId && (dish as Data).createdBy === uid
      ) {
        changed = true;
        const rest: Data = { ...(dish as Data) };
        delete rest.createdBy;
        return rest;
      }
      return dish;
    });
  }
  return changed ? next : null;
}

/**
 * Removes the reporter's uid from the reported dish when [reportId] is a
 * misattribution report on a menu dish. Never throws: it runs in
 * `onReportCreated`, which must still write the moderator's row.
 */
export async function withdrawReporterCredit(
  db: admin.firestore.Firestore,
  reportId: string,
): Promise<CreditWithdrawal> {
  try {
    return await db.runTransaction(async (tx) => {
      const report = await tx.get(db.collection(REPORTS).doc(reportId));
      if (
        !report.exists ||
        report.get("contentType") !== "menu_dish" ||
        report.get("reason") !== "misattribution"
      ) {
        return "not_applicable";
      }
      const reporterId = report.get("reporterId");
      const menuId = report.get("contentId");
      const dishId = report.get("dishId");
      if (!isValidDocId(reporterId) || !isValidDocId(menuId) || typeof dishId !== "string") {
        return "not_applicable";
      }

      const menuRef = db.collection("shared_content").doc(menuId);
      const menu = await tx.get(menuRef);
      if (!menu.exists) return "menu_gone";
      const next = withoutCredit(menu.get("menuSnapshot"), dishId, reporterId);
      if (!next) return "not_named";
      tx.update(menuRef, { menuSnapshot: next });
      return "withdrawn";
    });
  } catch (err) {
    // Error CODE only: a Firestore error message can echo a path with a uid in it.
    logger.error("menu_dish_credit_withdraw_failed", {
      report_prefix: reportId.slice(0, 6),
      errCode: (err as { code?: number | string }).code ?? null,
    });
    return "failed";
  }
}

/**
 * The evidence copy, then the withdrawal: the copy records whether the dish
 * named the reporter, so the name must still be there when it is taken.
 * [report] is the trigger's own data; it saves the withdrawal's transaction
 * on every report that cannot be one, and the transaction re-checks it.
 */
export async function captureThenWithdraw(
  db: admin.firestore.Firestore,
  reportId: string,
  report: { contentType?: unknown; reason?: unknown },
): Promise<{ outcome: Awaited<ReturnType<typeof captureReportEvidence>>; credit: CreditWithdrawal }> {
  const outcome = await captureReportEvidence(db, reportId);
  const credit = report.contentType === "menu_dish" && report.reason === "misattribution"
    ? await withdrawReporterCredit(db, reportId)
    : "not_applicable";
  return { outcome, credit };
}
