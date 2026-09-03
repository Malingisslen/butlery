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
 *   - DENY (BUT-1838, was ALLOW): a GROUP conversation (size == 3) created by a
 *            client. Group conversations are now minted only by
 *            `createChatGroup` under the Admin SDK, after the minor-membership
 *            gate has cleared every member — and the gate re-runs on every add.
 *
 * BUT-1838 (2026-08-13) added three more contracts to this file, each with its
 * own section banner:
 *
 *   - `directIdBinds`: a client may create ONLY a direct conversation, and only
 *     at the id derived from its own two participants (both orderings).
 *   - the group history cut-off on /messages (`sentAt >= memberSince[you]`),
 *     the fail-closed defaults behind it, the admin moderation bypass, and the
 *     immutability of `memberSince`/`groupId` that makes it a real control.
 *   - the roster lock: no parentless (bootstrap) branch on write OR read, and no
 *     client write at all to a GROUP conversation's roster.
 *
 * Five previously-passing assertions FLIP to deny (C5, P1, P3B, P14, P24). Each
 * flip is the intended signal of BUT-1838 and says so at its own site — do not
 * "restore" one without reading the comment there.
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

// MUTATION-PROBE SEAM (BUT-1838). Both values are overridable so a mutation
// probe can point this suite at a MUTATED COPY of firestore.rules in a scratch
// directory under a FRESH projectId, without ever writing to the real rules
// file. The repo has been bitten twice by probes left live in tracked files;
// an env var cannot be left behind. Defaults are the real rules + real project,
// so a plain `npm run test:rules:conversations` is unaffected.
const PROJECT_ID = process.env.PROBE_PROJECT_ID ?? "butlery-rules-conversations";
const RULES_PATH =
  process.env.PROBE_RULES_PATH ?? path.resolve(__dirname, "../../../firestore.rules");

// The minor whose users/{uid}.isMinor == true (seeded server-side below).
const MINOR_UID = "conv-minor-uid";
// An adult target (no isMinor field) — the fail-open case.
const ADULT_UID = "conv-adult-uid";
// A friend of the minor (friend doc at users/{minor}/friends/{friend}).
const FRIEND_UID = "conv-friend-uid";
// A user with no friendship to the minor.
const STRANGER_UID = "conv-stranger-uid";
// An app-level moderator: a document at /admins/{uid} makes isAdmin() true.
// BUT-1838 needs one because the messages block's moderation branch
// (`allow read, delete: if isAdmin()`) must bypass the new history cut-off.
const ADMIN_UID = "conv-admin-uid";

// BUT-1838: a client may now create ONLY a direct conversation, and only at the
// id derived from its two participants. Every create test therefore needs an id
// that AGREES with its participantIds, or it denies on `directIdBinds` before
// reaching the conjunct it means to test — the classic vacuous deny.
function directId(a: string, b: string): string {
  return `direct_${a}_${b}`;
}

// A throwaway counterparty with no users/{uid} profile. `otherIsMinor()` is
// exists()-guarded and fails OPEN to "adult", so an unseeded uid is a valid
// adult DM target — and a per-test uid keeps every create test on its OWN
// document id, so an earlier ALLOW never turns a later create into an update.
//
// BUT-1831 also uses one as an authenticated ACTOR (`authenticatedContext`),
// not only as a DM target. Sound on paths where no conjunct reads
// `users/{uid}` — check that before reusing it as an actor on a rule that does.
function peer(tag: string): string {
  return `conv-peer-${tag}`;
}

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
    // BUT-1838: the moderation branch on /messages is `allow read, delete: if
    // isAdmin()`, which resolves through a document in /admins.
    await db.doc(`admins/${ADMIN_UID}`).set({ role: "moderator" });
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

// BUT-1838 NOTE ON EVERY CREATE TEST BELOW. The create rule now also requires
// `directIdBinds(participantIds)` — the document id must be
// `direct_<a>_<b>` over exactly the two participants, in either order — and a
// PRESENT `metadata.creatorId` equal to the caller. Both conjuncts sit ABOVE
// most of what the older tests meant to prove, so every one of them carries a
// conforming id and a conforming metadata map. Otherwise the deny is real and
// the test is vacuous: it would go green with the minor gate deleted.

// C1: DENY — a non-friend of a minor cannot open a 1:1 DM with that minor.
// This is the core protection: minor's isMinor == true, no friend doc. The id
// and metadata conform, so the minor gate is the ONLY failing conjunct.
test("conversations: non-friend cannot create a 1:1 DM with a minor", async () => {
  const ctx = env.authenticatedContext(STRANGER_UID);
  await assertFails(
    ctx
      .firestore()
      .doc(`conversations/${directId(STRANGER_UID, MINOR_UID)}`)
      .set(
        convBody([STRANGER_UID, MINOR_UID], {
          metadata: { creatorId: STRANGER_UID },
        })
      )
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
      .doc(`conversations/${directId(FRIEND_UID, MINOR_UID)}`)
      .set(
        convBody([FRIEND_UID, MINOR_UID], {
          metadata: { creatorId: FRIEND_UID },
        })
      )
  );
});

// C3: ALLOW — a non-friend can open a 1:1 DM with an ADULT target.
// Adults are unaffected: isMinor absent -> otherIsMinor() false -> gate passes.
test("conversations: non-friend can create a 1:1 DM with an adult", async () => {
  const ctx = env.authenticatedContext(STRANGER_UID);
  const other = peer("c3");
  await assertSucceeds(
    ctx
      .firestore()
      .doc(`conversations/${directId(STRANGER_UID, other)}`)
      .set(
        convBody([STRANGER_UID, other], {
          metadata: { creatorId: STRANGER_UID },
        })
      )
  );
});

// C4: DENY — the minor gate holds regardless of participant ORDER.
// otherParticipant() must pick the non-creator whether the minor is index 0 or
// 1. Here the minor is at index 0 and the (non-friend) creator at index 1 ->
// must still DENY. (Order-sensitivity guard on the deny side.)
test("conversations: non-friend 1:1 DM with minor is denied when minor is first in the array", async () => {
  const ctx = env.authenticatedContext(STRANGER_UID);
  await assertFails(
    ctx
      .firestore()
      .doc(`conversations/${directId(MINOR_UID, STRANGER_UID)}`)
      .set(
        convBody([MINOR_UID, STRANGER_UID], {
          metadata: { creatorId: STRANGER_UID },
        })
      )
  );
});

// C5: DENY — THE FLIP. This test used to ALLOW and documented the
// rules-cannot-iterate gap: a non-friend could create a GROUP conversation
// (size 3) containing a minor, and group-minor protection was deferred to an
// after-the-fact Cloud Function trigger that ran once, at birth.
//
// BUT-1838 removes the gap by removing the capability: `directIdBinds` requires
// exactly two participants, so a client cannot create a group conversation AT
// ALL. Group conversations are minted by `createChatGroup` under the Admin SDK,
// after the minor-membership gate has cleared every member, and the gate re-runs
// on every add. If this ever goes back to ALLOW, the id binding was removed and
// the child-safety gate is bypassable again.
test("conversations: a client cannot create a group (size 3) conversation at all", async () => {
  const ctx = env.authenticatedContext(STRANGER_UID);
  await assertFails(
    ctx
      .firestore()
      .doc(`conversations/c-group-deny-${RUN}`)
      .set(
        convBody([STRANGER_UID, MINOR_UID, ADULT_UID], {
          metadata: { creatorId: STRANGER_UID },
        })
      )
  );
});

// C5B: DENY — the same group payload dressed as a direct conversation, i.e. a
// `direct_a_b` id over a THREE-person list. `directIdBinds` checks size() == 2
// first, so the id-shaped disguise buys nothing. Pairs with C5: one proves an
// arbitrary group id fails, this proves a plausible one does too.
test("conversations: a 3-person conversation is denied even at a direct_-shaped id", async () => {
  const ctx = env.authenticatedContext(STRANGER_UID);
  const other = peer("c5b");
  await assertFails(
    ctx
      .firestore()
      .doc(`conversations/${directId(STRANGER_UID, other)}`)
      .set(
        convBody([STRANGER_UID, other, ADULT_UID], {
          metadata: { creatorId: STRANGER_UID },
        })
      )
  );
});

// C6: DENY — a create whose metadata.creatorId is NOT the caller. BUT-1626 bound
// the recorded creator to the caller so the group minor-safety Cloud Function
// (enforceGroupMinorMembership) could trust metadata.creatorId; that CF has
// since been repointed to `chat_groups.memberAddedBy`. Without the binding a
// client could forge creatorId to a friend of a minor (or the minor's own uid)
// and slip a non-friend group add past the CF's friend check. The scenario is
// additionally unreachable now: a client can no longer create a group
// conversation at all. Adult 1:1 target
// so this isolates the creatorId binding, not the minor-DM gate.
test("conversations: cannot create with metadata.creatorId set to another uid", async () => {
  const ctx = env.authenticatedContext(STRANGER_UID);
  const other = peer("c6");
  await assertFails(
    ctx
      .firestore()
      .doc(`conversations/${directId(STRANGER_UID, other)}`)
      .set(
        convBody([STRANGER_UID, other], {
          metadata: { creatorId: FRIEND_UID },
        })
      )
  );
});

// C6B: DENY — BUT-1838 turns "records no creator" from a permitted state into a
// denied one. The old rule read `!('metadata' in data) || ...`, so a create with
// no metadata key at all was fine; `authorizeDeparture` then read that group as
// having no admin. The conjunct is now a bare equality, so an ABSENT metadata
// map is a CEL evaluation error and denies. Distinct from C7B (metadata present
// with value null) — that is a different CEL path and gets its own test.
test("conversations: a create with no metadata key at all is denied", async () => {
  const ctx = env.authenticatedContext(STRANGER_UID);
  const other = peer("c6b");
  await assertFails(
    ctx
      .firestore()
      .doc(`conversations/${directId(STRANGER_UID, other)}`)
      .set(convBody([STRANGER_UID, other]))
  );
});

// C7B: DENY — a create carrying `metadata: null`, the shape this whole suite
// never put through the CREATE rule (C1-C5 omit the key, C6/C7 send a map, and every
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
// BUT-1831 deleted the `MessageMutationModule` fallback that built a
// creator-less `Conversation` with no metadata and staged a top-level create.
// The corrected account of who can still reach this limb lives at the rule
// itself; do not restate it here, where nothing keeps the copy honest.
//
// WHAT THE MUTATION PROBE ACTUALLY SAYS, measured 2026-08-13 against the
// BUT-1838 rule and recorded here because the paragraph above is inherited from
// the OLD one. Two probes, 77 assertions each:
//
//   * harmonise the create conjunct with the UPDATE rule's `is map` ternary —
//     the edit the rule comment warns against — and NOTHING reddens (77/77).
//     Under the pre-BUT-1838 spelling that edit was fatal, because the conjunct
//     read `!('metadata' in d) || !('creatorId' in d.metadata) || d.metadata
//     .creatorId == uid`: the `||` escape hatches ALLOWED an absent creator, so
//     only the evaluation error stood between a non-creator and the document.
//     BUT-1838 replaced all three with a bare equality that requires the creator
//     to be PRESENT, and a ternary resolving null still fails `null == uid`.
//   * delete the conjunct outright and exactly three reddens: this test, C6 and
//     C6B (74/77).
//
// So the ASSERTION is load-bearing and the deny is attributable — the emulator
// names the `allow create` limb of `match /conversations/{conversationId}` (it
// prints a line number, which moves; cite the match pattern) — but the stated
// MECHANISM has changed. The shape is now refused by the presence requirement,
// not only by a CEL accident, which is a stronger bound: a CEL accident binds
// our own client, a presence requirement binds a tampered one too. The rule
// comment has since been corrected and no longer claims harmonising the
// spellings would disarm this.
//
// BUT-1838, 2026-08-13 — the ASSERTION is untouched (still DENY) and the reason
// is untouched (still the CEL evaluation error on a null `metadata`), but the
// document id had to change from `c-meta-null-<run>` to a conforming
// `direct_<caller>_<peer>`. The create rule now evaluates `directIdBinds` BEFORE
// the metadata conjunct, so at the old id this test would have kept passing
// while proving nothing about metadata at all — green with the metadata
// conjunct deleted. C7 immediately below is its fail-closed control: same
// caller, same shape, same id family, only `metadata` differs, and it ALLOWS.
test("conversations: a create carrying metadata: null is denied", async () => {
  const ctx = env.authenticatedContext(STRANGER_UID);
  const other = peer("c7b");
  await assertFails(
    ctx
      .firestore()
      .doc(`conversations/${directId(STRANGER_UID, other)}`)
      .set(convBody([STRANGER_UID, other], { metadata: null }))
  );
});

// C7: ALLOW — a create whose metadata.creatorId IS the caller. This is the
// legitimate client shape. `Conversation.group` stamps creatorId = self; the
// direct path does NOT use `Conversation.direct` (which stamps no metadata) —
// `createDirectConversation` builds its Conversation inline with
// `metadata: {'creatorId': user1Id}`. Both LIVE paths carry it, so the binding
// never blocks a real create; the factory named here before did not.
//
// Also the fail-closed control for C6, C6B and C7B: identical caller, identical
// participant shape, identical id family. Only `metadata` differs.
test("conversations: can create with metadata.creatorId equal to the caller", async () => {
  const ctx = env.authenticatedContext(STRANGER_UID);
  const other = peer("c7");
  await assertSucceeds(
    ctx
      .firestore()
      .doc(`conversations/${directId(STRANGER_UID, other)}`)
      .set(
        convBody([STRANGER_UID, other], {
          metadata: { creatorId: STRANGER_UID },
        })
      )
  );
});

// ============================================================================
// CONVERSATIONS — id/membership binding on CREATE (BUT-1838 / BUT-1830)
// ============================================================================
//
// `directIdBinds(p)` = `p.size() == 2 && (id == 'direct_'+p[0]+'_'+p[1] || id ==
// 'direct_'+p[1]+'_'+p[0])`. It closes BUT-1830's squat: before it, any signed-in
// user could write `{participantIds:[self], createdAt, metadata:{creatorId:self}}`
// at a KNOWN group id, permanently disarming the minor-safety trigger (an
// onDocumentCreated cannot fire twice) with no recovery path.
//
// Both orderings are accepted on purpose — the client sorts the uids when it
// mints the id, but the array order stored on the document is not guaranteed to
// match — so BOTH must be proven to allow, not just the one the client happens
// to send today.

// C15: ALLOW — array order matches id order.
test("conversations: a direct create is allowed when the id matches [a, b] in that order", async () => {
  const ctx = env.authenticatedContext(STRANGER_UID);
  const other = peer("c15");
  await assertSucceeds(
    ctx
      .firestore()
      .doc(`conversations/${directId(STRANGER_UID, other)}`)
      .set(
        convBody([STRANGER_UID, other], {
          metadata: { creatorId: STRANGER_UID },
        })
      )
  );
});

// C16: ALLOW — the REVERSED ordering. The id is direct_<caller>_<other> while
// the array is [other, caller]. If this ever denies, someone "simplified"
// directIdBinds to a single ordering and every conversation whose stored array
// happens to be sorted the other way stops being creatable.
test("conversations: a direct create is allowed when the id matches [b, a] reversed", async () => {
  const ctx = env.authenticatedContext(STRANGER_UID);
  const other = peer("c16");
  await assertSucceeds(
    ctx
      .firestore()
      .doc(`conversations/${directId(STRANGER_UID, other)}`)
      .set(
        convBody([other, STRANGER_UID], {
          metadata: { creatorId: STRANGER_UID },
        })
      )
  );
});

// C17: DENY — the squat. A `direct_`-shaped id that does NOT correspond to its
// participants: the id names one peer, the array names another. This is the
// shape that let an attacker seed a document at an id somebody else's client
// would later try to create.
test("conversations: a direct create whose id names a different peer than participantIds is denied", async () => {
  const ctx = env.authenticatedContext(STRANGER_UID);
  const idPeer = peer("c17-id");
  const bodyPeer = peer("c17-body");
  await assertFails(
    ctx
      .firestore()
      .doc(`conversations/${directId(STRANGER_UID, idPeer)}`)
      .set(
        convBody([STRANGER_UID, bodyPeer], {
          metadata: { creatorId: STRANGER_UID },
        })
      )
  );
});

// C18: DENY — minting a DM for two OTHER people. The id and the array agree
// perfectly; the caller simply is not in it. `request.auth.uid in
// participantIds` is the conjunct under test, and it is what stops a stranger
// pre-creating (and thereby owning the shape of) a conversation between two
// people who have never talked.
test("conversations: a user cannot mint a direct conversation between two other people", async () => {
  const ctx = env.authenticatedContext(STRANGER_UID);
  const a = peer("c18-a");
  const b = peer("c18-b");
  await assertFails(
    ctx
      .firestore()
      .doc(`conversations/${directId(a, b)}`)
      .set(convBody([a, b], { metadata: { creatorId: STRANGER_UID } }))
  );
});

// C19: DENY — the degenerate direct conversation: two array slots, one distinct
// uid. `toSet().size() >= 2` is the conjunct, and it is evaluated BEFORE
// directIdBinds (which this payload would satisfy), so the deny is attributable.
// A self-DM is worthless, and a rule that accepted it would also accept
// `participantIds: [self]` padded out to length two.
test("conversations: a direct create naming the same uid twice is denied", async () => {
  const ctx = env.authenticatedContext(STRANGER_UID);
  await assertFails(
    ctx
      .firestore()
      .doc(`conversations/${directId(STRANGER_UID, STRANGER_UID)}`)
      .set(
        convBody([STRANGER_UID, STRANGER_UID], {
          metadata: { creatorId: STRANGER_UID },
        })
      )
  );
});

// C20: DENY — participantIds is not a list. `is list` is the type floor that
// keeps every downstream conjunct (`toSet()`, `in`, `p[0]`) from being handed
// something it cannot reason about.
test("conversations: a create whose participantIds is not a list is denied", async () => {
  const ctx = env.authenticatedContext(STRANGER_UID);
  await assertFails(
    ctx
      .firestore()
      .doc(`conversations/${directId(STRANGER_UID, peer("c20"))}`)
      .set({
        participantIds: STRANGER_UID,
        createdAt: new Date(),
        metadata: { creatorId: STRANGER_UID },
      })
  );
});

// ============================================================================
// CONVERSATIONS — metadata.creatorId immutability on UPDATE (BUT-1788)
// ============================================================================
//
// The create binding (C6/C7) is only half the story. `affectedKeys()` is
// TOP-LEVEL, so before this rule conjunct existed the deny list
// ['participantIds','createdAt'] let any participant rewrite `metadata`
// wholesale. Two server functions TREATED metadata.creatorId as the group admin
// identity — enforceGroupMinorMembership (BUT-1626, since repointed to
// `chat_groups.memberAddedBy`) and the authorizeDeparture that then lived in
// leaveGroupConversation (the CALLABLE was deleted by BUT-1838; the symbol
// survives in remove-chat-group-member.ts, which reads
// `chat_groups.adminIds`) — so a self-promotion write was a group-takeover
// primitive: name yourself creator, then call the callable and evict everyone
// else. No server-side consumer treats the field as an identity today, though
// firestore.rules binds it on create and compares it on update; the conjunct
// stays because the primitive returns the moment a consumer does.

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

// BUT-1831: a DIRECT conversation, which the group fixtures above cannot stand
// in for, for two reasons that survive independently:
//   * FIDELITY — C11D stages what a RECIPIENT's client sends when a merge-set
//     rebuilds the array: TWO elements, opposite order to the stored one.
//     `createDirectConversation` writes [user1Id, user2Id], and its
//     existence-read fall-through can still merge-set over it; the deleted
//     `sendMessage` fallback used to as well. A three-person group fixture
//     cannot express that shape at all.
//   * CONTROL — C11E needs a document no other test writes. Share it with the
//     metadata fixtures and any write of theirs changes what C11E asserts
//     against, at which point the ALLOW control stops being a control.
// Creation order here is [initiator, recipient].
//
// `directIdBinds` is NOT the reason, however much it looks like one: it is
// called only from `allow create`, so it never runs on C11D or C11E, which are
// updates against a rules-disabled seed. An earlier version of this comment
// said otherwise, and a reader who believed it would conclude the update path
// is already id-bound and that `participantIds` is redundant in the deny-list
// — which is the exact regression C11D exists to catch.
//
// BOTH uids are dedicated, per the `peer()` convention above, and the id
// carries RUN. A direct id is a pure function of its two participants, so any
// two fixtures naming the same pair ARE the same document — measured: the
// first draft reused ADULT_UID/STRANGER_UID, `seedMessageFixtures` seeds
// `MSG_DIRECT` at that same pair and runs after `seedUpdateFixtures`, and the
// overwrite made the ALLOW control deny. C11D would have stayed green on its
// own and pinned nothing, which is the whole failure mode this trio exists to
// close.
const DM_INITIATOR = peer(`dm-init-${RUN}`);
const DM_RECIPIENT = peer(`dm-recip-${RUN}`);
const DIRECT_PARTICIPANTS = [DM_INITIATOR, DM_RECIPIENT];
const DIRECT_CONVO = `direct_${DM_INITIATOR}_${DM_RECIPIENT}`;

function directConvoPayload(
  extra: Record<string, unknown> = {}
): Record<string, unknown> {
  return {
    participantIds: [...DIRECT_PARTICIPANTS],
    createdAt: FIXTURE_CREATED_AT,
    updatedAt: new Date(),
    isGroup: false,
    metadata: { creatorId: DM_INITIATOR },
    ...extra,
  };
}

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
    // BUT-1831: the direct conversation C11D/C11E use. DM_INITIATOR created
    // it, so the stored array order is [DM_INITIATOR, DM_RECIPIENT].
    await db.doc(`conversations/${DIRECT_CONVO}`).set(directConvoPayload());
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
// reverse: a group with no recorded creator, which the authorizeDeparture of
// the time read as "no admin". The live one reads `chat_groups.adminIds` and
// never this field. Proves the guard compares the resolved value, not just
// presence.
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

// C11C: DENY — a re-stamped `createdAt`, the gap BUT-1831 named. C11 and C11B
// hold FIXTURE_CREATED_AT on BOTH the fixture and the payload, so neither of
// them moves the key; they remain sound for the metadata cases they describe.
// The call is otherwise identical to C11B's, which is what makes this deny
// attributable: C11B is its single-variable ALLOW control.
test("conversations: a merge-set that re-stamps createdAt is denied, even when metadata round-trips untouched", async () => {
  const ctx = env.authenticatedContext(STRANGER_UID);
  await assertFails(
    ctx
      .firestore()
      .doc(`conversations/${NULL_METADATA_GROUP}`)
      .set(
        conversationDtoPayload(null, {
          createdAt: new Date("2026-02-20T09:00:00.000Z"),
        }),
        { merge: true }
      )
  );
});

// C11D: DENY — the RECIPIENT's reversed participantIds, on a direct
// conversation. `createdAt` is held at the fixture instant on purpose: this
// test must fail for the array and nothing else, or it duplicates C11C.
// Sent as the recipient, because that is the only party whose client produced
// the opposite order.
test("conversations: the recipient cannot send back participantIds in the opposite order", async () => {
  const ctx = env.authenticatedContext(DM_RECIPIENT);
  await assertFails(
    ctx
      .firestore()
      .doc(`conversations/${DIRECT_CONVO}`)
      .set(
        directConvoPayload({
          participantIds: [DM_RECIPIENT, DM_INITIATOR],
        }),
        { merge: true }
      )
  );
});

// C11E: ALLOW — the control. Same document, same sender, same everything, with
// the stored order kept. Without it C11D proves only that SOMETHING about a
// recipient writing to a direct conversation is refused, which is the failure
// mode the whole BUT-1831 gap was made of.
test("conversations: the same recipient write SUCCEEDS when participantIds keeps the stored order", async () => {
  const ctx = env.authenticatedContext(DM_RECIPIENT);
  await assertSucceeds(
    ctx
      .firestore()
      .doc(`conversations/${DIRECT_CONVO}`)
      .set(directConvoPayload(), { merge: true })
  );
});

// C12A: DENY — injecting a creatorId onto a document that stored NONE
// (metadata key absent). Resolves to non-null == null. This is the takeover
// against a pre-BUT-1626 group, where authorizeDeparture then saw no admin at
// all. Uses update(), not a merge-set: merge DEEP-MERGES nested maps,
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
// CONVERSATIONS — memberSince / groupId immutability on UPDATE (BUT-1838)
// ============================================================================
//
// Malin's decision, 2026-08-13: "a new member sees only from now on". The
// messages read rule below enforces it by comparing a message's `sentAt`
// against `conversation.memberSince[reader]`. That makes the map a SECURITY
// CONTROL stored on a document its own subjects may update — and the
// conversations update rule is a DENY-LIST, not an allow-list.
//
// Without `memberSince` in that list, any group member could lower their own
// stamp and read the whole backlog from before they joined, or RAISE someone
// else's to blank their history. `groupId` is denied one step removed: it is
// what selects the history clause at all, so a member who could add or remove
// it could switch the control off.
//
// The plan revision caught this; it was not in the first draft.

const STAMP_GROUP = `g-stamp-${RUN}`;
const STAMP_DIRECT = directId(FRIEND_UID, STRANGER_UID);

const STAMP_ADULT_AT = new Date("2026-03-01T00:00:00.000Z");
const STAMP_FRIEND_AT = new Date("2026-04-01T00:00:00.000Z");
const STAMP_LOWERED = new Date("2026-01-01T00:00:00.000Z");

async function seedStampFixtures(): Promise<void> {
  await env.withSecurityRulesDisabled(async (ctx) => {
    const db = ctx.firestore();
    await db.doc(`conversations/${STAMP_GROUP}`).set({
      participantIds: [ADULT_UID, FRIEND_UID],
      createdAt: FIXTURE_CREATED_AT,
      isGroup: true,
      groupId: "grp-stamp",
      title: "Familjen",
      memberSince: {
        [ADULT_UID]: STAMP_ADULT_AT,
        [FRIEND_UID]: STAMP_FRIEND_AT,
      },
    });
    // A DIRECT conversation with no groupId and no memberSince — the state the
    // one pre-existing production conversation is in.
    await db.doc(`conversations/${STAMP_DIRECT}`).set({
      participantIds: [FRIEND_UID, STRANGER_UID],
      createdAt: FIXTURE_CREATED_AT,
      isGroup: false,
    });
  });
}

// U1: DENY — a member lowering their OWN stamp. The primary attack: set it to
// the epoch and the whole pre-join backlog becomes readable.
test("conversations: a group member cannot lower their own memberSince stamp", async () => {
  const ctx = env.authenticatedContext(FRIEND_UID);
  await assertFails(
    ctx
      .firestore()
      .doc(`conversations/${STAMP_GROUP}`)
      .update({ [`memberSince.${FRIEND_UID}`]: STAMP_LOWERED })
  );
});

// U2: DENY — a member touching ANOTHER member's stamp. The mirror attack:
// raising someone else's cut-off hides history from them. Same rule conjunct,
// opposite direction, and a rule that only pinned "your own" would miss it.
test("conversations: a group member cannot raise another member's memberSince stamp", async () => {
  const ctx = env.authenticatedContext(FRIEND_UID);
  await assertFails(
    ctx
      .firestore()
      .doc(`conversations/${STAMP_GROUP}`)
      .update({ [`memberSince.${ADULT_UID}`]: new Date("2027-01-01T00:00:00.000Z") })
  );
});

// U3: DENY — replacing the whole map in one write. `affectedKeys()` is
// TOP-LEVEL, so U1/U2 (dotted paths) and this (whole-map set) reach the deny
// list by the same route; pinning both keeps a future rewrite that special-cases
// nested paths from opening the wholesale one.
test("conversations: a group member cannot replace the whole memberSince map", async () => {
  const ctx = env.authenticatedContext(FRIEND_UID);
  await assertFails(
    ctx
      .firestore()
      .doc(`conversations/${STAMP_GROUP}`)
      .update({ memberSince: { [FRIEND_UID]: STAMP_LOWERED } })
  );
});

// U4: DENY — removing `groupId`, which is what SELECTS the history clause. A
// member who could drop it would turn the cut-off off for everyone at once,
// without ever touching memberSince.
test("conversations: a group member cannot change groupId", async () => {
  const ctx = env.authenticatedContext(FRIEND_UID);
  await assertFails(
    ctx
      .firestore()
      .doc(`conversations/${STAMP_GROUP}`)
      .update({ groupId: "grp-somebody-elses" })
  );
});

// U5: DENY — the same key from the other side: ADDING groupId to a direct
// conversation. Not an escalation on its own, but it hands the messages read
// rule a `memberSince` map that does not exist, which fails CLOSED and bricks a
// working DM. Pinned so the deny list is proven on both a document that HAS the
// key and one that does not.
test("conversations: a participant cannot add groupId to a direct conversation", async () => {
  const ctx = env.authenticatedContext(FRIEND_UID);
  await assertFails(
    ctx
      .firestore()
      .doc(`conversations/${STAMP_DIRECT}`)
      .update({ groupId: "grp-forged" })
  );
});

// U6: ALLOW — the control, and the reason U1–U5 are not just a blanket freeze.
// A member renames the group while memberSince and groupId are carried through
// untouched. Every deny above would still pass if someone froze the whole
// document; only this one goes red.
test("conversations: a group member can still update an unrelated field while memberSince is untouched", async () => {
  const ctx = env.authenticatedContext(FRIEND_UID);
  await assertSucceeds(
    ctx
      .firestore()
      .doc(`conversations/${STAMP_GROUP}`)
      .update({ title: "Familjen igen" })
  );
});

// ============================================================================
// MESSAGES — group history cut-off + sender membership (BUT-1838)
// ============================================================================
//
// READ: `sentAt >= conversation.memberSince[you]`, scoped on `'groupId' in` the
// conversation so the one pre-existing direct conversation is untouched. The
// lookup is spelled `.get('memberSince', {}).get(uid, request.time)` — indexing
// an absent key would be a CEL evaluation error (a blanket deny), and the
// default of `request.time` makes a member with NO stamp see nothing rather than
// everything. Both halves of that fail-closed claim get their own test.
//
// The moderation branch (`allow read, delete: if isAdmin()`) is a SEPARATE
// allow and must not be caught by the cut-off — Trust & Safety's condition: a
// moderator previewing a reported message must be able to read it whatever the
// reporter's join date. M4 is that test.
//
// CREATE: the sender must be IN the conversation. The rule used to check only
// that you were who you claimed to be, so anyone who knew a conversation id
// could inject messages into strangers' chats — and a direct id is derivable
// from two uids, with `public_profiles` readable by every signed-in user.

const MSG_GROUP = `g-history-${RUN}`;
const MSG_GROUP_NO_STAMPS = `g-nostamps-${RUN}`;
const MSG_DIRECT = directId(ADULT_UID, STRANGER_UID);

const T_BEFORE_JOIN = new Date("2026-03-01T12:00:00.000Z");
const T_JOIN = new Date("2026-04-01T00:00:00.000Z");
const T_AFTER_JOIN = new Date("2026-05-01T12:00:00.000Z");

const MSG_OLD = `m-old-${RUN}`;
const MSG_NEW = `m-new-${RUN}`;
const MSG_NO_STAMPS = `m-nostamps-${RUN}`;
const MSG_IN_DIRECT = `m-direct-${RUN}`;

// Claims every message CREATE needs regardless of BUT-1838: `isAgeCompliant()`
// (ADR-0002) and `isAccountMatured()` (BUT-659). Without them a create denies
// for a reason that has nothing to do with membership.
const MSG_CLAIMS = { ageCompliant: true, email_verified: true };

function messageBody(
  conversationId: string,
  senderId: string,
  sentAt: Date
): Record<string, unknown> {
  return {
    senderId,
    conversationId,
    content: "hej",
    sentAt,
    type: "text",
  };
}

async function seedMessageFixtures(): Promise<void> {
  await env.withSecurityRulesDisabled(async (ctx) => {
    const db = ctx.firestore();
    // A GROUP conversation: FRIEND joined on T_JOIN, ADULT has NO stamp at all.
    await db.doc(`conversations/${MSG_GROUP}`).set({
      participantIds: [ADULT_UID, FRIEND_UID],
      createdAt: FIXTURE_CREATED_AT,
      isGroup: true,
      groupId: "grp-history",
      memberSince: { [FRIEND_UID]: T_JOIN },
    });
    // A GROUP conversation with the memberSince map entirely ABSENT — the
    // `.get('memberSince', {})` default branch, which is a different CEL path
    // from "map present, key missing" and must ALSO fail closed.
    await db.doc(`conversations/${MSG_GROUP_NO_STAMPS}`).set({
      participantIds: [ADULT_UID, FRIEND_UID],
      createdAt: FIXTURE_CREATED_AT,
      isGroup: true,
      groupId: "grp-nostamps",
    });
    // A DIRECT conversation: no groupId, so the cut-off clause is skipped.
    await db.doc(`conversations/${MSG_DIRECT}`).set({
      participantIds: [ADULT_UID, STRANGER_UID],
      createdAt: FIXTURE_CREATED_AT,
      isGroup: false,
    });

    await db.doc(`messages/${MSG_OLD}`).set(
      messageBody(MSG_GROUP, ADULT_UID, T_BEFORE_JOIN)
    );
    await db.doc(`messages/${MSG_NEW}`).set(
      messageBody(MSG_GROUP, ADULT_UID, T_AFTER_JOIN)
    );
    await db.doc(`messages/${MSG_NO_STAMPS}`).set(
      messageBody(MSG_GROUP_NO_STAMPS, ADULT_UID, T_BEFORE_JOIN)
    );
    await db.doc(`messages/${MSG_IN_DIRECT}`).set(
      messageBody(MSG_DIRECT, ADULT_UID, T_BEFORE_JOIN)
    );
  });
}

// M1: ALLOW — a member reads a message sent AFTER their memberSince. The
// fail-closed control for M2: same reader, same conversation, same rule path;
// only `sentAt` differs. Without it M2 could be passing for any reason at all.
test("messages: a group member can read a message sent after their memberSince", async () => {
  const ctx = env.authenticatedContext(FRIEND_UID);
  await assertSucceeds(ctx.firestore().doc(`messages/${MSG_NEW}`).get());
});

// M2: DENY — the same member reading a message sent BEFORE they joined. This is
// the whole ticket: "a new member sees only from now on", enforced in the
// database rather than hidden by the app.
test("messages: a group member cannot read a message sent before their memberSince", async () => {
  const ctx = env.authenticatedContext(FRIEND_UID);
  await assertFails(ctx.firestore().doc(`messages/${MSG_OLD}`).get());
});

// M3: DENY — a PARTICIPANT with no entry in the memberSince map. The map is
// present, the key is missing, so `.get(uid, request.time)` returns request.time
// and nothing is ever old enough. Fails closed: a member with no stamp sees
// NOTHING rather than everything. The message here is one the member would
// otherwise be entitled to (it is newer than FRIEND's stamp), so the deny is
// attributable to the missing key.
test("messages: a group participant with no memberSince entry is denied (fail-closed)", async () => {
  const ctx = env.authenticatedContext(ADULT_UID);
  await assertFails(ctx.firestore().doc(`messages/${MSG_NEW}`).get());
});

// M3B: DENY — the OTHER fail-closed branch: the memberSince map is absent from
// the conversation entirely, so `.get('memberSince', {})` returns its default.
// A different CEL path from M3, and one that a rule spelled
// `resource.data.memberSince[uid]` would turn into an evaluation error instead.
// Consequence, stated rather than hidden: a group conversation carrying a
// groupId but no memberSince map has NO readable messages for anybody.
test("messages: a group with no memberSince map at all denies its members every message", async () => {
  const ctx = env.authenticatedContext(FRIEND_UID);
  await assertFails(ctx.firestore().doc(`messages/${MSG_NO_STAMPS}`).get());
});

// M4: ALLOW — TRUST & SAFETY MUST-HAVE. A moderator (isAdmin) reads a message
// sent long before any join date, in a group they are not a member of. The
// moderation branch is a SEPARATE `allow read, delete: if isAdmin()`, and rules
// OR their allow statements — so the cut-off in the participant branch must not
// reach it. If this ever denies, the moderation preview of a reported message is
// broken and the reports workflow silently shows an empty card.
test("messages: an admin can still read a pre-join message (moderation preview bypasses the cut-off)", async () => {
  const ctx = env.authenticatedContext(ADMIN_UID);
  await assertSucceeds(ctx.firestore().doc(`messages/${MSG_OLD}`).get());
});

// M5: ALLOW — a DIRECT conversation is untouched. The clause is scoped on
// `'groupId' in` the conversation document, and a direct conversation has
// neither groupId nor memberSince, so an old message stays readable. This is
// the test the plan asked for by name: the one pre-existing production
// conversation must not be affected by any of this.
test("messages: a direct conversation's old messages stay readable (no groupId, no cut-off)", async () => {
  const ctx = env.authenticatedContext(ADULT_UID);
  await assertSucceeds(ctx.firestore().doc(`messages/${MSG_IN_DIRECT}`).get());
});

// M6: DENY — the baseline membership check still holds on the read side: a
// non-participant reads nothing, groupId or not.
test("messages: a non-participant cannot read a direct conversation's message", async () => {
  const ctx = env.authenticatedContext(FRIEND_UID);
  await assertFails(ctx.firestore().doc(`messages/${MSG_IN_DIRECT}`).get());
});

// M7: ALLOW — a participant sends a message. The control for M8 and the proof
// that the new membership conjunct does not break the ordinary send path.
test("messages: a conversation participant can create a message", async () => {
  const ctx = env.authenticatedContext(FRIEND_UID, MSG_CLAIMS);
  await assertSucceeds(
    ctx
      .firestore()
      .doc(`messages/m-send-ok-${RUN}`)
      .set(messageBody(MSG_GROUP, FRIEND_UID, new Date()))
  );
});

// M8: DENY — a NON-participant sends into the same conversation. Identical
// claims, identical body shape, identical rule path; only membership differs.
// Before BUT-1838 this succeeded: the rule checked only `auth.uid ==
// senderId`, so anyone who knew a conversation id could write into strangers'
// chats (they could not read the replies, but the message landed).
test("messages: a non-participant cannot create a message in someone else's conversation", async () => {
  const ctx = env.authenticatedContext(STRANGER_UID, MSG_CLAIMS);
  await assertFails(
    ctx
      .firestore()
      .doc(`messages/m-send-deny-${RUN}`)
      .set(messageBody(MSG_GROUP, STRANGER_UID, new Date()))
  );
});

// M9: ALLOW — the SAME actor as M8, sending into a conversation they ARE in.
// Same uid, same claims, same payload shape: this is what makes M8's deny
// attributable to membership rather than to the actor, the claims or the
// account-maturity gate.
test("messages: the same actor can create a message in a conversation they are in", async () => {
  const ctx = env.authenticatedContext(STRANGER_UID, MSG_CLAIMS);
  await assertSucceeds(
    ctx
      .firestore()
      .doc(`messages/m-send-ok2-${RUN}`)
      .set(messageBody(MSG_DIRECT, STRANGER_UID, new Date()))
  );
});

// M10: DENY — a STRING where the timestamp belongs. Before BUT-1896 this
// SUCCEEDED: `hasRequiredFields` pins the key, never the type, and nothing else
// in the create rule looked at `sentAt`.
//
// It is not a cosmetic malformation. Firestore orders values by TYPE and puts
// strings ABOVE every timestamp, so this row wins `orderBy('sentAt','desc')`
// outright — and a DM's message query carries no range filter on the field
// (only a group's memberSince cut-off adds one). One planted message therefore
// pins itself to the top of both participants' history for good.
//
// M9 above is the ALLOW control that makes this deny attributable to the type:
// same actor, same claims, same conversation, same body shape. Only `sentAt`
// differs.
test("messages: a string sentAt is refused (it would win orderBy desc)", async () => {
  const ctx = env.authenticatedContext(STRANGER_UID, MSG_CLAIMS);
  await assertFails(
    ctx
      .firestore()
      .doc(`messages/m-sentat-string-${RUN}`)
      .set({
        ...messageBody(MSG_DIRECT, STRANGER_UID, new Date()),
        sentAt: "nope",
      })
  );
});

// M11: DENY — a NUMBER, the other shape a hand-rolled client reaches for.
// `hasRequiredFields` accepts it too.
//
// NOT for the reason the first draft of this comment gave. It claimed the
// client cannot parse an int and substitutes `clock.now()`; measured against
// `SerializationUtils.parseDateTimeValue:104`, an int parses fine
// (`DateTime.fromMillisecondsSinceEpoch`). That `clock.now()` fallback belongs
// to the STRING and MISSING cases, i.e. M10 and M12 — the claim was
// transplanted from the Cloud Function's comment, where it is about a missing
// stamp and correct.
//
// The real cost of a number: it sorts BELOW every timestamp, so the message
// buries itself out of the `limit(50)` window instead of pinning, and in a
// group it makes the read rule's `sentAt >= memberSince` a cross-type
// comparison.
test("messages: a numeric sentAt is refused", async () => {
  const ctx = env.authenticatedContext(STRANGER_UID, MSG_CLAIMS);
  await assertFails(
    ctx
      .firestore()
      .doc(`messages/m-sentat-number-${RUN}`)
      .set({
        ...messageBody(MSG_DIRECT, STRANGER_UID, new Date()),
        sentAt: 1755561600000,
      })
  );
});

// M12: DENY — the key missing entirely.
//
// This test pins BEHAVIOUR, and it does NOT guard the required-fields list.
// The first draft claimed the opposite ("if someone trims that list this is
// what goes red"), and the rules gate disproved it by running the mutation:
// drop `'sentAt'` from `hasRequiredFields` and NOTHING reddens — not this test
// and not M10, M11 or M13 either. (The first correction wrote a suite total
// here, and it was stale by the time it landed, because M13 arrived in the
// same commit. Name the tests that move; a total is a fact about the file's
// length.) The new
// type conjunct now masks the missing case — indexing an absent key is a CEL
// evaluation error, which denies — so the older conjunct beside it has become
// invisible to this test.
//
// Masking runs in both directions, which is the general lesson: a NEW conjunct
// can hide an OLD one standing next to it. A future editor who trims the list,
// sees green and believes M12 covered them is the specific harm.
test("messages: a missing sentAt is refused", async () => {
  const ctx = env.authenticatedContext(STRANGER_UID, MSG_CLAIMS);
  const body = messageBody(MSG_DIRECT, STRANGER_UID, new Date());
  delete body.sentAt;
  await assertFails(
    ctx.firestore().doc(`messages/m-sentat-missing-${RUN}`).set(body)
  );
});

// M13: DENY — a MAP shaped like a serialised Timestamp,
// `{seconds, nanoseconds}`.
//
// That is the RAW FIRESTORE map shape, which is what `parseDateTimeValue`'s
// own comment calls it. It is not what a JS SDK emits: measured on the
// installed SDK, `Timestamp.toJSON()` produces a three-key map with a `type`
// field, and the Dart-flavoured variant uses `_seconds`/`_nanoseconds`. All
// three are maps and `is timestamp` denies them identically, so coverage is
// unaffected — but the first draft credited the wrong producer, which is the
// same transplanted-rationale slip M11 records.
//
// The rules gate flagged this as the case a hand-rolled client reaches for
// FIRST, and the worst pin shape of the three: maps sit at the very top of
// Firestore's type order — above strings — and `parseDateTimeValue` parses
// this one happily, so it renders as a perfectly normal message while sitting
// permanently at the head of the list. The shipped conjunct closes it, because
// `is timestamp` is false for a map; nothing pinned that until now.
test("messages: a Timestamp-shaped MAP is refused", async () => {
  const ctx = env.authenticatedContext(STRANGER_UID, MSG_CLAIMS);
  await assertFails(
    ctx
      .firestore()
      .doc(`messages/m-sentat-map-${RUN}`)
      .set({
        ...messageBody(MSG_DIRECT, STRANGER_UID, new Date()),
        sentAt: { seconds: 1755561600, nanoseconds: 0 },
      })
  );
});

// M14-M16: BUT-1903, the VALUE route. M10-M13 above all attack the TYPE, and
// the conjunct that stops them says nothing about which instant a well-typed
// Timestamp names. A future one is worse than the string M10 plants: it wins
// the same `orderBy('sentAt','desc')` in a DM AND, being a real timestamp,
// clears the group `memberSince` cut-off and the client's range filter that
// the string tripped over. `shouldReplaceLastMessage` compares with `>=`, so it
// also freezes the chat-list preview every participant sees without opening
// the thread.
//
// The bound is ONE HOUR. It is a chosen ceiling, not a measured skew figure —
// `Message` stamps the device clock, so a tighter number risks locking a real
// user out of chat entirely.
//
// M15 and M16 build their fixtures from `Date.now()` AT TEST-RUN TIME, unlike
// the fixed ISO constants most of this file uses. That is deliberate: they test
// a ROLLING window against `request.time`, and a hardcoded date would silently
// change what it means as real time passes. Do not "fix" them to constants.
// M14 can be a literal, because 9999-12-31 denies whenever it runs.

// M14: DENY — the ticket's own case, a timestamp nine thousand years out.
test("messages: a far-future sentAt is refused", async () => {
  const ctx = env.authenticatedContext(STRANGER_UID, MSG_CLAIMS);
  await assertFails(
    ctx
      .firestore()
      .doc(`messages/m-sentat-year9999-${RUN}`)
      .set(
        messageBody(MSG_DIRECT, STRANGER_UID, new Date("9999-12-31T00:00:00Z"))
      )
  );
});

// M15: DENY — one minute PAST the bound. This is the case that makes the
// conjunct's NUMBER load-bearing rather than its mere existence: M14 would
// still fail under a bound of a century.
test("messages: a sentAt just outside the one-hour bound is refused", async () => {
  const ctx = env.authenticatedContext(STRANGER_UID, MSG_CLAIMS);
  const justOutside = new Date(Date.now() + 61 * 60 * 1000);
  await assertFails(
    ctx
      .firestore()
      .doc(`messages/m-sentat-outside-${RUN}`)
      .set(messageBody(MSG_DIRECT, STRANGER_UID, justOutside))
  );
});

// M16: ALLOW — inside the bound. Without it, tightening the bound to zero would
// pass every other test in this block, and a device running a few minutes fast
// would be locked out of chat with nothing red to show for it.
test("messages: a sentAt inside the one-hour bound is allowed", async () => {
  const ctx = env.authenticatedContext(STRANGER_UID, MSG_CLAIMS);
  const justInside = new Date(Date.now() + 55 * 60 * 1000);
  await assertSucceeds(
    ctx
      .firestore()
      .doc(`messages/m-sentat-inside-${RUN}`)
      .set(messageBody(MSG_DIRECT, STRANGER_UID, justInside))
  );
});

// ============================================================================
// CONVERSATION PARTICIPANTS — roster subcollection (BUT-1482 sprint,
// re-authorized by BUT-1838)
// ============================================================================
//
// `conversations/{id}/participants/{uid}` had NO match block, so every write
// hit default-deny. ConversationParticipantModule writes it in one WriteBatch
// with users/{uid}/conversation_memberships, and addParticipants has no local
// catch — the commit throws up through createDirectConversation /
// createGroupConversation. The flag that gates it, enable_subcollection_
// participants, defaults to TRUE.
//
// BUT-1838 REWROTE THE AUTHORIZATION MODEL HERE. Until 2026-08-13 there were
// two write branches — ATTESTED (the parent conversation names writer AND
// subject) and UNCLAIMED (no parent document yet) — because group creation
// wrote roster rows before the top-level conversation existed. `createChatGroup`
// now writes the group, the conversation and every roster row in ONE Admin-SDK
// transaction, so:
//
//   * `rosterUnclaimed()` is GONE, and so is the textually separate parentless
//     own-row READ fallback. Removing only one of the two would have left the
//     pre-seat residual alive.
//   * `mayWriteRoster()` is now `attestedWriter() && !('groupId' in
//     parentDoc().data)` — a GROUP roster row cannot be written by a client at
//     all, because membership is decided by `addChatGroupMembers` AFTER the
//     minor-membership gate, and a client that could seat a row would route
//     round the gate (and choose what a peer is called in the roster the whole
//     group reads).
//
// Four tests below therefore FLIP from allow to deny (P1, P3B, P14, P24). Each
// flip is the intended signal of this ticket, and each says so at its own site.
// UPDATE's self-lastReadAt branch is deliberately NOT affected by the groupId
// lock — P30 pins that. It is the only per-row UPDATE the lock leaves open to a
// group member; deleting their own row is the other client write on this path.

// Parent EXISTS and names ADULT + FRIEND — the attested branch. No `groupId`,
// so the client write branch is open on it (BUT-1838).
const P_ATT = `p-attested-${RUN}`;
// Attested parent with NO seeded roster rows, so the validator tests below are
// CREATEs rather than updates. Before BUT-1838 they ran against a parentless
// conversation; that route is now denied outright, which would have made every
// one of them pass vacuously — green with validParticipant() deleted.
const P_CREATE = `p-create-${RUN}`;
// Attested parent that DOES carry `groupId` — the Admin-SDK-only roster. Its
// twin P_UNGROUPED is byte-identical except for that one key, which is what
// makes the pair attributable.
const P_GROUPED = `p-grouped-${RUN}`;
const P_UNGROUPED = `p-ungrouped-${RUN}`;
// Attested parent that names the STRANGER — the fail-closed control for P3.
const P_ATT_STRANGER = `p-attested-stranger-${RUN}`;
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
// BUT-1851 gap: a second parentless roster, for the WRITE verbs. Its own id so
// P31's delete cannot take a row out from under P_READ_FRESH's read cases.
const P_ORPHAN_WRITE = `p-orphan-write-${RUN}`;
const P_UPD = `p-update-${RUN}`;
const P_DEL = `p-delete-${RUN}`;
const P_BATCH_GROUP = `p-batch-group-${RUN}`;
// BUT-1838: the direct end-to-end test writes its own parent conversation
// through the CREATE rule, so its id must now BIND to its participants
// (`directIdBinds`). `direct_p-<run>` no longer creates.
const P_BATCH_DIRECT = directId(ADULT_UID, FRIEND_UID);
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
    for (const id of [
      P_ATT,
      P_CREATE,
      P_UPD,
      P_DEL,
      P_BATCH_DENY,
      P_UNGROUPED,
    ]) {
      await db.doc(`conversations/${id}`).set({
        participantIds: [ADULT_UID, FRIEND_UID],
        createdAt: FIXTURE_CREATED_AT,
        isGroup: true,
      });
    }
    // BUT-1838: same shape, plus the one key that locks the roster to the Admin
    // SDK. P_UNGROUPED above is its control.
    await db.doc(`conversations/${P_GROUPED}`).set({
      participantIds: [ADULT_UID, FRIEND_UID],
      createdAt: FIXTURE_CREATED_AT,
      isGroup: true,
      groupId: "grp-roster",
    });
    // A seeded row on the grouped conversation, so the update/self-lastReadAt
    // tests below have something to write to.
    await db
      .doc(`conversations/${P_GROUPED}/participants/${FRIEND_UID}`)
      .set(participantBody(P_GROUPED, FRIEND_UID));
    // The fail-closed control for P3: an attested conversation that DOES name
    // the stranger, so the same actor + same body + same doc-id shape succeeds.
    await db.doc(`conversations/${P_ATT_STRANGER}`).set({
      participantIds: [ADULT_UID, STRANGER_UID],
      createdAt: FIXTURE_CREATED_AT,
      isGroup: true,
    });
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
    // Two orphaned rows, again with no parent: one per write verb, because both
    // branches under test are SELF checks and one uid cannot hold two rows in
    // the same conversation.
    for (const uid of [FRIEND_UID, ADULT_UID]) {
      await db
        .doc(`conversations/${P_ORPHAN_WRITE}/participants/${uid}`)
        .set(participantBody(P_ORPHAN_WRITE, uid));
    }
  });
}

// --- CREATE ---------------------------------------------------------------

// P1: DENY — THE FLIP. This used to be the group-create bootstrap ALLOW: no
// top-level conversation existed yet (UserScopedFirebaseRepository wrote it
// under users/{creator}/conversations) and the creator seated another
// participant through `rosterUnclaimed()`.
//
// BUT-1838 deletes that branch. Group creation no longer runs from a client at
// all — `createChatGroup` writes the conversation and its whole roster in one
// Admin-SDK transaction, where rules do not apply — so a parentless roster write
// is now exactly what it looks like: someone writing into a conversation nobody
// can vouch for. If this ever goes back to ALLOW, the bootstrap branch is back
// and with it the pre-seat residual (P3B) and the orphan residual.
test("participants: nobody can seat a row while the conversation has no top-level document (bootstrap branch removed)", async () => {
  const ctx = env.authenticatedContext(ADULT_UID);
  await assertFails(
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

// P3B: DENY — THE FLIP THIS TICKET EXISTS TO SIGNAL. This test used to ALLOW,
// and its allow WAS the documented residual in ACCEPTED_DEVIATIONS.md: an
// unattested user who knew a never-chatted group's id could seat a roster row
// through `rosterUnclaimed()`, and then LIST the roster — every member's display
// name and avatar URL — through the matching parentless read fallback.
//
// BUT-1838 removes both spellings of "parent absent" in the same edit, so the
// pre-seat is gone. THE FLIP FROM ALLOW TO DENY IS THE INTENDED SIGNAL, not a
// regression: if a future change makes this pass again, the bootstrap branch
// came back and the residual with it.
//
// Its old second job — fail-closed control for P3 — moves to P3D below, which
// keeps the attested route open for the same actor.
test("participants: an unattested user can no longer seat a row when no conversation document exists (BUT-1838 flip)", async () => {
  const ctx = env.authenticatedContext(STRANGER_UID);
  await assertFails(
    ctx
      .firestore()
      .doc(`conversations/${P_UNC_RESIDUAL}/participants/${STRANGER_UID}`)
      .set(participantBody(P_UNC_RESIDUAL, STRANGER_UID))
  );
});

// P3D: ALLOW — the fail-closed control P3 needs now that P3B denies. Same actor
// (STRANGER), same body shape, same doc-id shape; the ONLY difference is that
// this conversation's participantIds NAME the stranger. Without it, P3's deny
// could be about the payload, the persistence or the path, and every attestation
// test in this file would be vacuous.
test("participants: a user named by the conversation CAN seat their own row (fail-closed control for P3)", async () => {
  const ctx = env.authenticatedContext(STRANGER_UID);
  await assertSucceeds(
    ctx
      .firestore()
      .doc(`conversations/${P_ATT_STRANGER}/participants/${STRANGER_UID}`)
      .set(participantBody(P_ATT_STRANGER, STRANGER_UID))
  );
});

// P3C: DENY — a pre-seat on a DM that does not exist yet.
//
// This used to be the narrow case: `rosterUnclaimed()` carried a `direct_`
// exclusion precisely because a direct id is deterministic
// (`direct_${sortedUids[0]}_${sortedUids[1]}`) and uids are enumerable from the
// readable `public_profiles`, so without it a stranger got a DM-existence oracle
// (create succeeds ⇒ these two have never talked) plus a foothold that persisted
// into the real roster.
//
// BUT-1838 removes the whole parentless branch, so this deny is now the GENERAL
// case rather than a special exclusion — P3B denies for the same reason. It is
// kept as a distinct regression pin: if anyone re-introduces a bootstrap branch
// "just for groups", this is the test that says the DM half must not come back
// with it.
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

// BUT-1838: P5–P11 used to run against the PARENTLESS fixture (P_UNC), which
// was the most permissive branch at the time. That branch is gone, so a
// parentless write now denies on attestation before the payload validator is
// ever reached — every one of these deny tests would have passed vacuously, and
// P11's allow would have gone red for the wrong reason. They now run against an
// ATTESTED parent with no seeded roster rows (P_CREATE), so they still exercise
// `validParticipant()` on the CREATE path, which is what they are for.

// P5: DENY — unauthenticated, against an attested conversation whose roster the
// caller would otherwise be allowed to write. Proves the rule requires a
// signed-in caller and not merely a well-formed row.
test("participants: an unauthenticated caller cannot seat a row on an attested roster", async () => {
  const ctx = env.unauthenticatedContext();
  await assertFails(
    ctx
      .firestore()
      .doc(`conversations/${P_CREATE}/participants/${ADULT_UID}`)
      .set(participantBody(P_CREATE, ADULT_UID))
  );
});

// P6: DENY — a key outside the allowlist. hasOnly is the guard the whole sprint
// exists for; this is its positive-control failure case.
test("participants: a row carrying an unknown field is rejected", async () => {
  const ctx = env.authenticatedContext(ADULT_UID);
  await assertFails(
    ctx
      .firestore()
      .doc(`conversations/${P_CREATE}/participants/${ADULT_UID}`)
      .set(participantBody(P_CREATE, ADULT_UID, { nickname: "smeknamn" }))
  );
});

// P7: DENY — a required field missing (isMuted). hasAll's counterpart to P6.
test("participants: a row missing a required field is rejected", async () => {
  const ctx = env.authenticatedContext(ADULT_UID);
  const body = participantBody(P_CREATE, ADULT_UID);
  delete body.isMuted;
  await assertFails(
    ctx.firestore().doc(`conversations/${P_CREATE}/participants/${ADULT_UID}`).set(body)
  );
});

// P8: DENY — the payload's participantId disagrees with the document id.
// Identity is the path; a row that names someone else is a spoof.
test("participants: a row whose participantId field does not match the document id is rejected", async () => {
  const ctx = env.authenticatedContext(ADULT_UID);
  await assertFails(
    ctx
      .firestore()
      .doc(`conversations/${P_CREATE}/participants/${ADULT_UID}`)
      .set(participantBody(P_CREATE, ADULT_UID, { participantId: FRIEND_UID }))
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
      .doc(`conversations/${P_CREATE}/participants/${ADULT_UID}`)
      .set(participantBody(P_CREATE, ADULT_UID, { conversationId: P_ATT }))
  );
});

// P10: DENY — a role outside the ParticipantRole enum.
test("participants: a row with a role outside the enum is rejected", async () => {
  const ctx = env.authenticatedContext(ADULT_UID);
  await assertFails(
    ctx
      .firestore()
      .doc(`conversations/${P_CREATE}/participants/${ADULT_UID}`)
      .set(participantBody(P_CREATE, ADULT_UID, { role: "superuser" }))
  );
});

// P11: ALLOW — the production shape for a user with no avatar: toFirestore
// OMITS avatarUrl when it is null, so the optional-field branch has to hold or
// every avatar-less member breaks conversation creation. Also the fail-closed
// control for P6–P10: same actor, same path, same conversation, only the payload
// differs.
test("participants: a row omitting the optional avatarUrl is accepted", async () => {
  const ctx = env.authenticatedContext(ADULT_UID);
  await assertSucceeds(
    ctx
      .firestore()
      .doc(`conversations/${P_CREATE}/participants/${ADULT_UID}`)
      .set(participantBody(P_CREATE, ADULT_UID, {}, true))
  );
});

// P27: DENY — the new `!('groupId' in parentDoc().data)` conjunct. The writer is
// fully ATTESTED (the parent names both them and the subject) and the payload is
// valid; the ONLY thing wrong is that this conversation belongs to a chat group.
// Without this conjunct any group member could set() a peer's row directly and
// route round `addChatGroupMembers` — and therefore round the minor-membership
// gate — while also choosing what that peer is called in the roster the whole
// group reads.
test("participants: an attested member cannot seat a row on a GROUP conversation's roster", async () => {
  const ctx = env.authenticatedContext(ADULT_UID);
  await assertFails(
    ctx
      .firestore()
      .doc(`conversations/${P_GROUPED}/participants/${ADULT_UID}`)
      .set(participantBody(P_GROUPED, ADULT_UID))
  );
});

// P28: ALLOW — the discriminating control for P27. Same actor, same subject,
// same payload; the fixture conversation is byte-identical except that it
// carries NO `groupId`. Direct conversations keep their client-written roster
// (ConversationParticipantModule.addParticipants, flag default TRUE), so if this
// denies, group chat is safe and DM creation is broken.
test("participants: the same attested member CAN seat the same row when the conversation has no groupId", async () => {
  const ctx = env.authenticatedContext(ADULT_UID);
  await assertSucceeds(
    ctx
      .firestore()
      .doc(`conversations/${P_UNGROUPED}/participants/${ADULT_UID}`)
      .set(participantBody(P_UNGROUPED, ADULT_UID))
  );
});

// P29: DENY — the groupId lock holds on UPDATE too, not just create. The (u2)
// whole-row re-set branch routes through the same mayWriteRoster(), and a rule
// that guarded only create would let a member rewrite an existing peer's
// display name in the group roster.
test("participants: an attested member cannot rewrite another member's row on a GROUP conversation", async () => {
  const ctx = env.authenticatedContext(ADULT_UID);
  await assertFails(
    ctx
      .firestore()
      .doc(`conversations/${P_GROUPED}/participants/${FRIEND_UID}`)
      .set(participantBody(P_GROUPED, FRIEND_UID, { displayName: "Kapad" }))
  );
});

// P30: ALLOW — the groupId lock deliberately does NOT reach the (u1) self
// read-cursor branch, which never calls mayWriteRoster(). It is the only
// per-row UPDATE the lock leaves open to a group member, besides deleting their
// own row (`allow delete` is a bare self check). Its writer, updateLastRead,
// has NO production caller today — firestore.rules says so at the branch — and
// unread counts read `conversations.lastReadTimestamps`, not this row, so
// freezing it would break nothing right now. Kept open because it is the
// intended client cursor write, not because anything depends on it. Stated as a
// test rather than a comment because "the roster is server-written" reads like
// it should deny.
test("participants: a group member can still stamp their OWN lastReadAt on a GROUP roster row", async () => {
  const ctx = env.authenticatedContext(FRIEND_UID);
  await assertSucceeds(
    ctx
      .firestore()
      .doc(`conversations/${P_GROUPED}/participants/${FRIEND_UID}`)
      .update({ lastReadAt: new Date() })
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
// HISTORY: the read rule USED TO carry an own-row fallback scoped to
// `parentDoc() == null`, and this was the test that proved the scope was load-
// bearing. BUT-1838 deleted the fallback outright, so today this pins the plain
// attestation rule — a strictly stronger version of the same guarantee, which is
// why the test still passes unchanged. Unscoped, a row would have
// granted roster LIST forever — which mattered because
// `enforceGroupMinorMembership` USED TO evict a minor by deleting only the
// membership mirror, leaving this row in place. That half is closed in code as
// of 2026-08-12: the trigger clears the roster too. The scope mattered because
// that delete is best-effort and a row can survive it — without it, an evicted
// MINOR would have kept reading every member's name and avatar. BUT-1838 then
// removed the fallback entirely, which closes the same case outright.
//
// The pair is P12 (member named by a LIVE parent → ALLOW) against this
// (row exists, LIVE parent excludes → DENY). Re-introduce the fallback UNSCOPED
// and this reddens together with P14, whose fixture stages the same predicate
// over an absent parent; re-introduce it SCOPED to `parentDoc() == null` and
// only P14 reddens. That pair is the mutation to run if anyone proposes
// bringing it back.
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

// P14: DENY — THE FLIP. This used to be the own-row read fallback: with no
// top-level conversation document, parent attestation was impossible, so the
// reader's own seeded row was accepted as evidence.
//
// That fallback was a SECOND, textually separate spelling of the same "parent
// absent" idea as `rosterUnclaimed()`. Removing only the WRITE half would have
// left the pre-seat residual fully alive — seat a row while the parent does not
// exist, then list the roster forever — so BUT-1838 removed both in one edit.
//
// The cost is real and accepted: an orphaned roster row (a conversation deleted
// out from under it) is now simply unreadable. That is the intended outcome, and
// it is why the backfill BUT-1839 was closed unbuilt.
test("participants: an own row no longer grants the roster when the conversation document is absent (BUT-1838 flip)", async () => {
  const ctx = env.authenticatedContext(FRIEND_UID);
  await assertFails(
    ctx.firestore().collection(`conversations/${P_READ_FRESH}/participants`).get()
  );
});

// P15: DENY — the same parentless roster read by someone with no row in it.
// Kept as the pair to P14: both now deny, and if EITHER flips back to allow the
// parentless read branch was re-introduced.
test("participants: a non-member cannot LIST the roster of a conversation with no top-level document", async () => {
  const ctx = env.authenticatedContext(STRANGER_UID);
  await assertFails(
    ctx.firestore().collection(`conversations/${P_READ_FRESH}/participants`).get()
  );
});

// --- UPDATE ---------------------------------------------------------------

// P16: ALLOW — updateLastRead: the row's own subject stamps their read cursor.
// updateLastRead has no production caller outside its own module today, so
// this pins the rule rather than a live path.
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
// real "remove member" runs in the removeChatGroupMember Cloud Function under
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

// P24: DENY — THE FLIP. This is the exact batch
// ConversationParticipantModule.addParticipants used to commit on the GROUP
// path: one participant row AND one users/{uid}/conversation_memberships row per
// participant, atomically, with no top-level conversation document in existence.
//
// Under BUT-1838 a client does not create groups at all — `createChatGroup` does
// it under the Admin SDK after the minor-membership gate has cleared every
// member — so this whole batch must now be refused. The client code that built
// it is removed in the same ticket (Etapp 3, behind `enable_chat_groups`).
//
// A batch is all-or-nothing, so the assertion says only "this commit fails". The
// attributable half is P1 above, which denies the roster row on its own.
test("participants: the client's old create-group batch (3 rosters + 3 memberships, no parent doc) is now denied end to end", async () => {
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
  await assertFails(batch.commit());
});

// P25: ALLOW — the DIRECT path in full, and after BUT-1838 the ONLY end-to-end
// client path left: the client writes the top-level conversation first
// (awaited), then commits the 2+2 batch. It is the load-bearing allow of this
// whole block — every deny above survives a rule that froze the roster
// completely, and only this one would go red.
//
// The conversation id now BINDS to its participants (`directIdBinds`), so this
// also proves the new create rule and the roster block do not fight each other.
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

// --- ORPHANED ROSTER ROWS, WRITE VERBS (BUT-1851 gap) ----------------------
//
// P14/P15 pin that a parentless row cannot be READ. Only the read verb used
// that fixture, which left the shorthand "every predicate on this path reads
// through the parent" available to a future reader. It is false, and the two
// cases below are the measurement: the (u1) self-cursor update branch and
// `allow delete` are both pure SELF checks that never call `parentDoc()`, so an
// orphaned row's own subject can still stamp it and still remove it.
//
// It does not widen anything: the row is unreadable either way, and both
// branches gate on `participantId == request.auth.uid`.

// P31: ALLOW — the self-cursor update branch on an orphaned row.
test("participants: the subject of an ORPHANED row can still stamp their own lastReadAt", async () => {
  const ctx = env.authenticatedContext(FRIEND_UID);
  await assertSucceeds(
    ctx
      .firestore()
      .doc(`conversations/${P_ORPHAN_WRITE}/participants/${FRIEND_UID}`)
      .update({ lastReadAt: new Date() })
  );
});

// P32: ALLOW — `allow delete` on an orphaned row. Runs after P31 and on a
// different row, so neither disturbs the other.
test("participants: the subject of an ORPHANED row can still delete it", async () => {
  const ctx = env.authenticatedContext(ADULT_UID);
  await assertSucceeds(
    ctx
      .firestore()
      .doc(`conversations/${P_ORPHAN_WRITE}/participants/${ADULT_UID}`)
      .delete()
  );
});

async function run(): Promise<void> {
  console.log(
    "conversations rules tests — minor-DM gate (BUT-674), creator binding " +
      "(BUT-1788), id binding + group history cut-off + roster lock (BUT-1838)\n"
  );
  console.log("========================================\n");
  await setup();
  await seedUpdateFixtures();
  await seedStampFixtures();
  await seedMessageFixtures();
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
