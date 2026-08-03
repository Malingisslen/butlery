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

// C6: DENY — a create whose metadata.creatorId is NOT the caller. BUT-1626 binds
// the recorded creator to the caller so the group minor-safety Cloud Function
// (enforceGroupMinorMembership) can trust metadata.creatorId. Without this a
// client could forge creatorId to a friend of a minor (or the minor's own uid)
// and slip a non-friend group add past the CF's friend check. Adult 1:1 target
// so this isolates the creatorId binding, not the minor-DM gate.
test("conversations: cannot create with metadata.creatorId set to another uid", async () => {
  const ctx = env.authenticatedContext(STRANGER_UID);
  await assertFails(
    ctx
      .firestore()
      .doc(`conversations/c-creator-forge-${RUN}`)
      .set(
        convBody([STRANGER_UID, ADULT_UID], {
          metadata: { creatorId: FRIEND_UID },
        })
      )
  );
});

// C7: ALLOW — a create whose metadata.creatorId IS the caller. This is the
// legitimate client shape: Conversation.group()/direct both stamp
// creatorId = self, so the binding never blocks a real create.
test("conversations: can create with metadata.creatorId equal to the caller", async () => {
  const ctx = env.authenticatedContext(STRANGER_UID);
  await assertSucceeds(
    ctx
      .firestore()
      .doc(`conversations/c-creator-self-${RUN}`)
      .set(
        convBody([STRANGER_UID, ADULT_UID], {
          metadata: { creatorId: STRANGER_UID },
        })
      )
  );
});

// ============================================================================
// CONVERSATIONS — metadata.creatorId immutability on UPDATE (BUT-1788)
// ============================================================================
//
// The create binding (C6/C7) is only half the story. `affectedKeys()` is
// TOP-LEVEL, so before this rule conjunct existed the deny list
// ['participantIds','createdAt'] let any participant rewrite `metadata`
// wholesale. Two server functions treat metadata.creatorId as the group admin
// identity — enforceGroupMinorMembership (BUT-1626) and leaveGroupConversation's
// authorizeDeparture — so a self-promotion write was a group-takeover primitive:
// name yourself creator, then call the callable and evict everyone else.

const TAKEOVER_GROUP = `c-creator-immutable-${RUN}`;
const NO_METADATA_GROUP = `c-no-metadata-${RUN}`;
const NULL_METADATA_GROUP = `c-null-metadata-${RUN}`;
// A SECOND absent-metadata document, reserved for the creatorId-injection deny
// (C12A). C11 writes the real DTO payload onto NO_METADATA_GROUP, and that
// payload carries `metadata: null` — after it lands, that doc is no longer in
// the "metadata key absent" state, so reusing it for C12A would silently test
// the null branch twice and never the absent branch.
const NO_METADATA_INJECT_GROUP = `c-no-metadata-inject-${RUN}`;

// `createdAt` is immutable on update, so every fixture and every DTO-shaped
// payload must carry the SAME instant. A re-stamped `new Date()` lands in
// diff().affectedKeys() and denies for a reason that has nothing to do with
// metadata — which reads exactly like a rule defect.
const FIXTURE_CREATED_AT = new Date("2026-01-15T09:00:00.000Z");
const FIXTURE_PARTICIPANTS = [ADULT_UID, STRANGER_UID, FRIEND_UID];

// The payload a real client actually sends, mirroring
// ConversationDto.toFirestore (lib/repositories/firebase/dtos/conversation_dto.dart
// :128-145) key for key, with lastMessage mirroring MessageDto.toMap
// (message_dto.dart:140-165). Every production conversation write goes through
// this map; the message-send path batches it as set(..., merge: true) next to
// the message write, so a deny here kills the message too.
//
// Using it is the whole point: BUT-1788's defect was invisible to a
// hand-written `update({lastMessage: ...})` because that payload simply had no
// `metadata` key, while the DTO emits `'metadata': conversation.metadata`
// unconditionally — i.e. `metadata: null` on every conversation that records
// no creator.
function conversationDtoPayload(
  metadata: unknown,
  extra: Record<string, unknown> = {}
): Record<string, unknown> {
  return {
    participantIds: [...FIXTURE_PARTICIPANTS],
    participantDisplayNames: {
      [ADULT_UID]: "Vuxen",
      [STRANGER_UID]: "Okänd",
      [FRIEND_UID]: "Vän",
    },
    participantAvatarUrls: {
      [ADULT_UID]: null,
      [STRANGER_UID]: null,
      [FRIEND_UID]: null,
    },
    lastMessage: {
      id: `m-${RUN}`,
      conversationId: "",
      senderId: STRANGER_UID,
      senderDisplayName: "Okänd",
      senderAvatarUrl: null,
      content: "hej",
      type: "text",
      status: "sending",
      sentAt: new Date(),
      deliveredAt: null,
      readAt: null,
      metadata: null,
      replyToMessageId: null,
      isEdited: false,
      editedAt: null,
    },
    lastReadTimestamps: { [STRANGER_UID]: new Date() },
    createdAt: FIXTURE_CREATED_AT,
    updatedAt: new Date(),
    title: null,
    isGroup: true,
    metadata,
    ...extra,
  };
}

async function seedUpdateFixtures(): Promise<void> {
  await env.withSecurityRulesDisabled(async (ctx) => {
    const db = ctx.firestore();
    await db.doc(`conversations/${TAKEOVER_GROUP}`).set({
      participantIds: [...FIXTURE_PARTICIPANTS],
      createdAt: FIXTURE_CREATED_AT,
      isGroup: true,
      metadata: { creatorId: ADULT_UID, title: "Middagsgänget" },
    });
    // metadata key ABSENT — a pre-BUT-1626 document.
    await db.doc(`conversations/${NO_METADATA_GROUP}`).set({
      participantIds: [...FIXTURE_PARTICIPANTS],
      createdAt: FIXTURE_CREATED_AT,
      isGroup: true,
    });
    await db.doc(`conversations/${NO_METADATA_INJECT_GROUP}`).set({
      participantIds: [...FIXTURE_PARTICIPANTS],
      createdAt: FIXTURE_CREATED_AT,
      isGroup: true,
    });
    // metadata key PRESENT with value null — the shape the app itself writes
    // (ConversationDto.toFirestore emits the key unconditionally) and the one
    // the pre-fix rule blanket-denied: `.get('metadata', {})` returns the
    // DEFAULT only for an absent key; a present null returns null, and
    // `.get('creatorId', null)` on null is a CEL evaluation error. Absent
    // metadata (above) never exercised that path, which is why the old suite
    // stayed green while message sending was broken in production.
    await db.doc(`conversations/${NULL_METADATA_GROUP}`).set({
      participantIds: [...FIXTURE_PARTICIPANTS],
      createdAt: FIXTURE_CREATED_AT,
      isGroup: true,
      metadata: null,
    });
  });
}

// C8: DENY — a participant promoting themselves to creator. The takeover write.
test("conversations: participant cannot rewrite metadata.creatorId to their own uid", async () => {
  const ctx = env.authenticatedContext(STRANGER_UID);
  await assertFails(
    ctx
      .firestore()
      .doc(`conversations/${TAKEOVER_GROUP}`)
      .update({ metadata: { creatorId: STRANGER_UID, title: "Middagsgänget" } })
  );
});

// C9: DENY — dropping metadata (or just creatorId) is the same attack in
// reverse: a group with no recorded creator, which authorizeDeparture treats as
// "no admin". Proves the guard compares the resolved value, not just presence.
test("conversations: participant cannot delete metadata.creatorId", async () => {
  const ctx = env.authenticatedContext(STRANGER_UID);
  await assertFails(
    ctx
      .firestore()
      .doc(`conversations/${TAKEOVER_GROUP}`)
      .update({ metadata: { title: "Middagsgänget" } })
  );
});

// C10: ALLOW — a normal participant write with creatorId untouched still lands.
// Without this the deny above could be passing for an unrelated reason.
test("conversations: participant can update other fields while creatorId is unchanged", async () => {
  const ctx = env.authenticatedContext(STRANGER_UID);
  await assertSucceeds(
    ctx
      .firestore()
      .doc(`conversations/${TAKEOVER_GROUP}`)
      .update({ lastMessage: { content: "hej", senderId: STRANGER_UID } })
  );
});

// C10B: ALLOW — the real client payload against a document that DOES record a
// creator: the third branch of the ternary (is map true on both sides, equal
// non-null creatorId), and the commonest production write of all — a message
// sent into a group that has a creator. C10 above only proves a one-key
// hand-written update; it cannot catch a rule that trips over a key the DTO
// always sends.
test("conversations: the real ConversationDto payload lands on a conversation that records a creator", async () => {
  const ctx = env.authenticatedContext(STRANGER_UID);
  await assertSucceeds(
    ctx
      .firestore()
      .doc(`conversations/${TAKEOVER_GROUP}`)
      .set(
        conversationDtoPayload({
          creatorId: ADULT_UID,
          title: "Middagsgänget",
        }),
        { merge: true }
      )
  );
});

// C11: ALLOW — a conversation whose metadata key is ABSENT is still updatable
// by the REAL client payload. The guard must not brick pre-BUT-1626 documents.
// Sent as set(..., merge: true) with the full ConversationDto.toFirestore key
// set, exactly as message_mutation_module batches it next to the message write
// — an earlier version of this test used a hand-written {lastMessage} payload
// with no `metadata` key at all, which certified the broken case as working.
test("conversations: a conversation with no metadata is still updatable by the real ConversationDto payload", async () => {
  const ctx = env.authenticatedContext(STRANGER_UID);
  await assertSucceeds(
    ctx
      .firestore()
      .doc(`conversations/${NO_METADATA_GROUP}`)
      .set(conversationDtoPayload(null), { merge: true })
  );
});

// C11B: ALLOW — the production-breaking shape. The stored document has
// `metadata` PRESENT with value null, and the client sends `metadata: null`
// back. This is what every message send does on a conversation that records no
// creator, and it is the case the bare `.get('metadata', {}).get('creatorId',
// null)` spelling turned into a CEL evaluation error (= blanket deny of the
// whole batch, message included). Absent-metadata (C11) does NOT prove this:
// the default branch of `.get()` only fires for a MISSING key.
test("conversations: a conversation whose stored metadata is null is still updatable by the real ConversationDto payload", async () => {
  const ctx = env.authenticatedContext(STRANGER_UID);
  await assertSucceeds(
    ctx
      .firestore()
      .doc(`conversations/${NULL_METADATA_GROUP}`)
      .set(conversationDtoPayload(null), { merge: true })
  );
});

// C12A: DENY — injecting a creatorId onto a document that stored NONE
// (metadata key absent). Resolves to non-null == null. This is the takeover
// against a pre-BUT-1626 group, where authorizeDeparture currently sees no
// admin at all. Uses update(), not a merge-set: merge DEEP-MERGES nested maps,
// so a merge-set can never prove anything about a key's removal or addition
// semantics the way a plain update can.
test("conversations: participant cannot inject metadata.creatorId onto a conversation whose metadata key is absent", async () => {
  const ctx = env.authenticatedContext(STRANGER_UID);
  await assertFails(
    ctx
      .firestore()
      .doc(`conversations/${NO_METADATA_INJECT_GROUP}`)
      .update({ metadata: { creatorId: STRANGER_UID } })
  );
});

// C12B: DENY — the same injection against stored `metadata: null`. A DIFFERENT
// branch of the ternary from C12A: absent hits `.get()`'s default `{}` and then
// `{}.get('creatorId', null)`, while present-null skips the `is map` test
// entirely and short-circuits to the literal null. One does not prove the
// other, and this is the branch a real (DTO-written) document actually lands in.
test("conversations: participant cannot inject metadata.creatorId onto a conversation whose stored metadata is null", async () => {
  const ctx = env.authenticatedContext(STRANGER_UID);
  await assertFails(
    ctx
      .firestore()
      .doc(`conversations/${NULL_METADATA_GROUP}`)
      .update({ metadata: { creatorId: STRANGER_UID } })
  );
});

// C13A: DENY — metadata written as a STRING over a stored creatorId. The
// `is map` test exists so a null/non-map parent cannot CEL-error; it must not
// become a laundering primitive. A non-map request side resolves to null while
// the stored side still resolves to ADULT_UID, so null == 'adult' is false and
// the write dies. If this ever passes, the attacker gets step one of a two-step
// takeover: blank the creator, then claim it.
test("conversations: participant cannot overwrite metadata with a string to blank out creatorId", async () => {
  const ctx = env.authenticatedContext(STRANGER_UID);
  await assertFails(
    ctx
      .firestore()
      .doc(`conversations/${TAKEOVER_GROUP}`)
      .update({ metadata: "creatorId=whatever" })
  );
});

// C13B: DENY — the same laundering attempt with a NUMBER. `is map` is false for
// every non-map type; pinning two distinct types keeps a future rewrite from
// narrowing the check to something like `is string ? ... : ...`.
test("conversations: participant cannot overwrite metadata with a number to blank out creatorId", async () => {
  const ctx = env.authenticatedContext(STRANGER_UID);
  await assertFails(
    ctx
      .firestore()
      .doc(`conversations/${TAKEOVER_GROUP}`)
      .update({ metadata: 42 })
  );
});

// C14: ALLOW — a group RENAME by an ordinary participant, with creatorId
// carried through unchanged.
//
// Read this before "hardening" the rule: ONLY `metadata.creatorId` is pinned.
// The rest of `metadata` — title here, and any future key — stays freely
// mutable by ANY participant, deliberately. Group rename is a normal product
// feature with no creator/admin requirement, so a blanket metadata freeze (or
// a creator-only metadata rule) would break it. This test is the tripwire for
// exactly that regression: every deny in C8–C13B would still pass under a
// blanket freeze, and only this one would go red.
test("conversations: participant can rename the group via metadata.title while creatorId is carried through unchanged", async () => {
  const ctx = env.authenticatedContext(STRANGER_UID);
  await assertSucceeds(
    ctx
      .firestore()
      .doc(`conversations/${TAKEOVER_GROUP}`)
      .update({ metadata: { creatorId: ADULT_UID, title: "Nytt" } })
  );
});

async function run(): Promise<void> {
  console.log("conversations 1:1 minor-DM gate rules tests (BUT-674)\n");
  console.log("========================================\n");
  await setup();
  await seedUpdateFixtures();
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
