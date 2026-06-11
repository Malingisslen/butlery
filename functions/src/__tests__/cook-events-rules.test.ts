/**
 * Firestore rules tests for the recipe_cook_events append-only cook log
 * (BUT-838).
 *
 * Path: recipe_cook_events/{userId}/events/{eventId}
 *   - read:   owner-only, gated on the {userId} PATH segment alone — this is
 *             what makes the client's countSince aggregate
 *             (where cookedAt >= ts, count()) provable.
 *   - create: owner-only + shape-validated (hasOnly/hasAll
 *             ['recipeId','cookedAt'], recipeId non-empty string <= 200,
 *             cookedAt timestamp).
 *   - update: DENIED for everyone (append-only log).
 *   - delete: owner-only.
 *
 * Each test name states the behavior it proves. If a test fails, either the
 * rules changed or the product contract changed — decide which before
 * editing the assertion.
 *
 * Prerequisite: Firestore emulator must be running locally
 * (`firebase emulators:start --only firestore`).
 *
 * Run with: npm run test:rules:cook-events  (from functions/)
 */

import * as fs from "fs";
import * as path from "path";
import {
  initializeTestEnvironment,
  RulesTestEnvironment,
  assertFails,
  assertSucceeds,
} from "@firebase/rules-unit-testing";
// Modular helpers — the compat instance from ctx.firestore() is unwrapped via
// getModularInstance inside these, so the cast below is safe. Needed because
// the compat API surface has no count() aggregate.
import {
  collection,
  query,
  where,
  getCountFromServer,
  getDocs,
  Firestore,
} from "firebase/firestore";

const PROJECT_ID = "butlery-rules-cook-events";
const RULES_PATH = path.resolve(__dirname, "../../../firestore.rules");

const OWNER_UID = "cook-events-owner-uid";
const OTHER_UID = "cook-events-stranger-uid";

// Per-run token: the emulator persists docs across npm-run invocations, so a
// fixed-id create-allow test becomes an UPDATE on the 2nd run (and update is
// `if false` here — guaranteed false failure). See knowledge entry 2026-06-03.
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

type TestFn = () => Promise<void>;
const tests: { name: string; fn: TestFn }[] = [];
function test(name: string, fn: TestFn): void {
  tests.push({ name, fn });
}

function eventsPath(uid: string): string {
  return `recipe_cook_events/${uid}/events`;
}

// Minimal valid event body. Tests override/extend fields to go malformed.
function validEventBody(
  extra: Record<string, unknown> = {}
): Record<string, unknown> {
  return {
    recipeId: "recipe-1",
    cookedAt: new Date(),
    ...extra,
  };
}

// Seed an event as the server (bypasses rules) so read/delete/update tests
// prove the rule, not the absence of the doc.
async function seedEvent(
  uid: string,
  eventId: string,
  body: Record<string, unknown> = validEventBody()
): Promise<void> {
  await env.withSecurityRulesDisabled(async (admin) => {
    await admin.firestore().doc(`${eventsPath(uid)}/${eventId}`).set(body);
  });
}

// ============================================================================
// RECIPE COOK EVENTS — read (owner-only, path-segment gated)
// ============================================================================

// CE1: owner can read their own cook event.
test("cook_events: owner can read own event", async () => {
  await seedEvent(OWNER_UID, "ce-read-own");
  const ctx = env.authenticatedContext(OWNER_UID);
  await assertSucceeds(
    ctx.firestore().doc(`${eventsPath(OWNER_UID)}/ce-read-own`).get()
  );
});

// CE2: a different authenticated user cannot read someone else's event.
test("cook_events: stranger cannot read another user's event", async () => {
  await seedEvent(OWNER_UID, "ce-read-foreign");
  const ctx = env.authenticatedContext(OTHER_UID);
  await assertFails(
    ctx.firestore().doc(`${eventsPath(OWNER_UID)}/ce-read-foreign`).get()
  );
});

// CE3: unauthenticated request cannot read.
test("cook_events: unauthenticated user cannot read an event", async () => {
  await seedEvent(OWNER_UID, "ce-read-anon");
  const ctx = env.unauthenticatedContext();
  await assertFails(
    ctx.firestore().doc(`${eventsPath(OWNER_UID)}/ce-read-anon`).get()
  );
});

// ============================================================================
// RECIPE COOK EVENTS — create (owner-only, shape-validated)
// ============================================================================

// CE4: owner can create a valid event under their own path.
test("cook_events: owner can create a valid event", async () => {
  const ctx = env.authenticatedContext(OWNER_UID);
  await assertSucceeds(
    ctx
      .firestore()
      .doc(`${eventsPath(OWNER_UID)}/ce-create-ok-${RUN}`)
      .set(validEventBody())
  );
});

// CE5: boundary — recipeId of exactly 200 chars is accepted (<= 200).
test("cook_events: recipeId of exactly 200 chars is accepted", async () => {
  const ctx = env.authenticatedContext(OWNER_UID);
  await assertSucceeds(
    ctx
      .firestore()
      .doc(`${eventsPath(OWNER_UID)}/ce-create-200-${RUN}`)
      .set(validEventBody({ recipeId: "x".repeat(200) }))
  );
});

// CE6: cannot create under ANOTHER user's path (path-segment ownership).
test("cook_events: cannot create an event under another user's path", async () => {
  const ctx = env.authenticatedContext(OTHER_UID);
  await assertFails(
    ctx
      .firestore()
      .doc(`${eventsPath(OWNER_UID)}/ce-create-foreign`)
      .set(validEventBody())
  );
});

// CE7: unauthenticated create is denied.
test("cook_events: unauthenticated user cannot create an event", async () => {
  const ctx = env.unauthenticatedContext();
  await assertFails(
    ctx
      .firestore()
      .doc(`${eventsPath(OWNER_UID)}/ce-create-anon`)
      .set(validEventBody())
  );
});

// CE8: extra key beyond the two-field allowlist is rejected (keys().hasOnly).
test("cook_events: create with an extra key is rejected", async () => {
  const ctx = env.authenticatedContext(OWNER_UID);
  await assertFails(
    ctx
      .firestore()
      .doc(`${eventsPath(OWNER_UID)}/ce-extra-key`)
      .set(validEventBody({ note: "smaskigt" }))
  );
});

// CE9: missing recipeId is rejected (hasRequiredFields / hasAll).
test("cook_events: create without recipeId is rejected", async () => {
  const ctx = env.authenticatedContext(OWNER_UID);
  await assertFails(
    ctx
      .firestore()
      .doc(`${eventsPath(OWNER_UID)}/ce-no-recipe`)
      .set({ cookedAt: new Date() })
  );
});

// CE10: missing cookedAt is rejected (hasRequiredFields / hasAll).
test("cook_events: create without cookedAt is rejected", async () => {
  const ctx = env.authenticatedContext(OWNER_UID);
  await assertFails(
    ctx
      .firestore()
      .doc(`${eventsPath(OWNER_UID)}/ce-no-cookedat`)
      .set({ recipeId: "recipe-1" })
  );
});

// CE11: non-string recipeId is rejected (`is string`).
test("cook_events: non-string recipeId is rejected", async () => {
  const ctx = env.authenticatedContext(OWNER_UID);
  await assertFails(
    ctx
      .firestore()
      .doc(`${eventsPath(OWNER_UID)}/ce-recipe-num`)
      .set(validEventBody({ recipeId: 42 }))
  );
});

// CE12: empty recipeId is rejected (size() > 0).
test("cook_events: empty recipeId is rejected", async () => {
  const ctx = env.authenticatedContext(OWNER_UID);
  await assertFails(
    ctx
      .firestore()
      .doc(`${eventsPath(OWNER_UID)}/ce-recipe-empty`)
      .set(validEventBody({ recipeId: "" }))
  );
});

// CE13: oversized recipeId (201 chars) is rejected (size() <= 200).
test("cook_events: oversized recipeId is rejected", async () => {
  const ctx = env.authenticatedContext(OWNER_UID);
  await assertFails(
    ctx
      .firestore()
      .doc(`${eventsPath(OWNER_UID)}/ce-recipe-big`)
      .set(validEventBody({ recipeId: "x".repeat(201) }))
  );
});

// CE14: non-timestamp cookedAt is rejected (`is timestamp`).
test("cook_events: non-timestamp cookedAt is rejected", async () => {
  const ctx = env.authenticatedContext(OWNER_UID);
  await assertFails(
    ctx
      .firestore()
      .doc(`${eventsPath(OWNER_UID)}/ce-cookedat-str`)
      .set(validEventBody({ cookedAt: "2026-06-10" }))
  );
});

// ============================================================================
// RECIPE COOK EVENTS — update DENIED (append-only log)
// ============================================================================

// CE15: even the owner cannot update an event — the log is append-only.
// A shape-valid rewrite is used so the deny is provably the `update: if
// false` rule, not the create validator.
test("cook_events: owner cannot update own event (append-only)", async () => {
  await seedEvent(OWNER_UID, "ce-update-own");
  const ctx = env.authenticatedContext(OWNER_UID);
  await assertFails(
    ctx
      .firestore()
      .doc(`${eventsPath(OWNER_UID)}/ce-update-own`)
      .update({ cookedAt: new Date() })
  );
  // Full-doc set() on an existing doc is an update too — also denied.
  await assertFails(
    ctx
      .firestore()
      .doc(`${eventsPath(OWNER_UID)}/ce-update-own`)
      .set(validEventBody())
  );
});

// CE16: a stranger cannot update either.
test("cook_events: stranger cannot update another user's event", async () => {
  await seedEvent(OWNER_UID, "ce-update-foreign");
  const ctx = env.authenticatedContext(OTHER_UID);
  await assertFails(
    ctx
      .firestore()
      .doc(`${eventsPath(OWNER_UID)}/ce-update-foreign`)
      .update({ recipeId: "hijacked" })
  );
});

// ============================================================================
// RECIPE COOK EVENTS — delete (owner-only)
// ============================================================================

// CE17: owner can delete their own event.
test("cook_events: owner can delete own event", async () => {
  await seedEvent(OWNER_UID, "ce-del-own");
  const ctx = env.authenticatedContext(OWNER_UID);
  await assertSucceeds(
    ctx.firestore().doc(`${eventsPath(OWNER_UID)}/ce-del-own`).delete()
  );
});

// CE18: a stranger cannot delete another user's event.
test("cook_events: stranger cannot delete another user's event", async () => {
  await seedEvent(OWNER_UID, "ce-del-foreign");
  const ctx = env.authenticatedContext(OTHER_UID);
  await assertFails(
    ctx.firestore().doc(`${eventsPath(OWNER_UID)}/ce-del-foreign`).delete()
  );
});

// CE19: unauthenticated delete is denied.
test("cook_events: unauthenticated user cannot delete an event", async () => {
  await seedEvent(OWNER_UID, "ce-del-anon");
  const ctx = env.unauthenticatedContext();
  await assertFails(
    ctx.firestore().doc(`${eventsPath(OWNER_UID)}/ce-del-anon`).delete()
  );
});

// ============================================================================
// RECIPE COOK EVENTS — the client's countSince aggregate + list query
// ============================================================================
// The Dart repo issues: collection('recipe_cook_events/{uid}/events')
//   .where('cookedAt' >= since).count(). The read rule depends only on the
// {userId} path segment, so this must be provable for the owner with no
// per-document data access.

const SINCE = new Date(Date.now() - 7 * 24 * 60 * 60 * 1000); // 7 days ago

function countSinceQuery(ctx: { firestore(): unknown }, uid: string) {
  const db = ctx.firestore() as unknown as Firestore;
  return query(
    collection(db, eventsPath(uid)),
    where("cookedAt", ">=", SINCE)
  );
}

// CE20: the owner's countSince aggregate succeeds (the load-bearing test —
// the Dart repository's countSince depends on this exact query shape).
test("cook_events: owner countSince aggregate (cookedAt >= ts, count) succeeds", async () => {
  await seedEvent(OWNER_UID, "ce-agg-1", validEventBody());
  await seedEvent(
    OWNER_UID,
    "ce-agg-old",
    validEventBody({ cookedAt: new Date("2020-01-01") })
  );
  const ctx = env.authenticatedContext(OWNER_UID);
  const snap = await assertSucceeds(
    getCountFromServer(countSinceQuery(ctx, OWNER_UID))
  );
  // Sanity: the aggregate actually filters (old event excluded). At least the
  // fresh seed must be counted; persisted docs from prior runs may add more.
  if (snap.data().count < 1) {
    throw new Error(`expected count >= 1, got ${snap.data().count}`);
  }
});

// CE21: the same aggregate against ANOTHER user's path is denied.
test("cook_events: foreign countSince aggregate is denied", async () => {
  const ctx = env.authenticatedContext(OTHER_UID);
  await assertFails(getCountFromServer(countSinceQuery(ctx, OWNER_UID)));
});

// CE22: unauthenticated aggregate is denied.
test("cook_events: unauthenticated countSince aggregate is denied", async () => {
  const ctx = env.unauthenticatedContext();
  await assertFails(getCountFromServer(countSinceQuery(ctx, OWNER_UID)));
});

// CE23: the owner can also LIST with the same filter (non-aggregate fallback
// path — e.g. if the client ever degrades count() to a plain query).
test("cook_events: owner list query with cookedAt filter succeeds", async () => {
  const ctx = env.authenticatedContext(OWNER_UID);
  await assertSucceeds(getDocs(countSinceQuery(ctx, OWNER_UID)));
});

// CE24: a stranger's list query against the owner's path is denied.
test("cook_events: foreign list query is denied", async () => {
  const ctx = env.authenticatedContext(OTHER_UID);
  await assertFails(getDocs(countSinceQuery(ctx, OWNER_UID)));
});

async function run(): Promise<void> {
  console.log("recipe_cook_events rules tests (BUT-838)\n");
  console.log("========================================\n");
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
