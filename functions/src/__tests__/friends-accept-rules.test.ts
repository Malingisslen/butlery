/**
 * Firestore rules tests for the pre-release-audit B1 friends-write tightening.
 *
 * The hole: the old rule allowed `write: if ... request.auth.uid == friendId`,
 * letting ANY signed-in user create `users/{victim}/friends/{self}` — no
 * request, no consent. Because the `cook_snaps` and `activity_events` read
 * rules gate friend access on the EXISTENCE of that friend doc, a stranger
 * could self-insert and then read a victim's private cooking photos / feed.
 *
 * The fix splits the rule:
 *   create, update: isOwner(userId)                      // own list only
 *   delete:         isOwner(userId) || uid == friendId   // mutual removal ok
 * and moves the mutual-accept write into the `acceptFriendRequest` Cloud
 * Function (Admin SDK, bypasses rules after validating the social_request).
 *
 * Prerequisite: Firestore emulator running (`firebase emulators:start
 * --only firestore`).
 *
 * Run with: npx ts-node src/__tests__/friends-accept-rules.test.ts
 */

import * as fs from "fs";
import * as path from "path";
import {
  initializeTestEnvironment,
  RulesTestEnvironment,
  assertFails,
  assertSucceeds,
} from "@firebase/rules-unit-testing";

const PROJECT_ID = "butlery-friends-accept-test";
const RULES_PATH = path.resolve(__dirname, "../../../firestore.rules");

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

/** Seed a doc bypassing rules (simulates the Admin-SDK / function write). */
async function seed(docPath: string, data: Record<string, unknown>): Promise<void> {
  await env.withSecurityRulesDisabled(async (ctx) => {
    await ctx.firestore().doc(docPath).set(data);
  });
}

type TestFn = () => Promise<void>;
const tests: { name: string; fn: TestFn }[] = [];
function test(name: string, fn: TestFn): void {
  tests.push({ name, fn });
}

// ── The exploit and its closure ────────────────────────────────────────────

test("EXPLOIT CLOSED: stranger cannot create users/{victim}/friends/{self}", async () => {
  const ctx = env.authenticatedContext("attacker-1");
  await assertFails(
    ctx.firestore().doc("users/victim-1/friends/attacker-1").set({
      addedAt: Date.now(),
      displayNameLower: "attacker",
    })
  );
});

test("stranger cannot UPDATE a friend doc inside a victim's list", async () => {
  await seed("users/victim-2/friends/attacker-2", {
    addedAt: Date.now(),
    displayNameLower: "x",
  });
  const ctx = env.authenticatedContext("attacker-2");
  await assertFails(
    ctx.firestore().doc("users/victim-2/friends/attacker-2").update({
      displayNameLower: "y",
    })
  );
});

test("owner CAN create a friend doc in their OWN list", async () => {
  const ctx = env.authenticatedContext("owner-3");
  await assertSucceeds(
    ctx.firestore().doc("users/owner-3/friends/friend-3").set({
      addedAt: Date.now(),
      displayNameLower: "friend",
    })
  );
});

// ── Mutual removal must keep working (cross-user delete) ─────────────────────

test("a user CAN delete their own edge from another user's list (mutual removal)", async () => {
  // friend-4 removes the friendship → deletes users/{owner-4}/friends/{friend-4}
  // where the caller is the friendId.
  await seed("users/owner-4/friends/friend-4", { addedAt: Date.now() });
  const ctx = env.authenticatedContext("friend-4");
  await assertSucceeds(
    ctx.firestore().doc("users/owner-4/friends/friend-4").delete()
  );
});

test("owner CAN delete a friend doc from their own list", async () => {
  await seed("users/owner-5/friends/friend-5", { addedAt: Date.now() });
  const ctx = env.authenticatedContext("owner-5");
  await assertSucceeds(
    ctx.firestore().doc("users/owner-5/friends/friend-5").delete()
  );
});

// ── End-to-end: the privacy payoff via cook_snaps ───────────────────────────

test("stranger CANNOT read a victim's private cook_snap (no friend gate doc)", async () => {
  await seed("cook_snaps/snap-6", {
    userId: "victim-6",
    visibility: "sameAsRecipe",
  });
  // The stranger can't create the friend gate doc (proven above), so the
  // cook_snaps read rule's exists() check never passes.
  const ctx = env.authenticatedContext("attacker-6");
  await assertFails(ctx.firestore().doc("cook_snaps/snap-6").get());
});

test("a legitimate friend (gate doc present) CAN read the cook_snap", async () => {
  await seed("cook_snaps/snap-7", {
    userId: "victim-7",
    visibility: "sameAsRecipe",
  });
  // Gate doc written the legitimate way (server function → simulated here via a
  // disabled-rules seed). The read rule must still grant a real friend.
  await seed("users/victim-7/friends/friend-7", { addedAt: Date.now() });
  const ctx = env.authenticatedContext("friend-7");
  await assertSucceeds(ctx.firestore().doc("cook_snaps/snap-7").get());
});

// activity_events gates friend-reads on the same friend-doc existence, so the
// same exploit closure applies. Prove it explicitly (security-review note).
test("stranger CANNOT read a victim's activity_event (no friend gate doc)", async () => {
  await seed("activity_events/evt-8", { actorId: "victim-8" });
  const ctx = env.authenticatedContext("attacker-8");
  await assertFails(ctx.firestore().doc("activity_events/evt-8").get());
});

test("a legitimate friend CAN read the activity_event", async () => {
  await seed("activity_events/evt-9", { actorId: "victim-9" });
  await seed("users/victim-9/friends/friend-9", { addedAt: Date.now() });
  const ctx = env.authenticatedContext("friend-9");
  await assertSucceeds(ctx.firestore().doc("activity_events/evt-9").get());
});

async function run(): Promise<void> {
  console.log("Friends-accept rules tests (pre-release audit B1)\n");
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
