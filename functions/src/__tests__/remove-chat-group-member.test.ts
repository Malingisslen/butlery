/**
 * BUT-1838: unit tests for the remove-member / leave-group callable's pure core
 * (`authorizeDeparture`), its single write (`stageMemberRemoval`) and its
 * orchestration (`removeChatGroupMemberWithDeps`).
 *
 * **These cases are MOVED, not rewritten.** They come from
 * `leave-group-conversation.test.ts` (BUT-1788), whose callable this replaces:
 * the authorization model carried over unchanged, so its coverage had to carry
 * over with it rather than be re-derived from scratch. Three mechanical
 * adaptations, and nothing else:
 *   - `authorizeDeparture` now takes `{memberIds, adminIds}` from the
 *     `chat_groups` document instead of `{participantIds, isGroup, creatorId}`
 *     from the conversation. "Admin" is an authoritative list rather than a
 *     `metadata.creatorId` field on a document clients can write other parts of,
 *     so every "creator" fixture became an "admin" fixture.
 *   - `buildDepartureUpdate` became `stageMemberRemoval`, which writes THREE
 *     documents (group, conversation, roster row) rather than one, so the
 *     write-shape case asserts all three.
 *   - the write assertions run against a fake that APPLIES the payload, so they
 *     check the resulting document rather than the payload's shape alone.
 *
 * **The one case that is gone by design**: "a direct conversation refuses
 * removal outright" (`isGroup: false` → `failed-precondition`), and its
 * orchestration twin "a 1:1 participant cannot evict the other". The old
 * callable took a CONVERSATION id, so a 1:1 thread was addressable and the
 * refusal was load-bearing — one half of a DM could otherwise cut the other's
 * access to the whole history. This callable takes a GROUP id and reads the
 * conversation id off the group document, so a direct conversation cannot be
 * named at all: there is no branch left to guard, and a test asserting the
 * refusal would have to fabricate a `chat_groups` document pointing at a DM,
 * i.e. assert on a state no writer can produce. Stated rather than silently
 * dropped, because a reader who finds the DM case missing should not conclude
 * the protection was lost.
 *
 * No emulator: the Firestore I/O is thin around these, and the authorization
 * decision is the part a tampered client attacks.
 *
 * Run with: npx ts-node src/__tests__/remove-chat-group-member.test.ts
 */

import * as admin from "firebase-admin";
import { runTests, assertEqual, UnitCase } from "./_unit-runner";
import { FakeFirestore } from "./_fake-firestore";
import {
  authorizeDeparture,
  removeChatGroupMemberWithDeps,
} from "../groups/remove-chat-group-member";
import {
  stageMemberRemoval,
  PER_USER_CONVERSATION_MAPS,
} from "../groups/chat-group-writes";

if (!admin.apps.length) {
  admin.initializeApp({ projectId: "butlery-test-remove-chat-group" });
}

const MEMBERS = ["admin", "member", "other"];
const ADMINS = ["admin"];

function verdict(
  callerUid: string,
  targetUid: string,
  overrides: Partial<{ memberIds: string[]; adminIds: string[] }> = {},
) {
  return authorizeDeparture({
    callerUid,
    targetUid,
    memberIds: overrides.memberIds ?? MEMBERS,
    adminIds: overrides.adminIds ?? ADMINS,
  });
}

// ---------------------------------------------------------------------------
// Fixtures for the ORCHESTRATION half.
//
// A three-person group, its conversation, its roster rows and the per-user
// membership mirrors — every document the removal path touches, so an assertion
// that one of them changed is not an assertion about an absent document.
// ---------------------------------------------------------------------------

const JOINED = admin.firestore.Timestamp.fromMillis(1_600_000_000_000);

function seedGroup(
  fake: FakeFirestore,
  overrides: {
    memberIds?: string[];
    adminIds?: string[];
    conversationId?: string | undefined;
  } = {},
): void {
  const memberIds = overrides.memberIds ?? [...MEMBERS];
  const conversationId =
    "conversationId" in overrides ? overrides.conversationId : "c1";
  const names: Record<string, string> = {
    admin: "Ada",
    member: "Bea",
    other: "Cim",
  };
  const perUid = <T>(value: (uid: string) => T): Record<string, T> =>
    Object.fromEntries(memberIds.map((uid) => [uid, value(uid)]));

  fake.seed("chat_groups/g1", {
    name: "Familjen",
    memberIds,
    adminIds: overrides.adminIds ?? [...ADMINS],
    memberDisplayNames: perUid((uid) => names[uid] ?? "?"),
    memberAvatarUrls: perUid(() => null),
    memberAddedBy: perUid(() => "admin"),
    ...(conversationId === undefined ? {} : { conversationId }),
    createdBy: "admin",
    createdAt: JOINED,
    updatedAt: JOINED,
  });
  fake.seed("conversations/c1", {
    participantIds: memberIds,
    participantDisplayNames: perUid((uid) => names[uid] ?? "?"),
    participantAvatarUrls: perUid(() => null),
    lastReadTimestamps: perUid(() => JOINED),
    perUserSettings: {},
    memberSince: perUid(() => JOINED),
    groupId: "g1",
    isGroup: true,
    title: "Familjen",
  });
  for (const uid of memberIds) {
    fake.seed(`conversations/c1/participants/${uid}`, {
      conversationId: "c1",
      participantId: uid,
      displayName: names[uid] ?? "?",
      joinedAt: JOINED,
    });
    fake.seed(`users/${uid}/conversation_memberships/c1`, { convId: "c1" });
  }
}

async function captureError(fn: () => Promise<unknown>): Promise<string> {
  try {
    await fn();
    return "";
  } catch (e) {
    const err = e as { code?: string };
    return err.code ?? String(e);
  }
}

/** Writes recorded by the fake, excluding the seeding that set the scene. */
function writePaths(fake: FakeFirestore): string[] {
  return fake.writes.map((w) => `${w.op} ${w.path}`);
}

function messages(fake: FakeFirestore): FakeMessage[] {
  return fake
    .childPaths("messages")
    .map((path) => fake.read(path) as unknown as FakeMessage);
}

interface FakeMessage {
  conversationId?: unknown;
  senderId?: unknown;
  type?: unknown;
  content?: unknown;
  metadata?: { systemEvent?: unknown; subjectUserId?: unknown };
}

const cases: UnitCase[] = [
  // --- authorizeDeparture: moved verbatim in substance from BUT-1788 --------
  {
    name: "a member leaving the group is allowed",
    fn: () => assertEqual(verdict("member", "member").kind, "proceed", "self-leave"),
  },
  {
    name: "the admin leaving their own group is allowed",
    fn: () =>
      assertEqual(verdict("admin", "admin").kind, "proceed", "admin self-leave"),
  },
  {
    name: "the admin removing another member is allowed",
    fn: () =>
      assertEqual(verdict("admin", "member").kind, "proceed", "admin removal"),
  },
  {
    name: "a non-admin member cannot remove another member",
    fn: () => {
      const v = verdict("member", "other");
      assertEqual(v.kind, "deny", "non-admin removal kind");
      assertEqual(v.kind === "deny" ? v.code : "", "permission-denied", "code");
    },
  },
  {
    name: "an outsider cannot remove a member",
    fn: () => {
      const v = verdict("stranger", "member");
      assertEqual(v.kind, "deny", "outsider kind");
      assertEqual(v.kind === "deny" ? v.code : "", "permission-denied", "code");
    },
  },
  {
    // Fail CLOSED: with no usable admin nobody inherits the removal right —
    // otherwise every member would become one, which is a group-takeover
    // primitive. Was "a group with no recorded creator has no admin".
    name: "a group with no admin has no remover",
    fn: () => {
      const v = verdict("admin", "member", { adminIds: [] });
      assertEqual(v.kind, "deny", "adminless removal kind");
      assertEqual(v.kind === "deny" ? v.code : "", "permission-denied", "code");
    },
  },
  {
    name: "a member can still leave a group with no admin",
    fn: () =>
      assertEqual(
        verdict("member", "member", { adminIds: [] }).kind,
        "proceed",
        "adminless self-leave",
      ),
  },
  {
    // Idempotency: a double-tap or a retry after a dropped response must not
    // write a second "har lämnat gruppen" row into the thread.
    name: "leaving twice is a no-op, not an error",
    fn: () => assertEqual(verdict("gone", "gone").kind, "noop", "repeat self-leave"),
  },
  {
    name: "admin removing an already-removed member is a no-op",
    fn: () => assertEqual(verdict("admin", "gone").kind, "noop", "repeat removal"),
  },
  {
    // Authorization runs before idempotency, so a stranger probing for
    // membership gets the same denial whether or not the uid is present.
    name: "a stranger removing an absent uid is still denied",
    fn: () => assertEqual(verdict("stranger", "gone").kind, "deny", "stranger probe"),
  },
  {
    // Discriminator for the MEMBERSHIP branch. Every other denial fixture is a
    // caller who is neither a member NOR an admin, so the admin check denies
    // them too and deleting `!memberIds.includes(callerUid)` leaves the suite
    // green. Here the caller IS a recorded admin but has already left: only the
    // membership branch can refuse them. (Live state, not hypothetical —
    // `stageMemberRemoval` strips `adminIds` and `memberIds` in one write, but a
    // document written before that, or by a future path, can disagree.)
    name: "an admin who has left the group can no longer remove members",
    fn: () => {
      const v = verdict("admin", "member", { memberIds: ["member", "other"] });
      assertEqual(v.kind, "deny", "departed admin kind");
      assertEqual(v.kind === "deny" ? v.code : "", "permission-denied", "code");
    },
  },

  // --- stageMemberRemoval: the write shape, across all three documents ------
  {
    // Was "the write erases all four uid-keyed maps plus participantIds". There
    // are FIVE maps now (`memberSince` joined them), the group carries three of
    // its own, and the roster row is deleted outright. A missed key leaves a
    // departed member's name on a document they can no longer read — BUT-1705
    // in a new collection.
    name: "the removal write clears every uid-keyed copy in all three documents",
    fn: () => {
      const fake = new FakeFirestore();
      const updates: { path: string; data: Record<string, unknown> }[] = [];
      const deletes: string[] = [];
      const tx = {
        update: (ref: { path: string }, data: Record<string, unknown>) => {
          updates.push({ path: ref.path, data });
        },
        delete: (ref: { path: string }) => deletes.push(ref.path),
        get: () => {
          throw new Error("stageMemberRemoval must not read");
        },
        set: () => {
          throw new Error("stageMemberRemoval must not create documents");
        },
      } as unknown as admin.firestore.Transaction;

      stageMemberRemoval(tx, {
        db: fake.db,
        groupId: "g1",
        conversationId: "c1",
        uid: "u1",
        removedAt: JOINED,
      });

      assertEqual(updates.length, 2, "one update per membership document");
      const group = updates.find((u) => u.path === "chat_groups/g1")?.data ?? {};
      const convo = updates.find((u) => u.path === "conversations/c1")?.data ?? {};

      const removesU1 = (v: unknown) =>
        (v as admin.firestore.FieldValue)?.isEqual?.(
          admin.firestore.FieldValue.arrayRemove("u1"),
        ) === true;
      assertEqual(removesU1(group.memberIds), true, "memberIds arrayRemove");
      // A departing admin loses the right with the membership, in the same
      // write — never an instant where someone administers a group they left.
      assertEqual(removesU1(group.adminIds), true, "adminIds arrayRemove");
      assertEqual(removesU1(convo.participantIds), true, "participantIds arrayRemove");

      const DELETE = admin.firestore.FieldValue.delete();
      for (const map of [
        "memberDisplayNames",
        "memberAvatarUrls",
        "memberAddedBy",
      ]) {
        assertEqual(group[`${map}.u1`], DELETE, `group ${map} key deleted`);
      }
      for (const map of PER_USER_CONVERSATION_MAPS) {
        assertEqual(convo[`${map}.u1`], DELETE, `conversation ${map} key deleted`);
      }
      assertEqual(
        deletes.includes("conversations/c1/participants/u1"),
        true,
        "roster row deleted",
      );
    },
  },
  {
    // Guards the sanitisation contract: the uid is spliced into a FIELD PATH,
    // so a dotted uid would address a nested map and silently leave the name
    // behind. The callable rejects such uids upstream via isValidDocId — this
    // pins that the write is the reason why.
    name: "the write addresses the uid as a single field-path segment",
    fn: () => {
      const fake = new FakeFirestore();
      const keys: string[] = [];
      const tx = {
        update: (_ref: unknown, data: Record<string, unknown>) =>
          keys.push(...Object.keys(data)),
        delete: () => undefined,
      } as unknown as admin.firestore.Transaction;
      stageMemberRemoval(tx, {
        db: fake.db,
        groupId: "g1",
        conversationId: "c1",
        uid: "abc",
        removedAt: JOINED,
      });
      assertEqual(
        keys.includes("participantDisplayNames.abc"),
        true,
        "literal segment key",
      );
    },
  },

  // --- removeChatGroupMemberWithDeps: orchestration ------------------------
  {
    name: "an admin removal empties every copy, clears both mirrors and writes one system message",
    fn: async () => {
      const fake = new FakeFirestore();
      seedGroup(fake);

      const res = await removeChatGroupMemberWithDeps(
        fake.db,
        "admin",
        "g1",
        "member",
      );
      assertEqual(res.removed, true, "removed");
      assertEqual(res.remainingMembers, 2, "remaining after removal");

      const group = fake.read("chat_groups/g1") ?? {};
      assertEqual(
        (group.memberIds as string[]).includes("member"),
        false,
        "memberIds shrank",
      );
      assertEqual((group.memberIds as string[]).length, 2, "the other two remain");
      assertEqual(
        "member" in (group.memberDisplayNames as Record<string, unknown>),
        false,
        "group display name erased",
      );
      // The survivors' entries must outlive the dot-path deletes.
      assertEqual(
        (group.memberDisplayNames as Record<string, string>).admin,
        "Ada",
        "other members' names survive",
      );

      const convo = fake.read("conversations/c1") ?? {};
      assertEqual(
        (convo.participantIds as string[]).includes("member"),
        false,
        "participantIds shrank",
      );
      for (const map of PER_USER_CONVERSATION_MAPS) {
        assertEqual(
          "member" in ((convo[map] ?? {}) as Record<string, unknown>),
          false,
          `conversation ${map} key erased`,
        );
      }

      assertEqual(
        fake.has("conversations/c1/participants/member"),
        false,
        "roster row deleted",
      );
      assertEqual(
        fake.has("conversations/c1/participants/other"),
        true,
        "the cleanup is scoped to the removed uid",
      );
      assertEqual(
        fake.has("users/member/conversation_memberships/c1"),
        false,
        "membership mirror deleted",
      );

      const thread = messages(fake);
      assertEqual(thread.length, 1, "exactly one system message");
      assertEqual(thread[0].conversationId, "c1", "message conversationId");
      assertEqual(thread[0].senderId, "system", "message senderId");
      assertEqual(thread[0].type, "system", "message type");
      // Swedish UI string, mirroring `chatParticipantLeft` in app_sv.arb, with
      // the display name read off the group rather than the "?" fallback.
      assertEqual(thread[0].content, "Bea har lämnat gruppen", "message content");
    },
  },
  {
    // ADDED for BUT-1838 (the pure verdict above cannot see the writes): a
    // plain member holds no admin right at all, and must still be able to get
    // out. A regression that required `adminIds.includes(callerUid)` for every
    // path would trap people in groups.
    name: "a member with no admin right can always leave, and the group survives",
    fn: async () => {
      const fake = new FakeFirestore();
      seedGroup(fake);

      const res = await removeChatGroupMemberWithDeps(
        fake.db,
        "member",
        "g1",
        "member",
      );
      assertEqual(res.removed, true, "self-leave proceeds");
      assertEqual(res.remainingMembers, 2, "real count for a member");
      assertEqual(fake.has("chat_groups/g1"), true, "a viable group is not deleted");
      assertEqual(
        (fake.read("chat_groups/g1")?.adminIds as string[]).includes("admin"),
        true,
        "the admin keeps the right they did not use",
      );
    },
  },
  {
    // ADDED for BUT-1838: the denial has to hold through the ORCHESTRATOR, not
    // just in the pure core — the caller is a genuine member, so the no-oracle
    // gate lets them through and only the admin branch can stop them.
    name: "a non-admin removing someone else is denied and writes nothing",
    fn: async () => {
      const fake = new FakeFirestore();
      seedGroup(fake);

      const code = await captureError(() =>
        removeChatGroupMemberWithDeps(fake.db, "member", "g1", "other"),
      );
      assertEqual(code, "permission-denied", "denial code");
      assertEqual(writePaths(fake).length, 0, "no writes on denial");
      assertEqual(
        (fake.read("chat_groups/g1")?.memberIds as string[]).length,
        3,
        "membership untouched",
      );
      assertEqual(messages(fake).length, 0, "no system message on denial");
    },
  },
  {
    // The idempotency claim in the callable's header. The pure no-op verdict
    // cannot see the writes: only this proves a retry after a dropped response
    // adds no second row to the thread.
    name: "a repeat removal of an absent uid writes absolutely nothing",
    fn: async () => {
      const fake = new FakeFirestore();
      seedGroup(fake);

      const res = await removeChatGroupMemberWithDeps(fake.db, "admin", "g1", "gone");
      assertEqual(res.success, true, "idempotent success");
      assertEqual(res.removed, false, "nothing removed");
      assertEqual(res.remainingMembers, 3, "membership unchanged");
      assertEqual(writePaths(fake).length, 0, "no writes at all");
      assertEqual(messages(fake).length, 0, "no second system message");
    },
  },
  {
    // Best-effort mirror cleanup: the membership cut IS the access revocation,
    // so a mirror failure must not fail the user's leave — and must not skip
    // the system message that follows it.
    name: "a failing mirror cleanup still completes the leave",
    fn: async () => {
      const fake = new FakeFirestore({
        failDeleteAt: (path) => path.includes("conversation_memberships"),
      });
      seedGroup(fake);

      const res = await removeChatGroupMemberWithDeps(
        fake.db,
        "member",
        "g1",
        "member",
      );
      assertEqual(res.success, true, "leave still succeeds");
      assertEqual(res.removed, true, "still removed");
      assertEqual(
        (fake.read("chat_groups/g1")?.memberIds as string[]).includes("member"),
        false,
        "membership write landed",
      );
      assertEqual(messages(fake).length, 1, "system message still written");
    },
  },
  {
    // The system message is decoration on top of an already-committed access
    // cut. If its write could fail the call, the user would be told the leave
    // failed for a group they are already out of — and their retry now hits the
    // no-oracle gate, so they would never get a success.
    name: "a failing system-message write still completes the leave",
    fn: async () => {
      const fake = new FakeFirestore({ failAdds: true });
      seedGroup(fake);

      const res = await removeChatGroupMemberWithDeps(
        fake.db,
        "member",
        "g1",
        "member",
      );
      assertEqual(res.success, true, "leave still succeeds");
      assertEqual(res.removed, true, "still removed");
      assertEqual(res.remainingMembers, 2, "count still reported");
      assertEqual(
        fake.has("users/member/conversation_memberships/c1"),
        false,
        "mirror still cleared",
      );
    },
  },
  {
    // BUT-1788's no-oracle guarantee, carried over. The old callable answered
    // three different ways for a conversation the caller was not in
    // (`not-found`, `failed-precondition`, or a no-op carrying the real member
    // count), which let any signed-in account probe the messaging graph. All of
    // it is now one indistinguishable reply that carries no count.
    name: "a non-member learns nothing about a group they are not in",
    fn: async () => {
      const missing = new FakeFirestore();
      const absent = await removeChatGroupMemberWithDeps(
        missing.db,
        "stranger",
        "no-such-group",
        "stranger",
      );

      const outside = new FakeFirestore();
      seedGroup(outside);
      const outsideGroup = await removeChatGroupMemberWithDeps(
        outside.db,
        "stranger",
        "g1",
        "stranger",
      );

      for (const [label, res] of [
        ["missing group", absent],
        ["group the caller is not in", outsideGroup],
      ] as const) {
        assertEqual(res.success, true, `${label}: uniform success`);
        assertEqual(res.removed, false, `${label}: nothing removed`);
        assertEqual(res.remainingMembers, 0, `${label}: no member count disclosed`);
      }
      assertEqual(writePaths(missing).length, 0, "no write, missing group");
      assertEqual(writePaths(outside).length, 0, "no write, outsider");
      assertEqual(messages(outside).length, 0, "no system message for an outsider");
    },
  },
  {
    // Replaces "a padded participant list is still a group": there is no
    // group-ness test left to fool, but `memberIds` is still SANITISED before
    // anything is counted or spliced into a field path, and the count reported
    // back must reflect that. A junk id is not a member.
    name: "a malformed member id is not counted and cannot be removed",
    fn: async () => {
      const fake = new FakeFirestore();
      seedGroup(fake, { memberIds: ["admin", "member", "a.b"] });

      const res = await removeChatGroupMemberWithDeps(
        fake.db,
        "admin",
        "g1",
        "member",
      );
      assertEqual(res.removed, true, "the real removal proceeds");
      assertEqual(res.remainingMembers, 1, "junk uid not counted");
    },
  },
  {
    // A group whose `conversationId` is missing or malformed has nothing to cut
    // access to. Loud rather than silent, and BEFORE any write — a removal that
    // half-applied would leave the two membership copies disagreeing.
    name: "a group with no usable conversation refuses rather than half-writing",
    fn: async () => {
      const fake = new FakeFirestore();
      seedGroup(fake, { conversationId: undefined });

      const code = await captureError(() =>
        removeChatGroupMemberWithDeps(fake.db, "admin", "g1", "member"),
      );
      assertEqual(code, "failed-precondition", "refusal code");
      assertEqual(writePaths(fake).length, 0, "nothing written");
    },
  },
  {
    // GDPR Art. 17. The row embeds a display name in free text under
    // senderId:"system", which no cascade query can reach — the cascade's
    // `senderId == uid` leg does not match it, and once the person has left,
    // the cascade never visits that conversation at all.
    // `metadata.subjectUserId` is the only queryable handle, and
    // `anonymizeSystemMessagesAboutUser` consumes exactly this field name.
    name: "the departure system message carries an Art. 17 erasure handle",
    fn: async () => {
      const fake = new FakeFirestore();
      seedGroup(fake);
      await removeChatGroupMemberWithDeps(fake.db, "admin", "g1", "member");

      const thread = messages(fake);
      assertEqual(thread.length, 1, "one system message");
      assertEqual(
        thread[0].metadata?.subjectUserId,
        "member",
        "subjectUserId names the person the row is about",
      );
      assertEqual(
        thread[0].metadata?.systemEvent,
        "participant_left",
        "systemEvent labels the row",
      );
    },
  },
];

void runTests("removeChatGroupMember — authorization + write shape", cases);
