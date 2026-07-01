/**
 * Firestore rules tests for the `activity_events` social feed collection
 * (BUT-1294).
 *
 * Before this block existed the collection sat on Firestore default-deny, so
 * the activity feed could neither write ("mark as cooked"/shared) nor read in
 * production. These tests prove the new contract:
 *
 *   - read:   actor-of-the-doc OR a friend of the actor
 *             (friend doc at users/{actorId}/friends/{auth.uid}).
 *   - create: actor-only (request.auth.uid == actorId) + shape validation
 *             (required actorId/type/recipeId/createdAt; recipeId <= 200;
 *             recipeTitle, if present, string <= 300) + burst rate limit.
 *   - update: actor-only; actorId/recipeId/createdAt immutable.
 *   - delete: actor-only.
 *
 * Each test name states the behavior it proves. If a test fails, either the
 * rules changed or the product contract changed — decide which before editing
 * the assertion.
 *
 * Prerequisite: Firestore emulator must be running locally
 * (`firebase emulators:start --only firestore`).
 *
 * Run with: npx ts-node src/__tests__/activity-events-rules.test.ts
 */

import * as fs from "fs";
import * as path from "path";
import {
  initializeTestEnvironment,
  RulesTestEnvironment,
  assertFails,
  assertSucceeds,
} from "@firebase/rules-unit-testing";

const PROJECT_ID = "butlery-rules-activity-events";
const RULES_PATH = path.resolve(__dirname, "../../../firestore.rules");

const ACTOR_UID = "activity-actor-uid";
const FRIEND_UID = "activity-friend-uid";
const STRANGER_UID = "activity-stranger-uid";

// BUT-1418 (ADR-0002): activity_events create now ALSO requires
// `isAgeCompliant()` (custom claim `ageCompliant == true`). Every authed context
// that performs a create carries this claim so each test keeps isolating its
// intended gate (actor-only / required-field / size / rate-limit), not the new
// age gate. Without it every create-allow assertion fails closed. Read/update/
// delete contexts are NOT age-gated and stay claimless.
const AGE_OK = { ageCompliant: true };

// Per-run token: the emulator persists docs across invocations, so a
// fixed-id create-allow test would become an UPDATE on the 2nd run and hit a
// different rule. Unique ids keep create tests proving the create rule.
const RUN = Date.now().toString(36);

let env: RulesTestEnvironment;

async function setup(): Promise<void> {
  const rules = fs.readFileSync(RULES_PATH, "utf8");
  env = await initializeTestEnvironment({
    projectId: PROJECT_ID,
    firestore: { rules, host: "127.0.0.1", port: 8080 },
  });

  await env.withSecurityRulesDisabled(async (ctx) => {
    // Seed the friendship: FRIEND_UID is in ACTOR_UID's friends list. Only
    // the doc's existence matters per the activity_events read rule.
    await ctx
      .firestore()
      .doc(`users/${ACTOR_UID}/friends/${FRIEND_UID}`)
      .set({ addedAt: new Date() });
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

// A body that satisfies the structural validation. Tests override fields they
// want to vary.
function validEventBody(
  extra: Record<string, unknown> = {}
): Record<string, unknown> {
  return {
    actorId: ACTOR_UID,
    actorDisplayName: "Anna",
    type: "cooked",
    recipeId: "recipe-1",
    recipeTitle: "Köttbullar",
    extraData: {},
    createdAt: new Date(),
    ...extra,
  };
}

// Seed an event as the server (bypasses rules) so read/update/delete tests
// prove the rule, not the absence of the doc.
async function seedEvent(
  eventId: string,
  body: Record<string, unknown> = validEventBody()
): Promise<void> {
  await env.withSecurityRulesDisabled(async (admin) => {
    await admin.firestore().doc(`activity_events/${eventId}`).set(body);
  });
}

// ============================================================================
// ACTIVITY EVENTS — read (actor + friends)
// ============================================================================

// AE1: the actor can read their own event.
test("activity_events: actor can read own event", async () => {
  await seedEvent("ae-read-own");
  const ctx = env.authenticatedContext(ACTOR_UID);
  await assertSucceeds(
    ctx.firestore().doc(`activity_events/ae-read-own`).get()
  );
});

// AE2: a friend of the actor can read the actor's event (feed visibility).
test("activity_events: friend of the actor can read the event", async () => {
  await seedEvent("ae-read-friend");
  const ctx = env.authenticatedContext(FRIEND_UID);
  await assertSucceeds(
    ctx.firestore().doc(`activity_events/ae-read-friend`).get()
  );
});

// AE3: a stranger (not the actor, not a friend) cannot read the event.
test("activity_events: stranger cannot read the event", async () => {
  await seedEvent("ae-read-stranger");
  const ctx = env.authenticatedContext(STRANGER_UID);
  await assertFails(
    ctx.firestore().doc(`activity_events/ae-read-stranger`).get()
  );
});

// AE4: unauthenticated request cannot read.
test("activity_events: unauthenticated user cannot read the event", async () => {
  await seedEvent("ae-read-anon");
  const ctx = env.unauthenticatedContext();
  await assertFails(
    ctx.firestore().doc(`activity_events/ae-read-anon`).get()
  );
});

// ============================================================================
// ACTIVITY EVENTS — create (actor-only, shape-validated)
// ============================================================================

// AE5: the actor can create a valid event for themselves.
test("activity_events: actor can create a valid event", async () => {
  const ctx = env.authenticatedContext(ACTOR_UID, AGE_OK);
  await assertSucceeds(
    ctx.firestore().doc(`activity_events/ae-create-ok-${RUN}`).set(validEventBody())
  );
});

// AE5b: BUT-1418 DENY — an actor whose token lacks the ageCompliant claim
// cannot create an event, even with an otherwise-valid body and matching
// actorId. Load-bearing deny for the new age gate: fails closed on a missing
// claim (CEL `request.auth.token.ageCompliant` undefined -> `== true` false).
test("activity_events: actor without ageCompliant claim cannot create an event", async () => {
  const ctx = env.authenticatedContext(ACTOR_UID);
  await assertFails(
    ctx.firestore().doc(`activity_events/ae-noclaim-${RUN}`).set(validEventBody())
  );
});

// AE5c: BUT-1418 DENY — an explicit ageCompliant:false claim is rejected too.
test("activity_events: actor with ageCompliant=false cannot create an event", async () => {
  const ctx = env.authenticatedContext(ACTOR_UID, { ageCompliant: false });
  await assertFails(
    ctx.firestore().doc(`activity_events/ae-agefalse-${RUN}`).set(validEventBody())
  );
});

// AE6: a user cannot forge an event attributed to someone else (actorId spoof).
test("activity_events: cannot create an event with a spoofed actorId", async () => {
  const ctx = env.authenticatedContext(STRANGER_UID, AGE_OK);
  await assertFails(
    ctx
      .firestore()
      .doc(`activity_events/ae-create-spoof-${RUN}`)
      .set(validEventBody({ actorId: ACTOR_UID }))
  );
});

// AE7: unauthenticated create is denied.
test("activity_events: unauthenticated user cannot create an event", async () => {
  const ctx = env.unauthenticatedContext();
  await assertFails(
    ctx
      .firestore()
      .doc(`activity_events/ae-create-anon-${RUN}`)
      .set(validEventBody())
  );
});

// AE8: missing required field (recipeId) is rejected.
test("activity_events: create without recipeId is rejected", async () => {
  const ctx = env.authenticatedContext(ACTOR_UID, AGE_OK);
  const body = validEventBody();
  delete (body as Record<string, unknown>).recipeId;
  await assertFails(
    ctx.firestore().doc(`activity_events/ae-no-recipe-${RUN}`).set(body)
  );
});

// AE9: missing required field (createdAt) is rejected.
test("activity_events: create without createdAt is rejected", async () => {
  const ctx = env.authenticatedContext(ACTOR_UID, AGE_OK);
  const body = validEventBody();
  delete (body as Record<string, unknown>).createdAt;
  await assertFails(
    ctx.firestore().doc(`activity_events/ae-no-created-${RUN}`).set(body)
  );
});

// AE9b: missing required field (type) is rejected. `type` is in
// hasRequiredFields but had no dedicated deny — without this a future drop of
// 'type' from the required list would go unnoticed.
test("activity_events: create without type is rejected", async () => {
  const ctx = env.authenticatedContext(ACTOR_UID, AGE_OK);
  const body = validEventBody();
  delete (body as Record<string, unknown>).type;
  await assertFails(
    ctx.firestore().doc(`activity_events/ae-no-type-${RUN}`).set(body)
  );
});

// AE9c: non-string type is rejected (`type is string`).
test("activity_events: non-string type is rejected", async () => {
  const ctx = env.authenticatedContext(ACTOR_UID, AGE_OK);
  await assertFails(
    ctx
      .firestore()
      .doc(`activity_events/ae-type-num-${RUN}`)
      .set(validEventBody({ type: 7 }))
  );
});

// AE10: non-string recipeId is rejected (`is string`).
test("activity_events: non-string recipeId is rejected", async () => {
  const ctx = env.authenticatedContext(ACTOR_UID, AGE_OK);
  await assertFails(
    ctx
      .firestore()
      .doc(`activity_events/ae-recipe-num-${RUN}`)
      .set(validEventBody({ recipeId: 42 }))
  );
});

// AE11: oversized recipeId (201 chars) is rejected (size() <= 200).
test("activity_events: oversized recipeId is rejected", async () => {
  const ctx = env.authenticatedContext(ACTOR_UID, AGE_OK);
  await assertFails(
    ctx
      .firestore()
      .doc(`activity_events/ae-recipe-big-${RUN}`)
      .set(validEventBody({ recipeId: "x".repeat(201) }))
  );
});

// AE12: oversized recipeTitle (301 chars) is rejected (size() <= 300).
test("activity_events: oversized recipeTitle is rejected", async () => {
  const ctx = env.authenticatedContext(ACTOR_UID, AGE_OK);
  await assertFails(
    ctx
      .firestore()
      .doc(`activity_events/ae-title-big-${RUN}`)
      .set(validEventBody({ recipeTitle: "x".repeat(301) }))
  );
});

// AE12c: a create within the 2s burst window is rejected by
// rateLimitWrite('activity_events', 2). Seed the rate-limit doc with a fresh
// lastWrite for a dedicated actor (so AE5's actor stays clean), then prove the
// next create denies. Without this the rate-limit clause is unproven — a drop
// of the clause would silently pass every other create test.
test("activity_events: create within the rate-limit window is rejected", async () => {
  const RL_UID = "activity-ratelimited-uid";
  await env.withSecurityRulesDisabled(async (admin) => {
    await admin
      .firestore()
      .doc(`users/${RL_UID}/rate_limits/activity_events`)
      .set({ lastWrite: new Date() });
  });
  const ctx = env.authenticatedContext(RL_UID, AGE_OK);
  await assertFails(
    ctx
      .firestore()
      .doc(`activity_events/ae-ratelimited-${RUN}`)
      .set(validEventBody({ actorId: RL_UID }))
  );
});

// ============================================================================
// ACTIVITY EVENTS — update (actor-only, immutable identity/anchor fields)
// ============================================================================

// AE12b: the actor CAN update a mutable field on their own event. This is the
// only update allow-path proof — without it a regression of the actor check or
// cannotModify() to a blanket deny would pass every other (deny) update test.
test("activity_events: actor can update a mutable field on own event", async () => {
  await seedEvent("ae-update-ok");
  const ctx = env.authenticatedContext(ACTOR_UID);
  await assertSucceeds(
    ctx
      .firestore()
      .doc(`activity_events/ae-update-ok`)
      .update({ recipeTitle: "Köttbullar (uppdaterad)" })
  );
});

// AE13: the actor cannot mutate actorId (identity is immutable).
test("activity_events: actor cannot change actorId on update", async () => {
  await seedEvent("ae-update-actor");
  const ctx = env.authenticatedContext(ACTOR_UID);
  await assertFails(
    ctx
      .firestore()
      .doc(`activity_events/ae-update-actor`)
      .update({ actorId: STRANGER_UID })
  );
});

// AE13b: the actor cannot mutate recipeId (anchor field is immutable).
test("activity_events: actor cannot change recipeId on update", async () => {
  await seedEvent("ae-update-recipe");
  const ctx = env.authenticatedContext(ACTOR_UID);
  await assertFails(
    ctx
      .firestore()
      .doc(`activity_events/ae-update-recipe`)
      .update({ recipeId: "recipe-2" })
  );
});

// AE13c: the actor cannot mutate createdAt (anchor field is immutable).
test("activity_events: actor cannot change createdAt on update", async () => {
  await seedEvent("ae-update-created");
  const ctx = env.authenticatedContext(ACTOR_UID);
  await assertFails(
    ctx
      .firestore()
      .doc(`activity_events/ae-update-created`)
      .update({ createdAt: new Date(0) })
  );
});

// AE14: a stranger cannot update the actor's event.
test("activity_events: stranger cannot update the actor's event", async () => {
  await seedEvent("ae-update-stranger");
  const ctx = env.authenticatedContext(STRANGER_UID);
  await assertFails(
    ctx
      .firestore()
      .doc(`activity_events/ae-update-stranger`)
      .update({ recipeTitle: "hijacked" })
  );
});

// ============================================================================
// ACTIVITY EVENTS — delete (actor-only)
// ============================================================================

// AE15: the actor can delete their own event.
test("activity_events: actor can delete own event", async () => {
  await seedEvent("ae-del-own");
  const ctx = env.authenticatedContext(ACTOR_UID);
  await assertSucceeds(
    ctx.firestore().doc(`activity_events/ae-del-own`).delete()
  );
});

// AE16: a friend cannot delete the actor's event (read access != delete).
test("activity_events: friend cannot delete the actor's event", async () => {
  await seedEvent("ae-del-friend");
  const ctx = env.authenticatedContext(FRIEND_UID);
  await assertFails(
    ctx.firestore().doc(`activity_events/ae-del-friend`).delete()
  );
});

// AE17: a stranger cannot delete the actor's event.
test("activity_events: stranger cannot delete the actor's event", async () => {
  await seedEvent("ae-del-stranger");
  const ctx = env.authenticatedContext(STRANGER_UID);
  await assertFails(
    ctx.firestore().doc(`activity_events/ae-del-stranger`).delete()
  );
});

async function run(): Promise<void> {
  console.log("activity_events rules tests (BUT-1294)\n");
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
