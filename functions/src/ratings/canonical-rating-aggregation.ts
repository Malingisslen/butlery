/**
 * Stage A of the pooled-ratings pipeline ("Butlery-betyget") — the
 * server-authoritative mirror. See tasks/pooled-ratings-plan.md (decisions
 * 2, 4, 7) and tasks/todo.md Increment 2.
 *
 * On every write to a `recipe_ratings/{ratingId}` doc (the 'alla' rating, one
 * per user per recipe), this recomputes the recipe-identity poolKey HERE from
 * the recipe's own content and files ONE frozen pool event for the rater:
 *   users/{uid}/canonical_rating_events/{poolKey} = {poolKey, ratingValue, recipeId, createdAt}
 *
 * Guarantees this module enforces (not the security rules):
 *   - **Pool-poisoning defense (decision 2):** the key is ALWAYS recomputed by
 *     `computePoolKey` from the recipe content. A client-written key on the
 *     rating doc is never read — a tampered value cannot route a vote.
 *   - **One vote per uid per pool (decision 4):** the event doc-ID IS the
 *     poolKey, so a user rating two different recipes that map to the same dish
 *     writes to the same doc — their latest rating wins, never two votes.
 *   - **Account-maturity gate (decision 7):** the source rating already proves
 *     age-compliance (firestore.rules `isAgeCompliant` on create); this adds the
 *     maturity requirement the rules do NOT enforce (emailVerified OR account
 *     age ≥ 60 min).
 *   - **Family exclusion (decision 7):** family diners rate in the separate
 *     `family_ratings` collection; this trigger is bound to `recipe_ratings`
 *     ONLY, so a family rating structurally never reaches a pool.
 *
 * Feature-flag gated (decision 11): flag off ⇒ every path no-ops (no event
 * written, no event deleted) — the feature is fully dark.
 *
 * Frozen semantics (decision 4, accepted-deviations 2026-07-03): editing a
 * recipe does NOT fire this (it triggers on the rating doc, not the recipe doc),
 * so a past vote stays in the pool of the dish it judged. Deleting the *rating*
 * is an explicit retraction and removes the rater's pool contribution(s) — keyed
 * off the stored `recipeId`, which is edit-proof and needs no recipe read.
 *
 * Stage B (the aggregate into canonical_recipe_stats) is a SEPARATE trigger on
 * the event write — added in Increment 3, not here.
 */

import * as admin from "firebase-admin";
import { logger } from "firebase-functions/logger";
import { computePoolKey } from "./canonical-pool-key";
import { isPooledRatingsEnabled } from "./pooled-ratings-flag";

/** Firestore path this mirror is bound to. Bound to recipe_ratings ONLY — the
 *  structural guarantee that family ratings never pool (decision 7). */
export const POOL_MIRROR_TRIGGER_PATH = "recipe_ratings/{ratingId}";

/** Per-user subcollection holding one frozen pool event per pool the user voted in. */
export const CANONICAL_EVENTS_SUBCOLLECTION = "canonical_rating_events";

/** Decision 7: an account must be this old (or email-verified) before its
 *  ratings count toward a public pool — anti-throwaway-account spam. */
export const kAccountMaturityWindowMs = 60 * 60 * 1000; // 60 minutes

/** The fields this mirror reads off a `recipe_ratings` doc. */
export interface RatingDoc {
  userId?: string;
  recipeId?: string;
  rating?: number;
}

export interface MirrorInput {
  ratingId: string;
  /** `recipe_ratings` doc state before the write (null on create). */
  before: RatingDoc | null;
  /** `recipe_ratings` doc state after the write (null on delete). */
  after: RatingDoc | null;
}

export interface MirrorDeps {
  db?: admin.firestore.Firestore;
  auth?: admin.auth.Auth;
  /** now in ms; test seam. */
  now?: () => number;
  /** Feature-flag check; test seam. Defaults to the RC-backed kill switch. */
  isEnabled?: () => Promise<boolean>;
  /** poolKey recompute; test seam. Defaults to the TS authority `computePoolKey`. */
  computeKey?: (title: string, ingredients: string[]) => string | null;
}

export interface MirrorResult {
  action:
    | "skipped_flag" // kill switch off — feature dark
    | "skipped_invalid" // missing uid/recipeId or out-of-range rating
    | "skipped_unchanged" // update that didn't change the rating value
    | "skipped_immature" // account-maturity gate (decision 7)
    | "skipped_no_recipe" // recipe doc gone — cannot derive the key
    | "skipped_no_key" // fail-closed key (no anchor / no ingredient names)
    | "upserted" // one pool event written
    | "deleted" // rating retracted — event(s) removed
    | "delete_noop"; // retraction but no matching event to remove
  uid?: string;
  poolKey?: string;
  ratingValue?: number;
  deletedCount?: number;
}

function eventsRef(
  db: admin.firestore.Firestore,
  uid: string
): admin.firestore.CollectionReference {
  return db.collection("users").doc(uid).collection(CANONICAL_EVENTS_SUBCOLLECTION);
}

/**
 * Decision 7 maturity gate. The source rating already proves the account is
 * age-compliant; this only adds the "not a fresh throwaway" requirement.
 * Fail-closed: any lookup error ⇒ treat as immature (do not write a vote).
 */
async function isAccountMatured(
  uid: string,
  nowMs: number,
  deps: MirrorDeps
): Promise<boolean> {
  const auth = deps.auth ?? admin.auth();
  try {
    const user = await auth.getUser(uid);
    if (user.emailVerified) return true;
    const created = user.metadata?.creationTime;
    if (!created) return false;
    const createdMs = new Date(created).getTime();
    if (Number.isNaN(createdMs)) return false;
    return nowMs - createdMs >= kAccountMaturityWindowMs;
  } catch (err) {
    logger.warn("pool_mirror maturity check failed; treating as immature", {
      uid,
      err,
    });
    return false;
  }
}

/**
 * Mirror one `recipe_ratings` write into the pooled-rating event store.
 * Pure-ish: all IO goes through injectable deps so it is unit-testable with a
 * Firestore stub and a fake auth.
 */
export async function mirrorRatingToPool(
  input: MirrorInput,
  deps: MirrorDeps = {}
): Promise<MirrorResult> {
  const isEnabled = deps.isEnabled ?? isPooledRatingsEnabled;
  if (!(await isEnabled())) return { action: "skipped_flag" };

  const db = deps.db ?? admin.firestore();
  const now = deps.now ?? (() => Date.now());
  const computeKey = deps.computeKey ?? computePoolKey;

  const isDelete = input.after === null && input.before !== null;

  // ── Retraction: remove the rater's contribution(s) from THIS recipe ──
  // Keyed off the stored recipeId (edit-proof; no recipe read; works even if
  // the recipe was itself deleted). A user cannot have two live ratings for one
  // recipe, so this removes exactly the event(s) this recipe backed.
  if (isDelete) {
    const before = input.before!;
    const uid = before.userId;
    const recipeId = before.recipeId;
    if (!uid || !recipeId) return { action: "skipped_invalid" };

    const snap = await eventsRef(db, uid)
      .where("recipeId", "==", recipeId)
      .get();
    if (snap.empty) return { action: "delete_noop", uid };
    for (const doc of snap.docs) {
      await doc.ref.delete();
    }
    return { action: "deleted", uid, deletedCount: snap.size };
  }

  // ── Create / update: derive the key server-side and upsert one event ──
  const after = input.after;
  if (!after) return { action: "skipped_invalid" };
  const uid = after.userId;
  const recipeId = after.recipeId;
  const rating = after.rating;
  if (
    !uid ||
    !recipeId ||
    typeof rating !== "number" ||
    rating < 1 ||
    rating > 5
  ) {
    return { action: "skipped_invalid" };
  }

  // No-op when the update didn't change the rating value (review-text edit,
  // `updatedAt` touch, client re-save). Two reasons this matters:
  //  - Cost: skip a billed recipe read + event write per incidental write
  //    (mirrors the sibling `onRatingUpdated`'s before.rating===after.rating gate).
  //  - Correctness/anti-gaming: the key is recomputed from CURRENT recipe
  //    content, so reprocessing an unchanged rating AFTER the recipe was edited
  //    would file a vote at the new dish's key that the user never actively cast
  //    — and would let someone pad a pool by editing the recipe then touching
  //    the rating. The frozen design (decision 4) forbids exactly that.
  if (
    input.before &&
    input.before.rating === rating &&
    input.before.recipeId === recipeId
  ) {
    return { action: "skipped_unchanged", uid };
  }

  // Maturity gate BEFORE the billed recipe read: `getUser` is free, the recipe
  // read is billed, so the free anti-throwaway-spam check gates the paid read.
  const matured = await isAccountMatured(uid, now(), deps);
  if (!matured) return { action: "skipped_immature", uid };

  // Read the rater's own recipe copy — the ONLY source of the key. A poolKey
  // written on the rating doc by a client is deliberately never consulted.
  const recipeSnap = await db.collection("recipes").doc(recipeId).get();
  if (!recipeSnap.exists) return { action: "skipped_no_recipe" };
  const core = (recipeSnap.data()?.core ?? {}) as {
    title?: unknown;
    ingredients?: unknown;
  };
  const title = typeof core.title === "string" ? core.title : "";
  const ingredients = Array.isArray(core.ingredients)
    ? (core.ingredients.filter((s) => typeof s === "string") as string[])
    : [];

  const poolKey = computeKey(title, ingredients);
  if (poolKey === null) return { action: "skipped_no_key" };

  await eventsRef(db, uid).doc(poolKey).set({
    poolKey,
    ratingValue: rating,
    recipeId,
    // NOTE (Low, defer to Increment 3): serverTimestamp() is rewritten on every
    // upsert, so a CF retry/reprocess shifts it — last-write, not first-create,
    // semantics. Harmless today (no reader). Stage B must decide deliberately:
    // accept last-write (rename updatedAt) or preserve first-create (merge-if-absent).
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
  });
  return { action: "upserted", uid, poolKey, ratingValue: rating };
}
