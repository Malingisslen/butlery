/**
 * Firestore rules tests for the pre-release-audit WS2 recipe_ratings integrity
 * pin: a rating update may change only rating/review/updatedAt/recipeOwnerId — never the
 * identity/anchor fields (recipeId, userId, createdAt). Without the pin a user
 * could re-point their rating doc at another recipe or backdate it.
 *
 * Prerequisite: Firestore emulator running (127.0.0.1:8080).
 * Run: npx ts-node src/__tests__/recipe-ratings-rules.test.ts
 */

import * as fs from "fs";
import * as path from "path";
import {
  initializeTestEnvironment,
  RulesTestEnvironment,
  assertFails,
  assertSucceeds,
} from "@firebase/rules-unit-testing";
import { serverTimestamp } from "firebase/firestore";

const PROJECT_ID = "butlery-recipe-ratings-test";
const RULES_PATH = path.resolve(__dirname, "../../../firestore.rules");

const USER = "rater-uid";
const RECIPE = "recipe-1";
const RATING_ID = `${RECIPE}_${USER}`;

// BUT-2057: the update limb carries the same blocking gate as create, because
// the client re-rates with set(merge: true), which is evaluated as an UPDATE on
// an existing row.
const OWNER = "recipe-owner-uid";
const BLOCKED_RATER = "blocked-rater-uid";
const BLOCKED_RATING_ID = `${RECIPE}_${BLOCKED_RATER}`;
const OK_RATING_ID = `${RECIPE}_${USER}_owned`;
const MERGE_DENY_ID = `${RECIPE}_${BLOCKED_RATER}_merge`;
const MERGE_OK_ID = `${RECIPE}_${USER}_merge`;

// BUT-2077: the update limb requires isAgeCompliant(), so every update below
// authenticates with the claim unless the case is about its absence.
const AGE_OK = { ageCompliant: true };

// The emulator keeps documents between runs, and a create-allow case aimed at
// a fixed id that already exists would be evaluated as an UPDATE.
const RUN = Date.now().toString(36);

let env: RulesTestEnvironment;

async function setup(): Promise<void> {
  const rules = fs.readFileSync(RULES_PATH, "utf8");
  env = await initializeTestEnvironment({
    projectId: PROJECT_ID,
    firestore: { rules, host: "127.0.0.1", port: 8080 },
  });
}
async function teardown(): Promise<void> {
  if (env) await env.cleanup();
}

async function seedRating(): Promise<void> {
  await env.withSecurityRulesDisabled(async (ctx) => {
    await ctx.firestore().doc(`recipe_ratings/${RATING_ID}`).set({
      recipeId: RECIPE,
      userId: USER,
      rating: 4,
      review: "ok",
      createdAt: Date.now(),
    });
  });
}

/** Seeds the block record `isNotBlockedBy` reads: OWNER has blocked BLOCKED_RATER. */
async function seedBlock(): Promise<void> {
  await env.withSecurityRulesDisabled(async (ctx) => {
    await ctx.firestore().doc(`blocks/${OWNER}_${BLOCKED_RATER}`).set({
      blockerId: OWNER,
      blockedId: BLOCKED_RATER,
      blockedAt: new Date().toISOString(),
    });
  });
}

/** Seeds one rating row, optionally carrying the denormalised owner. */
async function seedRatingFor(
  docId: string,
  raterUid: string,
  withOwner: boolean
): Promise<void> {
  await env.withSecurityRulesDisabled(async (ctx) => {
    const body: Record<string, unknown> = {
      recipeId: RECIPE,
      userId: raterUid,
      rating: 4,
      review: "ok",
      createdAt: Date.now(),
    };
    if (withOwner) body.recipeOwnerId = OWNER;
    await ctx.firestore().doc(`recipe_ratings/${docId}`).set(body);
  });
}

type TestFn = () => Promise<void>;
const tests: { name: string; fn: TestFn }[] = [];
function test(name: string, fn: TestFn): void {
  tests.push({ name, fn });
}

test("owner can update rating/review (allowed fields)", async () => {
  await seedRating();
  const ctx = env.authenticatedContext(USER, AGE_OK);
  await assertSucceeds(
    ctx.firestore().doc(`recipe_ratings/${RATING_ID}`).update({
      rating: 5,
      review: "great",
      updatedAt: Date.now(),
    })
  );
});

test("owner CANNOT re-point the rating to another recipe", async () => {
  await seedRating();
  const ctx = env.authenticatedContext(USER, AGE_OK);
  await assertFails(
    ctx.firestore().doc(`recipe_ratings/${RATING_ID}`).update({
      rating: 5,
      recipeId: "some-other-recipe",
    })
  );
});

test("owner CANNOT change userId on the rating", async () => {
  await seedRating();
  const ctx = env.authenticatedContext(USER, AGE_OK);
  await assertFails(
    ctx.firestore().doc(`recipe_ratings/${RATING_ID}`).update({
      rating: 5,
      userId: "someone-else",
    })
  );
});

test("owner CANNOT backdate createdAt", async () => {
  await seedRating();
  const ctx = env.authenticatedContext(USER, AGE_OK);
  await assertFails(
    ctx.firestore().doc(`recipe_ratings/${RATING_ID}`).update({
      rating: 5,
      createdAt: 0,
    })
  );
});

// BUT-2057 update-limb blocking gate.

test("blocked rater CANNOT change a rating that carries recipeOwnerId", async () => {
  await seedBlock();
  await seedRatingFor(BLOCKED_RATING_ID, BLOCKED_RATER, true);
  const ctx = env.authenticatedContext(BLOCKED_RATER, AGE_OK);
  await assertFails(
    ctx.firestore().doc(`recipe_ratings/${BLOCKED_RATING_ID}`).update({
      rating: 1,
      updatedAt: Date.now(),
    })
  );
});

// Control for the case above: same actor, same block, same payload — only the
// field is gone. Legacy rows written before the repository stamped the owner
// stay ungated, which is the accepted residual, not an oversight.
test("blocked rater CAN change a legacy rating with no recipeOwnerId", async () => {
  await seedBlock();
  await seedRatingFor(BLOCKED_RATING_ID, BLOCKED_RATER, false);
  const ctx = env.authenticatedContext(BLOCKED_RATER, AGE_OK);
  await assertSucceeds(
    ctx.firestore().doc(`recipe_ratings/${BLOCKED_RATING_ID}`).update({
      rating: 1,
      updatedAt: Date.now(),
    })
  );
});


// The PRODUCTION verb. `rateRecipe` writes set(merge: true), so a legacy
// row acquires recipeOwnerId on the next re-rate — absent -> present, a
// transition neither .update() case above exercises.
test("blocked rater merge-ADDING recipeOwnerId to a legacy row is DENIED", async () => {
  await seedBlock();
  await seedRatingFor(MERGE_DENY_ID, BLOCKED_RATER, false);
  const ctx = env.authenticatedContext(BLOCKED_RATER, AGE_OK);
  await assertFails(
    ctx
      .firestore()
      .doc(`recipe_ratings/${MERGE_DENY_ID}`)
      .set({ rating: 1, recipeOwnerId: OWNER, updatedAt: Date.now() }, { merge: true })
  );
});

// Control for the case above: same merge-add, same transition, a rater the
// owner has not blocked.
test("non-blocked rater merge-ADDING recipeOwnerId to a legacy row is ALLOWED", async () => {
  await seedBlock();
  await seedRatingFor(MERGE_OK_ID, USER, false);
  const ctx = env.authenticatedContext(USER, AGE_OK);
  await assertSucceeds(
    ctx
      .firestore()
      .doc(`recipe_ratings/${MERGE_OK_ID}`)
      .set({ rating: 1, recipeOwnerId: OWNER, updatedAt: Date.now() }, { merge: true })
  );
});

// Control: the field is present exactly as in the deny
// case, but this rater is not blocked — so presence alone does not refuse.
test("non-blocked rater CAN change a rating that carries recipeOwnerId", async () => {
  await seedBlock();
  await seedRatingFor(OK_RATING_ID, USER, true);
  const ctx = env.authenticatedContext(USER, AGE_OK);
  await assertSucceeds(
    ctx.firestore().doc(`recipe_ratings/${OK_RATING_ID}`).update({
      rating: 5,
      updatedAt: Date.now(),
    })
  );
});

// Allowed twin of the three pin denials above: the same `rating: 5` update
// with no identity field in it.
test("owner CAN update the rating alone (twin of the pin denials)", async () => {
  await seedRating();
  const ctx = env.authenticatedContext(USER, AGE_OK);
  await assertSucceeds(
    ctx.firestore().doc(`recipe_ratings/${RATING_ID}`).update({ rating: 5 })
  );
});

// BUT-2077. Twin: "owner can update rating/review (allowed fields)" — same
// actor, same row, same payload, with the claim.
test("owner WITHOUT the ageCompliant claim CANNOT update a rating", async () => {
  await seedRating();
  const ctx = env.authenticatedContext(USER);
  await assertFails(
    ctx.firestore().doc(`recipe_ratings/${RATING_ID}`).update({
      rating: 5,
      review: "great",
      updatedAt: Date.now(),
    })
  );
});

// BUT-2077 R1: an update may change only rating/review/updatedAt/recipeOwnerId.
test("merging an undeclared field into an existing rating is DENIED", async () => {
  await seedRating();
  const ctx = env.authenticatedContext(USER, AGE_OK);
  await assertFails(
    ctx
      .firestore()
      .doc(`recipe_ratings/${RATING_ID}`)
      .set({ rating: 3, updatedAt: Date.now(), featured: true }, { merge: true })
  );
});

// The payload `FirebaseRatingsRepository.rateRecipe` sends when the row
// already exists: set(merge: true) with no createdAt, identity fields
// restated unchanged, review cleared to null, owner stamped.
test("app re-rate of an existing row (merge, review null, owner) is ALLOWED", async () => {
  await seedRating();
  const ctx = env.authenticatedContext(USER, AGE_OK);
  await assertSucceeds(
    ctx
      .firestore()
      .doc(`recipe_ratings/${RATING_ID}`)
      .set(
        {
          recipeId: RECIPE,
          userId: USER,
          rating: 3,
          review: null,
          recipeOwnerId: OWNER,
          updatedAt: serverTimestamp(),
        },
        { merge: true }
      )
  );
});

/** The map `rateRecipe` writes on a new row. */
function appCreateBody(raterUid: string, withOwner: boolean): Record<string, unknown> {
  const body: Record<string, unknown> = {
    recipeId: RECIPE,
    userId: raterUid,
    rating: 4,
    review: null,
    createdAt: serverTimestamp(),
    updatedAt: serverTimestamp(),
  };
  if (withOwner) body.recipeOwnerId = OWNER;
  return body;
}

test("app create payload WITH recipeOwnerId and review null is ALLOWED", async () => {
  const uid = `create-owner-${RUN}`;
  const ctx = env.authenticatedContext(uid, AGE_OK);
  await assertSucceeds(
    ctx
      .firestore()
      .doc(`recipe_ratings/${RECIPE}_${uid}`)
      .set(appCreateBody(uid, true), { merge: true })
  );
});

test("app create payload WITHOUT recipeOwnerId is ALLOWED", async () => {
  const uid = `create-noowner-${RUN}`;
  const ctx = env.authenticatedContext(uid, AGE_OK);
  await assertSucceeds(
    ctx
      .firestore()
      .doc(`recipe_ratings/${RECIPE}_${uid}`)
      .set(appCreateBody(uid, false), { merge: true })
  );
});

// BUT-2079. Twin: the WITH-recipeOwnerId create above, plus one key.
test("create carrying an undeclared field is DENIED", async () => {
  const uid = `create-extra-${RUN}`;
  const ctx = env.authenticatedContext(uid, AGE_OK);
  await assertFails(
    ctx
      .firestore()
      .doc(`recipe_ratings/${RECIPE}_${uid}`)
      .set({ ...appCreateBody(uid, true), featured: true }, { merge: true })
  );
});

async function run(): Promise<void> {
  console.log("recipe_ratings integrity-pin rules tests (WS2)\n");
  console.log("=============================\n");
  await setup();
  let failed = 0;
  for (const t of tests) {
    try {
      await t.fn();
      console.log(`  PASS  ${t.name}`);
    } catch (err) {
      failed++;
      console.log(`  FAIL  ${t.name}`);
      console.log(err);
    }
  }
  await teardown();
  console.log(
    `\n${tests.length - failed}/${tests.length} passed` +
      (failed ? `, ${failed} failed` : "")
  );
  if (failed > 0) process.exit(1);
}

run().catch((err) => {
  console.error(err);
  process.exit(1);
});
