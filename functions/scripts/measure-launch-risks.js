/**
 * BUT-2278: read-only count of minor public profiles that are searchable.
 * BUT-2260: read-only count of documents left in `globalRecipeCache`, the
 * collection BUT-2244 stopped using.
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
}

main().catch((err) => {
  console.error(`measure-launch-risks failed: ${err.code || err.name}`);
  process.exit(1);
});
