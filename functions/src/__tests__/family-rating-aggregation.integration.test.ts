/**
 * Integration test: the public rating counter folds in family-DINER ratings.
 *
 * Runs `updateRecipeRatingStats` against the Firestore emulator. Verifies the
 * "every rater once, no adult double-count" contract:
 *   - account users (recipe_ratings) + diner profiles (family_ratings,
 *     memberType profile) both count,
 *   - a user-type family row (an adult's mirrored/proxy verdict) does NOT
 *     double-count (adults come via recipe_ratings),
 *   - a recipe rated ONLY by a diner still gets a public average,
 *   - no ratings → stats cleared,
 *   - past the fold limit, count() aggregations give the same stats (BUT-2084).
 *
 * Run: FIRESTORE_EMULATOR_HOST=localhost:8080 \
 *   ts-node src/__tests__/family-rating-aggregation.integration.test.ts
 */

import * as admin from "firebase-admin";

const EMULATOR_HOST = process.env.FIRESTORE_EMULATOR_HOST ?? "localhost:8080";
process.env.FIRESTORE_EMULATOR_HOST = EMULATOR_HOST;

if (!admin.apps.length) {
  admin.initializeApp({ projectId: "butlery-test-family-rating-agg" });
}
const db = admin.firestore();

// eslint-disable-next-line @typescript-eslint/no-require-imports
const {
  updateRecipeRatingStats,
} = require("../ratings/update-recipe-rating-stats");
// eslint-disable-next-line @typescript-eslint/no-require-imports
const { recordRatingReads } = require("../ratings/rating-read-counter");

const RUN = Date.now().toString(36);
let failed = 0;
function assert(cond: boolean, msg: string): void {
  if (cond) {
    console.log(`  PASS  ${msg}`);
  } else {
    failed++;
    console.log(`  FAIL  ${msg}`);
  }
}

async function seedUserRating(
  recipeId: string,
  userId: string,
  rating: number
): Promise<void> {
  await db.collection("recipe_ratings").doc(`${recipeId}_${userId}`).set({
    recipeId,
    userId,
    rating,
    createdAt: admin.firestore.Timestamp.now(),
  });
}

async function seedFamilyRating(
  recipeId: string,
  memberId: string,
  memberType: "user" | "profile",
  stars: number
): Promise<void> {
  // Doc id mirrors production FamilyRating.buildId (`recipeId|memberId`).
  await db.collection("family_ratings").doc(`${recipeId}|${memberId}`).set({
    recipeId,
    householdId: `hh-${RUN}`,
    memberId,
    memberType,
    stars,
    enteredByUid: "someone",
    createdAt: admin.firestore.Timestamp.now(),
    lastUpdatedAt: admin.firestore.Timestamp.now(),
  });
}

async function statsFor(recipeId: string): Promise<Record<string, unknown>> {
  const snap = await db.collection("recipe_social_stats").doc(recipeId).get();
  return (snap.data() ?? {}) as Record<string, unknown>;
}

async function main(): Promise<void> {
  console.log("family-rating public-aggregation integration\n");

  // 1. Users + a diner count; a user-type family row does NOT double-count.
  const r1 = `r-mixed-${RUN}`;
  await seedUserRating(r1, "u-a", 5);
  await seedUserRating(r1, "u-b", 3);
  await seedFamilyRating(r1, "diner-emma", "profile", 1);
  await seedFamilyRating(r1, "u-a", "user", 5); // adult mirror/proxy — excluded
  await updateRecipeRatingStats(r1, db);
  const s1 = await statsFor(r1);
  assert(
    s1.ratingCount === 3,
    `2 users + 1 diner = 3 (user-type family row excluded), got ${s1.ratingCount}`
  );
  assert(
    s1.averageRating === 3.0,
    `(5 + 3 + 1) / 3 = 3.0, got ${s1.averageRating}`
  );

  // 2. A recipe rated ONLY by a diner still gets a public average.
  const r2 = `r-diner-only-${RUN}`;
  await seedFamilyRating(r2, "diner-liam", "profile", 4);
  await updateRecipeRatingStats(r2, db);
  const s2 = await statsFor(r2);
  assert(
    s2.ratingCount === 1 && s2.averageRating === 4.0,
    `diner-only recipe → count 1, avg 4.0, got count ${s2.ratingCount} avg ${s2.averageRating}`
  );

  // 3. No ratings → stats cleared.
  const r3 = `r-none-${RUN}`;
  await updateRecipeRatingStats(r3, db);
  const s3 = await statsFor(r3);
  assert(
    s3.ratingCount === 0 && s3.averageRating === null,
    `no ratings → count 0, avg null, got count ${s3.ratingCount} avg ${s3.averageRating}`
  );

  // 4. BUT-2084: past the fold limit the stats come from count() aggregations
  // and equal the in-memory fold of the same rows.
  const r4 = `r-counted-${RUN}`;
  for (const [i, stars] of [5, 5, 4, 3, 1, 2].entries()) {
    await seedUserRating(r4, `u-${i}`, stars);
  }
  await seedFamilyRating(r4, "diner-a", "profile", 4);
  await seedFamilyRating(r4, "diner-b", "profile", 2);
  await seedFamilyRating(r4, "u-0", "user", 1); // adult mirror/proxy — excluded
  const folded = await updateRecipeRatingStats(r4, db, 100);
  const sFolded = await statsFor(r4);
  const countedRun = await updateRecipeRatingStats(r4, db, 3);
  const sCounted = await statsFor(r4);
  assert(
    folded.counted === false && countedRun.counted === true,
    `limit 100 folds, limit 3 counts, got ${folded.counted}/${countedRun.counted}`
  );
  assert(
    sCounted.ratingCount === 8 && sFolded.ratingCount === 8,
    `6 users + 2 diners = 8 on both paths, got ${sFolded.ratingCount}/${sCounted.ratingCount}`
  );
  assert(
    sCounted.averageRating === sFolded.averageRating &&
      sCounted.averageRating === 3.3,
    `(5+5+4+3+1+2+4+2)/8 = 3.25 → 3.3 on both paths, got ${sFolded.averageRating}/${sCounted.averageRating}`
  );
  assert(
    JSON.stringify(sCounted.ratingDistribution) ===
      JSON.stringify({ 1: 1, 2: 2, 3: 1, 4: 2, 5: 2 }),
    `distribution from counts, got ${JSON.stringify(sCounted.ratingDistribution)}`
  );
  // Bounded: the user read stops at limit + 1 = 4 rows and is counted by five
  // aggregations of under 1,000 entries; the 2 diners fit and are folded.
  assert(
    countedRun.docsRead === 4 + 5 + 2,
    `counted path reads 11, got ${countedRun.docsRead}`
  );
  // Both collections past the limit: the diners are counted too, and the
  // adult's user-type family row (1 star) stays out of the counted figure.
  const bothCounted = await updateRecipeRatingStats(r4, db, 1);
  const sBoth = await statsFor(r4);
  assert(
    JSON.stringify(sBoth.ratingDistribution) ===
      JSON.stringify({ 1: 1, 2: 2, 3: 1, 4: 2, 5: 2 }) &&
      bothCounted.docsRead === 2 + 2 + 5 + 5,
    `both collections counted, got ${JSON.stringify(sBoth.ratingDistribution)} reads ${bothCounted.docsRead}`
  );
  assert(
    folded.docsRead === 6 + 2,
    `fold path reads the 8 rows, got ${folded.docsRead}`
  );

  // 5. A non-integer value is not counted.
  const r5 = `r-fraction-${RUN}`;
  await seedUserRating(r5, "u-a", 4);
  await seedUserRating(r5, "u-b", 3.5);
  await updateRecipeRatingStats(r5, db);
  const s5 = await statsFor(r5);
  assert(
    s5.ratingCount === 1 && s5.averageRating === 4.0,
    `3.5 is left out → count 1, avg 4.0, got count ${s5.ratingCount} avg ${s5.averageRating}`
  );

  // 6. The day's read counter sums every drain that read anything.
  const day = new Date(Date.UTC(2031, 0, 2, 12));
  const counterRef = db.doc("analytics/rating_reads/daily/2031-01-02");
  await counterRef.delete();
  await recordRatingReads(16, db, day);
  await recordRatingReads(0, db, day);
  await recordRatingReads(8, db, day);
  const counter = (await counterRef.get()).data() ?? {};
  assert(
    counter.docsRead === 24 && Object.keys(counter).length === 1,
    `16 + 8 reads on 2031-01-02, docsRead only, got ${JSON.stringify(counter)}`
  );

  console.log(`\n${failed === 0 ? "ALL PASS" : `${failed} FAILED`}`);
  if (failed > 0) process.exit(1);
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
