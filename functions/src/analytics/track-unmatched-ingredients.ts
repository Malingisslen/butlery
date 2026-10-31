/**
 * Counts the ingredient names the tagger could not match, so an admin can see
 * which ones the ingredient database is missing.
 *
 * Firestore structure:
 * /analytics/ingredients/unmatched/{normalizedName}
 *   - name: string (the name as first seen, for display)
 *   - count: number (occurrences: how many recipe writes newly added the name
 *     to a recipe's unknown list; not distinct recipes or users)
 *   - firstSeenDay, lastSeenDay: "YYYY-MM-DD" (UTC)
 * /analytics/ingredients
 *   - skippedPiiCount: names left out because they looked like personal data
 *
 * Nothing here links a name to a recipe or a user, so account deletion and
 * data export have nothing to cover. Names seen fewer than
 * `UNMATCHED_SHOWN_MIN_COUNT` times are never shown, and the weekly prune
 * removes them once they have not been seen for `UNMATCHED_RETENTION_DAYS`.
 * Art. 30 record: docs/security/unmatched-ingredients-retention.md.
 */

import { onDocumentWritten } from "firebase-functions/v2/firestore";
import { onCall, CallableRequest } from "firebase-functions/v2/https";
import { logger } from "firebase-functions/logger";
import * as admin from "firebase-admin";
import { stripDiacritics } from "../shared/swedish-normalize";
import { requireAdmin } from "../shared/require-admin";
import { clampLimit } from "../shared/validate-limit";
import { scrubPii } from "../llm/pii-scrubber";

const getDb = () => admin.firestore();

export const UNMATCHED_SHOWN_MIN_COUNT = 3;
export const UNMATCHED_RETENTION_DAYS = 365;
const MAX_NAME_LENGTH = 60;

// Spelled as literal chains: erasure-collection-coverage finds collections
// only through `.collection("<literal>")`.
const statsDoc = (db: admin.firestore.Firestore) =>
  db.collection("analytics").doc("ingredients");
const unmatchedCol = (db: admin.firestore.Firestore) =>
  db.collection("analytics").doc("ingredients").collection("unmatched");

/** Matches Dart-side normalization in ingredient_lookup_service.dart. */
export function normalizeIngredientName(name: string): string {
  return stripDiacritics(name.toLowerCase().trim())
    .replace(/[^a-z0-9]/g, "-")
    .replace(/-+/g, "-")
    .replace(/^-|-$/g, "");
}

/** A name that could carry personal data is never stored. */
export function looksPersonal(name: string): boolean {
  return (
    name.length > MAX_NAME_LENGTH ||
    name.includes("@") ||
    /https?:|www\./i.test(name) ||
    /\d{5,}/.test(name) ||
    scrubPii(name) !== name
  );
}

export function dayKey(date: Date): string {
  return date.toISOString().slice(0, 10);
}

function unknownsOf(data: admin.firestore.DocumentData | undefined): string[] {
  const raw = data?.core?.tagResult?.unknownIngredients;
  return Array.isArray(raw) ? raw.filter((n): n is string => typeof n === "string") : [];
}

/**
 * Names in `after` that were not in `before`. A name that leaves a recipe's
 * unknown list and comes back is counted again; that is accepted, since
 * `count` is a ranking signal and not a recipe tally.
 */
export function newlyUnknown(
  before: admin.firestore.DocumentData | undefined,
  after: admin.firestore.DocumentData | undefined
): string[] {
  const seen = new Set(unknownsOf(before));
  return [...new Set(unknownsOf(after))].filter((n) => !seen.has(n));
}

export async function recordUnmatched(
  db: admin.firestore.Firestore,
  names: string[],
  now: Date
): Promise<{ recorded: number; skipped: number }> {
  const byKey = new Map<string, string>();
  let skipped = 0;
  for (const name of names) {
    const trimmed = name.trim();
    if (looksPersonal(trimmed)) {
      skipped++;
      continue;
    }
    const key = normalizeIngredientName(trimmed);
    if (key && !byKey.has(key)) byKey.set(key, trimmed);
  }
  if (byKey.size === 0 && skipped === 0) return { recorded: 0, skipped: 0 };

  const today = dayKey(now);
  await db.runTransaction(async (tx) => {
    const statsRef = statsDoc(db);
    const entries = [...byKey].map(([key, name]) => ({
      name,
      ref: unmatchedCol(db).doc(key),
    }));
    const statsSnap = skipped > 0 ? await tx.get(statsRef) : null;
    const snaps: admin.firestore.DocumentSnapshot[] = [];
    for (const e of entries) snaps.push(await tx.get(e.ref));

    entries.forEach((e, i) => {
      if (!snaps[i].exists) {
        tx.set(e.ref, { name: e.name, count: 1, firstSeenDay: today, lastSeenDay: today });
        return;
      }
      // Older documents can carry recipe ids and timestamps; a write removes
      // them so no stored name stays linked to a recipe.
      tx.update(e.ref, {
        count: admin.firestore.FieldValue.increment(1),
        lastSeenDay: today,
        ...(snaps[i].get("firstSeenDay") ? {} : { firstSeenDay: today }),
        exampleRecipes: admin.firestore.FieldValue.delete(),
        firstSeen: admin.firestore.FieldValue.delete(),
        lastSeen: admin.firestore.FieldValue.delete(),
      });
    });

    if (statsSnap) {
      if (statsSnap.exists) {
        tx.update(statsRef, {
          skippedPiiCount: admin.firestore.FieldValue.increment(skipped),
        });
      } else {
        tx.set(statsRef, { skippedPiiCount: skipped });
      }
    }
  });
  return { recorded: byKey.size, skipped };
}

export async function handleRecipeWrite(
  db: admin.firestore.Firestore,
  before: admin.firestore.DocumentData | undefined,
  after: admin.firestore.DocumentData | undefined,
  now: Date
): Promise<void> {
  if (after === undefined) return;
  const names = newlyUnknown(before, after);
  if (names.length === 0) return;
  try {
    const result = await recordUnmatched(db, names, now);
    logger.info("unmatched_ingredients_recorded", result);
  } catch (error) {
    logger.error("unmatched_ingredients_failed", {
      errName: error instanceof Error ? error.name : typeof error,
    });
  }
}

export const trackUnmatchedIngredients = onDocumentWritten(
  "users/{uid}/recipes/{recipeId}",
  async (event) =>
    handleRecipeWrite(
      getDb(),
      event.data?.before.data(),
      event.data?.after.data(),
      new Date()
    )
);

/**
 * Deletes names that never reached the display threshold and have not been
 * seen for a year. Reads the whole collection once a week; it holds one
 * small document per distinct unknown name.
 */
export async function pruneUnmatchedIngredients(
  db: admin.firestore.Firestore,
  now: Date
): Promise<number> {
  const cutoff = dayKey(new Date(now.getTime() - UNMATCHED_RETENTION_DAYS * 86_400_000));
  const snap = await unmatchedCol(db).select("count", "lastSeenDay").get();
  const stale = snap.docs.filter((d) => {
    const count = d.get("count");
    const last = d.get("lastSeenDay");
    return (
      (typeof count !== "number" || count < UNMATCHED_SHOWN_MIN_COUNT) &&
      (typeof last !== "string" || last < cutoff)
    );
  });
  for (const d of stale) await d.ref.delete();
  return stale.length;
}

/** Admin only. Lists names seen at least `UNMATCHED_SHOWN_MIN_COUNT` times. */
export const getUnmatchedIngredientStats = onCall(
  async (request: CallableRequest) => {
    requireAdmin(request);

    const limit = clampLimit(request.data?.limit);
    const snapshot = await unmatchedCol(getDb())
      .where("count", ">=", UNMATCHED_SHOWN_MIN_COUNT)
      .orderBy("count", "desc")
      .limit(limit)
      .get();

    const items = snapshot.docs.map((doc) => ({
      id: doc.id,
      name: doc.get("name"),
      count: doc.get("count"),
      firstSeenDay: doc.get("firstSeenDay"),
      lastSeenDay: doc.get("lastSeenDay"),
    }));

    return { total: snapshot.size, items };
  }
);
