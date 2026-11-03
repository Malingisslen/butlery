/**
 * Admin-vy step C3: after the ingredient sync, a proposal that is `inReview`
 * becomes `applied` once Firestore holds every new value it proposed.
 *
 * The test is the C1 comparison (`columnValuesEqual`), so "applied" means
 * the same thing as "the sync sees no change". A proposal whose values are
 * not there yet (its PR is still open, or a later edit moved the value on)
 * stays `inReview`. Each write is a transaction that re-reads the proposal,
 * so a withdrawal made meanwhile is never overwritten, and a rerun finds
 * nothing left to do.
 */

import * as admin from "firebase-admin";
import { Collections } from "../shared/collections";
import { columnSpec, columnValuesEqual, docValueForColumn, isEditableColumn } from "./ingredient-compare";
import type { IngredientDoc } from "./sync-ingredients-core";

export const APPLIED_RETENTION_MS = 365 * 24 * 60 * 60 * 1000;
// The callable keeps at most 500 proposals in review; this only bounds a read
// that something else has made larger.
export const MAX_IN_REVIEW = 1000;

/** Fields only this job writes on a proposal. */
export const APPLIED_STAMP_KEYS = ["appliedAt"] as const;

/**
 * True when [stored] (an `ingredients/{id}` document) holds every proposed
 * new value. The writer trims what it writes, and csvToFirestore fills a
 * blank `english` from `swedish`, so both are read the way the sync reads them.
 */
export function proposalIsApplied(changes: unknown, stored: admin.firestore.DocumentData | undefined): boolean {
  if (!stored || changes === null || typeof changes !== "object" || Array.isArray(changes)) return false;
  const entries = Object.entries(changes as Record<string, unknown>);
  if (entries.length === 0) return false;
  return entries.every(([column, change]) => {
    if (!isEditableColumn(column) || change === null || typeof change !== "object") return false;
    let next = (change as Record<string, unknown>).new;
    const kind = columnSpec(column).kind;
    if (kind === "text") {
      next = typeof next === "string" ? next.trim() : next;
      if (column === "english" && next === "") next = stored.swedish;
    }
    if (kind === "list" && Array.isArray(next)) next = next.map((s) => String(s).trim());
    return columnValuesEqual(column, next, docValueForColumn(stored as IngredientDoc, column));
  });
}

export interface MarkAppliedCounts {
  inReview: number;
  applied: number;
  notYet: number;
  // Status moved between the read and the write (withdrawn, re-sent).
  skipped: number;
}

export async function markAppliedProposals(
  db: admin.firestore.Firestore,
  now: Date,
): Promise<MarkAppliedCounts> {
  const col = db.collection(Collections.ingredientChangeRequests);
  const snap = await col.where("status", "==", "inReview").limit(MAX_IN_REVIEW).get();
  const counts: MarkAppliedCounts = { inReview: snap.size, applied: 0, notYet: 0, skipped: 0 };
  for (const doc of snap.docs) {
    const outcome = await db.runTransaction(async (tx) => {
      const fresh = await tx.get(col.doc(doc.id));
      if (!fresh.exists || fresh.get("status") !== "inReview") return "skipped" as const;
      const ingredientId = fresh.get("ingredientId");
      if (typeof ingredientId !== "string" || ingredientId === "" || ingredientId.includes("/")) return "notYet" as const;
      const ingredient = await tx.get(db.collection(Collections.ingredients).doc(ingredientId));
      if (!proposalIsApplied(fresh.get("changes"), ingredient.data())) return "notYet" as const;
      tx.update(col.doc(doc.id), {
        status: "applied",
        appliedAt: admin.firestore.FieldValue.serverTimestamp(),
        expireAt: admin.firestore.Timestamp.fromMillis(now.getTime() + APPLIED_RETENTION_MS),
      });
      return "applied" as const;
    });
    counts[outcome]++;
  }
  return counts;
}

export function formatMarkAppliedSummary(c: MarkAppliedCounts): string {
  return [
    "## Admin proposals marked applied",
    "",
    "| | |",
    "|---|---|",
    `| In review before | ${c.inReview} |`,
    `| Marked applied | ${c.applied} |`,
    `| Not in Firestore yet | ${c.notYet} |`,
    `| Status moved meanwhile | ${c.skipped} |`,
    "",
  ].join("\n");
}
