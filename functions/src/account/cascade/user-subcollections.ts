import * as admin from "firebase-admin";
import { batchDeleteAll } from "./core";

/**
 * The `users/{uid}` subcollections `onUserDeleted` (cleanupContentGuardSubcollections)
 * owns, which run AFTER `admin.auth().deleteUser(uid)`.
 *
 * `probeResidualData` runs BEFORE that, so without the exclusion every single claim-lint:ok moved unchanged, BUT-2113
 * deletion would report them as residual and `gdprCompliant` would be false
 * forever, for every user.
 *
 * Exported (BUT-2043) so guards and the reset script's unknown-collection
 * report read the real value instead of parsing this file as source text. The
 * text parsers matched `[A-Za-z_]+` and stripped only `//` comments, so a name
 * carrying a digit was invisible to them and a quoted name inside a block
 * comment was read as a list entry. The `EXPORT_EXEMPT` const below is the
 * precedent, in this same file: no separate module is needed, because nothing
 * here runs at import.
 */
export const TRIGGER_OWNED_SUBCOLLECTIONS: ReadonlySet<string> = new Set([
  "notificationCounters",
  "recentContentHashes",
]);

/**
 * `users/{uid}` subcollections this cascade erases but the Art. 15 export
 * deliberately does NOT reproduce, each with the reason it is exempt.
 *
 * BUT-1992. The invariant is EXPORT ⊇ DELETION: anything erased on account
 * deletion must have been obtainable by its subject first, or it is erased
 * having never been disclosable. `scenario_exportCoversEveryDeletedSubcollection`
 * holds it, and a name that is neither exported nor listed here reddens.
 *
 * This lives in production source rather than in the test on purpose. An
 * exemption added here shows up in the diff a reviewer reads; one added inside
 * the test file reads as test bookkeeping and gets waved through — which is how
 * an escape hatch built to be deliberate becomes a rubber stamp.
 *
 * Malin's explicit calls, 2026-09-03, taken one question at a time against the
 * panel's split. She went AGAINST the recommendation on `rate_limits`, which was
 * to export it: the Security seat had measured that nothing secret is disclosed
 * (the limits live in client code and are already visible in the throttling copy
 * the user sees). She weighed
 * bundle legibility higher.
 * Recording it because a future reader will otherwise assume the security
 * argument won, and re-litigate a decision that was made on other grounds.
 *
 * An exemption the subject cannot see is an undisclosed gap, not a
 * minimisation decision (Art. 12(1), the BUT-1971 precedent).
 */
export const EXPORT_EXEMPT: Record<string, string> = {
  // ── Withheld on purpose, with a live writer. These are the decisions. ──
  rate_limits:
    "PLUMBING. " +
    "Malin, 2026-09-03, weighing bundle " +
    "legibility higher. Named in the bundle's data_minimisation line.",
  counters:
    "PLUMBING. Derived unread tallies over content this export already " +
    "reproduces in full, so they add nothing the bundle lacks. Their values " +
    "are also partly OTHER people's actions (the update limb accepts a " +
    "cross-user increment), so a per-actor breakdown must never be added. " +
    "Malin, 2026-09-03. Named in the bundle's data_minimisation line.",
  report_throttle:
    "PLUMBING: the cooldown between abuse reports, written by " +
    "firebase_report_repository.dart. NOT the same shape as rate_limits — its " +
    "doc id is the REPORTED user's uid (`contentOwnerId`), where rate_limits " +
    "ids are operation names. The substantive reason it is exempt is that the " +
    "reports themselves ARE exported (`reports` where `reporterId == uid`, " +
    "each already carrying `contentOwnerId`), so the throttle adds only a " +
    "derived recency stamp on top of rows the subject already receives. " +
    "NOT put to Malin — it was not among the three questions she was asked. " +
    "Named in the bundle's data_minimisation line like the two above.",

  block_mirror:
    "WITHHELD BY THE SAME DECISION as the `blocks` incoming direction, and " +
    "argued on its own facts rather than inherited. " +
    "`users/{uid}/block_mirror/current` holds the uids of everyone who has " +
    "blocked this user. Malin decided on 2026-09-05 (BUT-2018) that an " +
    "Art. 15 bundle must not tell a requester who blocked them nor how many " +
    "people did: Art. 15(4) permits withholding a copy that would adversely " +
    "affect the rights and freedoms of others, and a block is placed by " +
    "someone wanting distance from — often — the requester themselves. That " +
    "reasoning is about the FACT, so it reaches every store of it: the " +
    "`blocks` rows the mirror derives from, and this projection of them. " +
    "Withholding the source while exporting the copy would hand over the " +
    "same disclosure through a second door. " +
    "The omission is disclosed to the subject in the blocks section's own " +
    "`data_minimisation` line, which states that who has blocked them is " +
    "left out and why. " +
    "`scenario_blockMirrorExemptionRestsOnTheSameDecision` fails if that " +
    "section returns, so the dependency stays enforced rather than " +
    "described.",
  // ── Removed collection. Not a withholding, and not the family below. ──
  conversation_memberships:
    "REMOVED COLLECTION (BUT-1850, 2026-09-17). This is NOT a withholding " +
    "decision and rests on no Art. 15(4) argument — it is a claim about the " +
    "code: the client writer, the model and the firestore.rules block are all " +
    "deleted in the same change, so no new row can be created and no client " +
    "could read one if it were. Deliberately NOT prefixed NO LIVE WRITER: " +
    "that family means the collection is still readable and holds legacy rows " +
    "only, which is a materially different state from a deleted rules block. " +
    "The name stays in USER_SUBCOLLECTIONS for one release because it is then " +
    "the only remaining erasure handle — probeResidualData ENUMERATES, so " +
    "dropping it would leave a row written in the deploy window counted " +
    "forever with no deleter able to clear it. Scoped residual: for an " +
    "account that still holds rows written before the rules deploy, those " +
    "rows are erasable. BUT-2109 removes this entry " +
    "and the subs entry in the SAME edit — taking either alone reddens " +
    "scenario_exportCoversEveryDeletedSubcollection from one side or the " +
    "other. No disclosure site, deliberately: nothing is withheld, so no " +
    "data_minimisation line names it.",

  // ── No writer of the `users/{uid}` path. Swept for legacy rows only. ──
  // The cascade sweeps these so an account predating their removal cannot hold
  // rows the probe reports forever. Nothing writes them today, so for a current
  // account the export omits nothing.
  //
  // The residual the DPO seat named, recorded rather than argued away: for an
  // account that DOES still hold legacy rows, they are erasable but were never
  // exportable. Whether that is worth an export section for a shape no live
  // code writes is Malin's, and has not been asked.
  category_memberships:
    "NO LIVE WRITER of users/{uid}/category_memberships. Legacy sweep only.",
  connection_tests:
    "NO LIVE WRITER of users/{uid}/connection_tests. Legacy sweep only.",
  unified_recipes:
    "NO LIVE WRITER of users/{uid}/unified_recipes. Legacy sweep only.",
  conversations:
    "NO LIVE WRITER of the users/{uid}/conversations SUBCOLLECTION. The real " +
    "conversations are the top-level collection, which the export covers in " +
    "its own section. Legacy sweep only.",
  fcm_tokens:
    "NO LIVE WRITER of the users/{uid}/fcm_tokens SUBCOLLECTION — BUT-1990 " +
    "measured that it never had one. Device tokens live in the TOP-LEVEL " +
    "user_fcm_tokens, which the export reads by userId field. Legacy sweep " +
    "only; do not read the shared name as the same data.",
  user_shared_menus:
    "NO LIVE WRITER of the users/{uid}/user_shared_menus SUBCOLLECTION. The " +
    "share index is the TOP-LEVEL user_shared_menus/{recipientId}/" +
    "received_menus, and the shared menus themselves are exported by the " +
    "shared_content section. Same top-level-vs-subcollection name collision " +
    "as fcm_tokens. Legacy sweep only.",
  friendCategories:
    "NO LIVE WRITER of users/{uid}/friendCategories — the PRE-RENAME spelling " +
    "of friend_categories, which IS exported. `admin/migrate-friend-categories.ts` " +
    "moves a row under this spelling onto the live one. The alternative was a new " +
    "firestore.rules read block for the dead spelling, because the export runs " +
    "on the CLIENT SDK and that path has none. Malin chose the migration, " +
    "2026-09-08. Legacy sweep only.",
  rateLimits:
    "NO LIVE WRITER of users/{uid}/rateLimits — the PRE-RENAME spelling of " +
    "rate_limits, which is also exempt. One collection under two spellings, " +
    "evidenced by the rename commit, not two collections sharing a word. " +
    "So this inherits the standing decision rather than making a new one: " +
    "Malin, 2026-09-03, chose EXEMPT for rate_limits against the " +
    "recommendation to export it, weighing bundle legibility higher " +
    "(ADR-0011). Adding an export section here would reopen that " +
    "decision. Legacy sweep only. BUT-2040.",
  user_shared_shopping_lists:
    "NO LIVE WRITER of the users/{uid}/user_shared_shopping_lists " +
    "SUBCOLLECTION. The index is top-level, and the lists themselves are " +
    "exported by the shared_shopping_lists section (BUT-1732). Legacy sweep " +
    "only.",
};

export async function deleteUserPreferences(
  db: admin.firestore.Firestore,
  uid: string,
): Promise<boolean> {
  // The whole COLLECTION, not `settings/preferences` by id (BUT-1957).
  // `probeResidualData` counts collections, so a delete keyed to one document
  // id leaves any second document under `settings` reported as residual with no
  // step able to remove it — a `gdprCompliant: false` nobody can clear, plus a
  // real Art. 17 residual. `firestore.rules` leaves the id unconstrained on an
  // owner-only create, so a second document is a client write away.
  // Idempotent, and still deletes `preferences`.
  const snap = await db.collection("users").doc(uid).collection("settings").get();
  await batchDeleteAll(db, snap.docs);
  return true;
}

export async function deleteConsentRecords(
  db: admin.firestore.Firestore,
  uid: string,
): Promise<boolean> {
  const snap = await db
    .collection("users")
    .doc(uid)
    .collection("consent")
    .get();
  await batchDeleteAll(db, snap.docs);
  return true;
}

/**
 * The `users/{uid}` subcollections `deleteUserSubcollections` sweeps.
 *
 * Exported (BUT-2043) so the guards and the reset script's unknown-collection
 * report read the REAL value instead of parsing this file as source text. Two
 * guards used to do that with `/"([A-Za-z_]+)"/` over a body with only `//`
 * comments stripped, which made a name carrying a digit invisible to them and
 * read a quoted name inside a block comment as a list entry. `EXPORT_EXEMPT`
 * is the precedent, in this same file — no separate module is needed,
 * because nothing here runs at import.
 */
export const USER_SUBCOLLECTIONS: readonly string[] = [
  "conversation_memberships",
  "user_shared_menus",
  "user_shared_shopping_lists",
  "friend_categories",
  "friends",
  "category_preferences",
  "list_category_orders",
  "report_throttle",
  // BUT-1957: the win-back / activity-digest notification rows, written by
  // `analytics/detect-lapsed-users.ts` and `analytics/send-activity-digest.ts`.
  // They carry the push text ACTUALLY SHOWN to the user (`message`/`bodyShown`)
  // plus the win-back A/B assignment, and nothing reached them: deleting the
  // parent user document does not delete its subcollections, so every row
  // survived erasure.
  //
  // `deleteNotifications` is NOT this. That sweeps the TOP-LEVEL collection
  // `user_notifications` — a different collection whose name is one word away,
  // which is the likeliest reason this one went unnoticed for so long.
  "notifications",
  // Everything below is here for ONE reason: the probe in
  // `probeResidualData` ENUMERATES what is left under `users/{uid}` instead
  // of consulting a list. That makes it broader than any hand-written
  // deleter, and the direction of a disagreement matters — a row the probe
  // reports and nothing erases is a `gdprCompliant: false` that no code path
  // can ever clear. So the deleter must be a superset of the probe, which is
  // the rule `deleteWeeklyMenuPlans` already states about its own four
  // handles. A `.get()` on a collection that does not exist costs one empty
  // read, on a path that runs once per account, ever.
  //
  // WRITTEN TODAY, with no dedicated tier step of their own. Found by the
  // `subs` audit BUT-1957 asked for — the first pass of that audit scanned
  // for the literal `.collection("users").doc(x).collection("y")` chain and
  // therefore saw only the server; every Dart writer builds the path from a
  // `FirestoreCollections` constant and was invisible to it. Resolving the
  // constants is what turned these up.
  "onboarding", // onboarding_progress_service.dart
  "ingredients", // firebase_user_ingredient_repository.dart
  "rate_limits", // firebase_activity_event_repository.dart, and others
  "counters", // base_shared_content_repository.dart (unread counters)
  // BUT-612 attribution (channel, campaign, timestamps), written to
  // `users/{uid}/acquisition/current` by firebase_acquisition_repository.dart.
  // Found by the `integration-reviewer` gate, NOT by the drift guard, which
  // could not see it: that repository chains through a file-local `const`
  // rather than `FirestoreCollections.users` inline. The guard now resolves
  // local consts too, so the next one of this shape reddens.
  "acquisition",
  // P5-U26b: the user's own week menus and recipes that another person's save claim-lint:ok moved unchanged, BUT-2113
  // overwrote, kept 30 days behind "Återställ", written claim-lint:ok moved unchanged, BUT-2113
  // by firebase_overwritten_version_repository.dart. A TTL policy on
  // `expiresAt` removes each row after 30 days; this entry erases them at
  // once when the account goes. Exported in the account-subcollections
  // section, so EXPORT ⊇ DELETION holds.
  "overwritten_versions",
  // BUT-907: the user's own deleted recipes in the trash, written by the
  // trash repository in the same batch that deletes the recipe. A TTL policy
  // on `expireAt` removes each row; this entry erases them at once when the
  // account goes. Their photos
  // sit under `users/{uid}/recipes/`, which the Storage prefix delete covers.
  "trash",
  // Steg 10E: the profile copy of each recipe its owner chose to show, written
  // only by `syncPublicRecipe`. Exported in the account-subcollections section.
  "public_recipes",
  // NO live writer found in `lib/` or `functions/src`. Swept anyway, because
  // an account predating a writer's removal can still hold rows, and by the
  // superset rule above such a row would otherwise be permanently residual.
  // `fcm_tokens` was named here from the Art. 15 export, which read it while
  // nothing wrote it — BUT-1990 has since removed that reader.
  "category_memberships",
  "connection_tests",
  "unified_recipes",
  "conversations",
  "fcm_tokens",
  // BUT-2040: the PRE-RENAME spelling of `rate_limits` above — one
  // collection under two spellings, not two collections. Nothing has
  // written `users/{uid}/rateLimits` since commit b9a95bd02 (2026-03-19)
  // renamed `FirestoreCollections.userRateLimits` to `rate_limits`, and
  // `firestore.rules` has no block for the camelCase path, so no client
  // can recreate a row. The dry run of `admin/reset-user-data.ts` measured
  // 5 rows still standing in production on 2026-09-07.
  //
  // Without this entry the rows are unreachable: `probeResidualData`
  // ENUMERATES, so it counts them and stamps `residual_data_detected` on
  // every deletion of such an account, while no deleter can clear it. The
  // collection-group TTL on `expireAt` does not reach them either — a TTL
  // policy is keyed to an exact collection id, and `rateLimits` is not
  // `rate_limits`.
  "rateLimits",
  // BUT-2044: the PRE-RENAME spelling of `friend_categories`, from the SAME
  // rename commit as `rateLimits` above (b9a95bd02, 2026-03-19).
  // `admin/migrate-friend-categories.ts`
  // moves such a row to the live spelling; this sweep covers an account that
  // still holds one, including the collision case that script leaves standing.
  "friendCategories",
  // Pooled ratings (decision 12): the user's frozen pool events. Each delete
  // fires the Stage-B trigger (onPooledRatingEventWritten), which recomputes
  // the affected pool's canonical_recipe_stats — so erasing the rater also
  // shrinks the public averages they contributed to, with no explicit
  // recompute call (the established trigger separation).
  "canonical_rating_events",
  // BUT-1917: the block mirror, `users/{uid}/block_mirror/current`. This leg
  // erases the deleted user's OWN mirror — the list of who blocked THEM.
  // Removing their uid from OTHER people's mirrors is a separate, capped
  // step (`deleteBlockMirrors`), because that one is a cross-user sweep and
  // this list is only the owner's own subtree.
  "block_mirror",
];

export async function deleteUserSubcollections(
  db: admin.firestore.Firestore,
  uid: string,
): Promise<boolean> {
  const userDoc = db.collection("users").doc(uid);
  // `notificationCounters` + `recentContentHashes` are intentionally NOT
  // included — `onUserDeleted` (cleanupContentGuardSubcollections) owns
  // those and runs automatically after `admin.auth().deleteUser(uid)`.
  const subs = USER_SUBCOLLECTIONS;
  for (const name of subs) {
    const snap = await userDoc.collection(name).get();
    await batchDeleteAll(db, snap.docs);
  }

  // BUT-1390: THESE rate-limit buckets live at the TOP-LEVEL
  // `system_rate_limits` collection (doc id `${uid}_${operation}`), so they
  // need their own sweep.
  //
  // This comment used to add that the `users/{uid}/rate_limits` entry above
  // "deleted nothing". That was true when BUT-1390 was written and is false
  // now: `firebase_activity_event_repository.dart` writes a bucket there, and
  // BUT-1957 put the entry back for exactly that reason. The two are separate
  // collections with separate writers, not one collection that moved.
  //
  // Erase the top-level ones via a documentId prefix range:
  //   startAt(`${uid}_`) .. endAt(`${uid}_`)
  // The upper bound's trailing  is a high-codepoint sentinel that is
  // INVISIBLE in most editors/diff viewers — it is load-bearing: WITHOUT it the
  // range collapses to the single (nonexistent) id `${uid}_` and erases nothing.
  // Do not "tidy" it away. The `_` separator additionally prevents matching a
  // different user whose uid is a prefix of this one. No field filter/index needed.
  const rlSnap = await db
    .collection("system_rate_limits")
    .orderBy(admin.firestore.FieldPath.documentId())
    .startAt(`${uid}_`)
    .endAt(`${uid}_`)
    .get();
  await batchDeleteAll(db, rlSnap.docs);

  return true;
}

export async function deleteUserProfile(
  db: admin.firestore.Firestore,
  uid: string,
): Promise<boolean> {
  await db.collection("users").doc(uid).delete();
  return true;
}
