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
 *   - no ratings → stats cleared.
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

  console.log(`\n${failed === 0 ? "ALL PASS" : `${failed} FAILED`}`);
  if (failed > 0) process.exit(1);
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
