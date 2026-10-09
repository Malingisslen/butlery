/**
 * BUT-1600: the recipe-card family average refresh that the dormant-family
 * sweep runs after deleting orphaned ratings. Split out of
 * `purge-dormant-family-data.ts` to keep that file under the 500-line limit.
 */

import * as admin from "firebase-admin";
import { commitInChunks } from "../shared/batch-update";

/** Firestore's getAll rejects an empty arg list; page it so an unbounded
 * candidate set (a heavy rater leaving) never builds one oversized read. */
async function getAllChunked(
  db: admin.firestore.Firestore,
  refs: admin.firestore.DocumentReference[]
): Promise<admin.firestore.DocumentSnapshot[]> {
  const CHUNK = 300;
  const out: admin.firestore.DocumentSnapshot[] = [];
  for (let i = 0; i < refs.length; i += CHUNK) {
    out.push(...(await db.getAll(...refs.slice(i, i + CHUNK))));
  }
  return out;
}

/** A recipe copy already carries a denormalised family pill worth refreshing. */
function hasDenormFamilyValue(data: admin.firestore.DocumentData | undefined): boolean {
  const core = data?.core as Record<string, unknown> | undefined;
  return core != null &&
    (core.familyRatingCount != null || core.familyAverage != null);
}

/**
 * BUT-1600: recompute the denormalised recipe-card family average on every
 * household member's own recipe copy for each recipe an orphan rating touched.
 * Uses the SURVIVING ratings (simple unweighted mean, matching the client's
 * `FamilyRatingSummary.fromRatings`); clears the pill (null) when no rating
 * remains. Only patches copies that already hold a family value — never adds the
 * fields to a copy that never had a family pill. Best-effort: a failure here
 * leaves the pill to self-heal on the next in-app rating.
 */
export async function recomputeDenormalisedAverages(
  db: admin.firestore.Firestore,
  orphans: admin.firestore.QueryDocumentSnapshot[],
  survivors: admin.firestore.QueryDocumentSnapshot[],
  memberUserIds: string[]
): Promise<void> {
  const affectedRecipeIds = new Set<string>();
  for (const o of orphans) {
    const rid = o.data().recipeId;
    if (typeof rid === "string" && rid) affectedRecipeIds.add(rid);
  }
  if (affectedRecipeIds.size === 0 || memberUserIds.length === 0) return;

  const byRecipe = new Map<string, { sum: number; count: number }>();
  for (const s of survivors) {
    const d = s.data();
    const rid = d.recipeId;
    const stars = d.stars;
    if (typeof rid !== "string" || !affectedRecipeIds.has(rid)) continue;
    if (typeof stars !== "number" || stars < 1 || stars > 5) continue;
    const agg = byRecipe.get(rid) ?? { sum: 0, count: 0 };
    agg.sum += stars;
    agg.count += 1;
    byRecipe.set(rid, agg);
  }

  const refs: admin.firestore.DocumentReference[] = [];
  for (const uid of memberUserIds) {
    for (const rid of affectedRecipeIds) {
      refs.push(
        db.collection("users").doc(uid).collection("recipes").doc(rid)
      );
    }
  }
  const snaps = await getAllChunked(db, refs);
  const patchable = snaps.filter(
    (s) => s.exists && hasDenormFamilyValue(s.data())
  );
  if (patchable.length === 0) return;

  await commitInChunks(
    db,
    patchable,
    (batch, snap) => {
      const agg = byRecipe.get(snap.ref.id);
      const hasRatings = agg != null && agg.count > 0;
      batch.update(snap.ref, {
        "core.familyAverage": hasRatings ? agg!.sum / agg!.count : null,
        "core.familyRatingCount": hasRatings ? agg!.count : null,
      });
    },
    { label: "recomputeFamilyCardAverage", strict: false }
  );
}
