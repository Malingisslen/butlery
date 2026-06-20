/**
 * Firestore rules tests for the pre-release-audit WS2 recipe_ratings integrity
 * pin: a rating update may change only rating/review/updatedAt — never the
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

const PROJECT_ID = "butlery-recipe-ratings-test";
const RULES_PATH = path.resolve(__dirname, "../../../firestore.rules");

const USER = "rater-uid";
const RECIPE = "recipe-1";
const RATING_ID = `${RECIPE}_${USER}`;

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

type TestFn = () => Promise<void>;
const tests: { name: string; fn: TestFn }[] = [];
function test(name: string, fn: TestFn): void {
  tests.push({ name, fn });
}

test("owner can update rating/review (allowed fields)", async () => {
  await seedRating();
  const ctx = env.authenticatedContext(USER);
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
  const ctx = env.authenticatedContext(USER);
  await assertFails(
    ctx.firestore().doc(`recipe_ratings/${RATING_ID}`).update({
      rating: 5,
      recipeId: "some-other-recipe",
    })
  );
});

test("owner CANNOT change userId on the rating", async () => {
  await seedRating();
  const ctx = env.authenticatedContext(USER);
  await assertFails(
    ctx.firestore().doc(`recipe_ratings/${RATING_ID}`).update({
      rating: 5,
      userId: "someone-else",
    })
  );
});

test("owner CANNOT backdate createdAt", async () => {
  await seedRating();
  const ctx = env.authenticatedContext(USER);
  await assertFails(
    ctx.firestore().doc(`recipe_ratings/${RATING_ID}`).update({
      rating: 5,
      createdAt: 0,
    })
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
