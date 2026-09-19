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

/**
 * A rating CREATE is refused unless the same batch stamps
 * `users/{uid}/rate_limits/recipe_ratings` keyed on the rating id
 * (`rateLimitStamped`). Each create case commits the row and that stamp
 * together under its own per-run rater; updates carry no stamp.
 */
function createRating(
  uid: string,
  body: Record<string, unknown>,
  ratingId = `${RECIPE}_${uid}`
): Promise<void> {
  const db = env.authenticatedContext(uid, AGE_OK).firestore();
  const batch = db.batch();
  batch.set(db.doc(`recipe_ratings/${ratingId}`), body, { merge: true });
  batch.set(
    db.doc(`users/${uid}/rate_limits/recipe_ratings`),
    {
      lastWrite: serverTimestamp(),
      expireAt: new Date(Date.now() + 2 * 24 * 60 * 60 * 1000),
      lastDocId: ratingId,
    },
    { merge: true }
  );
  return batch.commit();
}

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
  await assertSucceeds(createRating(uid, appCreateBody(uid, true)));
});

test("app create payload WITHOUT recipeOwnerId is ALLOWED", async () => {
  const uid = `create-noowner-${RUN}`;
  await assertSucceeds(createRating(uid, appCreateBody(uid, false)));
});

// BUT-2079. Twin: the WITH-recipeOwnerId create above, plus one key.
test("create carrying an undeclared field is DENIED", async () => {
  const uid = `create-extra-${RUN}`;
  await assertFails(
    createRating(uid, { ...appCreateBody(uid, true), featured: true })
  );
});

// BUT-2086. Twin: the WITH-recipeOwnerId create above, under another doc id.
test("create under a doc id other than {recipeId}_{uid} is DENIED", async () => {
  const uid = `create-otherid-${RUN}`;
  await assertFails(
    createRating(uid, appCreateBody(uid, true), `${RECIPE}_${uid}_second`)
  );
});

test("create under another recipe's id carrying this recipeId is DENIED", async () => {
  const uid = `create-otherrecipe-${RUN}`;
  await assertFails(
    createRating(uid, appCreateBody(uid, true), `recipe-other_${uid}`)
  );
});

// BUT-2079 follow-up: `review` carries a type + length bound on both limbs.
// Malin chose 2000 on 2026-09-17, matching recipe_comments.text.

/** Seeds one rating row with an explicit `review` value (any type). */
async function seedRatingWithReview(
  docId: string,
  review: unknown
): Promise<void> {
  await env.withSecurityRulesDisabled(async (ctx) => {
    await ctx.firestore().doc(`recipe_ratings/${docId}`).set({
      recipeId: RECIPE,
      userId: USER,
      rating: 4,
      review,
      createdAt: Date.now(),
    });
  });
}

/** Seeds one rating row with no `review` key at all. */
async function seedRatingNoReview(docId: string): Promise<void> {
  await env.withSecurityRulesDisabled(async (ctx) => {
    await ctx.firestore().doc(`recipe_ratings/${docId}`).set({
      recipeId: RECIPE,
      userId: USER,
      rating: 4,
      createdAt: Date.now(),
    });
  });
}

// CREATE limb. Each DENY below differs from the ALLOW above it in exactly one
// variable — length for the 2001 case, type for the number case.

test("create with review at exactly 2000 units is ALLOWED", async () => {
  const uid = `create-2000-${RUN}`;
  await assertSucceeds(
    createRating(uid, { ...appCreateBody(uid, true), review: "a".repeat(2000) })
  );
});

test("create with review at 2001 units is DENIED", async () => {
  const uid = `create-2001-${RUN}`;
  await assertFails(
    createRating(uid, { ...appCreateBody(uid, true), review: "a".repeat(2001) })
  );
});

// 2000 Swedish letters are 2000 code units, so the bound is not halved by
// non-ASCII text. Measured, not assumed — see the comment beside the rule.
test("create with 2000 Swedish letters in review is ALLOWED", async () => {
  const uid = `create-aring-${RUN}`;
  await assertSucceeds(
    createRating(uid, { ...appCreateBody(uid, true), review: "ä".repeat(2000) })
  );
});

// An astral character is TWO code units, so 2000 of them exceed the bound.
test("create with 2000 emoji in review is DENIED", async () => {
  const uid = `create-emoji-${RUN}`;
  await assertFails(
    createRating(uid, { ...appCreateBody(uid, true), review: "🍕".repeat(2000) })
  );
});

// The `is string` arm. A map of few keys passes size() <= 2000 on its own, so
// without the type check this write would be accepted.
test("create with a MAP as review is DENIED", async () => {
  const uid = `create-map-${RUN}`;
  await assertFails(
    createRating(uid, { ...appCreateBody(uid, true), review: { a: 1 } })
  );
});

// OVER-DETERMINED, and kept anyway: a number is refused with or without the
// `is string` arm, because size() on a number is an evaluation error. Dropping
// the arm reddens the MAP case above and this one stays green — measured, so
// the map is the discriminating case and this one is breadth.
test("create with a NUMBER as review is DENIED", async () => {
  const uid = `create-number-${RUN}`;
  await assertFails(
    createRating(uid, { ...appCreateBody(uid, true), review: 5 })
  );
});

// The app's own create sends review: null, and two sibling suites' fixtures
// omit the key entirely. Both must stay allowed.
test("create with the review key ABSENT is ALLOWED", async () => {
  const uid = `create-absent-${RUN}`;
  const body = appCreateBody(uid, true);
  delete body.review;
  await assertSucceeds(createRating(uid, body));
});

// UPDATE limb. request.resource.data is the full resulting document here, so
// each case is also a statement about the STORED value.

test("update setting review to exactly 2000 units is ALLOWED", async () => {
  const id = `${RECIPE}_${USER}_u2000`;
  await seedRatingWithReview(id, "ok");
  const ctx = env.authenticatedContext(USER, AGE_OK);
  await assertSucceeds(
    ctx.firestore().doc(`recipe_ratings/${id}`).update({
      review: "a".repeat(2000),
      updatedAt: Date.now(),
    })
  );
});

test("update setting review to 2001 units is DENIED", async () => {
  const id = `${RECIPE}_${USER}_u2001`;
  await seedRatingWithReview(id, "ok");
  const ctx = env.authenticatedContext(USER, AGE_OK);
  await assertFails(
    ctx.firestore().doc(`recipe_ratings/${id}`).update({
      review: "a".repeat(2001),
      updatedAt: Date.now(),
    })
  );
});

// OVER-DETERMINED on this limb too, for the same reason as its create twin:
// `5.size()` is an evaluation error, so a number denies with or without the
// `is string` arm. Breadth, not the pin — the map case below is the pin.
test("update setting review to a NUMBER is DENIED", async () => {
  const id = `${RECIPE}_${USER}_unum`;
  await seedRatingWithReview(id, "ok");
  const ctx = env.authenticatedContext(USER, AGE_OK);
  await assertFails(
    ctx.firestore().doc(`recipe_ratings/${id}`).update({
      review: 5,
      updatedAt: Date.now(),
    })
  );
});

// The `is string` arm on the UPDATE limb, which the create-limb map case does
// not reach: the two limbs carry separate copies of the conjunct. Measured —
// dropping the arm from this limb alone leaves every other case green and
// lets this write through.
test("update setting review to a MAP is DENIED", async () => {
  const id = `${RECIPE}_${USER}_umap`;
  await seedRatingWithReview(id, "ok");
  const ctx = env.authenticatedContext(USER, AGE_OK);
  await assertFails(
    ctx.firestore().doc(`recipe_ratings/${id}`).update({
      review: { a: 1 },
      updatedAt: Date.now(),
    })
  );
});

test("update clearing review to null is ALLOWED", async () => {
  const id = `${RECIPE}_${USER}_unull`;
  await seedRatingWithReview(id, "ok");
  const ctx = env.authenticatedContext(USER, AGE_OK);
  await assertSucceeds(
    ctx.firestore().doc(`recipe_ratings/${id}`).update({
      review: null,
      updatedAt: Date.now(),
    })
  );
});

// The PRODUCTION verb, separately from .update(): rateRecipe re-rates with
// set(merge: true), which BUT-2057 already showed exercises a different path.
test("merge re-rate carrying a 2001-unit review is DENIED", async () => {
  const id = `${RECIPE}_${USER}_m2001`;
  await seedRatingWithReview(id, "ok");
  const ctx = env.authenticatedContext(USER, AGE_OK);
  await assertFails(
    ctx
      .firestore()
      .doc(`recipe_ratings/${id}`)
      .set(
        { rating: 3, review: "a".repeat(2001), updatedAt: Date.now() },
        { merge: true }
      )
  );
});

test("merge re-rate carrying a 2000-unit review is ALLOWED", async () => {
  const id = `${RECIPE}_${USER}_m2000`;
  await seedRatingWithReview(id, "ok");
  const ctx = env.authenticatedContext(USER, AGE_OK);
  await assertSucceeds(
    ctx
      .firestore()
      .doc(`recipe_ratings/${id}`)
      .set(
        { rating: 3, review: "a".repeat(2000), updatedAt: Date.now() },
        { merge: true }
      )
  );
});

// A row that has never carried the key stays updatable.
test("update of a row with NO review key is ALLOWED", async () => {
  const id = `${RECIPE}_${USER}_unokey`;
  await seedRatingNoReview(id);
  const ctx = env.authenticatedContext(USER, AGE_OK);
  await assertSucceeds(
    ctx.firestore().doc(`recipe_ratings/${id}`).update({ rating: 5 })
  );
});

// The regression pin for the merge landmine: this limb re-validates a stored
// `review` the write never touches, so a row sitting AT the bound must stay
// editable by a write that only changes the stars.
test("update touching only rating on a row storing a 2000-unit review is ALLOWED", async () => {
  const id = `${RECIPE}_${USER}_ustored`;
  await seedRatingWithReview(id, "a".repeat(2000));
  const ctx = env.authenticatedContext(USER, AGE_OK);
  await assertSucceeds(
    ctx.firestore().doc(`recipe_ratings/${id}`).update({ rating: 5 })
  );
});

// The other side of the same landmine, stated as behaviour rather than as a
// warning: a row whose stored review is over the bound cannot be edited at
// all, not even by a write that leaves the review alone. Production holds no
// such row (recipe_ratings is empty), and no client write can create one.
test("update touching only rating on a row storing a 2001-unit review is DENIED", async () => {
  const id = `${RECIPE}_${USER}_ufrozen`;
  await seedRatingWithReview(id, "a".repeat(2001));
  const ctx = env.authenticatedContext(USER, AGE_OK);
  await assertFails(
    ctx.firestore().doc(`recipe_ratings/${id}`).update({ rating: 5 })
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
