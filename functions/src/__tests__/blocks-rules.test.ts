/**
 * Firestore rules tests for the `blocks` collection (BUT-1917).
 *
 * WHY THIS FILE EXISTS. The collection has carried a read rule with two
 * disjuncts since it shipped, and until now every client read was a point
 * lookup on a uid the caller already held (`isBlocked`, `isBlockedBy`).
 * BUT-1917 adds the first client LIST reads — `where('blockedId', '==', uid)`,
 * used to strip the ballots of people who blocked the viewer — and a list query
 * is a different question to a rule than a get is.
 *
 * Rules are not filters. A list query is refused unless the rule can prove
 * every document it could return is readable, so a query whose constraint does
 * not line up with a disjunct is denied WHOLESALE, not filtered down. This repo
 * has already paid for that once: BUT-1971's contributor query is denied even
 * to a current member, because the read rule tests a different field from the
 * one the query constrains, and the shipped code said so only after the
 * emulator was asked.
 *
 * Nothing else can catch a regression here. `fake_cloud_firestore` enforces no
 * rules at all, and the repository's own suite drives mocktail doubles — both
 * would stay green on a rule that denies every incoming read in production.
 *
 * Prerequisite: Firestore emulator must be running locally
 * (`firebase emulators:start --only firestore`).
 *
 * Run with: npm run test:rules:blocks
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

// MUTATION-PROBE SEAM, same contract as the sibling suites: a probe can point
// this suite at a MUTATED COPY of firestore.rules under a FRESH projectId
// without touching the real file.
//
// `PROJECT_ID` stays a BARE LITERAL and its override lives at the call site.
// `rules-coverage-report.js` discovers project ids with a regex over
// `PROJECT_ID = "..."`, so folding `process.env.PROBE_PROJECT_ID ??` in here
// would drop this suite out of the coverage union — silently, which is the
// whole failure mode of a discovery mechanism.
const PROJECT_ID = "butlery-rules-blocks";
const RULES_PATH =
  process.env.PROBE_RULES_PATH ??
  path.resolve(__dirname, "../../../firestore.rules");

// The person whose client runs the queries.
const ME = "bl-me-uid";
// Blocked ME. Appears in my INCOMING list and nowhere I may write.
const BLOCKER = "bl-blocker-uid";
// I blocked them. Appears in my OUTGOING list.
const BLOCKED = "bl-blocked-uid";
// Two other people, blocking each other. Neither row names me, so neither is
// readable by me — this is what makes the unconstrained-list denial meaningful
// rather than vacuous over an empty collection.
const STRANGER_A = "bl-stranger-a";
const STRANGER_B = "bl-stranger-b";

let env: RulesTestEnvironment;

function clearFirestore(): Promise<void> {
  return new Promise((resolve, reject) => {
    const req = http.request(
      {
        host: "127.0.0.1",
        port: 8080,
        method: "DELETE",
        path: `/emulator/v1/projects/${
          process.env.PROBE_PROJECT_ID ?? PROJECT_ID
        }/databases/(default)/documents`,
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

function blockId(blockerId: string, blockedId: string): string {
  return `${blockerId}_${blockedId}`;
}

async function seed(): Promise<void> {
  await env.withSecurityRulesDisabled(async (ctx) => {
    const db = ctx.firestore();
    for (const [blockerId, blockedId] of [
      [BLOCKER, ME],
      [ME, BLOCKED],
      [STRANGER_A, STRANGER_B],
      [STRANGER_B, STRANGER_A],
    ]) {
      await db
        .doc(`blocks/${blockId(blockerId, blockedId)}`)
        .set({ blockerId, blockedId, createdAt: new Date() });
    }
  });
}

async function setup(): Promise<void> {
  const rules = fs.readFileSync(RULES_PATH, "utf8");
  env = await initializeTestEnvironment({
    projectId: process.env.PROBE_PROJECT_ID ?? PROJECT_ID,
    firestore: { rules, host: "127.0.0.1", port: 8080 },
  });
  await clearFirestore();
  await seed();
}

async function teardown(): Promise<void> {
  if (env) await env.cleanup();
}

type TestFn = () => Promise<void>;
const tests: { name: string; fn: TestFn }[] = [];
function test(name: string, fn: TestFn): void {
  tests.push({ name, fn });
}

// ============================================================================
// LIST — the capability BUT-1917 introduced
// ============================================================================

// L1: ALLOW — the incoming query the ballot strip depends on. If this is ever
// denied, `currentBlockedByIds`/`requireBlockedByIds` return nothing in
// production while every Dart suite stays green, and `closePoll` degrades to
// refusing on an exception it cannot explain.
test("blocks: I may LIST who blocked me", async () => {
  const db = env.authenticatedContext(ME).firestore();
  await assertSucceeds(
    db.collection("blocks").where("blockedId", "==", ME).get()
  );
});

// L2: ALLOW — the outgoing twin, which predates this ticket. Its value here is
// as the control for L1: it shows the collection is listable at all, so L1
// passing is about the second disjunct rather than about list being open.
test("blocks: I may LIST who I blocked", async () => {
  const db = env.authenticatedContext(ME).firestore();
  await assertSucceeds(
    db.collection("blocks").where("blockerId", "==", ME).get()
  );
});

// L3: DENY — no constraint, so the rule cannot prove every returnable document
// is mine. This is the case that shows the two allows above are earned by their
// `where`, not by a permissive collection.
test("blocks: an UNCONSTRAINED list is refused", async () => {
  const db = env.authenticatedContext(ME).firestore();
  await assertFails(db.collection("blocks").get());
});

// L4: DENY — somebody else's incoming list. A query constrained to a uid that
// is not the caller's proves nothing about readability, and being able to run
// it would disclose exactly who has blocked a third party.
test("blocks: I may not LIST who blocked SOMEBODY ELSE", async () => {
  const db = env.authenticatedContext(ME).firestore();
  await assertFails(
    db.collection("blocks").where("blockedId", "==", STRANGER_A).get()
  );
});

// L5: DENY — signed out. Do NOT read this as pinning `isAuthenticated()`:
// dropping that conjunct reddens nothing here, because a null uid already makes
// the query unprovable for a rule that compares against `request.auth.uid`.
// What it pins is the outcome, which is the thing that matters.
test("blocks: a signed-out client may not list at all", async () => {
  const db = env.unauthenticatedContext().firestore();
  await assertFails(
    db.collection("blocks").where("blockedId", "==", ME).get()
  );
});

// ============================================================================
// GET / WRITE — the pre-existing contract, pinned because this file is the
// collection's only rules coverage
// ============================================================================

// G1: ALLOW — a point read of a row naming me as the blocked party. This is
// what `isBlockedBy` does.
test("blocks: I may GET a row that names me", async () => {
  const db = env.authenticatedContext(ME).firestore();
  await assertSucceeds(db.doc(`blocks/${blockId(BLOCKER, ME)}`).get());
});

// G2: DENY — a row between two other people names neither of my roles.
test("blocks: I may not GET a row about two other people", async () => {
  const db = env.authenticatedContext(ME).firestore();
  await assertFails(
    db.doc(`blocks/${blockId(STRANGER_A, STRANGER_B)}`).get()
  );
});

// W1: ALLOW — the block button's own write.
test("blocks: I may create a block where I am the blocker", async () => {
  const db = env.authenticatedContext(ME).firestore();
  await assertSucceeds(
    db.doc(`blocks/${blockId(ME, STRANGER_A)}`).set({
      blockerId: ME,
      blockedId: STRANGER_A,
      createdAt: new Date(),
    })
  );
});

// W2: DENY — writing a block in somebody else's name. Without this, anyone
// could seat a block that silences a third party's votes everywhere, since
// `poll_votes` now consults the mirror derived from this collection.
test("blocks: I may not create a block in somebody else's name", async () => {
  // The id must be one NO fixture seeds. With a seeded id this write lands on
  // `allow update: if false` and passes without ever reaching the create limb
  // it argues about — measured: dropping `blockerId == request.auth.uid` from
  // create left the whole suite green while this test sat here looking like
  // its guard.
  const unseeded = blockId(STRANGER_A, ME);
  await env.withSecurityRulesDisabled(async (ctx) => {
    const existing = await ctx.firestore().doc(`blocks/${unseeded}`).get();
    if (existing.exists) {
      throw new Error(
        "this case must exercise CREATE, and a fixture now seeds its id"
      );
    }
  });
  const db = env.authenticatedContext(ME).firestore();
  await assertFails(
    db.doc(`blocks/${unseeded}`).set({
      blockerId: STRANGER_A,
      blockedId: ME,
      createdAt: new Date(),
    })
  );
});

// W3: DENY — a doc id that disagrees with the fields. The id is the only thing
// tying a row to its path, and `expectedMirrorFor` reads the FIELD, so a row
// whose id and fields disagree would be enforced under one identity and
// discoverable under another.
test("blocks: the doc id must match the fields", async () => {
  const db = env.authenticatedContext(ME).firestore();
  await assertFails(
    db.doc(`blocks/${blockId(ME, STRANGER_A)}`).set({
      blockerId: ME,
      blockedId: STRANGER_B,
      createdAt: new Date(),
    })
  );
});

// W4: DENY — blocking yourself. Harmless on its face, but it would put the
// user's own uid in their own mirror and refuse their own votes.
test("blocks: I may not block myself", async () => {
  const db = env.authenticatedContext(ME).firestore();
  await assertFails(
    db.doc(`blocks/${blockId(ME, ME)}`).set({
      blockerId: ME,
      blockedId: ME,
      createdAt: new Date(),
    })
  );
});

// W5: DENY — a block is immutable (`allow update: if false`). The blocker
// unblocks by DELETING, and an editable row would let a blocker silently
// redirect an existing block at a third party.
test("blocks: a block cannot be edited, only deleted", async () => {
  const db = env.authenticatedContext(ME).firestore();
  await assertFails(
    db
      .doc(`blocks/${blockId(ME, BLOCKED)}`)
      .update({ createdAt: new Date() })
  );
});

// W6: ALLOW — the blocker unblocks.
test("blocks: the blocker may delete their own block", async () => {
  const db = env.authenticatedContext(ME).firestore();
  await assertSucceeds(db.doc(`blocks/${blockId(ME, BLOCKED)}`).delete());
});

// W7: DENY — and the BLOCKED party may not. This is the one that matters: a
// blocked person deleting the row that constrains them would remove themselves
// from the blocker's list, the mirror would rebuild without it, and their votes
// would count again.
test("blocks: the blocked party may NOT delete the block", async () => {
  const db = env.authenticatedContext(ME).firestore();
  await assertFails(db.doc(`blocks/${blockId(BLOCKER, ME)}`).delete());
});

async function run(): Promise<void> {
  console.log("blocks collection rules tests (BUT-1917)\n");
  console.log("========================================\n");
  await setup();
  let failed = 0;
  for (const t of tests) {
    // Every test re-seeds: W6 deletes a row two other tests read, and the
    // emulator persists across `npm run` invocations, so a suite that seeded
    // once would pass on the first run and fail on the second.
    await clearFirestore();
    await seed();
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
