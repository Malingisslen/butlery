/**
 * BUT-773: Firestore rules tests for the `/realtime_menus/{menuId}/votes/{voteId}`
 * subcollection. Without these tests, the absence of an explicit rule block
 * silently fell through to default-deny, which obscured the missing rule
 * (clients failed without an obvious cause) and made future rule edits
 * untestable for this path.
 *
 * Each test name states the behavior it proves. If a test fails, either the
 * rule changed or the design intent changed — decide which.
 *
 * Prerequisite: Firestore emulator must be running locally
 * (`firebase emulators:start --only firestore --project demo-test`).
 *
 * Run with: npx ts-node src/__tests__/realtime-menus-rules.test.ts
 */

import * as fs from "fs";
import * as path from "path";
import {
  initializeTestEnvironment,
  RulesTestEnvironment,
  assertFails,
  assertSucceeds,
} from "@firebase/rules-unit-testing";

// MUTATION-PROBE SEAM (same contract as poll-votes-rules.test.ts): both values
// are overridable so a probe can point this suite at a MUTATED COPY of
// firestore.rules under a FRESH projectId without touching the real file.
const PROJECT_ID = process.env.PROBE_PROJECT_ID ?? "butlery-rules-rt-menus";
const RULES_PATH =
  process.env.PROBE_RULES_PATH ??
  path.resolve(__dirname, "../../../firestore.rules");

const OWNER_UID = "rt-menu-owner";
const PARTICIPANT_UID = "rt-menu-participant";
const STRANGER_UID = "rt-menu-stranger";
const MENU_ID = "rt-menu-1";

let env: RulesTestEnvironment;

async function setup(): Promise<void> {
  const rules = fs.readFileSync(RULES_PATH, "utf8");
  env = await initializeTestEnvironment({
    projectId: PROJECT_ID,
    firestore: { rules, host: "127.0.0.1", port: 8080 },
  });
  // Suites share one long-lived emulator; fixed doc ids left by an earlier
  // run turn a create-only `set` into a denied update.
  await env.clearFirestore();

  // Seed a realtime menu with owner + participant. The votes subcollection
  // rule reads this parent doc via isRealtimeParticipant('realtime_menus', menuId)
  // to authorize voters.
  await env.withSecurityRulesDisabled(async (ctx) => {
    await ctx.firestore().doc(`realtime_menus/${MENU_ID}`).set({
      ownerId: OWNER_UID,
      participants: [
        { userId: OWNER_UID, joinedAt: new Date() },
        { userId: PARTICIPANT_UID, joinedAt: new Date() },
      ],
      participantIds: [OWNER_UID, PARTICIPANT_UID],
      createdAt: new Date(),
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

// Test 1: a participant can create their own vote (doc id == their uid).
// This is the primary happy-path the rule must allow.
test(
  "BUT-773: participant can create vote with doc id == own uid",
  async () => {
    const ctx = env.authenticatedContext(PARTICIPANT_UID);
    await assertSucceeds(
      ctx
        .firestore()
        .doc(`realtime_menus/${MENU_ID}/votes/${PARTICIPANT_UID}`)
        .set({
          userId: PARTICIPANT_UID,
          choice: "tacos",
          createdAt: new Date(),
        })
    );
  }
);

// Test 2: a non-participant cannot vote. Without this gate, anyone with the
// menuId could spam the votes subcollection — the parent menu's read rule
// already protects the menu doc, but votes need the same gate independently.
test(
  "BUT-773: non-participant cannot create a vote",
  async () => {
    const ctx = env.authenticatedContext(STRANGER_UID);
    await assertFails(
      ctx
        .firestore()
        .doc(`realtime_menus/${MENU_ID}/votes/${STRANGER_UID}`)
        .set({
          userId: STRANGER_UID,
          choice: "tacos",
          createdAt: new Date(),
        })
    );
  }
);

// Test 3: a user cannot vote on behalf of another user. The doc-id-as-uid
// convention is what makes the per-user-one-vote constraint rules-enforceable;
// allowing arbitrary doc ids would let anyone register multiple votes by
// picking different doc ids.
test(
  "BUT-773: participant cannot create a vote with someone else's uid as doc id",
  async () => {
    const ctx = env.authenticatedContext(PARTICIPANT_UID);
    await assertFails(
      ctx
        .firestore()
        .doc(`realtime_menus/${MENU_ID}/votes/${OWNER_UID}`) // wrong id
        .set({
          userId: PARTICIPANT_UID,
          choice: "pizza",
          createdAt: new Date(),
        })
    );
  }
);

// BUT-2118: `votes` is also the collection id of live-menu ballots, which the
// account erasure finds by collection group on `userId`. A legacy vote naming
// someone else would sit in that person's erasure for good.
test(
  "BUT-2118: a legacy vote whose userId names someone else is refused",
  async () => {
    // Test 1 left this document behind; a create is what is being tested.
    await env.withSecurityRulesDisabled(async (ctx) => {
      await ctx
        .firestore()
        .doc(`realtime_menus/${MENU_ID}/votes/${PARTICIPANT_UID}`)
        .delete();
    });
    const ctx = env.authenticatedContext(PARTICIPANT_UID);
    await assertFails(
      ctx
        .firestore()
        .doc(`realtime_menus/${MENU_ID}/votes/${PARTICIPANT_UID}`)
        .set({ userId: OWNER_UID, choice: "tacos", createdAt: new Date() })
    );
  }
);

test(
  "BUT-2118: a legacy vote without userId is still allowed",
  async () => {
    // Test 1 left this document behind; a create is what is being tested.
    await env.withSecurityRulesDisabled(async (ctx) => {
      await ctx
        .firestore()
        .doc(`realtime_menus/${MENU_ID}/votes/${PARTICIPANT_UID}`)
        .delete();
    });
    const ctx = env.authenticatedContext(PARTICIPANT_UID);
    await assertSucceeds(
      ctx
        .firestore()
        .doc(`realtime_menus/${MENU_ID}/votes/${PARTICIPANT_UID}`)
        .set({ choice: "tacos", createdAt: new Date() })
    );
  }
);

// Test 4: vote owner can update their own vote (re-vote / change choice).
// Realtime menus are collaborative; the UI lets users change their vote
// while the menu is open.
test(
  "BUT-773: vote owner can update own vote",
  async () => {
    // Seed an existing vote by the owner.
    await env.withSecurityRulesDisabled(async (ctx) => {
      await ctx
        .firestore()
        .doc(`realtime_menus/${MENU_ID}/votes/${OWNER_UID}`)
        .set({
          userId: OWNER_UID,
          choice: "burger",
          createdAt: new Date(),
        });
    });
    const ctx = env.authenticatedContext(OWNER_UID);
    await assertSucceeds(
      ctx
        .firestore()
        .doc(`realtime_menus/${MENU_ID}/votes/${OWNER_UID}`)
        .update({ choice: "salad" })
    );
  }
);

// Test 5: vote owner can delete their own vote.
test(
  "BUT-773: vote owner can delete own vote",
  async () => {
    await env.withSecurityRulesDisabled(async (ctx) => {
      await ctx
        .firestore()
        .doc(`realtime_menus/${MENU_ID}/votes/${PARTICIPANT_UID}`)
        .set({
          userId: PARTICIPANT_UID,
          choice: "ramen",
          createdAt: new Date(),
        });
    });
    const ctx = env.authenticatedContext(PARTICIPANT_UID);
    await assertSucceeds(
      ctx
        .firestore()
        .doc(`realtime_menus/${MENU_ID}/votes/${PARTICIPANT_UID}`)
        .delete()
    );
  }
);

// Test 6: participants can read votes (collaborative awareness — every
// participant sees the running tally). Strangers cannot. This is the read
// gate that protects vote PII (which user voted what).
test(
  "BUT-773: participant can read votes; stranger cannot",
  async () => {
    await env.withSecurityRulesDisabled(async (ctx) => {
      await ctx
        .firestore()
        .doc(`realtime_menus/${MENU_ID}/votes/${OWNER_UID}`)
        .set({
          userId: OWNER_UID,
          choice: "soup",
          createdAt: new Date(),
        });
    });
    const partCtx = env.authenticatedContext(PARTICIPANT_UID);
    await assertSucceeds(
      partCtx
        .firestore()
        .doc(`realtime_menus/${MENU_ID}/votes/${OWNER_UID}`)
        .get()
    );
    const strangerCtx = env.authenticatedContext(STRANGER_UID);
    await assertFails(
      strangerCtx
        .firestore()
        .doc(`realtime_menus/${MENU_ID}/votes/${OWNER_UID}`)
        .get()
    );
  }
);

// Test 8 (gap fill): a participant cannot delete another participant's vote.
// Per-user-one-vote integrity hinges on the deletion gate too — without
// coverage on the deny path, a regression that broadened delete to "any
// participant" would let one voter erase others' votes silently.
test(
  "BUT-773 (gap): participant cannot delete another voter's vote",
  async () => {
    await env.withSecurityRulesDisabled(async (ctx) => {
      await ctx
        .firestore()
        .doc(`realtime_menus/${MENU_ID}/votes/${OWNER_UID}`)
        .set({
          userId: OWNER_UID,
          choice: "x",
          createdAt: new Date(),
        });
    });
    // PARTICIPANT tries to delete OWNER's vote — must be denied.
    const ctx = env.authenticatedContext(PARTICIPANT_UID);
    await assertFails(
      ctx
        .firestore()
        .doc(`realtime_menus/${MENU_ID}/votes/${OWNER_UID}`)
        .delete()
    );
  }
);

// Test 7: vote with a `userId` field that doesn't match the doc id is
// rejected. Defence in depth — the doc-id check alone covers the new path,
// but a legacy / migration script writing a vote with a foreign userId
// inside the body should not be silently accepted on update.
test(
  "BUT-773: update rejected when stored userId disagrees with auth uid",
  async () => {
    // Seed a vote whose body contains a different userId than the doc id.
    await env.withSecurityRulesDisabled(async (ctx) => {
      await ctx
        .firestore()
        .doc(`realtime_menus/${MENU_ID}/votes/${PARTICIPANT_UID}`)
        .set({
          userId: STRANGER_UID,  // mismatched on purpose
          choice: "old",
          createdAt: new Date(),
        });
    });
    const ctx = env.authenticatedContext(PARTICIPANT_UID);
    await assertFails(
      ctx
        .firestore()
        .doc(`realtime_menus/${MENU_ID}/votes/${PARTICIPANT_UID}`)
        .update({ choice: "new" })
    );
  }
);

// ============================================================================
// BUT-2017: the menu vote is a ballot surface, and blocking reaches it
// ============================================================================
//
// `poll_votes` got this gate in BUT-1917; the household menu vote is the
// second, identical surface. The voter's own `users/{uid}/block_mirror/current`
// (Admin-SDK-written) is crossed with the menu's `participantIds`. Fail-open on
// a missing mirror and one-directional, both by BUT-1917's decisions.

const BLOCKED_UID = "rt-menu-blocked";
const MENU_BLOCK_ID = "rt-menu-block-1";

async function seedMirror(uid: string, blockers: string[]): Promise<void> {
  await env.withSecurityRulesDisabled(async (ctx) => {
    await ctx.firestore().doc(`users/${uid}/block_mirror/current`).set({
      blockedByUserIds: blockers,
      sourceRev: 1,
      truncated: false,
    });
  });
}

async function deleteMirror(uid: string): Promise<void> {
  await env.withSecurityRulesDisabled(async (ctx) => {
    await ctx.firestore().doc(`users/${uid}/block_mirror/current`).delete();
  });
}

async function seedBlockMenu(): Promise<void> {
  await env.withSecurityRulesDisabled(async (ctx) => {
    await ctx.firestore().doc(`realtime_menus/${MENU_BLOCK_ID}`).set({
      ownerId: OWNER_UID,
      participants: [
        { userId: OWNER_UID, joinedAt: new Date() },
        { userId: BLOCKED_UID, joinedAt: new Date() },
      ],
      participantIds: [OWNER_UID, BLOCKED_UID],
      createdAt: new Date(),
    });
  });
}

function castVote(uid: string, choice: string): Promise<void> {
  return env
    .authenticatedContext(uid)
    .firestore()
    .doc(`realtime_menus/${MENU_BLOCK_ID}/votes/${uid}`)
    .set({ userId: uid, choice, createdAt: new Date() });
}

// V1: DENY — the owner has blocked this participant; their vote is refused.
test("BUT-2017: a participant blocked by someone on the menu cannot create a vote", async () => {
  await seedBlockMenu();
  await seedMirror(BLOCKED_UID, [OWNER_UID]);
  try {
    await assertFails(castVote(BLOCKED_UID, "tacos"));
  } finally {
    await deleteMirror(BLOCKED_UID);
  }
});

// V2: ALLOW (control) — same voter, same menu, same payload; the mirror names
// somebody who is not on this menu.
test("BUT-2017: a participant whose blocker is not on the menu can vote (control)", async () => {
  await seedBlockMenu();
  await seedMirror(BLOCKED_UID, [STRANGER_UID]);
  try {
    await assertSucceeds(castVote(BLOCKED_UID, "tacos"));
  } finally {
    await deleteMirror(BLOCKED_UID);
  }
});

// V3: DENY — the gate is on UPDATE too: a vote cast before the block cannot
// be steered afterwards. V2 left the row in place, so this write is an update.
test("BUT-2017: a blocked participant cannot update the vote they cast before the block", async () => {
  await seedBlockMenu();
  await seedMirror(BLOCKED_UID, [OWNER_UID]);
  try {
    await assertFails(
      env
        .authenticatedContext(BLOCKED_UID)
        .firestore()
        .doc(`realtime_menus/${MENU_BLOCK_ID}/votes/${BLOCKED_UID}`)
        .update({ choice: "pizza" })
    );
  } finally {
    await deleteMirror(BLOCKED_UID);
  }
});

// V4: ALLOW — no mirror document fails open (BUT-1917).
test("BUT-2017: a voter with no mirror document is allowed (fail-open, BUT-1917)", async () => {
  await seedBlockMenu();
  await deleteMirror(BLOCKED_UID);
  await assertSucceeds(castVote(BLOCKED_UID, "pasta"));
});

// V5: ALLOW — the blocker votes normally (one-directional).
test("BUT-2017: the blocker can still vote on the shared menu (one-directional)", async () => {
  await seedBlockMenu();
  await seedMirror(BLOCKED_UID, [OWNER_UID]);
  try {
    await assertSucceeds(castVote(OWNER_UID, "soppa"));
  } finally {
    await deleteMirror(BLOCKED_UID);
  }
});

async function run(): Promise<void> {
  console.log("BUT-773: realtime_menus/votes rules tests\n");
  console.log("==========================================\n");
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
