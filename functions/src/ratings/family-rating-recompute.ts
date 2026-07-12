/**
 * Decision helpers for the `onFamilyRatingUpdated` public-aggregation trigger.
 *
 * Extracted from index.ts so the recompute gate is unit-testable without
 * importing the whole functions entrypoint (which runs `admin.initializeApp`
 * and pulls in every LLM module). index.ts imports both helpers.
 */

import * as admin from "firebase-admin";

type Data = admin.firestore.DocumentData | undefined;

/** True when a family_ratings doc is a non-account diner-profile rating. */
export function isProfileRating(data: Data): boolean {
  return data?.memberType === "profile";
}

/**
 * True when a family_ratings UPDATE must re-run public rating aggregation.
 *
 * Recompute whenever the row participates in the public average either BEFORE
 * or AFTER the update:
 *  - a memberType flip in EITHER direction — promotion INTO `profile`
 *    (BUT-1511) or demotion OUT OF `profile` (BUT-1592) — changes whether the
 *    row counts toward the public average, so it recomputes even with unchanged
 *    stars;
 *  - a both-`profile` update recomputes only when the star value changed;
 *  - a both-non-`profile` update never touches the public counter (adult/proxy
 *    `user` rows go via recipe_ratings), so it costs no recompute.
 *
 * The demotion case (BUT-1592) matters because a row leaving `profile` must
 * drop out of the public average — the old `after`-only gate short-circuited
 * it and left the average stale.
 */
export function shouldRecomputeOnFamilyRatingUpdate(
  before: Data,
  after: Data
): boolean {
  const wasProfile = isProfileRating(before);
  const isProfile = isProfileRating(after);
  if (!wasProfile && !isProfile) return false;
  if (wasProfile !== isProfile) return true;
  return before?.stars !== after?.stars;
}
