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
import {
  removeChatGroupMemberWithDeps,
  MAX_GROUP_MENU_PLANS,
  MAX_TRAIL_ROWS,
  MAX_CONTRIBUTOR_UIDS,
} from "../groups/remove-chat-group-member";
import { stageMemberRemoval } from "../groups/chat-group-writes";
import { stageBackstopRemovals } from "../messaging/enforce-group-minor-membership";
import { MAX_CHAT_GROUP_MEMBERS } from "../groups/minor-membership-gate";
import { RATE_LIMIT_CONFIGS } from "../middleware/rate_limiter";
import * as fs from "fs";
import * as path from "path";

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

  // --- the departure tombstone (BUT-1856) -----------------------------------
  {
    // `departedUserIds` sits on a document every member can read, and the
    // meal-vote sync consults it so "leave the chat" cannot be undone by the
    // next poll. The safety property is the PAIRING: it may only ever hold
    // departures that also produce a visible `memberLeft` row. Hold that, and
    // the array says nothing the group did not already see in the thread; break
    // it, and the difference between the two lists is the set of accounts the
    // child-safety backstop evicted — a durable, queryable claim that someone
    // is a minor.
    name: "a departure that people can SEE is the only kind that is tombstoned",
    fn: async () => {
      const fake = new FakeFirestore();
      seedExistingGroup(fake, ["admin", "leaver"], ["admin"]);

      await removeChatGroupMemberWithDeps(fake.db, "leaver", "g1", "leaver");

      assertEqual(
        ((fake.read("chat_groups/g1")?.departedUserIds as string[]) ?? []).join(","),
        "leaver",
        "tombstoned",
      );
      const systemRows = messagePaths(fake)
        .map((p) => fake.read(p)?.metadata as { subjectUserId?: string } | undefined)
        .filter((m) => m?.subjectUserId === "leaver");
      assertEqual(systemRows.length, 1, "…and it is visible in the thread");
    },
  },
  {
    // The one that matters, and the one an assertion on the callee's DEFAULT
    // cannot make: the backstop's omission is a decision at ITS call site.
    // Restoring `tombstone: true` there left every suite green until this case
    // existed.
    name: "the minor backstop evicts without leaving a tombstone",
    fn: async () => {
      const fake = new FakeFirestore();
      seedExistingGroup(fake, ["adder", "minor"], ["adder"]);

      await fake.db.runTransaction(async (tx) => {
        stageBackstopRemovals(tx as never, {
          db: fake.db,
          groupId: "g1",
          conversationId: "c1",
          uids: ["minor"],
          removedAt: admin.firestore.Timestamp.now(),
        });
      });

      assertEqual(
        fake.read("chat_groups/g1")?.departedUserIds,
        undefined,
        "no departedUserIds field",
      );
      assertEqual(
        ((fake.read("chat_groups/g1")?.memberIds as string[]) ?? []).join(","),
        "adder",
        "…while the eviction itself landed",
      );
    },
  },
  {
    // The callee's default, which is also what the deletion cascade takes.
    name: "a removal staged WITHOUT the flag leaves no tombstone",
    fn: async () => {
      const fake = new FakeFirestore();
      seedExistingGroup(fake, ["admin", "gone"], ["admin"]);

      await fake.db.runTransaction(async (tx) => {
        stageMemberRemoval(tx as never, {
          db: fake.db,
          groupId: "g1",
          conversationId: "c1",
          uid: "gone",
          removedAt: admin.firestore.Timestamp.now(),
        });
      });

      assertEqual(
        fake.read("chat_groups/g1")?.departedUserIds,
        undefined,
        "no departedUserIds field",
      );
      assertEqual(
        ((fake.read("chat_groups/g1")?.memberIds as string[]) ?? []).join(","),
        "admin",
        "…while the removal itself landed",
      );
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

      // BUT-1979: the menu sweep is INDEPENDENT of the roster outcome, so it
      // must have run even though the teardown declined. With the call below
      // the decline this assertion fails, which is what makes it worth having.
      fake.seed("group_weekly_menu_plans/c1_2026-W16", { groupId: "c1" });

      const res = await removeChatGroupMemberWithDeps(fake.db, "solo", "g1", "solo");
      assertEqual(res.removed, true, "the access cut still happened");
      assertEqual(res.remainingMembers, 0, "group is empty");
      assertEqual(
        fake.has("group_weekly_menu_plans/c1_2026-W16"),
        false,
        "the menu plans went even though the roster clear declined",
      );
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
  {
    // BUT-1979, Malin's call 2026-08-28: the group's weekly menu plans go with
    // it. Two plans for this group and one for another are seeded, so the
    // assertion discriminates the FILTER and not merely "something was
    // deleted" — a sweep that took the collection would pass without it.
    //
    // Keyed on the CONVERSATION id, because that is what the producer writes
    // into `groupId` (`messaging_service.dart` passes `groupId:
    // conversation.id`). Seeding the chat-group id instead would exercise a key
    // production never writes.
    //
    // Selected on the `groupId` field rather than the doc-id prefix, which is
    // what makes this provable here at all: the fake models `==` and
    // `array-contains` and THROWS on anything else.
    name: "the last member leaving takes the group's weekly menu plans with it",
    fn: async () => {
      const fake = new FakeFirestore();
      seedExistingGroup(fake, ["solo"], ["solo"]);
      fake.seed("group_weekly_menu_plans/c1_2026-W16", { groupId: "c1" });
      fake.seed("group_weekly_menu_plans/c1_2026-W17", { groupId: "c1" });
      fake.seed("group_weekly_menu_plans/other_2026-W16", { groupId: "other" });

      await removeChatGroupMemberWithDeps(fake.db, "solo", "g1", "solo");

      assertEqual(
        fake.has("group_weekly_menu_plans/c1_2026-W16"),
        false,
        "the group's plan is gone",
      );
      assertEqual(
        fake.has("group_weekly_menu_plans/c1_2026-W17"),
        false,
        "both of its weeks are gone",
      );
      assertEqual(
        fake.has("group_weekly_menu_plans/other_2026-W16"),
        true,
        "another group's plan is untouched",
      );
    },
  },
  {
    // BUT-1971 follow-up. Leaving a group that SURVIVES must cut the leaver's
    // access to its weeks, which `firestore.rules` grants purely off
    // `memberPermissions`. Nothing did this before: the only plan cleanup ran
    // when the group emptied, so a departed member kept read AND write forever.
    //
    // Two members leave one behind, so this exercises the surviving-group path
    // rather than the teardown beside it.
    name: "a member leaving a surviving group loses access to its weeks",
    fn: async () => {
      const fake = new FakeFirestore();
      seedExistingGroup(fake, ["stay", "leaver"], ["stay"]);
      fake.seed("group_weekly_menu_plans/c1_2026-W16", {
        groupId: "c1",
        participants: [
          { userId: "stay", permission: "admin" },
          { userId: "leaver", permission: "edit" },
        ],
        participantUserIds: ["stay", "leaver"],
        memberPermissions: { stay: "admin", leaver: "edit" },
        entries: [{ id: "e1", proposedBy: "leaver", votedInBy: ["leaver"] }],
      });

      await removeChatGroupMemberWithDeps(fake.db, "leaver", "g1", "leaver");

      const plan = fake.read("group_weekly_menu_plans/c1_2026-W16")!;
      assertEqual(
        JSON.stringify(plan.memberPermissions),
        JSON.stringify({ stay: "admin" }),
        "the ACL key the read and update rules test is gone",
      );
      assertEqual(
        JSON.stringify(plan.participantUserIds),
        JSON.stringify(["stay"]),
        "and so is the queryable mirror",
      );
      assertEqual(
        (plan.participants as unknown[]).length,
        1,
        "the roster the projections are recomputed from is the real store",
      );
    },
  },
  {
    // The other half of the same decision, and the reason the array exists:
    // Malin's call 2026-08-30 is that the NAME stays. Cutting access must not
    // quietly take the provenance with it, and the uid must stay reachable by
    // a query or account deletion could never erase it.
    name: "…but their name stays on the dish, and stays findable",
    fn: async () => {
      const fake = new FakeFirestore();
      seedExistingGroup(fake, ["stay", "leaver"], ["stay"]);
      fake.seed("group_weekly_menu_plans/c1_2026-W16", {
        groupId: "c1",
        participants: [
          { userId: "stay", permission: "admin" },
          { userId: "leaver", permission: "edit" },
        ],
        participantUserIds: ["stay", "leaver"],
        memberPermissions: { stay: "admin", leaver: "edit" },
        entries: [{ id: "e1", proposedBy: "leaver", votedInBy: ["leaver"] }],
      });

      await removeChatGroupMemberWithDeps(fake.db, "leaver", "g1", "leaver");

      const plan = fake.read("group_weekly_menu_plans/c1_2026-W16")!;
      const entry = (plan.entries as Record<string, unknown>[])[0];
      assertEqual(entry.proposedBy, "leaver", "the dish still names them");
      assertEqual(
        ((plan.contributorUserIds as string[]) ?? []).includes("leaver"),
        true,
        "and erasure can still find this document by them",
      );
    },
  },
  {
    // Not merely wasteful — it is two capped scans of the same collection on
    // one leave. `deleteEmptyGroup` deletes these very rows immediately after.
    name: "the last member leaving does NOT also rewrite the rows it deletes",
    fn: async () => {
      // The delete is made to FAIL, which is what makes this provable. If the
      // access cut had run first, the surviving document would come back with
      // `solo` already stripped out of it; asserting only that the plan is gone
      // would pass whether or not the cut ran, since the sweep deletes it
      // either way.
      const fake = new FakeFirestore({
        failDeleteAt: (path) => path === "group_weekly_menu_plans/c1_2026-W16",
      });
      seedExistingGroup(fake, ["solo"], ["solo"]);
      fake.seed("group_weekly_menu_plans/c1_2026-W16", {
        groupId: "c1",
        participants: [{ userId: "solo", permission: "admin" }],
        participantUserIds: ["solo"],
        memberPermissions: { solo: "admin" },
      });

      await removeChatGroupMemberWithDeps(fake.db, "solo", "g1", "solo");

      const plan = fake.read("group_weekly_menu_plans/c1_2026-W16")!;
      assertEqual(
        JSON.stringify(plan.memberPermissions),
        JSON.stringify({ solo: "admin" }),
        "untouched — the cut never ran on a group that is being torn down",
      );
      assertEqual(
        plan.contributorUserIds === undefined,
        true,
        "and no contributor trail was seeded on a row about to be deleted",
      );
    },
  },
  {
    // Same cap and same verdict as the sweep beside it, for the same reason:
    // the create rule ties a writer only to their own submitted
    // `memberPermissions`, so the row count is chosen by a hostile writer.
    name: "an implausible plan count still cuts the capped page",
    fn: async () => {
      const fake = new FakeFirestore();
      seedExistingGroup(fake, ["stay", "leaver"], ["stay"]);
      for (let i = 0; i <= MAX_GROUP_MENU_PLANS; i++) {
        fake.seed(`group_weekly_menu_plans/c1_planted-${i}`, {
          groupId: "c1",
          participants: [
            { userId: "stay", permission: "admin" },
            { userId: "leaver", permission: "edit" },
          ],
          participantUserIds: ["stay", "leaver"],
          memberPermissions: { stay: "admin", leaver: "edit" },
        });
      }

      const res = await removeChatGroupMemberWithDeps(
        fake.db,
        "leaver",
        "g1",
        "leaver",
      );

      assertEqual(res.removed, true, "the leave itself still succeeds");
      const cut = fake.read("group_weekly_menu_plans/c1_planted-0")!;
      assertEqual(
        ((cut.memberPermissions as Record<string, unknown>) ?? {}).leaver,
        undefined,
        "a partial cut beats none: refusing would let anyone plant rows to " +
          "keep their access, and nothing retries this step",
      );
      // Counted, not read by id: the fake returns children in LEXICOGRAPHIC
      // order, so `planted-500` sorts among the first five hundred and which
      // specific row spills over is not a property worth asserting.
      const stillUncut = Array.from({ length: MAX_GROUP_MENU_PLANS + 1 })
        .map((_, i) => fake.read(`group_weekly_menu_plans/c1_planted-${i}`)!)
        .filter(
          (d) =>
            ((d.memberPermissions as Record<string, unknown>) ?? {}).leaver ===
            "edit",
        ).length;
      assertEqual(
        stillUncut,
        1,
        "exactly the overflow past the cap is left, logged rather than read",
      );
    },
  },
  {
    // A plan whose only admin walks out would otherwise be frozen: the update
    // rule lets only an admin change `participants`, so nobody could ever add
    // or remove a member on that week again.
    name: "the last admin leaving promotes the lowest remaining uid",
    fn: async () => {
      const fake = new FakeFirestore();
      seedExistingGroup(fake, ["zeta", "alpha", "boss"], ["boss"]);
      fake.seed("group_weekly_menu_plans/c1_2026-W16", {
        groupId: "c1",
        participants: [
          { userId: "boss", permission: "admin" },
          { userId: "zeta", permission: "edit" },
          { userId: "alpha", permission: "edit" },
        ],
        participantUserIds: ["boss", "zeta", "alpha"],
        memberPermissions: { boss: "admin", zeta: "edit", alpha: "edit" },
      });

      await removeChatGroupMemberWithDeps(fake.db, "boss", "g1", "boss");

      const plan = fake.read("group_weekly_menu_plans/c1_2026-W16")!;
      const perms = plan.memberPermissions as Record<string, unknown>;
      assertEqual(perms.alpha, "admin", "lowest uid, not first in the array");
      assertEqual(perms.zeta, "edit", "and nobody else is promoted");
    },
  },
  {
    // A silent privilege grant does not belong in a build whose whole point is
    // attribution (ADR-0010). Nobody is notified, so the trail is the record.
    name: "…and the promotion is written into the week's edit trail",
    fn: async () => {
      const fake = new FakeFirestore();
      seedExistingGroup(fake, ["alpha", "boss"], ["boss"]);
      fake.seed("group_weekly_menu_plans/c1_2026-W16", {
        groupId: "c1",
        participants: [
          { userId: "boss", permission: "admin" },
          { userId: "alpha", permission: "edit" },
        ],
        participantUserIds: ["boss", "alpha"],
        memberPermissions: { boss: "admin", alpha: "edit" },
      });

      await removeChatGroupMemberWithDeps(fake.db, "boss", "g1", "boss");

      const plan = fake.read("group_weekly_menu_plans/c1_2026-W16")!;
      const trail = (plan.editTrail as Record<string, unknown>[]) ?? [];
      assertEqual(trail.length, 1, "exactly one row is appended");
      assertEqual(trail[0].action, "adminPromoted", "naming what happened");
      assertEqual(trail[0].subjectId, "alpha", "and who it happened to");
      assertEqual(
        trail[0].actorId,
        "boss",
        "and who did it — on a self-leave the caller IS the leaver",
      );
    },
  },
  {
    // An ADMIN EVICTION, where the caller and the departing member differ. The
    // trail row must name the caller: stamping the departing uid would say the
    // person who was removed did the promoting. ADR-0010's accepted "a trail
    // row can name the wrong person" is about CLIENT forgery and does not reach
    // the server writing a wrong actor.
    name: "an eviction's promotion names the admin who evicted, not the evicted",
    fn: async () => {
      const fake = new FakeFirestore();
      seedExistingGroup(fake, ["alpha", "boss", "chief"], ["chief"]);
      fake.seed("group_weekly_menu_plans/c1_2026-W16", {
        groupId: "c1",
        participants: [
          { userId: "boss", permission: "admin" },
          { userId: "alpha", permission: "edit" },
        ],
        participantUserIds: ["boss", "alpha"],
        memberPermissions: { boss: "admin", alpha: "edit" },
      });

      await removeChatGroupMemberWithDeps(fake.db, "chief", "g1", "boss");

      const plan = fake.read("group_weekly_menu_plans/c1_2026-W16")!;
      const trail = (plan.editTrail as Record<string, unknown>[]) ?? [];
      assertEqual(trail.length, 1, "one promotion row");
      assertEqual(trail[0].actorId, "chief", "the evicting admin, not `boss`");
      assertEqual(trail[0].subjectId, "alpha", "who gained admin");
    },
  },
  {
    // A DESYNC: `participants` names only the leaver while a projection still
    // names somebody else. Deleting on that one field destroys the other
    // member's week, which is the failure the account cascade's three-witness
    // gate exists for. No writer in the repo produces this shape, but the
    // failure is destructive rather than a leftover.
    name: "an emptied roster is NOT deleted while another roster still names someone",
    fn: async () => {
      const fake = new FakeFirestore();
      seedExistingGroup(fake, ["stay", "leaver"], ["stay"]);
      fake.seed("group_weekly_menu_plans/c1_2026-W01", {
        groupId: "c1",
        participants: [{ userId: "leaver", permission: "admin" }],
        participantUserIds: ["leaver", "mirror-only"],
        memberPermissions: { leaver: "admin", "perm-only": "edit" },
      });

      await removeChatGroupMemberWithDeps(fake.db, "leaver", "g1", "leaver");

      assertEqual(
        fake.has("group_weekly_menu_plans/c1_2026-W01"),
        true,
        "the week survives — somebody else is still on one of its rosters",
      );
      // …and survives USABLE. Falling through with the rosters rebuilt from an
      // empty `remaining` would write `memberPermissions: {}`, which fails
      // every limb of this collection — nobody could read, write, re-plan or
      // delete that ISO week again. Refusing the delete and then bricking the
      // document is worse than the delete.
      const plan = fake.read("group_weekly_menu_plans/c1_2026-W01")!;
      const perms = (plan.memberPermissions as Record<string, unknown>) ?? {};
      assertEqual(
        Object.keys(perms).length > 0,
        true,
        "somebody can still open it",
      );
      assertEqual(perms.leaver, undefined, "and the leaver is still cut");
    },
  },
  {
    // The Admin SDK bypasses `firestore.rules`, so an over-cap trail written
    // here would be accepted and would then refuse every subsequent CLIENT save
    // of that week. The prune is the only thing stopping it, and this is its
    // only fixture — the promotion test above seeds no existing trail, so
    // without this case the branch is never entered.
    name: "the promotion row prunes the trail rather than pushing it over the cap",
    fn: async () => {
      const fake = new FakeFirestore();
      seedExistingGroup(fake, ["alpha", "boss"], ["boss"]);
      fake.seed("group_weekly_menu_plans/c1_2026-W16", {
        groupId: "c1",
        participants: [
          { userId: "boss", permission: "admin" },
          { userId: "alpha", permission: "edit" },
        ],
        participantUserIds: ["boss", "alpha"],
        memberPermissions: { boss: "admin", alpha: "edit" },
        editTrail: Array.from({ length: MAX_TRAIL_ROWS }, (_, i) => ({
          actorId: "boss",
          entryId: `e${i}`,
          action: "removed",
        })),
      });

      await removeChatGroupMemberWithDeps(fake.db, "boss", "g1", "boss");

      const plan = fake.read("group_weekly_menu_plans/c1_2026-W16")!;
      const trail = (plan.editTrail as Record<string, unknown>[]) ?? [];
      assertEqual(trail.length, MAX_TRAIL_ROWS, "still exactly at the cap");
      assertEqual(
        trail[trail.length - 1].action,
        "adminPromoted",
        "with the new row kept and the OLDEST dropped, not the new one",
      );
      assertEqual(
        trail[0].entryId,
        "e1",
        "pruned from the front, so e0 is the row that went",
      );
    },
  },
  {
    // The same brick the emptied roster caused, one field over: the Admin SDK
    // bypasses `firestore.rules`, so a union past the 200-uid cap is accepted
    // here and then refuses every subsequent CLIENT save of that week.
    // Recording the uid loses to freezing the week, so at the cap it is skipped
    // and logged — and the access cut still happens either way, which is what
    // this case pins.
    name: "at the contributor cap the union is skipped, but access is still cut",
    fn: async () => {
      const fake = new FakeFirestore();
      seedExistingGroup(fake, ["stay", "leaver"], ["stay"]);
      fake.seed("group_weekly_menu_plans/c1_2026-W16", {
        groupId: "c1",
        participants: [
          { userId: "stay", permission: "admin" },
          { userId: "leaver", permission: "edit" },
        ],
        participantUserIds: ["stay", "leaver"],
        memberPermissions: { stay: "admin", leaver: "edit" },
        contributorUserIds: Array.from(
          { length: MAX_CONTRIBUTOR_UIDS },
          (_, i) => `other-${i}`,
        ),
      });

      await removeChatGroupMemberWithDeps(fake.db, "leaver", "g1", "leaver");

      const plan = fake.read("group_weekly_menu_plans/c1_2026-W16")!;
      assertEqual(
        ((plan.contributorUserIds as string[]) ?? []).length,
        MAX_CONTRIBUTOR_UIDS,
        "the array is left exactly at the cap, not pushed past it",
      );
      assertEqual(
        ((plan.memberPermissions as Record<string, unknown>) ?? {}).leaver,
        undefined,
        "and the access cut happens anyway — the bound costs erasability on " +
          "one exceptional document, never the cut",
      );
    },
  },
  {
    // The already-present arm of the cap condition. Invisible in STORED state —
    // unioning a uid the array already holds is a no-op — so this reads the
    // recorded write PAYLOAD instead. Without the arm the field is omitted and
    // a false "uid not recorded" ERROR fires about a uid that IS recorded, and
    // that stream is the only signal anywhere that erasability was lost.
    name: "a uid already in a capped array is still written, not reported missing",
    fn: async () => {
      const fake = new FakeFirestore();
      seedExistingGroup(fake, ["stay", "leaver"], ["stay"]);
      fake.seed("group_weekly_menu_plans/c1_2026-W16", {
        groupId: "c1",
        participants: [
          { userId: "stay", permission: "admin" },
          { userId: "leaver", permission: "edit" },
        ],
        participantUserIds: ["stay", "leaver"],
        memberPermissions: { stay: "admin", leaver: "edit" },
        contributorUserIds: [
          "leaver",
          ...Array.from(
            { length: MAX_CONTRIBUTOR_UIDS - 1 },
            (_, i) => `other-${i}`,
          ),
        ],
      });

      await removeChatGroupMemberWithDeps(fake.db, "leaver", "g1", "leaver");

      const write = fake.writes.find(
        (w) =>
          w.op === "update" &&
          w.path === "group_weekly_menu_plans/c1_2026-W16",
      );
      assertEqual(write !== undefined, true, "the plan was written");
      assertEqual(
        Object.prototype.hasOwnProperty.call(
          write!.data ?? {},
          "contributorUserIds",
        ),
        true,
        "the union is still sent for a uid the array already holds",
      );
    },
  },
  {
    // The plan's roster is a snapshot taken when the week was BUILT and is
    // never re-synced, so a leaver can be the sole participant of an OLD week
    // while the chat group still has members. There is nobody to promote, and
    // `remaining === 0` never fires, so no sweep cleans up.
    name: "a week only the leaver was on is DELETED, not left as an empty shell",
    fn: async () => {
      // An empty `memberPermissions` map does not merely hide the week — every
      // limb of this collection gates on it, and `save()` is a whole-document
      // `set()` on the deterministic id, so the shell would brick that ISO week
      // for the whole group, poll-close included. The group still has members;
      // only this old week's snapshot roster had just the leaver on it.
      const fake = new FakeFirestore();
      seedExistingGroup(fake, ["stay", "leaver"], ["stay"]);
      fake.seed("group_weekly_menu_plans/c1_2026-W01", {
        groupId: "c1",
        participants: [{ userId: "leaver", permission: "admin" }],
        participantUserIds: ["leaver"],
        memberPermissions: { leaver: "admin" },
        entries: [{ id: "e1", proposedBy: "leaver" }],
      });
      // A week the group is still on, to prove the delete is scoped to the
      // emptied roster rather than to the leave.
      fake.seed("group_weekly_menu_plans/c1_2026-W16", {
        groupId: "c1",
        participants: [
          { userId: "stay", permission: "admin" },
          { userId: "leaver", permission: "edit" },
        ],
        participantUserIds: ["stay", "leaver"],
        memberPermissions: { stay: "admin", leaver: "edit" },
      });

      await removeChatGroupMemberWithDeps(fake.db, "leaver", "g1", "leaver");

      assertEqual(
        fake.has("group_weekly_menu_plans/c1_2026-W01"),
        false,
        "the week nobody is left on goes, so the group can plan it again",
      );
      assertEqual(
        fake.has("group_weekly_menu_plans/c1_2026-W16"),
        true,
        "while a week the group is still on survives the same leave",
      );
    },
  },
  {
    // THE CAP, with the verdict DECLINE. The row count is chosen by whoever can
    // write the collection: `firestore.rules` ties a create only to the
    // caller's OWN submitted `memberPermissions`, never to the chat group's
    // members, and the doc-id suffix is free — so a signed-in stranger can
    // plant rows carrying this group's id. Above the cap the sweep must leave
    // everything alone rather than truncate, and the teardown must still
    // proceed.
    name: "an implausible plan count declines the sweep and leaves the rows",
    fn: async () => {
      const fake = new FakeFirestore();
      seedExistingGroup(fake, ["solo"], ["solo"]);
      for (let i = 0; i <= MAX_GROUP_MENU_PLANS; i++) {
        fake.seed(`group_weekly_menu_plans/c1_planted-${i}`, { groupId: "c1" });
      }

      const res = await removeChatGroupMemberWithDeps(fake.db, "solo", "g1", "solo");

      assertEqual(res.removed, true, "the access cut still happened");
      assertEqual(
        fake.has("group_weekly_menu_plans/c1_planted-0"),
        true,
        "nothing was swept — a partial sweep above the cap is the worst outcome",
      );
      assertEqual(
        fake.has(`group_weekly_menu_plans/c1_planted-${MAX_GROUP_MENU_PLANS}`),
        true,
        "including the row past the cap",
      );
      assertEqual(fake.has("conversations/c1"), false, "teardown still proceeded");
    },
  },
  {
    // The teardown is best-effort throughout, and the menu sweep must not be
    // the exception: a person leaving a group cannot be failed because
    // cleanup stumbled. With the plan delete refusing, the conversation and
    // the group must still go.
    name: "a menu-plan delete that fails does not stop the group teardown",
    fn: async () => {
      const fake = new FakeFirestore({
        failDeleteAt: (path) => path === "group_weekly_menu_plans/c1_2026-W16",
      });
      seedExistingGroup(fake, ["solo"], ["solo"]);
      fake.seed("group_weekly_menu_plans/c1_2026-W16", { groupId: "c1" });

      const res = await removeChatGroupMemberWithDeps(fake.db, "solo", "g1", "solo");

      assertEqual(res.removed, true, "the access cut still happened");
      assertEqual(fake.has("conversations/c1"), false, "conversation still deleted");
      assertEqual(fake.has("chat_groups/g1"), false, "group still deleted");
    },
  },
];

// BUT-1851 gap: every case above drives a `…WithDeps` core, which sits BELOW
// the rate-limit call in its onCall wrapper. Nothing therefore reads the
// operation key the wrapper passes, and `getRateLimitConfig` falls back to
// `RATE_LIMIT_CONFIGS.default` for an unknown one — so renaming the key on
// either side alone leaves every bucket-value pin in
// `rate-limiter-daily-cap.test.ts` green while the callable runs on the default
// bucket. One case for the whole family, derived from source rather than a
// hand-typed list, so a new `groups/` callable is covered on arrival.
const GROUPS_DIR = path.resolve(__dirname, "../groups");

/** Comments stripped: a commented-out call would otherwise satisfy the match. */
function sourceWithoutComments(file: string): string {
  return fs
    .readFileSync(path.join(GROUPS_DIR, file), "utf8")
    .replace(/\/\*[\s\S]*?\*\//g, "")
    .replace(/(^|[^:])\/\/.*$/gm, (_m, keep: string) => keep);
}

cases.push({
  name: "every groups/ callable passes an operation key that RATE_LIMIT_CONFIGS defines",
  fn: async () => {
    const files = fs
      .readdirSync(GROUPS_DIR)
      .filter((f) => f.endsWith(".ts"))
      .filter((f) => /(?:check|enforce)RateLimit\(/.test(sourceWithoutComments(f)));
    assertEqual(
      files.includes("create-chat-group.ts"),
      true,
      "create-chat-group.ts rate-limits its callable",
    );

    const found: Record<string, string> = {};
    for (const file of files) {
      const src = sourceWithoutComments(file);
      const keys = [
        ...src.matchAll(
          // BUT-1862 moved these call sites from the bare `checkRateLimit` +
          // hand-rolled throw to `enforceRateLimit`, which carries
          // `retryAfterSeconds`. Both spellings are matched so the wiring
          // stays pinned across that move.
          /(?:check|enforce)RateLimit\(\s*[^,()]+,\s*"([A-Za-z][A-Za-z0-9]*)"\s*,?\s*\)/g,
        ),
      ].map((m) => m[1]);
      // Without this the loop below is vacuous for any call site the regex
      // stopped reading — a reshaped call would read as "no keys to check".
      assertEqual(keys.length > 0, true, `${file}: an operation key was parsed`);
      for (const key of keys) {
        assertEqual(
          Object.prototype.hasOwnProperty.call(RATE_LIMIT_CONFIGS, key),
          true,
          `${file}: RATE_LIMIT_CONFIGS defines "${key}"`,
        );
        assertEqual(
          key === "default",
          false,
          `${file}: "${key}" is not the fallback bucket`,
        );
        found[file] = key;
      }
    }
    // The literal the ticket names, pinned by itself as well: the derived check
    // above passes if BOTH sides are renamed together, which is fine, but this
    // collection's own key is one the export name has to keep agreeing with.
    assertEqual(
      found["create-chat-group.ts"],
      "createChatGroup",
      "createChatGroup passes its own name as the operation key",
    );
  },
});

void runTests("chat-group callables — create / add / remove cores", cases);
