import * as admin from "firebase-admin";
import { logger } from "firebase-functions/logger";
import { commitInChunks } from "../../shared/batch-update";
import { Collections } from "../../shared/collections";
import { DEEP_LINK_PAGE, deleteDeepLinkDocs } from "../../shared/deep-links";
import { batchDeleteAll } from "./core";

// The SUBCOLLECTION read is what erases a real user's recipes: `users/{uid}/recipes` claim-lint:ok moved unchanged, BUT-2113
// is the only shape any production writer uses. Every `FirestoreCollections.recipes` claim-lint:ok moved unchanged, BUT-2113
// site in `lib/` that BUILDS A PATH is user-scoped — the repository's
// `collectionName` under `UserScopedFirebaseRepository`,
// `firestore_repository.userRecipesCollection`, `family_rating_service` and
// `rating_statistics`. The remaining site, `recipe_stats_repository`, is a
// `collectionGroup` READ and builds no path at all. (Stated as a property rather
// than a tally: an earlier version said "all three sites", which was wrong when
// written and would have gone stale by addition anyway.)
//
// The top-level read beside it finds nothing IN PRODUCTION — no client can write claim-lint:ok moved unchanged, BUT-2113
// that collection, since the only rule reaching it is an admin-only, read-only claim-lint:ok moved unchanged, BUT-2113
// collection-group catch-all — so it returns an empty snapshot on every real
// deletion.
//
// BUT-1801 removed it as dead weight and that was WRONG, twice over. It is
// exercised: `request-account-deletion.integration.test.ts` plants a top-level
// `recipes` doc through the Admin SDK and asserts the cascade deletes it, and
// that suite runs in CI. And an Admin-SDK writer needs no rule, so "no client
// can write it" was never the same claim as "nothing can be there". Erasure is
// the wrong place to trade defence-in-depth for one saved query.
//
// What BUT-1801 genuinely fixed is one layer down: the same top-level path had
// been copied into `probeResidualData`, where an empty result is
// indistinguishable from a clean one — a permanent all-clear that never looked
// at a recipe. The probe now counts the subcollection. Deleter stays a superset
// of the probe, which is the invariant that matters.
export async function deleteRecipes(
  db: admin.firestore.Firestore,
  uid: string,
): Promise<boolean> {
  const [sub, top] = await Promise.all([
    db.collection("users").doc(uid).collection("recipes").get(),
    db.collection("recipes").where("userId", "==", uid).get(),
  ]);
  await batchDeleteAll(db, [...sub.docs, ...top.docs]);
  return true;
}

export async function deleteMenus(
  db: admin.firestore.Firestore,
  uid: string,
): Promise<boolean> {
  // Subcollection menus under users/{uid}
  const sub = await db.collection("users").doc(uid).collection("menus").get();
  await batchDeleteAll(db, sub.docs);

  // BUT-746: top-level shared menus owned by uid.
  const owned = await db
    .collection("menus")
    .where("sharedByUserId", "==", uid)
    .get();
  await batchDeleteAll(db, owned.docs);

  // BUT-747: scrub uid from sharedToUserIds on inbound menus.
  const inbound = await db
    .collection("menus")
    .where("sharedToUserIds", "array-contains", uid)
    .get();
  if (inbound.docs.length > 0) {
    await commitInChunks(
      db,
      inbound.docs,
      (batch, doc) => {
        batch.update(doc.ref, {
          sharedToUserIds: admin.firestore.FieldValue.arrayRemove(uid),
        });
      },
      { label: "scrubInboundMenus", strict: false },
    );
  }
  return true;
}

export async function deletePersonalTags(
  db: admin.firestore.Firestore,
  uid: string,
): Promise<boolean> {
  const snap = await db
    .collection("users")
    .doc(uid)
    .collection("personal_tags")
    .get();
  await batchDeleteAll(db, snap.docs);
  return true;
}

export async function deletePersonalTagGroups(
  db: admin.firestore.Firestore,
  uid: string,
): Promise<boolean> {
  const snap = await db
    .collection("users")
    .doc(uid)
    .collection("personal_tag_groups")
    .get();
  await batchDeleteAll(db, snap.docs);
  return true;
}

export async function deleteTagOverridesLog(
  db: admin.firestore.Firestore,
  uid: string,
): Promise<boolean> {
  // BUT-1473: top-level, userId-keyed allergen tag-override corrections
  // (linked PII: userId, recipeId, tag, direction, triggeringIngredients).
  // No TTL, so GDPR Art. 17 needs an explicit cascade delete — analogous to
  // the other top-level userId-scoped own-data collections above.
  const snap = await db
    .collection("tag_overrides_log")
    .where("userId", "==", uid)
    .get();
  await batchDeleteAll(db, snap.docs);
  return true;
}

// A user's own correction log can run past one batch; paging keeps each read
// small and a re-run after a partial failure simply finds what is left.
export const PARSING_CORRECTIONS_PAGE = 500;

export async function deleteParsingCorrections(
  db: admin.firestore.Firestore,
  uid: string,
): Promise<boolean> {
  // Linked PII: userId plus the raw ingredient and instruction lines the user
  // typed, written straight from the client. Nothing else erased this
  // collection on account deletion.
  let previous: Set<string> | null = null;
  for (;;) {
    const snap = await db
      .collection("parsing_corrections")
      .where("userId", "==", uid)
      .limit(PARSING_CORRECTIONS_PAGE)
      .get();
    if (snap.empty) return true;
    const paths = new Set(snap.docs.map((d) => d.ref.path));
    const prior: Set<string> | null = previous;
    // batchDeleteAll swallows a failed chunk, so a full page that cannot be
    // deleted comes back unchanged; without this the loop re-reads it until
    // the callable times out and the later cascade steps never run.
    if (prior !== null && [...paths].every((p) => prior.has(p))) {
      logger.error("[deletion-cascade] parsing-correction page did not shrink; stopping", {
        uid_prefix: uid.slice(0, 6),
        rows: snap.size,
      });
      return false;
    }
    previous = paths;
    await batchDeleteAll(db, snap.docs);
    if (snap.size < PARSING_CORRECTIONS_PAGE) return true;
  }
}

export async function deleteCookSnaps(
  db: admin.firestore.Firestore,
  uid: string,
): Promise<boolean> {
  const snap = await db
    .collection("cook_snaps")
    .where("userId", "==", uid)
    .get();
  await batchDeleteAll(db, snap.docs);
  return true;
}

export async function deleteActivityEvents(
  db: admin.firestore.Firestore,
  uid: string,
): Promise<boolean> {
  // BUT-2350: events carry `actorId` (`ActivityEvent.toFirestore`, and the
  // create rule pins it to the caller); there is no `userId` field to match.
  const snap = await db
    .collection("activity_events")
    .where("actorId", "==", uid)
    .get();
  await batchDeleteAll(db, snap.docs);
  return true;
}

export const TEMPLATE_SWEEP_PAGE = 500;

export async function deleteShoppingListTemplates(
  db: admin.firestore.Firestore,
  uid: string,
): Promise<boolean> {
  // BUT-2354: a public template is readable by every signed-in user and
  // carries `ownerDisplayName`, so a surviving one keeps showing the erased
  // user's name. Paged like `deleteRecipeSuggestions`.
  let previous: Set<string> | null = null;
  for (;;) {
    const snap = await db
      .collection(Collections.shoppingListTemplates)
      .where("ownerId", "==", uid)
      .limit(TEMPLATE_SWEEP_PAGE)
      .get();
    if (snap.empty) return true;
    const paths = new Set(snap.docs.map((doc) => doc.ref.path));
    const prior: Set<string> | null = previous;
    if (prior !== null && [...paths].every((path) => prior.has(path))) {
      logger.error(
        "[deletion-cascade] template page did not shrink; stopping",
        { uid_prefix: uid.slice(0, 6), rows: snap.size },
      );
      return false;
    }
    previous = paths;
    await batchDeleteAll(db, snap.docs);
  }
}

/**
 * BUT-2463: the user's short links. Each one's `longUrl` carries their uid
 * (`from=`), and any signed-in account that has the code can read it. Paged
 * like `deleteShoppingListTemplates`; `deleteDeepLinkDocs` takes each link's
 * `clicks` with it.
 */
export async function deleteDeepLinks(
  db: admin.firestore.Firestore,
  uid: string,
): Promise<boolean> {
  let previous: Set<string> | null = null;
  for (;;) {
    const snap = await db
      .collection(Collections.deepLinks)
      .where("createdBy", "==", uid)
      .limit(DEEP_LINK_PAGE)
      .get();
    if (snap.empty) return true;
    const paths = new Set(snap.docs.map((doc) => doc.ref.path));
    const prior: Set<string> | null = previous;
    if (prior !== null && [...paths].every((path) => prior.has(path))) {
      logger.error(
        "[deletion-cascade] deep link page did not shrink; stopping",
        { uid_prefix: uid.slice(0, 6), rows: snap.size },
      );
      return false;
    }
    previous = paths;
    await deleteDeepLinkDocs(db, snap.docs);
  }
}

/**
 * BUT-2038. Same SHAPE as `MAX_ROSTER_SWEEP_ROWS`, not the same reason — that
 * cap exists because a PEER can seat rows keyed on this user. No such route
 * exists here: the create limb pins `userId == request.auth.uid`, so only the
 * subject inflates their own count, which is the poll-vote cap's argument.
 *
 * What it bounds is the read: an unbounded `.get()` in a callable held to 540s
 * and 512 MiB is a timeout waiting for somebody who planted the rows
 * themselves — degrading their own erasure, the same exposure `deleteCookSnaps`
 * and `deleteActivityEvents` still carry, deliberately not widened into here.
 *
 * Exported so its scenario can import it rather than retype the number.
 */
export const MAX_SUGGESTION_SWEEP_ROWS = 2000;

/**
 * BUT-2028: ingredient suggestions, the rows `firestore.rules` lets a client
 * write to `ingredient_suggestions`.
 *
 * Flat top-level collection with a raw `userId`. Nothing erased it before —
 * not this cascade, not `on-user-deleted.ts`, and not `reset-user-data.ts`
 * until that ticket added it to the script's delete list.
 *
 * **It can find zero rows for a long time, and that is expected.** No code in
 * `lib/` creates a suggestion today; `onSuggestionCreated` only updates ones
 * that already exist. What keeps the collection reachable is the `allow create`
 * limb, which lets any signed-in client write a row keyed to their own uid.
 * This leg exists so that the first such write is erasable on the day it
 * happens rather than the day someone notices — a uid-keyed row nothing deletes
 * is an Art. 17 defect from the moment it exists.
 *
 * Shipped with its probe leg, because a deleter without a probe is how an
 * erasure becomes silently incomplete and this one is new enough that nothing
 * else would notice it failing.
 */
export async function deleteIngredientSuggestions(
  db: admin.firestore.Firestore,
  uid: string,
): Promise<boolean> {
  // BUT-2038: DECLINES above the cap rather than truncating, the same verdict
  // as the roster and block sweeps. Truncating would half-erase somebody and
  // report success; declining returns false, which lands in `failedCollections`
  // and reports `gdprCompliant: false` about itself.
  //
  // `probeResidualData` counts this collection UNBOUNDED, so an over-cap case is
  // seen by the probe even though the deleter refused it — the two must not
  // quietly agree that nothing is left.
  const snap = await db
    .collection("ingredient_suggestions")
    .where("userId", "==", uid)
    .limit(MAX_SUGGESTION_SWEEP_ROWS + 1)
    .get();
  if (snap.size > MAX_SUGGESTION_SWEEP_ROWS) {
    logger.error(
      "[deletion-cascade] implausible ingredient-suggestion count; not sweeping",
      { uid_prefix: uid.slice(0, 6), rows: snap.size },
    );
    return false;
  }
  await batchDeleteAll(db, snap.docs);
  return true;
}

/**
 * Page size for [deleteRecipeSuggestions]: one Firestore batch.
 *
 * Exported so its scenario can import it rather than retype the number.
 */
export const RECIPE_SUGGESTION_SWEEP_PAGE = 500;

/**
 * P5-U27b: suggestions to someone else's shared recipe
 * (`recipe_suggestions`). claim-lint:ok moved unchanged, BUT-2113
 *
 * A row names TWO people, the suggester (`suggesterId`) and the recipe's owner
 * (`ownerId`), and it is deleted with EITHER account: the suggester's change is
 * their content, and a suggestion to a recipe whose owner is gone has nobody
 * to decide it. So both legs run, and both ship with a probe leg in
 * `probeResidualData`.
 *
 * Unlike [deleteIngredientSuggestions] this sweep has NO decline cap. The
 * `ownerId` leg is filled by OTHER people's writes (any member the recipe is
 * shared with may suggest), so a large count is no sign of a bug in this
 * user's data, and declining would let someone else hold this user's erasure
 * in a failed state. It pages through each leg in batches of
 * [RECIPE_SUGGESTION_SWEEP_PAGE] until the leg is empty. It returns false only
 * when a page makes no progress (its deletes did not land), which the probe
 * then also reports.
 */
export async function deleteRecipeSuggestions(
  db: admin.firestore.Firestore,
  uid: string,
): Promise<boolean> {
  for (const field of ["suggesterId", "ownerId"] as const) {
    let previous: Set<string> | null = null;
    for (;;) {
      const snap = await db
        .collection("recipe_suggestions")
        .where(field, "==", uid)
        .limit(RECIPE_SUGGESTION_SWEEP_PAGE)
        .get();
      if (snap.empty) break;
      const paths = new Set(snap.docs.map((doc) => doc.ref.path));
      const prior: Set<string> | null = previous;
      if (prior !== null && [...paths].every((path) => prior.has(path))) {
        logger.error(
          "[deletion-cascade] recipe-suggestion page did not shrink; stopping",
          { uid_prefix: uid.slice(0, 6), leg: field, rows: snap.size },
        );
        return false;
      }
      previous = paths;
      await batchDeleteAll(db, snap.docs);
    }
  }
  return true;
}
