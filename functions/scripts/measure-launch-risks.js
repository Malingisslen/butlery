/**
 * BUT-2278: read-only count of minor public profiles that are searchable.
 * BUT-2260: read-only count of documents left in `globalRecipeCache`, the
 * collection BUT-2244 stopped using.
 * BUT-2213: read-only count of `realtime_recipes` documents and of the
 * `presence` rows under them, before the code that erases and exports them is
 * removed.
 * BUT-2332: read-only count of groups whose `ownerId` names a different account
 * than the one they are stored under, which only the retired
 * `transferOwnership` could leave behind.
 *
 * Prints counts only, never a uid, so the job log can be read by anyone with
 * access to the repository. Writes nothing.
 *
 * A minor who opted in through `setProfileSearchability` leaves the same
 * `isSearchable: true` as a profile left over from before BUT-1626, so this
 * count is an upper bound on the leftovers.
 *
 * Usage (from functions/):
 *   GOOGLE_APPLICATION_CREDENTIALS=<service-account.json> \
 *     node scripts/measure-launch-risks.js
 */

const admin = require("firebase-admin");

admin.initializeApp();
const db = admin.firestore();

const GET_ALL_CHUNK = 100;

async function main() {
  const searchable = await db
    .collection("public_profiles")
    .where("isSearchable", "==", true)
    .select()
    .get();

  const ids = searchable.docs.map((d) => d.id);
  let minors = 0;
  let missingUserDoc = 0;
  for (let i = 0; i < ids.length; i += GET_ALL_CHUNK) {
    const refs = ids
      .slice(i, i + GET_ALL_CHUNK)
      .map((id) => db.collection("users").doc(id));
    const snaps = await db.getAll(...refs, { fieldMask: ["isMinor"] });
    for (const snap of snaps) {
      if (!snap.exists) {
        missingUserDoc++;
      } else if (snap.get("isMinor") === true) {
        minors++;
      }
    }
  }

  console.log(`searchable_public_profiles=${ids.length}`);
  console.log(`searchable_minor_profiles=${minors}`);
  console.log(`searchable_profiles_without_user_doc=${missingUserDoc}`);

  const cache = await db.collection("globalRecipeCache").count().get();
  console.log(`global_recipe_cache_docs=${cache.data().count}`);

  const realtimeRecipes = await db.collection("realtime_recipes").count().get();
  console.log(`realtime_recipes_docs=${realtimeRecipes.data().count}`);

  // `presence` is also the name of a subcollection elsewhere, so only rows
  // whose grandparent collection is `realtime_recipes` are counted. A row can
  // outlive its parent document, which is why this does not walk the parents.
  const presence = await db.collectionGroup("presence").select().get();
  const recipePresence = presence.docs.filter(
    (d) => d.ref.parent.parent?.parent.id === "realtime_recipes",
  ).length;
  console.log(`realtime_recipes_presence_rows=${recipePresence}`);

  // Only the live `users/{uid}/friend_categories` spelling; `handOverGroup`
  // refuses a group whose `ownerId` is not the account it is stored under.
  const groups = await db.collectionGroup("friend_categories").select("ownerId").get();
  let userGroups = 0;
  let ownerMismatch = 0;
  let ownerMissing = 0;
  for (const doc of groups.docs) {
    const account = doc.ref.parent.parent;
    if (account?.parent.id !== "users") continue;
    userGroups++;
    const ownerId = doc.get("ownerId");
    if (typeof ownerId !== "string" || ownerId === "") {
      ownerMissing++;
    } else if (ownerId !== account.id) {
      ownerMismatch++;
    }
  }
  console.log(`friend_categories_docs=${userGroups}`);
  console.log(`friend_categories_owner_mismatch=${ownerMismatch}`);
  console.log(`friend_categories_owner_missing=${ownerMissing}`);
}

main().catch((err) => {
  console.error(`measure-launch-risks failed: ${err.code || err.name}`);
  process.exit(1);
});
