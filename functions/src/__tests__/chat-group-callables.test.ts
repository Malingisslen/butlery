/**
 * BUT-1838: unit tests for the three chat-group callables' dependency-injected
 * cores — `createChatGroupWithDeps`, `addChatGroupMembersWithDeps` and the
 * group-teardown half of `removeChatGroupMemberWithDeps`.
 *
 * These cover what the pure suites structurally cannot. `minor-membership-gate`
 * proves the POLICY (who is refused); this proves the callables OBEY it —
 * refusing before any document is written, rather than writing and then
 * evicting, which is precisely what the old trigger-only design did.
 *
 * The removal callable's authorization is NOT re-tested here; it lives in
 * `remove-chat-group-member.test.ts`, moved there from the BUT-1788 suite. What
 * this file adds for removal is the EMPTY-GROUP teardown and its gate: the
 * `tryClearRoster` verdict that decides whether the conversation may be deleted.
 * That gate is the shape the repo has been burned by — a boolean verdict
 * guarding a destructive delete is invisible to any suite whose fixtures all
 * make the verdict TRUE — so both outcomes are fixtures here.
 *
 * The fake applies writes (see `_fake-firestore.ts`), so "wrote nothing" is an
 * assertion about the store and not merely about a recorded payload.
 *
 * Run with: npx ts-node src/__tests__/chat-group-callables.test.ts
 */

import * as admin from "firebase-admin";
import { runTests, assertEqual, UnitCase } from "./_unit-runner";
import { FakeFirestore } from "./_fake-firestore";
import { createChatGroupWithDeps } from "../groups/create-chat-group";
import { addChatGroupMembersWithDeps } from "../groups/add-chat-group-members";
import { removeChatGroupMemberWithDeps } from "../groups/remove-chat-group-member";
import { MAX_CHAT_GROUP_MEMBERS } from "../groups/minor-membership-gate";

if (!admin.apps.length) {
  admin.initializeApp({ projectId: "butlery-test-chat-group-callables" });
}

interface CapturedError {
  code: string;
  message: string;
  details: unknown;
}

async function capture(fn: () => Promise<unknown>): Promise<CapturedError> {
  try {
    await fn();
    return { code: "", message: "(no error thrown)", details: undefined };
  } catch (e) {
    const err = e as { code?: string; message?: string; details?: unknown };
    return {
      code: err.code ?? String(e),
      message: err.message ?? "",
      details: err.details,
    };
  }
}

function seedProfile(fake: FakeFirestore, uid: string, displayName: string): void {
  fake.seed(`public_profiles/${uid}`, { displayName, avatarUrl: null });
}

/** A user document with the minor flag the gate reads. */
function seedUser(fake: FakeFirestore, uid: string, isMinor: boolean): void {
  fake.seed(`users/${uid}`, { isMinor });
}

/** The directional friend edge: users/{minor}/friends/{adder}. */
function seedFriend(fake: FakeFirestore, minorUid: string, adderUid: string): void {
  fake.seed(`users/${minorUid}/friends/${adderUid}`, { createdAt: null });
}

const EARLIER = admin.firestore.Timestamp.fromMillis(1_500_000_000_000);

/**
 * An existing group with its conversation and roster, as `stageGroupCreation`
 * would have left them — every document an add or a remove has to touch.
 */
function seedExistingGroup(
  fake: FakeFirestore,
  members: string[],
  admins: string[],
): void {
  const perUid = <T>(value: T): Record<string, T> =>
    Object.fromEntries(members.map((uid) => [uid, value]));
  fake.seed("chat_groups/g1", {
    name: "Familjen",
    memberIds: members,
    adminIds: admins,
    memberDisplayNames: Object.fromEntries(members.map((u) => [u, u])),
    memberAvatarUrls: perUid<string | null>(null),
    memberAddedBy: perUid(members[0]),
    conversationId: "c1",
    createdBy: members[0],
    createdAt: EARLIER,
    updatedAt: EARLIER,
  });
  fake.seed("conversations/c1", {
    participantIds: members,
    participantDisplayNames: Object.fromEntries(members.map((u) => [u, u])),
    participantAvatarUrls: perUid<string | null>(null),
    lastReadTimestamps: perUid(EARLIER),
    perUserSettings: {},
    memberSince: perUid(EARLIER),
    groupId: "g1",
    isGroup: true,
    title: "Familjen",
  });
  for (const uid of members) {
    fake.seed(`conversations/c1/participants/${uid}`, {
      conversationId: "c1",
      participantId: uid,
      joinedAt: EARLIER,
    });
    fake.seed(`users/${uid}/conversation_memberships/c1`, { convId: "c1" });
    seedProfile(fake, uid, uid);
  }
}

function messagePaths(fake: FakeFirestore): string[] {
  return fake.childPaths("messages");
}

const cases: UnitCase[] = [
  // --- createChatGroupWithDeps ---------------------------------------------
  {
    // THE point of the redesign. The old trigger could only evict AFTER the
    // group existed, because it fired on the write; here the refusal happens
    // before anything is created, and it names who could not be added so the
    // caller can be told.
    name: "create refuses a blocked minor BEFORE any document is written",
    fn: async () => {
      const fake = new FakeFirestore();
      seedUser(fake, "creator", false);
      seedUser(fake, "minor", true); // no friend edge → the adder is a stranger
      seedProfile(fake, "creator", "Ada");
      seedProfile(fake, "minor", "Moa");

      const err = await capture(() =>
        createChatGroupWithDeps(fake.db, "creator", "Familjen", ["creator", "minor"]),
      );
      assertEqual(err.code, "permission-denied", "refusal code");
      assertEqual(
        JSON.stringify((err.details as { blockedUserIds?: string[] })?.blockedUserIds),
        JSON.stringify(["minor"]),
        "the refusal names who was blocked",
      );
      assertEqual(fake.writes.length, 0, "not one document written");
      assertEqual(messagePaths(fake).length, 0, "no system message");
    },
  },
  {
    // Positive control for the case above: same fixture plus the friend edge.
    // Without it, a gate that refused EVERYTHING would pass the refusal test.
    name: "create admits a minor whose friend is the creator",
    fn: async () => {
      const fake = new FakeFirestore();
      seedUser(fake, "creator", false);
      seedUser(fake, "minor", true);
      seedFriend(fake, "minor", "creator");
      seedProfile(fake, "creator", "Ada");
      seedProfile(fake, "minor", "Moa");

      const res = await createChatGroupWithDeps(fake.db, "creator", "Familjen", [
        "creator",
        "minor",
      ]);
      assertEqual(res.memberCount, 2, "both members seated");
      const group = fake.read(`chat_groups/${res.groupId}`) ?? {};
      assertEqual(
        (group.memberIds as string[]).includes("minor"),
        true,
        "the friend-added minor is in the group",
      );
    },
  },
  {
    // The caller is always a member and the only admin at birth. (The
    // `[...new Set([callerUid, ...requested])]` injection itself lives in the
    // onCall wrapper above this core, which needs an auth context and App Check
    // to reach; what is pinned here is that the core seats whoever it is handed
    // as member, admin, roster row and conversation participant — the four
    // places a missing seat would strand them.)
    name: "create seats the caller as a member and the sole admin",
    fn: async () => {
      const fake = new FakeFirestore();
      seedProfile(fake, "creator", "Ada");
      seedProfile(fake, "friend", "Bea");

      const res = await createChatGroupWithDeps(fake.db, "creator", "Familjen", [
        "creator",
        "friend",
      ]);
      const group = fake.read(`chat_groups/${res.groupId}`) ?? {};
      assertEqual(
        JSON.stringify(group.memberIds),
        JSON.stringify(["creator", "friend"]),
        "memberIds",
      );
      assertEqual(JSON.stringify(group.adminIds), JSON.stringify(["creator"]), "adminIds");
      assertEqual(group.createdBy, "creator", "createdBy");
      assertEqual(
        (group.memberAddedBy as Record<string, string>).friend,
        "creator",
        "memberAddedBy records who seated each member — the backstop reads it",
      );
      const convo = fake.read(`conversations/${res.conversationId}`) ?? {};
      assertEqual(
        (convo.participantIds as string[]).includes("creator"),
        true,
        "the caller is a conversation participant",
      );
      assertEqual(
        fake.has(`conversations/${res.conversationId}/participants/creator`),
        true,
        "the caller has a roster row",
      );
      assertEqual(
        (convo.groupId as string) === res.groupId,
        true,
        "the conversation carries groupId — what makes the history cut-off apply to it",
      );
    },
  },
  {
    // D1: "joined when" is stored three times because three readers need it and
    // none can read the others. The mitigation is that all three are written
    // HERE, from ONE value — which is a property a test can assert exactly,
    // rather than a property of how Firestore resolves a serverTimestamp
    // sentinel per document.
    name: "the three copies of the join stamp are byte-identical",
    fn: async () => {
      const fake = new FakeFirestore();
      seedProfile(fake, "creator", "Ada");
      seedProfile(fake, "friend", "Bea");

      const res = await createChatGroupWithDeps(fake.db, "creator", "Familjen", [
        "creator",
        "friend",
      ]);
      const convo = fake.read(`conversations/${res.conversationId}`) ?? {};
      const roster =
        fake.read(`conversations/${res.conversationId}/participants/friend`) ?? {};
      const group = fake.read(`chat_groups/${res.groupId}`) ?? {};

      const memberSince = (convo.memberSince as Record<string, admin.firestore.Timestamp>)
        .friend;
      assertEqual(
        memberSince.isEqual(roster.joinedAt as admin.firestore.Timestamp),
        true,
        "conversation memberSince == roster joinedAt",
      );
      assertEqual(
        memberSince.isEqual(group.createdAt as admin.firestore.Timestamp),
        true,
        "and both == the group's createdAt",
      );
    },
  },
  {
    // Display names come from `public_profiles`, never from the request. The old
    // client path passed them, which let whoever created a group decide what
    // everyone else was called inside it — a name the whole group then sees in
    // the roster. A member with no profile gets a neutral placeholder rather
    // than failing the invite.
    name: "create reads member names from public_profiles, with a placeholder for none",
    fn: async () => {
      const fake = new FakeFirestore();
      seedProfile(fake, "creator", "Ada");
      // No profile for "newbie" — a real state for a fresh account.

      const res = await createChatGroupWithDeps(fake.db, "creator", "Familjen", [
        "creator",
        "newbie",
      ]);
      const names = (fake.read(`chat_groups/${res.groupId}`)?.memberDisplayNames ??
        {}) as Record<string, string>;
      assertEqual(names.creator, "Ada", "profile name used");
      assertEqual(names.newbie, "?", "missing profile falls back, it does not fail");
    },
  },
  {
    name: "create writes exactly one system message, carrying the Art. 17 handle",
    fn: async () => {
      const fake = new FakeFirestore();
      seedProfile(fake, "creator", "Ada");
      seedProfile(fake, "friend", "Bea");

      await createChatGroupWithDeps(fake.db, "creator", "Familjen", [
        "creator",
        "friend",
      ]);
      const paths = messagePaths(fake);
      assertEqual(paths.length, 1, "exactly one system message");
      const msg = fake.read(paths[0]) ?? {};
      assertEqual(msg.senderId, "system", "system-authored row");
      assertEqual(msg.content, 'Ada skapade gruppen "Familjen"', "content");
      const meta = (msg.metadata ?? {}) as Record<string, unknown>;
      assertEqual(meta.subjectUserId, "creator", "subjectUserId is the erasure handle");
      assertEqual(meta.systemEvent, "group_created", "systemEvent labels the row");
    },
  },

  // --- addChatGroupMembersWithDeps -----------------------------------------
  {
    // Admins only — the rule the client already pretended to enforce in
    // `GroupDetailViewModel.addMembers`, now enforced where a tampered client
    // cannot skip it.
    name: "add is admin-only: an ordinary member is refused and writes nothing",
    fn: async () => {
      const fake = new FakeFirestore();
      seedExistingGroup(fake, ["admin", "member"], ["admin"]);
      seedProfile(fake, "newbie", "Nils");

      const err = await capture(() =>
        addChatGroupMembersWithDeps(fake.db, "member", "g1", ["newbie"]),
      );
      assertEqual(err.code, "permission-denied", "refusal code");
      assertEqual(fake.writes.length, 0, "nothing written");
      assertEqual(
        (fake.read("chat_groups/g1")?.memberIds as string[]).length,
        2,
        "membership untouched",
      );
    },
  },
  {
    // NO ORACLE: "no such group" and "not your group" must be one answer, or a
    // group id in someone else's hands confirms the group exists.
    name: "add tells a non-member and a stranger the same thing",
    fn: async () => {
      const fake = new FakeFirestore();
      seedExistingGroup(fake, ["admin", "member"], ["admin"]);

      const outsider = await capture(() =>
        addChatGroupMembersWithDeps(fake.db, "stranger", "g1", ["newbie"]),
      );
      const missing = await capture(() =>
        addChatGroupMembersWithDeps(fake.db, "stranger", "no-such-group", ["newbie"]),
      );
      assertEqual(outsider.code, "permission-denied", "outsider code");
      assertEqual(missing.code, "permission-denied", "missing-group code");
      assertEqual(outsider.message, missing.message, "byte-identical message");
      assertEqual(fake.writes.length, 0, "no writes on either probe");
    },
  },
  {
    // Idempotency: re-adding people who are already in writes nothing and spams
    // no system message — a double-tap, or a retry after a dropped response.
    name: "add is idempotent for a member who is already in",
    fn: async () => {
      const fake = new FakeFirestore();
      seedExistingGroup(fake, ["admin", "member"], ["admin"]);

      const res = await addChatGroupMembersWithDeps(fake.db, "admin", "g1", ["member"]);
      assertEqual(res.success, true, "success");
      assertEqual(JSON.stringify(res.addedUserIds), "[]", "nobody newly added");
      assertEqual(res.memberCount, 2, "count unchanged");
      assertEqual(fake.writes.length, 0, "no writes at all");
      assertEqual(messagePaths(fake).length, 0, "no system message");
    },
  },
  {
    // The cap bounds the gate's read fan-out AND the size of the five uid-keyed
    // maps on the conversation document. Refused as a whole rather than
    // partially applied: seating some of a batch would leave the caller unsure
    // who is in.
    name: "add refuses a batch that would exceed MAX_CHAT_GROUP_MEMBERS",
    fn: async () => {
      const fake = new FakeFirestore();
      const existing = Array.from(
        { length: MAX_CHAT_GROUP_MEMBERS - 1 },
        (_, i) => `m${i}`,
      );
      seedExistingGroup(fake, ["admin", ...existing], ["admin"]);
      seedProfile(fake, "x1", "X1");
      seedProfile(fake, "x2", "X2");

      const err = await capture(() =>
        addChatGroupMembersWithDeps(fake.db, "admin", "g1", ["x1", "x2"]),
      );
      assertEqual(err.code, "invalid-argument", "refusal code");
      assertEqual(fake.writes.length, 0, "nothing written");
      assertEqual(
        (fake.read("chat_groups/g1")?.memberIds as string[]).length,
        MAX_CHAT_GROUP_MEMBERS,
        "the group stays exactly at the cap",
      );
    },
  },
  {
    // The BUT-1838 property in one line: the gate runs at INVITE time, against
    // the person doing the inviting. Before this, `enforceGroupMinorMembership`
    // fired on conversation CREATE, so anyone added later was checked by nobody.
    name: "add refuses a minor whose friend the adder is not, before any write",
    fn: async () => {
      const fake = new FakeFirestore();
      seedExistingGroup(fake, ["admin", "member"], ["admin"]);
      seedUser(fake, "minor", true);
      seedProfile(fake, "minor", "Moa");
      // The minor IS a friend of "member" — but "admin" is doing the adding,
      // and it is the adder the gate has to ask about.
      seedFriend(fake, "minor", "member");

      const err = await capture(() =>
        addChatGroupMembersWithDeps(fake.db, "admin", "g1", ["minor"]),
      );
      assertEqual(err.code, "permission-denied", "refusal code");
      assertEqual(
        JSON.stringify((err.details as { blockedUserIds?: string[] })?.blockedUserIds),
        JSON.stringify(["minor"]),
        "the refusal names who was blocked",
      );
      assertEqual(fake.writes.length, 0, "nothing written");
      assertEqual(
        fake.has("conversations/c1/participants/minor"),
        false,
        "no roster row for a refused member",
      );
    },
  },
  {
    // The happy path, and the property that makes "sees only from now on" work:
    // the new member's stamp is the moment they were added, while an EXISTING
    // member's stamp is never restamped — re-stamping would silently erase
    // history someone already had access to.
    name: "a seated member gets a fresh stamp; an existing member's is untouched",
    fn: async () => {
      const fake = new FakeFirestore();
      seedExistingGroup(fake, ["admin", "member"], ["admin"]);
      seedProfile(fake, "newbie", "Nils");

      // The batch deliberately names an EXISTING member as well as a new one:
      // with only new uids in it, "an existing member's stamp is untouched"
      // would hold for any writer that simply never saw them, and the assertion
      // below would pin nothing about the already-in filter.
      const res = await addChatGroupMembersWithDeps(fake.db, "admin", "g1", [
        "newbie",
        "member",
      ]);
      assertEqual(JSON.stringify(res.addedUserIds), JSON.stringify(["newbie"]), "added");
      assertEqual(res.memberCount, 3, "count");

      const group = fake.read("chat_groups/g1") ?? {};
      assertEqual(
        (group.memberIds as string[]).includes("newbie"),
        true,
        "group membership",
      );
      assertEqual(
        (group.memberAddedBy as Record<string, string>).newbie,
        "admin",
        "memberAddedBy names the adder — the backstop trigger judges against it",
      );
      assertEqual(
        (group.memberDisplayNames as Record<string, string>).newbie,
        "Nils",
        "name from public_profiles",
      );

      const convo = fake.read("conversations/c1") ?? {};
      const stamps = convo.memberSince as Record<string, admin.firestore.Timestamp>;
      assertEqual(
        stamps.member.isEqual(EARLIER),
        true,
        "an existing member's cut-off is NOT restamped",
      );
      assertEqual(
        stamps.newbie.isEqual(EARLIER),
        false,
        "the new member's cut-off is the moment they were added",
      );
      const roster = fake.read("conversations/c1/participants/newbie") ?? {};
      assertEqual(
        stamps.newbie.isEqual(roster.joinedAt as admin.firestore.Timestamp),
        true,
        "the roster mirror is written from the same value",
      );
      assertEqual(messagePaths(fake).length, 1, "one system message for one addition");
    },
  },

  // --- removeChatGroupMemberWithDeps: the empty-group teardown --------------
  {
    // The last member out takes the group down with them. ORDER MATTERS and it
    // is the opposite of the obvious one: roster rows first, then the
    // conversation, then the group — deleting the conversation is what orphans
    // rows that carry names and avatars under a parent nobody can produce.
    name: "the last member leaving deletes the roster, the conversation and the group",
    fn: async () => {
      const fake = new FakeFirestore();
      seedExistingGroup(fake, ["solo"], ["solo"]);

      const res = await removeChatGroupMemberWithDeps(fake.db, "solo", "g1", "solo");
      assertEqual(res.removed, true, "removed");
      assertEqual(res.remainingMembers, 0, "group is empty");
      assertEqual(fake.childPaths("conversations/c1/participants").length, 0, "roster cleared");
      assertEqual(fake.has("conversations/c1"), false, "conversation deleted");
      assertEqual(fake.has("chat_groups/g1"), false, "group deleted");

      const order = fake.writes
        .filter((w) => w.op === "delete")
        .map((w) => w.path);
      assertEqual(
        order.indexOf("conversations/c1") < order.indexOf("chat_groups/g1"),
        true,
        "the conversation goes before the group",
      );
      assertEqual(
        order.indexOf("conversations/c1/participants/solo") <
          order.indexOf("conversations/c1"),
        true,
        "and the roster row goes before the conversation",
      );
    },
  },
  {
    // THE GATE, with the verdict FALSE. A boolean guarding a destructive delete
    // is invisible to a suite whose fixtures all make it true — measured once
    // already on this very trigger family, where neutralising the gate left the
    // whole suite green. Here a roster row refuses to delete, so
    // `tryClearRoster` reports false and BOTH documents must survive: an empty
    // group whose documents linger is untidy, but an unreachable set of rows
    // carrying people's names is a disclosure.
    name: "an unclearable roster leaves the conversation and the group standing",
    fn: async () => {
      const fake = new FakeFirestore({
        failDeleteAt: (path) => path === "conversations/c1/participants/ghost",
      });
      seedExistingGroup(fake, ["solo"], ["solo"]);
      // A row no uid list can name — the roster is enumerated, not derived, and
      // this one cannot be cleared.
      fake.seed("conversations/c1/participants/ghost", {
        conversationId: "c1",
        participantId: "ghost",
      });

      const res = await removeChatGroupMemberWithDeps(fake.db, "solo", "g1", "solo");
      assertEqual(res.removed, true, "the access cut still happened");
      assertEqual(res.remainingMembers, 0, "group is empty");
      assertEqual(fake.has("conversations/c1"), true, "conversation NOT deleted");
      assertEqual(fake.has("chat_groups/g1"), true, "group NOT deleted");
      assertEqual(
        (fake.read("chat_groups/g1")?.memberIds as string[]).length,
        0,
        "the membership cut landed even though the teardown declined",
      );
      assertEqual(
        fake.has("conversations/c1/participants/ghost"),
        true,
        "the row that could not be deleted is still there — a partial clear is the worst outcome",
      );
    },
  },
];

void runTests("chat-group callables — create / add / remove cores", cases);
