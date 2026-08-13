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

// C7B: DENY — a create carrying `metadata: null`, which is the ONLY shape the
// non-creator fallback writer sends, and the shape this whole suite never put
// through the CREATE rule (C1-C5 omit the key, C6/C7 send a map, and every
// `conversationDtoPayload(null)` write is a merge-set onto a seeded document,
// i.e. an update).
//
// It matters far beyond tidiness. `ConversationDto.toFirestore` emits
// `'metadata': conversation.metadata` UNCONDITIONALLY, so a client that builds a
// Conversation without metadata sends the key set to null. The create rule then
// evaluates `!('creatorId' in request.resource.data.metadata)` against null — an
// `in` on a null is a CEL EVALUATION ERROR, which denies. The named equality
// conjunct below it is never reached.
//
// That evaluation error is currently the only thing stopping a NON-CREATOR from
// materialising a group's top-level conversation document THROUGH THE APP. It is
// not a security bound — a hand-rolled create carrying a real metadata map is
// allowed today and ends the window irreversibly (BUT-1830). What it stops is
// our own client: `MessageMutationModule` falls through to a fallback that builds
// `Conversation(participantIds: [senderId], isGroup: false)` with no metadata and
// stages a top-level create. If it landed, `enforceGroupMinorMembership` would
// return early on it — that payload trips BOTH halves of the trigger's guard
// (`isGroup: false` AND a single participant), so do not read the flag alone as
// sufficient: a false flag with >2 participants does not return early — and
// `onDocumentCreated` cannot fire
// twice, so the child-safety cut would never run for that group at all.
//
// The reason this needs a test rather than a comment: the UPDATE rule thirty
// lines below answers the same null-metadata question the OTHER way, with an
// `is map` ternary (pinned by C11B/C12B). Harmonising the two spellings "for
// consistency" is an obvious, well-intentioned edit — and it would disarm the
// trigger. If this test starts failing, that is what happened.
test("conversations: a create carrying metadata: null is denied", async () => {
  const ctx = env.authenticatedContext(STRANGER_UID);
  await assertFails(
    ctx
      .firestore()
      .doc(`conversations/c-meta-null-${RUN}`)
      .set(convBody([STRANGER_UID, ADULT_UID], { metadata: null }))
  );
});

// C7: ALLOW — a create whose metadata.creatorId IS the caller. This is the
// legitimate client shape. `Conversation.group` stamps creatorId = self; the
// direct path does NOT use `Conversation.direct` (which stamps no metadata) —
// `createDirectConversation` builds its Conversation inline with
// `metadata: {'creatorId': user1Id}`. Both LIVE paths carry it, so the binding
// never blocks a real create; the factory named here before did not.
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

// ============================================================================
// CONVERSATION PARTICIPANTS — roster subcollection (BUT-1482 sprint)
// (29 tests: P1-P26 plus P3B, P3C and P12B)
// ============================================================================
//
// `conversations/{id}/participants/{uid}` had NO match block, so every write
// hit default-deny. ConversationParticipantModule writes it in one WriteBatch
// with users/{uid}/conversation_memberships, and addParticipants has no local
// catch — the commit throws up through createDirectConversation /
// createGroupConversation. The flag that gates it, enable_subcollection_
// participants, defaults to TRUE.
//
// The rule cannot simply read the parent conversation on create: for a GROUP,
// the top-level conversations/{id} document does not exist at roster-write time
// (createGroupConversation writes through UserScopedFirebaseRepository, i.e. to
// users/{creatorUid}/conversations/{id} — the BUT-1795 path split). So there are
// two branches, ATTESTED (parent names writer AND subject) and UNCLAIMED (no
// parent yet), and the tests below prove each one separately in both directions.

// Parent EXISTS and names ADULT + FRIEND — the attested branch.
const P_ATT = `p-attested-${RUN}`;
// A LIVE conversation carrying a roster row for someone its participantIds do
// NOT name — the shape enforceGroupMinorMembership leaves behind (P12B).
const P_EVICTED = `p-evicted-${RUN}`;
// No parent document — the unclaimed (group-create bootstrap) branch.
const P_UNC = `p-unclaimed-${RUN}`;
// A second unclaimed roster, reserved for the documented residual (P3B), so it
// cannot interfere with the bootstrap-allow fixture.
const P_UNC_RESIDUAL = `p-unclaimed-residual-${RUN}`;
// No parent, one seeded row for FRIEND — proves the own-row read branch.
const P_READ_FRESH = `p-fresh-read-${RUN}`;
const P_UPD = `p-update-${RUN}`;
const P_DEL = `p-delete-${RUN}`;
const P_BATCH_GROUP = `p-batch-group-${RUN}`;
const P_BATCH_DIRECT = `direct_p-${RUN}`;
const P_BATCH_DENY = `p-batch-deny-${RUN}`;

// Constant, not new Date(): the self-update branch pins the diff to lastReadAt,
// so a re-stamped joinedAt would deny for a reason that has nothing to do with
// the rule under test and would read exactly like a rule defect.
const P_JOINED_AT = new Date("2026-02-01T08:00:00.000Z");

// Mirrors ConversationParticipant.toFirestore
// (lib/models/messaging/conversation_participant.dart:73-84) key for key.
// avatarUrl is emitted only when non-null — `omitAvatar` reproduces that shape.
function participantBody(
  conversationId: string,
  participantId: string,
  extra: Record<string, unknown> = {},
  omitAvatar = false
): Record<string, unknown> {
  const body: Record<string, unknown> = {
    conversationId,
    participantId,
    displayName: "Vuxen",
    avatarUrl: "https://example.com/avatar.png",
    joinedAt: P_JOINED_AT,
    lastReadAt: P_JOINED_AT,
    role: "member",
    isMuted: false,
  };
  if (omitAvatar) delete body.avatarUrl;
  return { ...body, ...extra };
}

// Mirrors ConversationMembership.toFirestore
// (lib/models/messaging/conversation_membership.dart:74-86). The module writes
// one of these next to every participant row in the SAME batch, so the
// end-to-end tests below only prove anything if this shape is real.
function membershipBody(
  conversationId: string,
  isGroup: boolean
): Record<string, unknown> {
  return {
    conversationId,
    conversationTitle: isGroup ? "Middagsgänget" : "",
    isGroup,
    lastActivityAt: P_JOINED_AT,
    joinedAt: P_JOINED_AT,
    hasUnread: false,
    isMuted: false,
    isPinned: false,
    isArchived: false,
  };
}

async function seedParticipantFixtures(): Promise<void> {
  await env.withSecurityRulesDisabled(async (ctx) => {
    const db = ctx.firestore();
    for (const id of [P_ATT, P_UPD, P_DEL, P_BATCH_DENY]) {
      await db.doc(`conversations/${id}`).set({
        participantIds: [ADULT_UID, FRIEND_UID],
        createdAt: FIXTURE_CREATED_AT,
        isGroup: true,
      });
    }
    // A row to list against, so the read tests are not vacuously empty.
    await db
      .doc(`conversations/${P_ATT}/participants/${ADULT_UID}`)
      .set(participantBody(P_ATT, ADULT_UID));
    // P12B's fixture, on its OWN conversation. It must not live on P_ATT:
    // seeding a STRANGER row there turns P3's create into an UPDATE, and a full
    // set() of an identical body has affectedKeys() == {}, which the
    // self-scoped update branch allows — so P3 would flip to green for a reason
    // that has nothing to do with what it tests. Found by running it.
    await db.doc(`conversations/${P_EVICTED}`).set({
      participantIds: [ADULT_UID, FRIEND_UID],
      createdAt: FIXTURE_CREATED_AT,
      isGroup: true,
    });
    await db
      .doc(`conversations/${P_EVICTED}/participants/${ADULT_UID}`)
      .set(participantBody(P_EVICTED, ADULT_UID));
    await db
      .doc(`conversations/${P_EVICTED}/participants/${STRANGER_UID}`)
      .set(participantBody(P_EVICTED, STRANGER_UID));
    for (const uid of [ADULT_UID, FRIEND_UID]) {
      await db
        .doc(`conversations/${P_UPD}/participants/${uid}`)
        .set(participantBody(P_UPD, uid));
      await db
        .doc(`conversations/${P_DEL}/participants/${uid}`)
        .set(participantBody(P_DEL, uid));
    }
    // No parent conversation for P_READ_FRESH — only a roster row. This is the
    // state a group sits in until somebody sends the first message.
    await db
      .doc(`conversations/${P_READ_FRESH}/participants/${FRIEND_UID}`)
      .set(participantBody(P_READ_FRESH, FRIEND_UID));
  });
}

// --- CREATE ---------------------------------------------------------------

// P1: ALLOW — the group-create bootstrap. No top-level conversation exists yet
// (UserScopedFirebaseRepository wrote it under users/{creator}/conversations),
// and the creator seats ANOTHER participant. If this denies, group chat creation
// throws for every user — the exact bug this block fixes.
test("participants: creator can seat another participant while the conversation has no top-level document yet", async () => {
  const ctx = env.authenticatedContext(ADULT_UID);
  await assertSucceeds(
    ctx
      .firestore()
      .doc(`conversations/${P_UNC}/participants/${FRIEND_UID}`)
      .set(participantBody(P_UNC, FRIEND_UID))
  );
});

// P2: ALLOW — the attested branch: the parent exists and names both the writer
// (ADULT) and the subject (FRIEND). This is the direct-message create, whose
// conversation document IS written and awaited before the roster batch.
test("participants: a participant can seat a co-participant when the conversation roster names both", async () => {
  const ctx = env.authenticatedContext(ADULT_UID);
  await assertSucceeds(
    ctx
      .firestore()
      .doc(`conversations/${P_ATT}/participants/${FRIEND_UID}`)
      .set(participantBody(P_ATT, FRIEND_UID))
  );
});

// P3: DENY — the core protection. A stranger seats THEMSELVES into an existing
// conversation's roster. Same body shape as P2; only the attestation differs.
test("participants: a stranger cannot seat themselves into an existing conversation's roster", async () => {
  const ctx = env.authenticatedContext(STRANGER_UID);
  await assertFails(
    ctx
      .firestore()
      .doc(`conversations/${P_ATT}/participants/${STRANGER_UID}`)
      .set(participantBody(P_ATT, STRANGER_UID))
  );
});

// P3B: ALLOW — fail-closed control for P3 AND the documented residual. Identical
// actor, identical body, identical doc id shape; the ONLY difference is that no
// top-level conversation document exists, so the unclaimed branch applies. It
// proves P3's deny is the attestation gate rather than payload/shape/persistence
// — and it is the honest record of what the bootstrap branch costs: an attacker
// who knows an unchatted group's UUIDv4 id can seat a row. If this ever
// starts FAILING, the bootstrap was removed — check that group creation now
// writes its conversation to the TOP-LEVEL path (BUT-1795) before celebrating.
test("participants: an unattested user CAN seat a row when no conversation document exists (documented residual)", async () => {
  const ctx = env.authenticatedContext(STRANGER_UID);
  await assertSucceeds(
    ctx
      .firestore()
      .doc(`conversations/${P_UNC_RESIDUAL}/participants/${STRANGER_UID}`)
      .set(participantBody(P_UNC_RESIDUAL, STRANGER_UID))
  );
});

// P3C: DENY — the bootstrap branch does NOT extend to direct conversations.
//
// This is the finding the gate caught: a direct id is deterministic
// (`direct_${sortedUids[0]}_${sortedUids[1]}`) and uids are enumerable, because
// `public_profiles` is readable by any signed-in user. Without the `direct_`
// exclusion in `rosterUnclaimed()`, P3B's allow would extend to any DM that has
// not happened yet — giving a stranger both a DM-existence oracle (create
// succeeds ⇒ these two have never talked) and a pre-seat foothold that persists
// into the real roster and then grants its read.
//
// The pair matters: P3B must stay ALLOW (group bootstrap) while this stays
// DENY. If both flip, the exclusion was written too wide and group creation is
// broken; if both allow, it was deleted.
test("participants: an unattested user cannot seat a row on a not-yet-created DIRECT conversation", async () => {
  const ctx = env.authenticatedContext(STRANGER_UID);
  const directId = `direct_${STRANGER_UID}_${ADULT_UID}`;
  await assertFails(
    ctx
      .firestore()
      .doc(`conversations/${directId}/participants/${STRANGER_UID}`)
      .set(participantBody(directId, STRANGER_UID))
  );
});

// P4: DENY — an attested member cannot seat a NON-member. The subject half of
// the attestation is load-bearing on its own: without it any participant could
// inject an arbitrary uid into a group's visible roster.
test("participants: a participant cannot seat a uid that the conversation roster does not name", async () => {
  const ctx = env.authenticatedContext(FRIEND_UID);
  await assertFails(
    ctx
      .firestore()
      .doc(`conversations/${P_ATT}/participants/${STRANGER_UID}`)
      .set(participantBody(P_ATT, STRANGER_UID))
  );
});

// P5: DENY — unauthenticated, against the unclaimed branch (the most permissive
// one). Proves the bootstrap still requires a signed-in caller.
test("participants: an unauthenticated caller cannot seat a row even on an unclaimed roster", async () => {
  const ctx = env.unauthenticatedContext();
  await assertFails(
    ctx
      .firestore()
      .doc(`conversations/${P_UNC}/participants/${ADULT_UID}`)
      .set(participantBody(P_UNC, ADULT_UID))
  );
});

// P6: DENY — a key outside the allowlist. hasOnly is the guard the whole sprint
// exists for; this is its positive-control failure case.
test("participants: a row carrying an unknown field is rejected", async () => {
  const ctx = env.authenticatedContext(ADULT_UID);
  await assertFails(
    ctx
      .firestore()
      .doc(`conversations/${P_UNC}/participants/${ADULT_UID}`)
      .set(participantBody(P_UNC, ADULT_UID, { nickname: "smeknamn" }))
  );
});

// P7: DENY — a required field missing (isMuted). hasAll's counterpart to P6.
test("participants: a row missing a required field is rejected", async () => {
  const ctx = env.authenticatedContext(ADULT_UID);
  const body = participantBody(P_UNC, ADULT_UID);
  delete body.isMuted;
  await assertFails(
    ctx.firestore().doc(`conversations/${P_UNC}/participants/${ADULT_UID}`).set(body)
  );
});

// P8: DENY — the payload's participantId disagrees with the document id.
// Identity is the path; a row that names someone else is a spoof.
test("participants: a row whose participantId field does not match the document id is rejected", async () => {
  const ctx = env.authenticatedContext(ADULT_UID);
  await assertFails(
    ctx
      .firestore()
      .doc(`conversations/${P_UNC}/participants/${ADULT_UID}`)
      .set(participantBody(P_UNC, ADULT_UID, { participantId: FRIEND_UID }))
  );
});

// P9: DENY — the payload's conversationId disagrees with the path. Blocks a row
// that claims to belong to a different conversation (the denormalised field is
// what fromFirestore reads back).
test("participants: a row whose conversationId field does not match the path is rejected", async () => {
  const ctx = env.authenticatedContext(ADULT_UID);
  await assertFails(
    ctx
      .firestore()
      .doc(`conversations/${P_UNC}/participants/${ADULT_UID}`)
      .set(participantBody(P_UNC, ADULT_UID, { conversationId: P_ATT }))
  );
});

// P10: DENY — a role outside the ParticipantRole enum.
test("participants: a row with a role outside the enum is rejected", async () => {
  const ctx = env.authenticatedContext(ADULT_UID);
  await assertFails(
    ctx
      .firestore()
      .doc(`conversations/${P_UNC}/participants/${ADULT_UID}`)
      .set(participantBody(P_UNC, ADULT_UID, { role: "superuser" }))
  );
});

// P11: ALLOW — the production shape for a user with no avatar: toFirestore
// OMITS avatarUrl when it is null, so the optional-field branch has to hold or
// every avatar-less member breaks group creation.
test("participants: a row omitting the optional avatarUrl is accepted", async () => {
  const ctx = env.authenticatedContext(ADULT_UID);
  await assertSucceeds(
    ctx
      .firestore()
      .doc(`conversations/${P_UNC}/participants/${ADULT_UID}`)
      .set(participantBody(P_UNC, ADULT_UID, {}, true))
  );
});

// --- READ -----------------------------------------------------------------

// P12: ALLOW — the client reads the roster with a whole-collection get()
// (getParticipants) / snapshots() (watchParticipants), which is a LIST, not a
// get: the engine refuses the whole query unless the predicate holds for every
// candidate document. Asserting non-emptiness keeps a broken fixture from
// passing this vacuously.
test("participants: a roster member can LIST the whole participants subcollection", async () => {
  const ctx = env.authenticatedContext(FRIEND_UID);
  const snap = await assertSucceeds(
    ctx.firestore().collection(`conversations/${P_ATT}/participants`).get()
  );
  if (snap.empty) throw new Error("expected a non-empty roster — fixture broken");
});

// P12B: DENY — an own row does NOT outlive the parent naming you.
//
// The read rule's own-row fallback is scoped to `parentDoc() == null`, and this
// is the test that proves the scope is load-bearing. Unscoped, a row would
// grant roster LIST forever — which mattered because
// `enforceGroupMinorMembership` USED TO evict a minor by deleting only the
// membership mirror, leaving this row in place. That half is closed in code as
// of 2026-08-12: the trigger clears the roster too. The scope is still
// load-bearing, because that delete is best-effort and a row can survive it —
// and without the scope, an evicted MINOR would keep reading every member's
// name and avatar.
//
// The pair is P12 (member named by a LIVE parent → ALLOW) against this
// (row exists, LIVE parent excludes → DENY). Remove `parentDoc() == null` from
// the fallback and this reddens alone; remove the whole fallback and P14 (the
// fresh-group bootstrap read) reddens instead.
test("participants: a row whose LIVE parent no longer names you does not grant the roster", async () => {
  const ctx = env.authenticatedContext(STRANGER_UID);
  await assertFails(
    ctx.firestore().collection(`conversations/${P_EVICTED}/participants`).get()
  );
});

// P13: DENY — a stranger cannot list the roster. This is the read that the
// bootstrap branch must not hand out on an established conversation: the roster
// carries every member's display name and avatar URL.
test("participants: a stranger cannot LIST an existing conversation's roster", async () => {
  const ctx = env.authenticatedContext(STRANGER_UID);
  await assertFails(
    ctx.firestore().collection(`conversations/${P_ATT}/participants`).get()
  );
});

// P14: ALLOW — the own-row read branch. The group has no top-level document, so
// parent attestation is impossible; the reader's own seeded row is the only
// evidence available, and without this branch a freshly created group's member
// list would not render for anyone.
test("participants: a member can LIST the roster of a group that has no top-level conversation document", async () => {
  const ctx = env.authenticatedContext(FRIEND_UID);
  const snap = await assertSucceeds(
    ctx.firestore().collection(`conversations/${P_READ_FRESH}/participants`).get()
  );
  if (snap.empty) throw new Error("expected a non-empty roster — fixture broken");
});

// P15: DENY — the same fresh roster, read by someone with no row in it. Pairs
// with P14: the branch is "your own row exists", not "the parent is missing".
test("participants: a non-member cannot LIST the roster of a group that has no top-level conversation document", async () => {
  const ctx = env.authenticatedContext(STRANGER_UID);
  await assertFails(
    ctx.firestore().collection(`conversations/${P_READ_FRESH}/participants`).get()
  );
});

// --- UPDATE ---------------------------------------------------------------

// P16: ALLOW — updateLastRead: the row's own subject stamps their read cursor.
// The single most frequent write on this path.
test("participants: the row's subject can stamp their own lastReadAt", async () => {
  const ctx = env.authenticatedContext(FRIEND_UID);
  await assertSucceeds(
    ctx
      .firestore()
      .doc(`conversations/${P_UPD}/participants/${FRIEND_UID}`)
      .update({ lastReadAt: new Date() })
  );
});

// P17: DENY — a stranger stamping someone else's read cursor. Neither branch
// applies: not the subject, and not named by the parent roster.
test("participants: a stranger cannot stamp another member's lastReadAt", async () => {
  const ctx = env.authenticatedContext(STRANGER_UID);
  await assertFails(
    ctx
      .firestore()
      .doc(`conversations/${P_UPD}/participants/${FRIEND_UID}`)
      .update({ lastReadAt: new Date() })
  );
});

// P18: DENY — re-pointing an existing row at another uid. validParticipant runs
// on update too, so participantId/conversationId are immutable for free.
test("participants: an existing row cannot be re-pointed at another uid", async () => {
  const ctx = env.authenticatedContext(FRIEND_UID);
  await assertFails(
    ctx
      .firestore()
      .doc(`conversations/${P_UPD}/participants/${FRIEND_UID}`)
      .update({ participantId: STRANGER_UID })
  );
});

// P19: DENY — an unknown key added by an update. The allowlist has to hold on
// both write verbs, not just create.
test("participants: an update cannot add a field outside the allowlist", async () => {
  const ctx = env.authenticatedContext(FRIEND_UID);
  await assertFails(
    ctx
      .firestore()
      .doc(`conversations/${P_UPD}/participants/${FRIEND_UID}`)
      .update({ nickname: "smeknamn" })
  );
});

// P20: ALLOW — the re-set path. addParticipant uses set() WITHOUT merge, so
// adding a member who already has a row, and migrateToSubcollection, are UPDATES
// in rules terms and must survive. Without this test every deny above would
// still pass under a rule that froze the row completely.
test("participants: an attested co-participant can rewrite a whole existing row (the re-set / migration path)", async () => {
  const ctx = env.authenticatedContext(ADULT_UID);
  await assertSucceeds(
    ctx
      .firestore()
      .doc(`conversations/${P_UPD}/participants/${FRIEND_UID}`)
      .set(participantBody(P_UPD, FRIEND_UID, { displayName: "Vän" }))
  );
});

// --- DELETE ---------------------------------------------------------------

// P21: ALLOW — the row's own subject removes it.
test("participants: the row's subject can delete their own row", async () => {
  const ctx = env.authenticatedContext(FRIEND_UID);
  await assertSucceeds(
    ctx.firestore().doc(`conversations/${P_DEL}/participants/${FRIEND_UID}`).delete()
  );
});

// P22: DENY — delete is deliberately SELF-ONLY, narrower than create/update. A
// co-participant evicting someone from the roster mirror is pure griefing; the
// real "remove member" runs in the leaveGroupConversation Cloud Function under
// the Admin SDK, which bypasses these rules. If this ever passes, someone
// widened delete to mayWriteRoster() — that is a product decision, not a tidy-up.
test("participants: an attested co-participant cannot delete another member's row", async () => {
  const ctx = env.authenticatedContext(FRIEND_UID);
  await assertFails(
    ctx.firestore().doc(`conversations/${P_DEL}/participants/${ADULT_UID}`).delete()
  );
});

// P23: DENY — a stranger deleting a row.
test("participants: a stranger cannot delete a roster row", async () => {
  const ctx = env.authenticatedContext(STRANGER_UID);
  await assertFails(
    ctx.firestore().doc(`conversations/${P_DEL}/participants/${ADULT_UID}`).delete()
  );
});

// --- END TO END: the module's real WriteBatch ------------------------------

// P24: ALLOW — the actual shape ConversationParticipantModule.addParticipants
// commits on the GROUP path: one participant row AND one
// users/{uid}/conversation_memberships row per participant, all in a single
// atomic batch, with no top-level conversation document in existence. A batch is
// all-or-nothing, so this is the only test that proves the two rule blocks
// cooperate — a single denied document here is a thrown createGroupConversation.
test("participants: the module's real create-group batch (3 rosters + 3 memberships, no parent doc) commits end to end", async () => {
  const db = env.authenticatedContext(ADULT_UID).firestore();
  const batch = db.batch();
  for (const uid of [ADULT_UID, FRIEND_UID, MINOR_UID]) {
    batch.set(
      db.doc(`conversations/${P_BATCH_GROUP}/participants/${uid}`),
      participantBody(P_BATCH_GROUP, uid, {
        role: uid === ADULT_UID ? "owner" : "member",
      })
    );
    batch.set(
      db.doc(`users/${uid}/conversation_memberships/${P_BATCH_GROUP}`),
      membershipBody(P_BATCH_GROUP, true)
    );
  }
  await assertSucceeds(batch.commit());
});

// P25: ALLOW — the DIRECT path in full: the client writes the top-level
// conversation first (awaited), then commits the 2+2 batch. This is the attested
// branch end to end, and it also proves the roster block does not fight the
// conversations create rule.
test("participants: the module's real create-direct sequence (conversation, then 2 rosters + 2 memberships) commits end to end", async () => {
  const db = env.authenticatedContext(ADULT_UID).firestore();
  await assertSucceeds(
    db.doc(`conversations/${P_BATCH_DIRECT}`).set({
      participantIds: [ADULT_UID, FRIEND_UID],
      createdAt: new Date(),
      isGroup: false,
      metadata: { creatorId: ADULT_UID },
    })
  );
  const batch = db.batch();
  for (const uid of [ADULT_UID, FRIEND_UID]) {
    batch.set(
      db.doc(`conversations/${P_BATCH_DIRECT}/participants/${uid}`),
      participantBody(P_BATCH_DIRECT, uid)
    );
    batch.set(
      db.doc(`users/${uid}/conversation_memberships/${P_BATCH_DIRECT}`),
      membershipBody(P_BATCH_DIRECT, false)
    );
  }
  await assertSucceeds(batch.commit());
});

// P26: DENY — the same batch shape, run by a stranger against a conversation
// that already exists and does not name them. The mirror image of P24/P25: the
// end-to-end path is open for a member and shut for everyone else.
test("participants: a stranger's identically-shaped batch against an existing conversation is denied end to end", async () => {
  const db = env.authenticatedContext(STRANGER_UID).firestore();
  const batch = db.batch();
  batch.set(
    db.doc(`conversations/${P_BATCH_DENY}/participants/${STRANGER_UID}`),
    participantBody(P_BATCH_DENY, STRANGER_UID)
  );
  batch.set(
    db.doc(`users/${STRANGER_UID}/conversation_memberships/${P_BATCH_DENY}`),
    membershipBody(P_BATCH_DENY, true)
  );
  await assertFails(batch.commit());
});

async function run(): Promise<void> {
  console.log("conversations 1:1 minor-DM gate rules tests (BUT-674)\n");
  console.log("========================================\n");
  await setup();
  await seedUpdateFixtures();
  await seedParticipantFixtures();
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
