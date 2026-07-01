/**
 * Firestore rules tests for the `conversations` collection 1:1 minor-DM gate
 * (BUT-674).
 *
 * A non-friend must not be able to start a direct-message conversation with a
 * minor. `isMinor: true` is written server-authoritatively by the
 * verifySignupAge Cloud Function onto users/{uid} for a compliant
 * 15–17-year-old, and is readable from rules via get(). Because a conversation
 * grants message access via its immutable `participantIds` (set at create),
 * conversation-create is the chokepoint for 1:1 DMs — these tests prove:
 *
 *   - DENY:  a non-friend of a minor creating a 1:1 [creator, minor].
 *   - ALLOW: a FRIEND of the minor creating the same 1:1.
 *   - ALLOW: a 1:1 with an ADULT target (isMinor absent/false) by a non-friend
 *            (adults unaffected; fail-open).
 *   - ALLOW (documents a known gap): a GROUP conversation (size == 3) that
 *            includes a minor, created by a non-friend, still succeeds today —
 *            rules cannot iterate the participant list, so group-minor
 *            protection is deferred to default-private profiles + a planned CF.
 *
 * Each test name states the behavior it proves. If a test fails, either the
 * rules changed or the product contract changed — decide which before editing
 * the assertion.
 *
 * Prerequisite: Firestore emulator must be running locally
 * (`firebase emulators:start --only firestore`).
 *
 * Run with: npx ts-node src/__tests__/conversations-rules.test.ts
 */

import * as fs from "fs";
import * as http from "http";
import * as path from "path";
import {
  initializeTestEnvironment,
  RulesTestEnvironment,
  assertFails,
  assertSucceeds,
} from "@firebase/rules-unit-testing";

const PROJECT_ID = "butlery-rules-conversations";
const RULES_PATH = path.resolve(__dirname, "../../../firestore.rules");

// The minor whose users/{uid}.isMinor == true (seeded server-side below).
const MINOR_UID = "conv-minor-uid";
// An adult target (no isMinor field) — the fail-open case.
const ADULT_UID = "conv-adult-uid";
// A friend of the minor (friend doc at users/{minor}/friends/{friend}).
const FRIEND_UID = "conv-friend-uid";
// A user with no friendship to the minor.
const STRANGER_UID = "conv-stranger-uid";

// Per-run token: the emulator persists docs across invocations, so a fixed-id
// create-allow test would become an UPDATE on the 2nd run and hit a different
// rule. Unique ids keep create tests proving the create rule.
const RUN = Date.now().toString(36);

let env: RulesTestEnvironment;

function clearFirestore(): Promise<void> {
  return new Promise((resolve, reject) => {
    const req = http.request(
      {
        host: "127.0.0.1",
        port: 8080,
        method: "DELETE",
        path: `/emulator/v1/projects/${PROJECT_ID}/databases/(default)/documents`,
      },
      (res) => {
        res.on("data", () => undefined);
        res.on("end", resolve);
      }
    );
    req.on("error", reject);
    req.end();
  });
}

async function setup(): Promise<void> {
  const rules = fs.readFileSync(RULES_PATH, "utf8");
  env = await initializeTestEnvironment({
    projectId: PROJECT_ID,
    firestore: { rules, host: "127.0.0.1", port: 8080 },
  });
  await clearFirestore();

  await env.withSecurityRulesDisabled(async (ctx) => {
    const db = ctx.firestore();
    // The minor's server-authoritative profile flag. Only isMinor matters to
    // the gate; the rest mirrors a real profile doc.
    await db.doc(`users/${MINOR_UID}`).set({ isMinor: true });
    // An adult profile: NO isMinor field -> otherIsMinor() returns false.
    await db.doc(`users/${ADULT_UID}`).set({ displayName: "Vuxen" });
    // Friendship: FRIEND_UID is a friend of the minor. Directional per the
    // established pattern users/{minor}/friends/{friend}.
    await db.doc(`users/${MINOR_UID}/friends/${FRIEND_UID}`).set({
      addedAt: new Date(),
    });
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

// A minimal-but-valid 1:1 conversation body. `participantIds` must contain the
// creator (auth.uid) per the base create rule; tests set it per case.
function convBody(
  participantIds: string[],
  extra: Record<string, unknown> = {}
): Record<string, unknown> {
  return {
    participantIds,
    createdAt: new Date(),
    ...extra,
  };
}

// ============================================================================
// CONVERSATIONS — 1:1 minor-DM gate (BUT-674)
// ============================================================================

// C1: DENY — a non-friend of a minor cannot open a 1:1 DM with that minor.
// This is the core protection: minor's isMinor == true, no friend doc.
test("conversations: non-friend cannot create a 1:1 DM with a minor", async () => {
  const ctx = env.authenticatedContext(STRANGER_UID);
  await assertFails(
    ctx
      .firestore()
      .doc(`conversations/c-minor-deny-${RUN}`)
      .set(convBody([STRANGER_UID, MINOR_UID]))
  );
});

// C2: ALLOW — a friend of the minor can open the same 1:1 DM.
// Proves the deny in C1 is the FRIENDSHIP gate, not an unrelated failure:
// identical body/shape, only the friend doc differs.
test("conversations: friend of a minor can create a 1:1 DM with the minor", async () => {
  const ctx = env.authenticatedContext(FRIEND_UID);
  await assertSucceeds(
    ctx
      .firestore()
      .doc(`conversations/c-minor-allow-${RUN}`)
      .set(convBody([FRIEND_UID, MINOR_UID]))
  );
});

// C3: ALLOW — a non-friend can open a 1:1 DM with an ADULT target.
// Adults are unaffected: isMinor absent -> otherIsMinor() false -> gate passes.
test("conversations: non-friend can create a 1:1 DM with an adult", async () => {
  const ctx = env.authenticatedContext(STRANGER_UID);
  await assertSucceeds(
    ctx
      .firestore()
      .doc(`conversations/c-adult-allow-${RUN}`)
      .set(convBody([STRANGER_UID, ADULT_UID]))
  );
});

// C4: ALLOW — the minor gate holds regardless of participant ORDER.
// otherParticipant() must pick the non-creator whether the minor is index 0 or
// 1. Here the minor is at index 0 and the (non-friend) creator at index 1 ->
// must still DENY. (Order-sensitivity guard on the deny side.)
test("conversations: non-friend 1:1 DM with minor is denied when minor is first in the array", async () => {
  const ctx = env.authenticatedContext(STRANGER_UID);
  await assertFails(
    ctx
      .firestore()
      .doc(`conversations/c-minor-order-deny-${RUN}`)
      .set(convBody([MINOR_UID, STRANGER_UID]))
  );
});

// C5: ALLOW — documents the KNOWN GAP. A GROUP conversation (size == 3) that
// includes a minor, created by a non-friend, SUCCEEDS today. Firestore rules
// cannot iterate the participant list to find the minor, so group-minor
// protection is intentionally NOT enforced here — it relies on default-private
// profiles (a non-friend can't discover the minor to add them) plus a planned
// Cloud Function follow-up. If this ever starts FAILING, the group path was
// (accidentally or deliberately) gated — reconcile with the rule comment.
test("conversations: non-friend CAN create a group (size 3) conversation including a minor (known rules-cannot-iterate gap)", async () => {
  const ctx = env.authenticatedContext(STRANGER_UID);
  await assertSucceeds(
    ctx
      .firestore()
      .doc(`conversations/c-group-allow-${RUN}`)
      .set(convBody([STRANGER_UID, MINOR_UID, ADULT_UID]))
  );
});

async function run(): Promise<void> {
  console.log("conversations 1:1 minor-DM gate rules tests (BUT-674)\n");
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
