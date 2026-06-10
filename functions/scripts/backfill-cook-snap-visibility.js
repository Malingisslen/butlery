/**
 * BUT-1214 one-time backfill: set `visibility: 'sameAsRecipe'` on every
 * cook_snaps doc that lacks the field.
 *
 * Why: the friend-facing gallery query now constrains
 * `where('visibility', '==', 'sameAsRecipe')` (rules deny foreign `onlyMe`
 * docs, and queries cannot express "field missing OR value"). Legacy docs
 * written before BUT-1214 have no `visibility` field and would silently
 * disappear from friends' galleries until backfilled.
 *
 * Run ORDER matters: run this BEFORE (or together with) deploying the
 * updated firestore.rules + the new client. Idempotent — re-running is a
 * no-op once all docs carry the field.
 *
 * Usage (from functions/):
 *   GOOGLE_APPLICATION_CREDENTIALS=<service-account.json> \
 *     node scripts/backfill-cook-snap-visibility.js [--dry-run]
 */

const admin = require("firebase-admin");

admin.initializeApp();
const db = admin.firestore();

const DRY_RUN = process.argv.includes("--dry-run");
const BATCH_LIMIT = 400; // headroom under Firestore's 500-op batch cap

async function main() {
  const snapshot = await db.collection("cook_snaps").get();
  const missing = snapshot.docs.filter((d) => !("visibility" in d.data()));

  console.log(
    `cook_snaps: ${snapshot.size} total, ${missing.length} missing visibility` +
      (DRY_RUN ? " (dry-run, no writes)" : "")
  );
  if (DRY_RUN || missing.length === 0) return;

  let written = 0;
  for (let i = 0; i < missing.length; i += BATCH_LIMIT) {
    const batch = db.batch();
    for (const doc of missing.slice(i, i + BATCH_LIMIT)) {
      batch.update(doc.ref, { visibility: "sameAsRecipe" });
    }
    await batch.commit();
    written += Math.min(BATCH_LIMIT, missing.length - i);
    console.log(`  backfilled ${written}/${missing.length}`);
  }
  console.log("Done.");
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
