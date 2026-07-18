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
 * DATA MODEL (verified 2026-07-03): `recipe_ratings` is a TOP-LEVEL collection
 * (doc-id `{recipeId}_{userId}`) carrying only {recipeId,userId,rating,review,
 * createdAt,updatedAt} — NO owner uid. Recipe CONTENT is USER-SCOPED at
 * `users/{uid}/recipes/{recipeId}` (firestore.rules has only the nested match;
 * FirebaseRecipeRepository is UserScoped). So the mirror reads the RATER'S OWN
 * copy `users/{userId}/recipes/{recipeId}` — which is the pooled model's primary
 * case (each user rates their own imported copy). A rating on a friend's recipe
 * that the rater doesn't own is not locatable server-side and simply doesn't
 * pool in v1 (skipped_no_recipe).
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
 * Feature-flag gated (decision 11): while the flag is off, create/update no-op.
 * DELETE/retraction is deliberately NOT flag-gated — retracting data must always
 * run (mirrors the existing always-on `onRatingDeleted`), or a rating deleted
 * while the feature is dark would orphan its pool vote.
 *
 * Frozen semantics (decision 4, accepted-deviations 2026-07-03): editing a
 * recipe does NOT fire this (it triggers on the rating doc, not the recipe doc),
 * so a past vote stays in the pool of the dish it judged. Deleting the *rating*
 * is an explicit retraction and removes the rater's pool contribution(s) — found
 * by the stored `recipeId`, which is edit-proof (survives key drift) and needs
 * no recipe read. Two rare frozen-key edges are accepted, see accepted-deviations.
 *
 * Stage B (the aggregate into canonical_recipe_stats) is a SEPARATE trigger on
 * the event write — added in Increment 3, not here.
 */

import * as admin from "firebase-admin";
import { logger } from "firebase-functions/logger";
import { computePoolKey, poolKeyComponents } from "./canonical-pool-key";
import { isPooledRatingsEnabled } from "./pooled-ratings-flag";
import { hashUid } from "../shared/hash-uid";

/** Firestore path this mirror is bound to. Bound to recipe_ratings ONLY — the
 *  structural guarantee that family ratings never pool (decision 7). */
export const POOL_MIRROR_TRIGGER_PATH = "recipe_ratings/{ratingId}";

/** Per-user subcollection holding one frozen pool event per pool the user voted in. */
export const CANONICAL_EVENTS_SUBCOLLECTION = "canonical_rating_events";

/** Decision 7: an account must be this old (or email-verified) before its
 *  ratings count toward a public pool — anti-throwaway-account spam. */
export const kAccountMaturityWindowMs = 60 * 60 * 1000; // 60 minutes

// In-isolate memo of uids proven matured. Maturity is monotonic (once true it
// stays true), so we never re-query a known-matured uid — saves an Identity
// Platform round-trip per rating in a burst. Immature/unknown uids are not
// cached (they may cross the window at any time). Capped so a long-lived,
// high-traffic isolate can't accumulate unbounded retained state — on overflow
// we simply clear (the memo is a pure optimization; a cold re-query is correct).
const maturedUids = new Set<string>();
const MATURED_MEMO_CAP = 10_000;

/** Test-only reset so a fresh account can be re-evaluated between cases. */
export function __resetMaturedMemoForTests(): void {
  maturedUids.clear();
}

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
    | "skipped_flag" // kill switch off — feature dark (create/update only)
    | "skipped_invalid" // missing uid/recipeId or out-of-range/NaN rating
    | "skipped_immature" // account-maturity gate (decision 7)
    | "skipped_no_recipe" // rater's own recipe copy not found — cannot derive key
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
 * Compute the poolKey for the rater's own recipe copy. Returns null if the
 * recipe doc is missing OR the content yields no key (fail-closed). Reads
 * `users/{uid}/recipes/{recipeId}` — the user-scoped location (see module doc).
 */
// Exported so the one-shot backfill CF (migrations/backfill-canonical-ratings.ts)
// derives keys through the IDENTICAL code path — a forked copy could silently
// drift from the live mirror (the C5 word-list lesson applied to the derivation).
export async function recipeContentToKey(
  db: admin.firestore.Firestore,
  uid: string,
  recipeId: string,
  computeKey: (title: string, ingredients: string[]) => string | null
): Promise<{
  found: boolean;
  poolKey: string | null;
  // The content the key was derived from, passed through so the caller can emit
  // anchor / ingredient-signature telemetry (BUT-1518) WITHOUT a second recipe
  // read. Empty defaults when the recipe is absent.
  title: string;
  ingredients: string[];
}> {
  const snap = await db
    .collection("users")
    .doc(uid)
    .collection("recipes")
    .doc(recipeId)
    .get();
  if (!snap.exists)
    return { found: false, poolKey: null, title: "", ingredients: [] };
  const core = (snap.data()?.core ?? {}) as {
    title?: unknown;
    ingredients?: unknown;
  };
  const title = typeof core.title === "string" ? core.title : "";
  const ingredients = Array.isArray(core.ingredients)
    ? (core.ingredients.filter((s) => typeof s === "string") as string[])
    : [];
  return { found: true, poolKey: computeKey(title, ingredients), title, ingredients };
}

/**
 * Decision 7 maturity gate. The source rating already proves the account is
 * age-compliant; this only adds the "not a fresh throwaway" requirement.
 *
 * Distinguishes two failure modes (the earlier version conflated them, losing
 * real votes): a DETERMINATE "young/unverified" returns false (skip, no retry);
 * an INDETERMINATE transient `getUser` error THROWS so the trigger retries
 * (with `{ retry: true }`) — otherwise a mature user's vote is silently dropped.
 * A deleted account (`auth/user-not-found`) is terminal → false (no retry).
 */
// Exported for the backfill CF — the maturity gate (with its transient-vs-terminal
// error handling) must be byte-identical between the live mirror and the backfill.
export async function isAccountMatured(
  uid: string,
  nowMs: number,
  deps: MirrorDeps
): Promise<boolean> {
  if (maturedUids.has(uid)) return true;
  const auth = deps.auth ?? admin.auth();
  let user: admin.auth.UserRecord;
  try {
    user = await auth.getUser(uid);
  } catch (err) {
    const code = (err as { code?: string })?.code;
    if (code === "auth/user-not-found") return false; // terminal: account gone
    logger.warn("pool_mirror maturity lookup failed transiently; will retry", {
      uidHash: hashUid(uid),
      err,
    });
    throw err; // transient → propagate so the trigger retries
  }
  let matured = false;
  if (user.emailVerified) {
    matured = true;
  } else {
    const created = user.metadata?.creationTime;
    const createdMs = created ? new Date(created).getTime() : NaN;
    matured = !Number.isNaN(createdMs) && nowMs - createdMs >= kAccountMaturityWindowMs;
  }
  if (matured) {
    if (maturedUids.size >= MATURED_MEMO_CAP) maturedUids.clear();
    maturedUids.add(uid);
  }
  return matured;
}

/**
 * Mirror one `recipe_ratings` write into the pooled-rating event store.
 * Pure-ish: all IO goes through injectable deps so it is unit-testable with a
 * Firestore stub and a fake auth. May throw on transient IO (recipe read, event
 * write, maturity lookup) — the trigger re-runs it under `{ retry: true }`.
 */
export async function mirrorRatingToPool(
  input: MirrorInput,
  deps: MirrorDeps = {}
): Promise<MirrorResult> {
  const db = deps.db ?? admin.firestore();
  const now = deps.now ?? (() => Date.now());
  const computeKey = deps.computeKey ?? computePoolKey;

  const isDelete = input.after === null && input.before !== null;

  // ── Retraction: remove the rater's contribution(s) for THIS recipe ──
  // NOT flag-gated — a deletion must always be honored, or turning the kill
  // switch off would orphan votes for ratings deleted while dark. Found by the
  // stored recipeId (edit-proof: survives poolKey drift from a since-edited
  // recipe; needs no recipe read; works even if the recipe was itself deleted).
  if (isDelete) {
    const before = input.before!;
    const uid = before.userId;
    const recipeId = before.recipeId;
    if (!uid || !recipeId) return { action: "skipped_invalid" };

    const snap = await eventsRef(db, uid)
      .where("recipeId", "==", recipeId)
      .get();
    if (snap.empty) return { action: "delete_noop", uid };
    await Promise.all(snap.docs.map((doc) => doc.ref.delete()));
    return { action: "deleted", uid, deletedCount: snap.size };
  }

  // ── Create / update: derive the key server-side and upsert one event ──
  // Flag-gated (kill switch). Deletes above are intentionally NOT gated.
  // Parens matter: `await` MUST cover the whole `?? fallback`. Without them, in
  // production (deps.isEnabled undefined) `await` binds only to
  // `deps.isEnabled?.()` → awaits `undefined`, leaving the fallback Promise
  // un-awaited (always truthy) → the kill switch silently disables itself.
  // isPooledRatingsEnabled THROWS if RC is unreachable (indeterminate ≠ off) so
  // the retry-enabled trigger re-runs — a vote is not lost to a brief RC blip.
  if (!(await (deps.isEnabled?.() ?? isPooledRatingsEnabled()))) {
    return { action: "skipped_flag" };
  }

  const after = input.after;
  if (!after) return { action: "skipped_invalid" };
  const uid = after.userId;
  const recipeId = after.recipeId;
  const rating = after.rating;
  // Number.isFinite rejects NaN/Infinity (which slip past the < / > comparisons)
  // while ALLOWING fractional half-star ratings — firestore.rules and the Dart
  // `double rating` API permit non-integer [1,5], and recipe_social_stats counts
  // them, so the pool must too (Number.isInteger would silently drop half-stars).
  if (
    !uid ||
    !recipeId ||
    typeof rating !== "number" ||
    !Number.isFinite(rating) ||
    rating < 1 ||
    rating > 5
  ) {
    return { action: "skipped_invalid" };
  }

  // Maturity gate BEFORE the billed recipe read: the memoized `getUser` is far
  // cheaper (and free after the first hit) than the recipe read, so the free
  // anti-throwaway-spam check gates the paid read. (No skipped_unchanged gate:
  // it would make a rating first cast while immature never pool after the
  // account matures unless the star value later changed — a common miss.)
  const matured = await isAccountMatured(uid, now(), deps);
  if (!matured) return { action: "skipped_immature", uid };

  const keyed = await recipeContentToKey(db, uid, recipeId, computeKey);
  if (!keyed.found) return { action: "skipped_no_recipe" };
  if (keyed.poolKey === null) return { action: "skipped_no_key" };
  const poolKey = keyed.poolKey;

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

  // ── Rating-laundering visibility (C10 / BUT-1518) ──
  // Emit the pool key's two orthogonal dimensions — the dish `anchor` and an
  // ingredient-only `ingredientSig` — as a structured telemetry line. Because a
  // rating is frozen to its dish (no edit-triggered detachment, decision 6) and
  // this mirror does not see recipe edits, the CF cannot compare a poolKey to
  // its own past value without a hot-path read (rejected on cost) or a stored
  // field (out of scope). Logging the dimensions instead makes the two cases
  // separable OFFLINE: across a recipeId's events, an anchor-only title change
  // shows a STABLE ingredientSig with a moved anchor/poolKey (the cheap
  // laundering lever), whereas a genuine dish change also moves ingredientSig.
  // Deterministic, no LLM, no new field or collection, no extra Firestore read
  // (recipeContentToKey already read this content). Reuses computePoolKey's own
  // normalization (poolKeyComponents), so it can never drift from the key.
  const dims = poolKeyComponents(keyed.title, keyed.ingredients);
  logger.info(
    JSON.stringify({
      tag: "pool_key_dimensions",
      uidHash: hashUid(uid),
      recipeId,
      poolKey,
      anchorSig: dims?.anchorSig ?? null,
      ingredientSig: dims?.ingredientSig ?? null,
    })
  );

  return { action: "upserted", uid, poolKey, ratingValue: rating };
}
