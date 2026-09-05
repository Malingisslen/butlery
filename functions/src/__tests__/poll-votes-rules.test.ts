/**
 * Firestore rules tests for poll voting and message receipts (BUT-1832), plus
 * the `shared_content` create shape that BUT-1812 depends on.
 *
 * THE ONE THING THIS SUITE EXISTS TO GUARANTEE: a write that everybody in a
 * conversation legitimately makes must not be gated on being the message's
 * AUTHOR. `messages/{id}` had exactly one `allow update`, keyed on
 * `senderId == uid`, and three separate features rode on it — casting a poll
 * vote, marking a message read, marking a batch delivered. All three are
 * performed by the RECIPIENT by definition, so all three were denied for
 * everyone except the person who sent the message. The poll's author could
 * vote in their own poll; nobody else could.
 *
 * The fix is two-shaped, and the shapes are not interchangeable:
 *
 *   - RECEIPTS stay on the message, under a SECOND `allow update` statement
 *     that is scoped by `affectedKeys().hasOnly([...])`. Separate statement,
 *     never OR'd into the sender branch: an `||` makes every conjunct on one
 *     side reachable by the other side's caller, and the recipient's grant must
 *     stay strictly smaller than the sender's.
 *
 *   - VOTES move to `messages/{id}/poll_votes/{voterUid}`. They could not stay
 *     on the message under any rule: votes live inside
 *     `metadata.poll.options[].voterIds`, a list of maps, and CEL cannot walk
 *     one — so "change only your own entry in options[i].voterIds" is not
 *     expressible, and any rule loose enough to permit the write would also let
 *     a participant rewrite the question and everyone else's votes. Putting the
 *     voter in the PATH is what makes the constraint exact.
 *
 * Prerequisite: Firestore emulator must be running locally
 * (`firebase emulators:start --only firestore`).
 *
 * Run with: npm run test:rules:poll-votes
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

// MUTATION-PROBE SEAM (same contract as chat-groups-rules.test.ts): both values
// are overridable so a probe can point this suite at a MUTATED COPY of
// firestore.rules under a FRESH projectId without touching the real file.
const PROJECT_ID = process.env.PROBE_PROJECT_ID ?? "butlery-rules-poll-votes";
const RULES_PATH =
  process.env.PROBE_RULES_PATH ??
  path.resolve(__dirname, "../../../firestore.rules");

// Sent the poll message. Under the OLD rule this was the ONLY uid that could
// vote — which is the whole bug.
const AUTHOR_UID = "pv-author-uid";
// In the conversation, sent nothing. The person the fix is for.
const VOTER_UID = "pv-voter-uid";
// Also in the conversation. Proves one voter cannot write another's row.
const OTHER_MEMBER_UID = "pv-other-uid";
// Not in the conversation at all.
const STRANGER_UID = "pv-stranger-uid";

// The emulator persists across `npm run` invocations, so a fixed-id create test
// would silently become an update on the second run. setup() clears this
// suite's namespace and every test re-seeds, but unique ids cost nothing.
const RUN = Date.now().toString(36);

const CONV_ID = `pv-conv-${RUN}`;
const POLL_MSG_ID = `pv-poll-${RUN}`;
const CLOSED_POLL_MSG_ID = `pv-poll-closed-${RUN}`;
const TEXT_MSG_ID = `pv-text-${RUN}`;
// The shape production actually stores. `MessageDto.toFirestore`
// (`message_dto.dart`:127,157) emits `'metadata': message.metadata`
// unconditionally, so every ordinary message carries `metadata: null` — NOT an
// absent key, which is what `TEXT_MSG_ID` has. The two behave differently under
// the rule and neither was covered (BUT-1801 review, 2026-08-17).
const NULL_META_MSG_ID = `pv-null-meta-${RUN}`;
// An OPEN poll that no other test writes a vote into, reserved for the one test
// that must land on the CREATE limb. Sharing `POLL_MSG_ID` does not work: an
// earlier test has AUTHOR_UID cast a real vote there, so by the time the seating
// test runs the row exists and the write is an UPDATE. That is the exact flaw
// this test was added to fix in V3, and it reproduced here on the first attempt
// — mutation-proved vacuous before this fixture existed (2026-08-17).
const SEAT_POLL_MSG_ID = `pv-poll-seat-${RUN}`;
// `metadata` present, a MAP, with no `poll` key — the fourth state of a nullable
// map and the one production writes most: `Message.recipeShare`,
// `Message.menuShare` and `Message.shoppingListShare` all store
// `{'recipeId': …}`-shaped maps, and the group system-message CF writes another.
// Distinct from both `TEXT_MSG_ID` (key absent) and `NULL_META_MSG_ID` (present
// null), and an `is map` guard does not separate it from a real poll.
const SHARE_META_MSG_ID = `pv-share-meta-${RUN}`;

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

// Constant, never `new Date()`. The receipt rule pins the diff to four keys, so
// a re-stamped `sentAt` would deny for a reason unrelated to the rule under
// test and would read exactly like a rule defect (the BUT-1725 lesson).
const FIXTURE_SENT_AT = new Date("2026-08-16T09:00:00.000Z");

function pollBody(isClosed: boolean): Record<string, unknown> {
  return {
    senderId: AUTHOR_UID,
    conversationId: CONV_ID,
    content: "Vad ska vi äta?",
    sentAt: FIXTURE_SENT_AT,
    status: "sent",
    metadata: {
      poll: {
        id: `p-${RUN}`,
        question: "Vad ska vi äta?",
        creatorId: AUTHOR_UID,
        isClosed,
        options: [
          { id: "opt-a", text: "Tacos", voterIds: [] },
          { id: "opt-b", text: "Pasta", voterIds: [] },
        ],
      },
    },
  };
}

function voteBody(
  voterId: string,
  extra: Record<string, unknown> = {}
): Record<string, unknown> {
  return {
    voterId,
    optionIds: ["opt-a"],
    votedAt: FIXTURE_SENT_AT,
    ...extra,
  };
}

async function seed(): Promise<void> {
  await env.withSecurityRulesDisabled(async (ctx) => {
    const db = ctx.firestore();
    await db.doc(`conversations/${CONV_ID}`).set({
      participantIds: [AUTHOR_UID, VOTER_UID, OTHER_MEMBER_UID],
      isGroup: true,
      createdAt: FIXTURE_SENT_AT,
      updatedAt: FIXTURE_SENT_AT,
    });
    await db.doc(`messages/${POLL_MSG_ID}`).set(pollBody(false));
    await db.doc(`messages/${CLOSED_POLL_MSG_ID}`).set(pollBody(true));
    await db.doc(`messages/${TEXT_MSG_ID}`).set({
      senderId: AUTHOR_UID,
      conversationId: CONV_ID,
      content: "hej",
      sentAt: FIXTURE_SENT_AT,
      status: "sent",
    });
    await db.doc(`messages/${SEAT_POLL_MSG_ID}`).set(pollBody(false));
    await db.doc(`messages/${SHARE_META_MSG_ID}`).set({
      senderId: AUTHOR_UID,
      conversationId: CONV_ID,
      content: "Jag delade ett recept",
      sentAt: FIXTURE_SENT_AT,
      status: "sent",
      metadata: { recipeId: `r-${RUN}`, recipeTitle: "Köttbullar" },
    });
    await db.doc(`messages/${NULL_META_MSG_ID}`).set({
      senderId: AUTHOR_UID,
      conversationId: CONV_ID,
      content: "hej igen",
      sentAt: FIXTURE_SENT_AT,
      status: "sent",
      metadata: null,
    });
    // A row belonging to someone else, so the "cannot write another's row"
    // tests are not vacuously about a missing document.
    await db
      .doc(`messages/${POLL_MSG_ID}/poll_votes/${OTHER_MEMBER_UID}`)
      .set(voteBody(OTHER_MEMBER_UID));
    // BUT-1917: mirrors are CLEARED, not just re-written. `seed()` runs before
    // every test so that one test's writes cannot decide another's outcome, and
    // a mirror is the one fixture that DENIES — so a leftover from a block test
    // would silently deny every later vote, and the failure would read as a
    // broken rule rather than a dirty fixture. It cost exactly that once.
    for (const uid of [AUTHOR_UID, VOTER_UID, OTHER_MEMBER_UID]) {
      await db.doc(`users/${uid}/block_mirror/current`).delete();
    }
  });
}

async function setup(): Promise<void> {
  const rules = fs.readFileSync(RULES_PATH, "utf8");
  env = await initializeTestEnvironment({
    projectId: PROJECT_ID,
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
// POLL VOTES — the write the old rule denied
// ============================================================================

// ----------------------------------------------------------------------------
// BUT-1917 — the block gate. `notBlockedByAnyoneHere()` on create and update.
//
// The mirror is what makes this expressible at all: rules cannot iterate a
// participant list, and a per-counterparty check would cost N document accesses
// against a hard cap of 10, where exceeding the cap DENIES. So the voter's own
// `users/{uid}/block_mirror/current` is crossed against the conversation's
// participants in one `hasAny`.
//
// Every case below writes through the REAL production path (the voter's own
// row, a valid body, an open poll) so a deny can only come from the block
// conjunct. A deny test that also violated membership or shape would pass for
// the wrong reason, and `PERMISSION_DENIED` names a rule line, not a reason.
// ----------------------------------------------------------------------------

/** Give `uid` a mirror naming `blockers`. Server-written in production. */
async function seedMirror(
  uid: string,
  blockers: string[],
  overrides: Record<string, unknown> = {}
): Promise<void> {
  await env.withSecurityRulesDisabled(async (ctx) => {
    await ctx
      .firestore()
      .doc(`users/${uid}/block_mirror/current`)
      // All FOUR fields `sync-block-mirror.ts` writes, `updatedAt` included.
      // The rule reads one of them today, so the rest are inert — but the
      // natural next conjunct is a freshness test on `updatedAt`, and a
      // fixture missing it would leave every case below blind to that change.
      .set({
        blockedByUserIds: blockers,
        sourceRev: 1,
        truncated: false,
        updatedAt: new Date("2026-09-05T00:00:00Z"),
        ...overrides,
      });
  });
}

async function clearMirror(uid: string): Promise<void> {
  await env.withSecurityRulesDisabled(async (ctx) => {
    await ctx.firestore().doc(`users/${uid}/block_mirror/current`).delete();
  });
}

// B1: DENY — the whole point. A participant blocked the voter, so the vote is
// refused even though they are a member and the poll is open.
//
// The blocker here is OTHER_MEMBER_UID, who did NOT send the poll. That is
// deliberate: it is the case that kills the cheaper, wrong implementation which
// only checks the message's author.
test("poll_votes: a voter blocked by a NON-AUTHOR participant cannot vote", async () => {
  await seedMirror(VOTER_UID, [OTHER_MEMBER_UID]);
  // `clearFirestore()` runs ONCE for the file, so an allow declared above this
  // one leaves a row at this path and turns the write below into an UPDATE.
  // The limb would change silently and the deny would still pass, so the
  // absence is asserted rather than assumed: this case is the create limb's
  // only kill, measured.
  await env.withSecurityRulesDisabled(async (ctx) => {
    const existing = await ctx
      .firestore()
      .doc(`messages/${POLL_MSG_ID}/poll_votes/${VOTER_UID}`)
      .get();
    if (existing.exists) {
      throw new Error(
        "B1 must exercise CREATE: a row already exists at its path, so an " +
          "allow above it wrote one. Give B1 its own message id."
      );
    }
  });
  const ctx = env.authenticatedContext(VOTER_UID);
  await assertFails(
    ctx
      .firestore()
      .doc(`messages/${POLL_MSG_ID}/poll_votes/${VOTER_UID}`)
      .set(voteBody(VOTER_UID))
  );
});

// B2: ALLOW — the fail-open control, and B1's single-variable pair. Same voter,
// same room, same body; only the mirror is gone. Without this, B1 could be
// denying for any reason at all.
test("poll_votes: a voter with NO mirror votes normally", async () => {
  await clearMirror(VOTER_UID);
  const ctx = env.authenticatedContext(VOTER_UID);
  await assertSucceeds(
    ctx
      .firestore()
      .doc(`messages/${POLL_MSG_ID}/poll_votes/${VOTER_UID}`)
      .set(voteBody(VOTER_UID))
  );
});

// B3: ALLOW — an EMPTY mirror is not a missing one. This is the state an
// unblock leaves behind, and it must not deny.
test("poll_votes: an empty mirror does not block anyone", async () => {
  await seedMirror(VOTER_UID, []);
  const ctx = env.authenticatedContext(VOTER_UID);
  await assertSucceeds(
    ctx
      .firestore()
      .doc(`messages/${POLL_MSG_ID}/poll_votes/${VOTER_UID}`)
      .set(voteBody(VOTER_UID))
  );
});

// B4: ALLOW — a mirror naming somebody who is NOT in this conversation. The
// gate is per-room, not global: being blocked by a stranger must not silence
// the voter everywhere.
test("poll_votes: a blocker outside this conversation does not block", async () => {
  await seedMirror(VOTER_UID, ["pv-outsider-uid"]);
  const ctx = env.authenticatedContext(VOTER_UID);
  await assertSucceeds(
    ctx
      .firestore()
      .doc(`messages/${POLL_MSG_ID}/poll_votes/${VOTER_UID}`)
      .set(voteBody(VOTER_UID))
  );
});

// B5: ALLOW — the direction. The BLOCKER keeps voting normally; only the
// blocked person is refused. A symmetric rule would punish the person who used
// the safety feature, and no assertion about B1 alone would catch that.
test("poll_votes: the BLOCKER is not silenced by their own block", async () => {
  await seedMirror(VOTER_UID, [OTHER_MEMBER_UID]);
  await clearMirror(OTHER_MEMBER_UID);
  const ctx = env.authenticatedContext(OTHER_MEMBER_UID);
  await assertSucceeds(
    ctx
      .firestore()
      .doc(`messages/${POLL_MSG_ID}/poll_votes/${OTHER_MEMBER_UID}`)
      .set(voteBody(OTHER_MEMBER_UID))
  );
});

// B6: DENY — UPDATE carries the gate too. The panel asked what happens to a
// vote cast BEFORE the block: the row survives, because rules are not
// retroactive, but the blocked voter can no longer STEER it. Without the
// conjunct on update, create would refuse a new row while update let them keep
// changing the old one.
test("poll_votes: a blocked voter cannot change a vote cast before the block", async () => {
  await env.withSecurityRulesDisabled(async (ctx) => {
    await ctx
      .firestore()
      .doc(`messages/${POLL_MSG_ID}/poll_votes/${VOTER_UID}`)
      .set(voteBody(VOTER_UID));
  });
  await seedMirror(VOTER_UID, [OTHER_MEMBER_UID]);
  const ctx = env.authenticatedContext(VOTER_UID);
  await assertFails(
    ctx
      .firestore()
      .doc(`messages/${POLL_MSG_ID}/poll_votes/${VOTER_UID}`)
      .set(voteBody(VOTER_UID))
  );
});

// B7: ALLOW — Art. 17 survives the gate. A blocked voter may still DELETE their
// own row; erasure of your own personal data cannot depend on whether somebody
// else blocked you.
test("poll_votes: a blocked voter can still delete their own vote", async () => {
  await env.withSecurityRulesDisabled(async (ctx) => {
    await ctx
      .firestore()
      .doc(`messages/${POLL_MSG_ID}/poll_votes/${VOTER_UID}`)
      .set(voteBody(VOTER_UID));
  });
  await seedMirror(VOTER_UID, [OTHER_MEMBER_UID]);
  const ctx = env.authenticatedContext(VOTER_UID);
  await assertSucceeds(
    ctx
      .firestore()
      .doc(`messages/${POLL_MSG_ID}/poll_votes/${VOTER_UID}`)
      .delete()
  );
});

// B8: ALLOW — reading the tally is NOT block-gated, deliberately. Hiding it
// would tell the blocked person that a block exists, turning a silent control
// into a notification.
test("poll_votes: a blocked voter can still READ the tally", async () => {
  await seedMirror(VOTER_UID, [OTHER_MEMBER_UID]);
  const ctx = env.authenticatedContext(VOTER_UID);
  await assertSucceeds(
    ctx.firestore().collection(`messages/${POLL_MSG_ID}/poll_votes`).get()
  );
});

// B9: DENY — nobody may write the mirror, INCLUDING its owner. The control is
// forgeable otherwise: the blocked user could empty their own mirror and vote.
test("block_mirror: the owner cannot write their own mirror", async () => {
  const ctx = env.authenticatedContext(VOTER_UID);
  await assertFails(
    ctx
      .firestore()
      .doc(`users/${VOTER_UID}/block_mirror/current`)
      .set({ blockedByUserIds: [], sourceRev: 2, truncated: false })
  );
});

// B10: DENY — nor READ it. It is the list of who blocked them, so a client read
// would disclose exactly what blocking exists to withhold.
test("block_mirror: the owner cannot read their own mirror", async () => {
  await seedMirror(VOTER_UID, [OTHER_MEMBER_UID]);
  const ctx = env.authenticatedContext(VOTER_UID);
  await assertFails(
    ctx.firestore().doc(`users/${VOTER_UID}/block_mirror/current`).get()
  );
});


// B11: ALLOW — the TRUNCATED mirror under-blocks, and that is today's decided
// behaviour rather than an oversight.
//
// `sync-block-mirror.ts` caps the list at `MAX_MIRROR_ENTRIES` and stamps
// `truncated: true`; `notBlockedByAnyoneHere()` never reads the flag. So a
// blocker who fell off the end stops being enforced. The alternative — deny
// while truncated — would refuse every vote from anyone blocked by that many
// people, which is why it was not chosen.
//
// Pinned GREEN deliberately, in the "known gap" style the rest of this file
// uses: the day somebody adds the `truncated` conjunct, this test reddens and
// tells them the decision they are reversing.
test("poll_votes: a TRUNCATED mirror does not block a voter it omits", async () => {
  await seedMirror(VOTER_UID, [], { truncated: true });
  const ctx = env.authenticatedContext(VOTER_UID);
  await assertSucceeds(
    ctx
      .firestore()
      .doc(`messages/${POLL_MSG_ID}/poll_votes/${VOTER_UID}`)
      .set(voteBody(VOTER_UID))
  );
});

// B12: DENY — a mirror whose list is not a list refuses the vote.
//
// Fail-CLOSED, and silently: such a mirror stops that user voting in every
// room, everywhere, with no signal. No writer emits this shape today — the
// trigger always writes an array — so this pins the behaviour rather than a
// live path, and it is the case a future writer that spells "empty" as `null`
// would land on.
test("poll_votes: a malformed mirror refuses the vote", async () => {
  await seedMirror(VOTER_UID, [], { blockedByUserIds: "not-a-list" });
  const ctx = env.authenticatedContext(VOTER_UID);
  await assertFails(
    ctx
      .firestore()
      .doc(`messages/${POLL_MSG_ID}/poll_votes/${VOTER_UID}`)
      .set(voteBody(VOTER_UID))
  );
});

// B14: ALLOW — a mirror that EXISTS but carries no `blockedByUserIds` key.
//
// `.data.get('blockedByUserIds', [])` defaults it, so this fails OPEN — the
// same direction as a missing mirror, and a different one from B12's malformed
// value, which denies. No writer produces this today: the trigger always writes
// the array. It is the shape a future writer that omits the field when empty
// would produce.
test("poll_votes: a mirror with no list key does not block", async () => {
  await env.withSecurityRulesDisabled(async (ctx) => {
    await ctx
      .firestore()
      .doc(`users/${VOTER_UID}/block_mirror/current`)
      .set({ sourceRev: 1, truncated: false });
  });
  const ctx = env.authenticatedContext(VOTER_UID);
  await assertSucceeds(
    ctx
      .firestore()
      .doc(`messages/${POLL_MSG_ID}/poll_votes/${VOTER_UID}`)
      .set(voteBody(VOTER_UID))
  );
});

// B13: ALLOW — B6's exact single-variable control.
//
// B6 denies an UPDATE that re-sends a byte-identical body under a mirror. The
// nearest existing allow (V13) changes the option ids as well, so it differs
// from B6 in two variables. This one differs in exactly one: no mirror.
test("poll_votes: the same update with NO mirror is allowed", async () => {
  await env.withSecurityRulesDisabled(async (ctx) => {
    await ctx
      .firestore()
      .doc(`messages/${POLL_MSG_ID}/poll_votes/${VOTER_UID}`)
      .set(voteBody(VOTER_UID));
  });
  await clearMirror(VOTER_UID);
  const ctx = env.authenticatedContext(VOTER_UID);
  await assertSucceeds(
    ctx
      .firestore()
      .doc(`messages/${POLL_MSG_ID}/poll_votes/${VOTER_UID}`)
      .set(voteBody(VOTER_UID))
  );
});

// V1: ALLOW — the regression this ticket exists for. A participant who did NOT
// send the poll casts a vote.
test("poll_votes: a participant who is not the author can vote", async () => {
  const ctx = env.authenticatedContext(VOTER_UID);
  await assertSucceeds(
    ctx
      .firestore()
      .doc(`messages/${POLL_MSG_ID}/poll_votes/${VOTER_UID}`)
      .set(voteBody(VOTER_UID))
  );
});

// V2: ALLOW — the author too. The fix must not invert the bug.
test("poll_votes: the poll author can also vote", async () => {
  const ctx = env.authenticatedContext(AUTHOR_UID);
  await assertSucceeds(
    ctx
      .firestore()
      .doc(`messages/${POLL_MSG_ID}/poll_votes/${AUTHOR_UID}`)
      .set(voteBody(AUTHOR_UID))
  );
});

// V3: DENY — the constraint the path exists to express. A member of the
// conversation writing into somebody ELSE's row is the "rewrite other people's
// votes" case that no inline-array rule could have refused.
test("poll_votes: a participant cannot write another member's row", async () => {
  const ctx = env.authenticatedContext(VOTER_UID);
  await assertFails(
    ctx
      .firestore()
      .doc(`messages/${POLL_MSG_ID}/poll_votes/${OTHER_MEMBER_UID}`)
      .set(voteBody(OTHER_MEMBER_UID))
  );
});

// V4: DENY — the doc id says one uid, the field says another. Both are checked,
// because the id is what the rule can constrain and the field is what the Art.
// 17 sweep can query; letting them disagree makes a vote unerasable.
test("poll_votes: voterId must match the document id", async () => {
  const ctx = env.authenticatedContext(VOTER_UID);
  await assertFails(
    ctx
      .firestore()
      .doc(`messages/${POLL_MSG_ID}/poll_votes/${VOTER_UID}`)
      .set(voteBody(OTHER_MEMBER_UID))
  );
});

// V5: DENY — outside the conversation. The gate is the conversation's roster,
// one document further out, exactly as for reading the message.
test("poll_votes: a stranger to the conversation cannot vote", async () => {
  const ctx = env.authenticatedContext(STRANGER_UID);
  await assertFails(
    ctx
      .firestore()
      .doc(`messages/${POLL_MSG_ID}/poll_votes/${STRANGER_UID}`)
      .set(voteBody(STRANGER_UID))
  );
});

// V6: DENY — unauthenticated.
test("poll_votes: an unauthenticated caller cannot vote", async () => {
  const ctx = env.unauthenticatedContext();
  await assertFails(
    ctx
      .firestore()
      .doc(`messages/${POLL_MSG_ID}/poll_votes/${VOTER_UID}`)
      .set(voteBody(VOTER_UID))
  );
});

// V7: DENY — the poll is closed. Paired with V1 on the same rule: without V1
// this would pass for the wrong reason (everything denied).
test("poll_votes: no new vote once the poll is closed", async () => {
  const ctx = env.authenticatedContext(VOTER_UID);
  await assertFails(
    ctx
      .firestore()
      .doc(`messages/${CLOSED_POLL_MSG_ID}/poll_votes/${VOTER_UID}`)
      .set(voteBody(VOTER_UID))
  );
});

// V8: ALLOW — un-voting survives the close. The row is the voter's own personal
// data; Art. 17 erasure must not depend on somebody else pressing "avsluta".
test("poll_votes: the voter can delete their own row on a CLOSED poll", async () => {
  await env.withSecurityRulesDisabled(async (ctx) => {
    await ctx
      .firestore()
      .doc(`messages/${CLOSED_POLL_MSG_ID}/poll_votes/${VOTER_UID}`)
      .set(voteBody(VOTER_UID));
  });
  const ctx = env.authenticatedContext(VOTER_UID);
  await assertSucceeds(
    ctx
      .firestore()
      .doc(`messages/${CLOSED_POLL_MSG_ID}/poll_votes/${VOTER_UID}`)
      .delete()
  );
});

// V9: DENY — deleting somebody else's vote.
test("poll_votes: a participant cannot delete another member's row", async () => {
  const ctx = env.authenticatedContext(VOTER_UID);
  await assertFails(
    ctx
      .firestore()
      .doc(`messages/${POLL_MSG_ID}/poll_votes/${OTHER_MEMBER_UID}`)
      .delete()
  );
});

// V3b: DENY — seating a vote for a member who has not voted yet. This pins the
// CREATE limb of `request.auth.uid == voterId`, which nothing else did: V3 aims
// at `OTHER_MEMBER_UID`, whose row `seed()` pre-writes, so it lands on UPDATE.
// Dropping the uid check from the create limb alone left the whole suite green
// (mutation-proved, BUT-1801 review 2026-08-17) — and the regression it hides is
// forged votes for any member who has not voted, i.e. the ballot-stuffing this
// subcollection shape was chosen to make impossible.
// Every conjunct except the one under test is deliberately satisfied, so a deny
// can only come from the create limb's uid check:
//   · `SEAT_POLL_MSG_ID` is an OPEN poll — `CLOSED_POLL_MSG_ID` would deny via
//     `pollIsOpen()` and the test would pass for the wrong reason;
//   · it holds NO vote rows, so this is a CREATE, not an update — the whole
//     point, since the UPDATE limb carries its own `request.auth.uid == voterId`
//     and would mask a removal from the create limb. (`isValidVote()` does NOT
//     check `request.auth.uid` at all; it compares the payload's `voterId` to
//     the path segment. An earlier version of this comment blamed the wrong
//     masker.);
//   · AUTHOR_UID is in `participantIds`, so `inPollConversation()` passes;
//   · the payload names AUTHOR_UID as `voterId`, matching the document id, so
//     `isValidVote()` passes too.
// What is left is `request.auth.uid == voterId`, and the caller is VOTER_UID.
test("poll_votes: a participant cannot SEAT a row for a member who has not voted", async () => {
  // Self-checking: create-ness is the whole premise, and today it rests on the
  // convention that no other test writes here. If a future test seeds a row
  // under this fixture, the write below becomes an UPDATE and would still pass
  // — silently testing the wrong limb. Assert the premise instead of trusting it.
  await env.withSecurityRulesDisabled(async (admin) => {
    const snap = await admin
      .firestore()
      .doc(`messages/${SEAT_POLL_MSG_ID}/poll_votes/${AUTHOR_UID}`)
      .get();
    if (snap.exists) {
      throw new Error(
        "fixture broken: SEAT_POLL_MSG_ID must hold no vote row, or this test " +
          "lands on the UPDATE limb and stops pinning CREATE"
      );
    }
  });

  const ctx = env.authenticatedContext(VOTER_UID);
  await assertFails(
    ctx
      .firestore()
      .doc(`messages/${SEAT_POLL_MSG_ID}/poll_votes/${AUTHOR_UID}`)
      .set(voteBody(AUTHOR_UID))
  );
});

// V10: DENY — an extra key. `hasOnly` is an ALLOW-list here on purpose: without
// it a voter could stamp arbitrary fields onto a row every other participant
// reads.
test("poll_votes: an unexpected key is refused", async () => {
  const ctx = env.authenticatedContext(VOTER_UID);
  await assertFails(
    ctx
      .firestore()
      .doc(`messages/${POLL_MSG_ID}/poll_votes/${VOTER_UID}`)
      .set(voteBody(VOTER_UID, { note: "<script>" }))
  );
});

// V10b: DENY — `optionIds` of the wrong TYPE. The `is list` conjunct had no
// coverage: removing it left the suite green. Independent of the size cap below,
// not redundant with it — a CEL string HAS `.size()`, so with `is list` gone
// `"opt-a".size() == 5 <= 20` passes and the cap catches nothing.
//
// The consequence is on the WRITER, not the reader: `MessageQueryModule`'s
// hydration guards with `if (optionIds is! List) continue;`, but
// `MessageMutationModule` casts `as List<dynamic>?` and throws.
test("poll_votes: optionIds must be a list", async () => {
  const ctx = env.authenticatedContext(VOTER_UID);
  await assertFails(
    ctx
      .firestore()
      .doc(`messages/${POLL_MSG_ID}/poll_votes/${VOTER_UID}`)
      .set({
        voterId: VOTER_UID,
        optionIds: "opt-a",
        votedAt: FIXTURE_SENT_AT,
      })
  );
});

// V10c: DENY — past the size cap. Nothing pinned it: dropping
// `optionIds.size() <= 20` left the suite green. The cap is what stops one row
// carrying an unbounded array into every participant's tally render.
test("poll_votes: optionIds past the size cap is refused", async () => {
  const ctx = env.authenticatedContext(VOTER_UID);
  await assertFails(
    ctx
      .firestore()
      .doc(`messages/${POLL_MSG_ID}/poll_votes/${VOTER_UID}`)
      .set({
        voterId: VOTER_UID,
        optionIds: Array.from({ length: 21 }, (_, i) => `opt-${i}`),
        votedAt: FIXTURE_SENT_AT,
      })
  );
});

// V10d: DENY — a vote on the shape production really writes, `metadata: null`.
//
// This is the BUT-1788 trap, unmoved: `pollIsOpen()` uses the naive
// `.get('metadata', {}).get('poll', {})` chain, and `.get` on a key that is
// PRESENT-BUT-NULL returns null, so the next `.get` is a CEL evaluation error
// and the statement denies. The deny is right; the reason is an accident.
//
// Pinned anyway, and it stays green under the `is map ? ... : null` spelling of
// the owed repair (measured): null is not a map, the branch yields null, and
// `== false` is still false. It DOES redden under `is map ? ... : {}`, which
// flips null to ALLOW. That asymmetry is the point — the else branch is the
// security decision, and this test is what forces whoever lands the repair to
// choose it deliberately rather than by reflex.
test("poll_votes: a vote on a message whose metadata is null is refused", async () => {
  const ctx = env.authenticatedContext(VOTER_UID);
  await assertFails(
    ctx
      .firestore()
      .doc(`messages/${NULL_META_MSG_ID}/poll_votes/${VOTER_UID}`)
      .set(voteBody(VOTER_UID))
  );
});

// V10e / V10f: ALLOW — and these document a GAP, not a guarantee.
//
// `pollIsOpen()`'s default cascade (`{}` → `{}` → `false`) reads "open" on a
// message that is not a poll, so a vote is accepted and a junk `poll_votes` row
// lands on it. Two live shapes reach that, and they are pinned separately
// because they fail differently under the owed repair:
//
//   V10e — `metadata` key ABSENT.
//   V10f — `metadata` a MAP with no `poll` key. THIS is the common one:
//          `Message.recipeShare` / `menuShare` / `shoppingListShare` all write
//          it, so every share card in every chat is votable today. An `is map`
//          guard does NOT close it — a map without the key is still a map — so a
//          repair written from the null case alone would leave this open while
//          looking finished.
//
// Contrast V10d: `metadata: null` DENIES, via a CEL error. Four states, three
// answers; covering one hides the others.
//
// Asserted as ALLOW deliberately, to pin today's behaviour rather than pretend
// it is closed. Harm is low: the row carries the caller's own uid, reading the
// tally is membership-gated, `isValidVote()` bounds it to three keys and ≤20
// ids, and `deletePollVotes` erases it by collection group wherever it sits.
//
// What these tests do NOT do is force the repair. Measured against three
// candidate spellings (naming which tests move, never a suite total — a count
// goes stale the moment anyone adds a test):
//   · `is map ? … : null`  — nothing reddens. The gap stays open, silently.
//   · `is map ? … : {}`    — V10d reddens. That spelling flips null to ALLOW.
//   · `is map && 'poll' in metadata && …` (the real repair) — V10e and V10f
//     redden, and nothing else does.
// So a green pair here IS the signal that the gap is still open; only a repair
// that actually closes it turns these red, one line each.
test("poll_votes: a message with NO metadata key still accepts a vote (known gap)", async () => {
  const ctx = env.authenticatedContext(VOTER_UID);
  await assertSucceeds(
    ctx
      .firestore()
      .doc(`messages/${TEXT_MSG_ID}/poll_votes/${VOTER_UID}`)
      .set(voteBody(VOTER_UID))
  );
});

test("poll_votes: a shared-recipe card still accepts a vote (known gap, live shape)", async () => {
  const ctx = env.authenticatedContext(VOTER_UID);
  await assertSucceeds(
    ctx
      .firestore()
      .doc(`messages/${SHARE_META_MSG_ID}/poll_votes/${VOTER_UID}`)
      .set(voteBody(VOTER_UID))
  );
});

// V11: ALLOW — the tally read. Every participant must see it; this is what the
// repository folds back into `metadata.poll.options[].voterIds` for display.
test("poll_votes: a participant can read the whole tally", async () => {
  const ctx = env.authenticatedContext(VOTER_UID);
  const snap = await assertSucceeds(
    ctx.firestore().collection(`messages/${POLL_MSG_ID}/poll_votes`).get()
  );
  if (snap.empty) throw new Error("expected the seeded vote — fixture broken");
});

// V12: DENY — a stranger reads the tally. The rows carry uids.
test("poll_votes: a stranger cannot read the tally", async () => {
  const ctx = env.authenticatedContext(STRANGER_UID);
  await assertFails(
    ctx.firestore().collection(`messages/${POLL_MSG_ID}/poll_votes`).get()
  );
});

// V13: ALLOW — changing an existing vote. This is the `allow update` branch,
// and it is the live path for every vote after a voter's first one:
// `MessageMutationModule.votePoll` runs `transaction.set` on the voter's own
// row, so toggling an option, switching choice and re-voting all arrive as
// updates. Without this the branch had no allow coverage at all — an
// `allow update: if false` regression left the suite green while voting broke
// for everyone who had already voted once.
//
// The row is seeded here rather than relied on from V1: `run()` re-seeds
// before every test but never clears, so leaning on a neighbour's write would
// make this test's meaning depend on declaration order.
test("poll_votes: a voter can change their own existing vote", async () => {
  await env.withSecurityRulesDisabled(async (ctx) => {
    await ctx
      .firestore()
      .doc(`messages/${POLL_MSG_ID}/poll_votes/${VOTER_UID}`)
      .set(voteBody(VOTER_UID));
  });
  const ctx = env.authenticatedContext(VOTER_UID);
  await assertSucceeds(
    ctx
      .firestore()
      .doc(`messages/${POLL_MSG_ID}/poll_votes/${VOTER_UID}`)
      .set(voteBody(VOTER_UID, { optionIds: ["opt-b"] }))
  );
});

// V14: DENY — the update branch is not a way round the closed-poll gate. Pairs
// with V13 the way V7 pairs with V1: without V13 this would pass because
// everything was denied.
test("poll_votes: an existing vote cannot be changed once the poll is closed", async () => {
  await env.withSecurityRulesDisabled(async (ctx) => {
    await ctx
      .firestore()
      .doc(`messages/${CLOSED_POLL_MSG_ID}/poll_votes/${VOTER_UID}`)
      .set(voteBody(VOTER_UID));
  });
  const ctx = env.authenticatedContext(VOTER_UID);
  await assertFails(
    ctx
      .firestore()
      .doc(`messages/${CLOSED_POLL_MSG_ID}/poll_votes/${VOTER_UID}`)
      .set(voteBody(VOTER_UID, { optionIds: ["opt-b"] }))
  );
});

// ============================================================================
// MESSAGE RECEIPTS — same rule, same trap
// ============================================================================

// R1: ALLOW — `markMessageAsRead`, performed by the RECIPIENT. Denied before
// this change, for every message anyone else sent.
test("messages: a recipient can stamp a read receipt", async () => {
  const ctx = env.authenticatedContext(VOTER_UID);
  await assertSucceeds(
    ctx.firestore().doc(`messages/${TEXT_MSG_ID}`).update({
      status: "read",
      readAt: new Date(),
      updatedAt: new Date(),
    })
  );
});

// R2: ALLOW — `batchMarkAsDelivered`, same shape, the other key.
test("messages: a recipient can stamp a delivery receipt", async () => {
  const ctx = env.authenticatedContext(VOTER_UID);
  await assertSucceeds(
    ctx.firestore().doc(`messages/${TEXT_MSG_ID}`).update({
      status: "delivered",
      deliveredAt: new Date(),
      updatedAt: new Date(),
    })
  );
});

// R3: DENY — the receipt branch is not a general write grant. This is what the
// `affectedKeys().hasOnly` scope buys, and what an `||` into the sender branch
// would have given away.
test("messages: a recipient cannot edit the content under cover of a receipt", async () => {
  const ctx = env.authenticatedContext(VOTER_UID);
  await assertFails(
    ctx.firestore().doc(`messages/${TEXT_MSG_ID}`).update({
      status: "read",
      readAt: new Date(),
      updatedAt: new Date(),
      content: "något helt annat",
    })
  );
});

// R3b: DENY — `metadata` under cover of a receipt. R3 above pins `content`, and
// only `content`: widening the receipt allow-list to `[..., 'metadata']` left
// this whole suite green (mutation-proved, BUT-1801 review 2026-08-17). Granting
// it would hand every participant the poll question, `isClosed`, and
// `metadata.poll.options[].voterIds` — the inline vote store this ticket exists
// to abandon.
//
// Still UNCOVERED, and worth a test the day anyone touches this list:
// `MessageDto.toFirestore` also emits a top-level `reactions` key, which appears
// nowhere in `firestore.rules`. A "let participants react" ticket would widen the
// allow-list with `'reactions'`, not `'metadata'` — so that is the plausible
// widening this test does NOT catch.
test("messages: a recipient cannot rewrite metadata under cover of a receipt", async () => {
  const ctx = env.authenticatedContext(VOTER_UID);
  await assertFails(
    ctx
      .firestore()
      .doc(`messages/${POLL_MSG_ID}`)
      .update({
        status: "read",
        readAt: new Date(),
        updatedAt: new Date(),
        metadata: {
          poll: {
            id: `p-${RUN}`,
            question: "Vad ska vi äta?",
            creatorId: VOTER_UID,
            isClosed: true,
            options: [
              { id: "opt-a", text: "Tacos", voterIds: [VOTER_UID] },
              { id: "opt-b", text: "Pasta", voterIds: [] },
            ],
          },
        },
      })
  );
});

// R4: DENY — a stranger cannot stamp a receipt. The branch is gated on the
// conversation roster, not merely on being signed in.
test("messages: a stranger cannot stamp a receipt", async () => {
  const ctx = env.authenticatedContext(STRANGER_UID);
  await assertFails(
    ctx.firestore().doc(`messages/${TEXT_MSG_ID}`).update({
      status: "read",
      readAt: new Date(),
      updatedAt: new Date(),
    })
  );
});

// R5: ALLOW — the sender branch is untouched. Pairs with R3: the two grants are
// different sizes, and this proves the split did not shrink the larger one.
test("messages: the sender can still edit their own content", async () => {
  const ctx = env.authenticatedContext(AUTHOR_UID);
  await assertSucceeds(
    ctx.firestore().doc(`messages/${TEXT_MSG_ID}`).update({
      content: "hej igen",
      isEdited: true,
      updatedAt: new Date(),
    })
  );
});

// R6: DENY — a recipient still cannot edit content the ordinary way, which is
// the grant the sender branch holds and the receipt branch does not.
test("messages: a recipient cannot edit content", async () => {
  const ctx = env.authenticatedContext(VOTER_UID);
  await assertFails(
    ctx
      .firestore()
      .doc(`messages/${TEXT_MSG_ID}`)
      .update({ content: "kapad", updatedAt: new Date() })
  );
});

// ============================================================================
// SHARED CONTENT — the create shape BUT-1812 relies on
// ============================================================================

// S1: ALLOW — a share row with an auto-id. Each share is now its own document
// rather than one keyed on the recipeId, so re-sharing can never collide with a
// row another user owns (which `allow get`/`allow update` both refuse, so no
// payload could rescue it).
test("shared_content: a sharer can create a row naming its recipients", async () => {
  const ctx = env.authenticatedContext(AUTHOR_UID);
  await assertSucceeds(
    ctx.firestore().collection("shared_content").add({
      contentType: "recipe",
      recipeId: `r-${RUN}`,
      title: "Köttbullar",
      sharedByUserId: AUTHOR_UID,
      sharedToUserIds: [AUTHOR_UID, VOTER_UID],
      sharedAt: new Date(),
      isActive: true,
    })
  );
});

// S2: DENY — no `sharedToUserIds`. That field is the only membership this
// collection can be QUERIED on: `allow list` reads it and nothing else, and so
// do the group shared-content feed, the GDPR export and the Art. 17 scrub. A
// row without it is reachable only by whoever already knows its id — the same
// silent loss BUT-1812 produced, reached from the other direction.
test("shared_content: a row with no sharedToUserIds is refused", async () => {
  const ctx = env.authenticatedContext(AUTHOR_UID);
  await assertFails(
    ctx.firestore().collection("shared_content").add({
      contentType: "recipe",
      recipeId: `r2-${RUN}`,
      sharedByUserId: AUTHOR_UID,
      sharedAt: new Date(),
      isActive: true,
    })
  );
});

// S3: DENY — claiming to be somebody else's share.
test("shared_content: sharedByUserId must be the caller", async () => {
  const ctx = env.authenticatedContext(VOTER_UID);
  await assertFails(
    ctx.firestore().collection("shared_content").add({
      contentType: "recipe",
      recipeId: `r3-${RUN}`,
      sharedByUserId: AUTHOR_UID,
      sharedToUserIds: [AUTHOR_UID, VOTER_UID],
      sharedAt: new Date(),
      isActive: true,
    })
  );
});

// S4 / S5: ALLOW — the MENU and SHOPPING-LIST creates, sent with the key set
// their models really produce (`getCommonFirestoreFields` +
// `getCopyOnWriteFirestoreFields` + the type's own fields), plus the two keys
// the repository layer stamps on top (`contentType` and `sharedToUserIds`).
//
// S1 covers recipes, and a recipe-only allow test is what let the required-field
// tightening ship while denying two of the three live writers: neither model's
// `toFirestore` emits `sharedToUserIds`, and the menu and shopping-list
// repositories pass no initial list, so every menu and shopping-list share was
// refused. The stamp now lives in `BaseSharedContentRepository
// .createSharedContent` — one place, all three types. These two tests are the
// shape that stamp has to keep producing; if either starts failing, the rule and
// the writer have drifted apart again.
function menuSharePayload(): Record<string, unknown> {
  return {
    // BaseSharedContentRepository.createSharedContent
    contentType: "menu",
    sharedToUserIds: [AUTHOR_UID],
    // getCommonFirestoreFields()
    sharedByUserId: AUTHOR_UID,
    sharedByDisplayName: "Malin i appen",
    sharedAt: FIXTURE_SENT_AT,
    shareMessage: null,
    viewCount: 0,
    engagementCount: 0,
    dismissalCount: 0,
    // getCopyOnWriteFirestoreFields()
    isOriginalReference: true,
    copyOnWriteTriggered: false,
    originalOwnerStaticCopyId: null,
    activeCollaboratorCount: 0,
    // SharedMenu.toFirestore()
    menuTitle: "Veckans meny",
    menuSnapshot: {},
    totalRecipeCount: 0,
    categories: [],
    allowCollaboration: false,
    schemaVersion: 1,
  };
}

test("shared_content: a menu share with its real payload is allowed", async () => {
  const ctx = env.authenticatedContext(AUTHOR_UID);
  await assertSucceeds(
    ctx.firestore().collection("shared_content").add(menuSharePayload())
  );
});

test("shared_content: a menu share missing the stamped list is refused", async () => {
  const ctx = env.authenticatedContext(AUTHOR_UID);
  const withoutList = menuSharePayload();
  delete withoutList.sharedToUserIds;
  await assertFails(
    ctx.firestore().collection("shared_content").add(withoutList)
  );
});

test("shared_content: a shopping-list share with its real payload is allowed", async () => {
  const ctx = env.authenticatedContext(AUTHOR_UID);
  await assertSucceeds(
    ctx.firestore().collection("shared_content").add({
      // BaseSharedContentRepository.createSharedContent
      contentType: "shopping_list",
      sharedToUserIds: [AUTHOR_UID],
      // getCommonFirestoreFields()
      sharedByUserId: AUTHOR_UID,
      sharedByDisplayName: "Malin i appen",
      sharedAt: FIXTURE_SENT_AT,
      shareMessage: null,
      viewCount: 0,
      engagementCount: 0,
      dismissalCount: 0,
      // getCopyOnWriteFirestoreFields()
      isOriginalReference: true,
      copyOnWriteTriggered: false,
      originalOwnerStaticCopyId: null,
      activeCollaboratorCount: 0,
      // SharedShoppingList.toFirestore()
      listName: "Veckohandling",
      listDescription: null,
      itemCount: 0,
      originalOwnerId: AUTHOR_UID,
      originalOwnerDisplayName: "Malin i appen",
      joinedCount: 0,
    })
  );
});

async function run(): Promise<void> {
  console.log("poll votes + message receipts rules tests (BUT-1832/BUT-1812)\n");
  console.log("========================================\n");
  await setup();
  let failed = 0;
  for (const t of tests) {
    // Every test starts from the same seeded state: the allows genuinely change
    // documents, and a later deny that reads `resource.data` would otherwise be
    // measuring the previous test's write.
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
