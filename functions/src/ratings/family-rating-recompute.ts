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
 * Gated to updates whose `after` is still a diner-profile row — adult/proxy
 * (`user`) rows never touch the public counter, so their edits cost no
 * recompute. Within that gate, recompute when EITHER the star value changed
 * OR the memberType flipped: a memberType-only flip (e.g. a row promoted INTO
 * `profile`) changes whether the row counts toward the public average, so it
 * must trigger a recompute even when the star value is unchanged (BUT-1511).
 *
 * Note: a demotion (`profile` -> non-`profile`) is intentionally NOT handled
 * here — the `after` guard short-circuits first. That residual case is out of
 * BUT-1511's scope (which targets only the recompute condition).
 */
export function shouldRecomputeOnFamilyRatingUpdate(
  before: Data,
  after: Data
): boolean {
  if (!isProfileRating(after)) return false;
  return (
    before?.stars !== after?.stars ||
    before?.memberType !== after?.memberType
  );
}
