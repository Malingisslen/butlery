/**
 * Firestore rules tests for the pooled-ratings ("Butlery-betyget") storage
 * (Increment 4, decision 10). Two collections, both server-authoritative:
 *
 *   users/{uid}/canonical_rating_events/{poolKey}
 *     - owner may READ their own events (GDPR export + future "my votes" UI)
 *     - a stranger may NOT read them
 *     - ALL client writes denied (create/update/delete) — the mirror CF (Admin
 *       SDK) is the only writer; a client write could forge/poison a vote.
 *
 *   canonical_recipe_stats/{poolKey}
 *     - any signed-in user may READ the anonymous {count, average}
 *     - an unauthenticated caller may NOT read
 *     - ALL client writes denied — the Stage-B aggregator CF is the only writer.
 *
 * Prerequisite: Firestore emulator running (127.0.0.1:8080).
 * Run: npx ts-node src/__tests__/canonical-stats-rules.test.ts
 */

import * as fs from "fs";
import * as path from "path";
import {
  initializeTestEnvironment,
  RulesTestEnvironment,
  assertFails,
  assertSucceeds,
} from "@firebase/rules-unit-testing";

const PROJECT_ID = "butlery-canonical-stats-test";
const RULES_PATH = path.resolve(__dirname, "../../../firestore.rules");

const OWNER = "owner-uid";
const STRANGER = "stranger-uid";
const POOL_KEY = "v1:aaaabbbbccccdddd";
const FRESH_POOL_KEY = "v1:1111222233334444";

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

/** Seed a frozen pool event for OWNER and an aggregate stats doc, bypassing rules. */
async function seed(): Promise<void> {
  await env.withSecurityRulesDisabled(async (ctx) => {
    await ctx
      .firestore()
      .doc(`users/${OWNER}/canonical_rating_events/${POOL_KEY}`)
      .set({ poolKey: POOL_KEY, ratingValue: 4, recipeId: "r1", createdAt: Date.now() });
    await ctx
      .firestore()
      .doc(`canonical_recipe_stats/${POOL_KEY}`)
      .set({ count: 7, average: 4.1, updatedAt: Date.now() });
  });
}

type TestFn = () => Promise<void>;
const tests: { name: string; fn: TestFn }[] = [];
function test(name: string, fn: TestFn): void {
  tests.push({ name, fn });
}

// ── canonical_rating_events: owner-read, CF-only writes ──

test("owner CAN read their own canonical_rating_events", async () => {
  await seed();
  const ctx = env.authenticatedContext(OWNER);
  await assertSucceeds(
    ctx.firestore().doc(`users/${OWNER}/canonical_rating_events/${POOL_KEY}`).get()
  );
});

test("stranger CANNOT read another user's canonical_rating_events", async () => {
  await seed();
  const ctx = env.authenticatedContext(STRANGER);
  await assertFails(
    ctx.firestore().doc(`users/${OWNER}/canonical_rating_events/${POOL_KEY}`).get()
  );
});

test("unauthenticated user CANNOT read canonical_rating_events", async () => {
  await seed();
  const ctx = env.unauthenticatedContext();
  await assertFails(
    ctx.firestore().doc(`users/${OWNER}/canonical_rating_events/${POOL_KEY}`).get()
  );
});

// Leak guard: no collection-group rule matches canonical_rating_events, so an
// unconstrained collectionGroup query must DENY (it cannot prove every matched
// doc satisfies auth.uid == userId). Without this, a broad catch-all added later
// could silently expose every rater's frozen votes cross-user.
test("collectionGroup read of canonical_rating_events DENIES (no cross-user leak)", async () => {
  await seed();
  const ctx = env.authenticatedContext(STRANGER);
  await assertFails(
    ctx.firestore().collectionGroup("canonical_rating_events").get()
  );
});

test("owner CANNOT create a canonical_rating_events doc (CF-only)", async () => {
  const ctx = env.authenticatedContext(OWNER);
  await assertFails(
    ctx
      .firestore()
      .doc(`users/${OWNER}/canonical_rating_events/${FRESH_POOL_KEY}`)
      .set({ poolKey: FRESH_POOL_KEY, ratingValue: 5, recipeId: "r2", createdAt: Date.now() })
  );
});

test("owner CANNOT update their own canonical_rating_events doc", async () => {
  await seed();
  const ctx = env.authenticatedContext(OWNER);
  await assertFails(
    ctx
      .firestore()
      .doc(`users/${OWNER}/canonical_rating_events/${POOL_KEY}`)
      .update({ ratingValue: 1 })
  );
});

test("owner CANNOT delete their own canonical_rating_events doc", async () => {
  await seed();
  const ctx = env.authenticatedContext(OWNER);
  await assertFails(
    ctx.firestore().doc(`users/${OWNER}/canonical_rating_events/${POOL_KEY}`).delete()
  );
});

// ── canonical_recipe_stats: any-authed read, CF-only writes ──

test("any authenticated user CAN read canonical_recipe_stats", async () => {
  await seed();
  const ctx = env.authenticatedContext(STRANGER); // not the rater — still allowed
  await assertSucceeds(
    ctx.firestore().doc(`canonical_recipe_stats/${POOL_KEY}`).get()
  );
});

test("unauthenticated user CANNOT read canonical_recipe_stats", async () => {
  await seed();
  const ctx = env.unauthenticatedContext();
  await assertFails(
    ctx.firestore().doc(`canonical_recipe_stats/${POOL_KEY}`).get()
  );
});

test("authenticated user CANNOT create canonical_recipe_stats (CF-only)", async () => {
  const ctx = env.authenticatedContext(OWNER);
  await assertFails(
    ctx
      .firestore()
      .doc(`canonical_recipe_stats/${FRESH_POOL_KEY}`)
      .set({ count: 1, average: 5, updatedAt: Date.now() })
  );
});

test("authenticated user CANNOT update canonical_recipe_stats", async () => {
  await seed();
  const ctx = env.authenticatedContext(OWNER);
  await assertFails(
    ctx.firestore().doc(`canonical_recipe_stats/${POOL_KEY}`).update({ average: 5 })
  );
});

test("authenticated user CANNOT delete canonical_recipe_stats", async () => {
  await seed();
  const ctx = env.authenticatedContext(OWNER);
  await assertFails(
    ctx.firestore().doc(`canonical_recipe_stats/${POOL_KEY}`).delete()
  );
});

async function run(): Promise<void> {
  console.log("canonical rating events + stats rules tests (pooled ratings, decision 10)\n");
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
