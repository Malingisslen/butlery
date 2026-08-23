/**
 * BUT-1856: unit tests for `ensureCategoryChatWithDeps`, the resolve-or-create
 * core behind the meal-vote poll.
 *
 * The ticket's whole point is a NEGATIVE: the second poll must not mint a second
 * chat. A test that only compares the returned id would pass against an
 * implementation that created a fresh group and happened to return the old id,
 * so the reuse cases assert against the STORE — `fake.writes` and the set of
 * `chat_groups` documents — which the fake can answer because it applies writes.
 *
 * Properties here exist because removing them is invisible:
 *  - the pointer is keyed on OWNER + category id. A category id is a UUID the
 *    client picks, so keyed on the id alone an ex-member could hand themselves
 *    the victim's chat. The hijack case is what keeps the second `where` clause.
 *  - the minor gate runs against the CALLER, not the category owner. Owner-keyed,
 *    a stranger to a minor could seat them via the owner's friendships.
 *  - a departure tombstone survives the sync. Without it "leave the chat" means
 *    nothing, because the category still lists you and the next poll seats you.
 *  - and the mirror: the sync evicts only its OWN seats, so an admin's explicit
 *    invitation is not deleted by the next poll.
 *
 * Run with: npx ts-node src/__tests__/ensure-category-chat.test.ts
 */

import * as admin from "firebase-admin";
import { runTests, assertEqual, UnitCase } from "./_unit-runner";
import { FakeFirestore } from "./_fake-firestore";
import { ensureCategoryChatWithDeps } from "../groups/ensure-category-chat";
import { addChatGroupMembersWithDeps } from "../groups/add-chat-group-members";
import { removeChatGroupMemberWithDeps } from "../groups/remove-chat-group-member";

if (!admin.apps.length) {
  admin.initializeApp({ projectId: "butlery-test-ensure-category-chat" });
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

const OWNER = "owner";
const FRIEND = "friend";
const CAT = "cat-1";
const EARLIER = admin.firestore.Timestamp.fromMillis(1_500_000_000_000);

function seedPerson(fake: FakeFirestore, uid: string, isMinor = false): void {
  fake.seed(`users/${uid}`, { isMinor });
  fake.seed(`public_profiles/${uid}`, { displayName: uid, avatarUrl: null });
}

/** The directional friend edge the minor gate reads: users/{minor}/friends/{adder}. */
function seedFriendEdge(fake: FakeFirestore, minorUid: string, adderUid: string): void {
  fake.seed(`users/${minorUid}/friends/${adderUid}`, { createdAt: null });
}

/**
 * A social group. The owner is seeded INTO `friendUserIds` because that is what
 * the app does — `FriendCategory.create` puts them there and
 * `migrateOwnersAsMembers()` re-appends them on every login, so the uid can
 * appear twice.
 */
function seedCategory(
  fake: FakeFirestore,
  members: string[],
  opts: { ownerId?: string; categoryId?: string; name?: string } = {},
): void {
  const ownerId = opts.ownerId ?? OWNER;
  fake.seed(
    `users/${ownerId}/friend_categories/${opts.categoryId ?? CAT}`,
    {
      ownerId,
      name: opts.name ?? "Familjen",
      friendUserIds: members,
      isHousehold: false,
    },
  );
}

function chatGroupPaths(fake: FakeFirestore): string[] {
  return fake.childPaths("chat_groups");
}

function membersOf(fake: FakeFirestore, groupPath: string): string[] {
  return ((fake.read(groupPath)?.memberIds as string[]) ?? []).slice().sort();
}

const cases: UnitCase[] = [
  {
    name: "first call creates the chat and stamps BOTH halves of the pointer",
    fn: async () => {
      const fake = new FakeFirestore();
      seedPerson(fake, OWNER);
      seedPerson(fake, FRIEND);
      seedCategory(fake, [OWNER, FRIEND]);

      const res = await ensureCategoryChatWithDeps(fake.db, OWNER, OWNER, CAT);

      assertEqual(res.created, true, "created");
      assertEqual(res.conversationId, res.groupId, "conversationId == groupId");
      const groups = chatGroupPaths(fake);
      assertEqual(groups.length, 1, "chat_groups count");
      const stored = fake.read(groups[0]);
      assertEqual(stored?.sourceCategoryId, CAT, "sourceCategoryId");
      assertEqual(stored?.sourceCategoryOwnerId, OWNER, "sourceCategoryOwnerId");
      assertEqual(membersOf(fake, groups[0]).join(","), "friend,owner", "roster");
    },
  },
  {
    // THE ticket. Asserted against the store, not the return value: an
    // implementation that created a second group and returned the first id
    // would pass an id-only check.
    name: "second call returns the same chat and writes NOTHING",
    fn: async () => {
      const fake = new FakeFirestore();
      seedPerson(fake, OWNER);
      seedPerson(fake, FRIEND);
      seedCategory(fake, [OWNER, FRIEND]);

      const first = await ensureCategoryChatWithDeps(fake.db, OWNER, OWNER, CAT);
      const writesAfterFirst = fake.writes.length;

      const second = await ensureCategoryChatWithDeps(fake.db, FRIEND, OWNER, CAT);

      assertEqual(second.groupId, first.groupId, "same group id");
      assertEqual(second.created, false, "created");
      assertEqual(chatGroupPaths(fake).length, 1, "chat_groups count");
      assertEqual(fake.writes.length, writesAfterFirst, "writes after reuse");
    },
  },
  {
    name: "ten polls in a row leave exactly one group-created system message",
    fn: async () => {
      const fake = new FakeFirestore();
      seedPerson(fake, OWNER);
      seedPerson(fake, FRIEND);
      seedCategory(fake, [OWNER, FRIEND]);

      for (let i = 0; i < 10; i++) {
        await ensureCategoryChatWithDeps(fake.db, OWNER, OWNER, CAT);
      }
      assertEqual(fake.childPaths("messages").length, 1, "system message count");
    },
  },
  {
    name: "a friend added to the category later is seated on the next poll",
    fn: async () => {
      const fake = new FakeFirestore();
      seedPerson(fake, OWNER);
      seedPerson(fake, FRIEND);
      seedPerson(fake, "latecomer");
      seedCategory(fake, [OWNER, FRIEND]);

      const first = await ensureCategoryChatWithDeps(fake.db, OWNER, OWNER, CAT);
      await fake.db
        .doc(`users/${OWNER}/friend_categories/${CAT}`)
        .update({ friendUserIds: [OWNER, FRIEND, "latecomer"] });

      const second = await ensureCategoryChatWithDeps(fake.db, OWNER, OWNER, CAT);

      assertEqual(second.groupId, first.groupId, "same group id");
      assertEqual(second.addedUserIds.join(","), "latecomer", "addedUserIds");
      assertEqual(
        membersOf(fake, `chat_groups/${first.groupId}`).join(","),
        "friend,latecomer,owner",
        "roster",
      );
      assertEqual(
        (fake.read(`conversations/${first.conversationId}`)
          ?.memberSince as Record<string, unknown>)["latecomer"] !== undefined,
        true,
        "latecomer got a history cut-off",
      );
    },
  },
  {
    name: "a member dropped from the category is removed from the chat",
    fn: async () => {
      const fake = new FakeFirestore();
      seedPerson(fake, OWNER);
      seedPerson(fake, FRIEND);
      seedPerson(fake, "third");
      seedCategory(fake, [OWNER, FRIEND, "third"]);

      const first = await ensureCategoryChatWithDeps(fake.db, OWNER, OWNER, CAT);
      await fake.db
        .doc(`users/${OWNER}/friend_categories/${CAT}`)
        .update({ friendUserIds: [OWNER, FRIEND] });

      const second = await ensureCategoryChatWithDeps(fake.db, OWNER, OWNER, CAT);

      assertEqual(second.removedUserIds.join(","), "third", "removedUserIds");
      assertEqual(
        membersOf(fake, `chat_groups/${first.groupId}`).join(","),
        "friend,owner",
        "roster",
      );
      assertEqual(
        fake.read(`conversations/${first.conversationId}/participants/third`),
        undefined,
        "third's roster row",
      );
      // Mirroring the category, so NO tombstone: putting them back in the
      // social group must put them back in its chat.
      assertEqual(
        ((fake.read(`chat_groups/${first.groupId}`)?.departedUserIds as
          | string[]
          | undefined) ?? []).join(","),
        "",
        "departedUserIds after a sync removal",
      );
    },
  },
  {
    name: "the owner is never removed by the sync, even if the category drops them",
    fn: async () => {
      const fake = new FakeFirestore();
      seedPerson(fake, OWNER);
      seedPerson(fake, FRIEND);
      seedCategory(fake, [OWNER, FRIEND]);

      const first = await ensureCategoryChatWithDeps(fake.db, OWNER, OWNER, CAT);
      // `friendUserIds` without the owner; `rosterOf` re-adds them, which is the
      // property this pins — an owner evicted from their own group's chat could
      // never get back in, since `adminIds` is immutable.
      await fake.db
        .doc(`users/${OWNER}/friend_categories/${CAT}`)
        .update({ friendUserIds: [FRIEND] });

      const second = await ensureCategoryChatWithDeps(fake.db, OWNER, OWNER, CAT);

      assertEqual(second.removedUserIds.join(","), "", "removedUserIds");
      assertEqual(
        membersOf(fake, `chat_groups/${first.groupId}`).join(","),
        "friend,owner",
        "roster",
      );
    },
  },
  {
    // The mirror of the tombstone, and the direction that was missing: an admin
    // can invite somebody through the group screen who is not in the social
    // group at all. Evicting "everyone not in the category" deleted that
    // invitation on the next poll, wrote "X har lämnat gruppen" into the thread,
    // and did it again after every re-invite.
    name: "somebody an admin invited is NOT evicted for being outside the category",
    fn: async () => {
      const fake = new FakeFirestore();
      seedPerson(fake, OWNER);
      seedPerson(fake, FRIEND);
      seedPerson(fake, "guest");
      seedPerson(fake, "third");
      seedCategory(fake, [OWNER, FRIEND, "third"]);

      const first = await ensureCategoryChatWithDeps(fake.db, OWNER, OWNER, CAT);
      await addChatGroupMembersWithDeps(fake.db, OWNER, first.groupId, ["guest"]);
      // Drop one CATEGORY member so the sync has an eviction to make; the guest
      // was never in the category at all.
      await fake.db
        .doc(`users/${OWNER}/friend_categories/${CAT}`)
        .update({ friendUserIds: [OWNER, "third"] });

      const second = await ensureCategoryChatWithDeps(fake.db, OWNER, OWNER, CAT);

      assertEqual(second.removedUserIds.join(","), FRIEND, "removedUserIds");
      assertEqual(
        membersOf(fake, `chat_groups/${first.groupId}`).join(","),
        "guest,owner,third",
        "the invited guest stays",
      );
    },
  },
  {
    // `stageMemberRemoval` clears the seat marker along with the membership. If
    // it did not, a uid removed once would carry its old marker back in on the
    // next explicit invite — and the sync could then evict a person an admin
    // had just deliberately re-added.
    name: "an explicit re-invite after a removal is not evictable by the sync",
    fn: async () => {
      const fake = new FakeFirestore();
      seedPerson(fake, OWNER);
      seedPerson(fake, FRIEND);
      seedPerson(fake, "third");
      seedCategory(fake, [OWNER, FRIEND, "third"]);

      const first = await ensureCategoryChatWithDeps(fake.db, OWNER, OWNER, CAT);
      await removeChatGroupMemberWithDeps(fake.db, OWNER, first.groupId, "third");
      await fake.db
        .doc(`users/${OWNER}/friend_categories/${CAT}`)
        .update({ friendUserIds: [OWNER, FRIEND] });
      await addChatGroupMembersWithDeps(fake.db, OWNER, first.groupId, ["third"]);

      const second = await ensureCategoryChatWithDeps(fake.db, OWNER, OWNER, CAT);

      assertEqual(second.removedUserIds.join(","), "", "removedUserIds");
      assertEqual(
        membersOf(fake, `chat_groups/${first.groupId}`).join(","),
        "friend,owner,third",
        "the re-invited member stays",
      );
    },
  },
  {
    // The escape hatch. The category still lists them, so an implementation
    // without the tombstone seats them again on the very next poll.
    name: "somebody who left the chat is NOT dragged back by the sync",
    fn: async () => {
      const fake = new FakeFirestore();
      seedPerson(fake, OWNER);
      seedPerson(fake, FRIEND);
      seedCategory(fake, [OWNER, FRIEND]);

      const first = await ensureCategoryChatWithDeps(fake.db, OWNER, OWNER, CAT);
      // What `removeChatGroupMember` leaves behind when someone leaves.
      await fake.db.doc(`chat_groups/${first.groupId}`).update({
        memberIds: [OWNER],
        departedUserIds: [FRIEND],
      });

      const second = await ensureCategoryChatWithDeps(fake.db, OWNER, OWNER, CAT);

      assertEqual(second.addedUserIds.join(","), "", "addedUserIds");
      assertEqual(
        membersOf(fake, `chat_groups/${first.groupId}`).join(","),
        "owner",
        "roster",
      );
    },
  },
  {
    name: "an explicit re-invite clears the tombstone, so the sync may seat them again",
    fn: async () => {
      const fake = new FakeFirestore();
      seedPerson(fake, OWNER);
      seedPerson(fake, FRIEND);
      seedCategory(fake, [OWNER, FRIEND]);

      const first = await ensureCategoryChatWithDeps(fake.db, OWNER, OWNER, CAT);
      await fake.db.doc(`chat_groups/${first.groupId}`).update({
        memberIds: [OWNER],
        departedUserIds: [FRIEND],
      });
      await fake.db
        .doc(`conversations/${first.conversationId}/participants/${FRIEND}`)
        .delete();

      await addChatGroupMembersWithDeps(fake.db, OWNER, first.groupId, [FRIEND]);

      assertEqual(
        ((fake.read(`chat_groups/${first.groupId}`)?.departedUserIds as
          | string[]
          | undefined) ?? []).join(","),
        "",
        "departedUserIds after an explicit add",
      );
    },
  },
  {
    // The gate's subject. Owner-keyed, this call would succeed: the owner IS the
    // minor's friend. Caller-keyed it must fail, and fail whole.
    name: "the minor gate is checked against the CALLER, and refuses the whole call",
    fn: async () => {
      const fake = new FakeFirestore();
      seedPerson(fake, OWNER);
      seedPerson(fake, FRIEND);
      seedPerson(fake, "minor", true);
      seedFriendEdge(fake, "minor", OWNER); // the owner is a friend; the caller is not
      seedCategory(fake, [OWNER, FRIEND]);

      const first = await ensureCategoryChatWithDeps(fake.db, OWNER, OWNER, CAT);
      await fake.db
        .doc(`users/${OWNER}/friend_categories/${CAT}`)
        .update({ friendUserIds: [OWNER, FRIEND, "minor"] });
      const writesBefore = fake.writes.length;

      const err = await capture(() =>
        ensureCategoryChatWithDeps(fake.db, FRIEND, OWNER, CAT),
      );

      assertEqual(err.code, "permission-denied", "refusal code");
      assertEqual(
        (err.details as { blockedUserIds?: string[] } | undefined)?.blockedUserIds?.join(","),
        "minor",
        "blockedUserIds",
      );
      assertEqual(fake.writes.length, writesBefore, "writes after refusal");
      assertEqual(
        membersOf(fake, `chat_groups/${first.groupId}`).join(","),
        "friend,owner",
        "roster unchanged",
      );
    },
  },
  {
    name: "the same seat succeeds when the CALLER is the minor's friend",
    fn: async () => {
      const fake = new FakeFirestore();
      seedPerson(fake, OWNER);
      seedPerson(fake, FRIEND);
      seedPerson(fake, "minor", true);
      seedFriendEdge(fake, "minor", OWNER);
      seedCategory(fake, [OWNER, FRIEND]);

      const first = await ensureCategoryChatWithDeps(fake.db, OWNER, OWNER, CAT);
      await fake.db
        .doc(`users/${OWNER}/friend_categories/${CAT}`)
        .update({ friendUserIds: [OWNER, FRIEND, "minor"] });

      const second = await ensureCategoryChatWithDeps(fake.db, OWNER, OWNER, CAT);

      assertEqual(second.addedUserIds.join(","), "minor", "addedUserIds");
      assertEqual(
        membersOf(fake, `chat_groups/${first.groupId}`).join(","),
        "friend,minor,owner",
        "roster",
      );
    },
  },
  {
    // A category id is a client-chosen UUID with no cross-account uniqueness.
    // Keyed on the id alone, this call hands the attacker the victim's chat and
    // the sync then evicts everyone in it.
    name: "a colliding category id under another owner does NOT find the victim's chat",
    fn: async () => {
      const fake = new FakeFirestore();
      seedPerson(fake, OWNER);
      seedPerson(fake, FRIEND);
      seedPerson(fake, "attacker");
      seedPerson(fake, "accomplice");
      seedCategory(fake, [OWNER, FRIEND]);
      // Same category id, different owner — exactly what an ex-member can do.
      seedCategory(fake, ["attacker", "accomplice"], {
        ownerId: "attacker",
        categoryId: CAT,
        name: "Familjen",
      });

      const victim = await ensureCategoryChatWithDeps(fake.db, OWNER, OWNER, CAT);
      const attacker = await ensureCategoryChatWithDeps(
        fake.db,
        "attacker",
        "attacker",
        CAT,
      );

      assertEqual(attacker.created, true, "attacker got their own chat");
      assertEqual(
        attacker.groupId === victim.groupId,
        false,
        "attacker did not receive the victim's group",
      );
      assertEqual(
        membersOf(fake, `chat_groups/${victim.groupId}`).join(","),
        "friend,owner",
        "victim roster untouched",
      );
    },
  },
  {
    name: "a group with no pointer fields is not treated as this category's chat",
    fn: async () => {
      const fake = new FakeFirestore();
      seedPerson(fake, OWNER);
      seedPerson(fake, FRIEND);
      seedCategory(fake, [OWNER, FRIEND]);
      // A pre-BUT-1856 group: same people, no pointer.
      fake.seed("chat_groups/legacy", {
        name: "Familjen",
        memberIds: [OWNER, FRIEND],
        adminIds: [OWNER],
        conversationId: "legacy-c",
        createdAt: EARLIER,
      });

      const res = await ensureCategoryChatWithDeps(fake.db, OWNER, OWNER, CAT);

      assertEqual(res.created, true, "created a real category chat");
      assertEqual(res.groupId === "legacy", false, "did not adopt the legacy group");
    },
  },
  {
    name: "a torn-down chat is re-created and the pointer re-stamped",
    fn: async () => {
      const fake = new FakeFirestore();
      seedPerson(fake, OWNER);
      seedPerson(fake, FRIEND);
      seedCategory(fake, [OWNER, FRIEND]);

      const first = await ensureCategoryChatWithDeps(fake.db, OWNER, OWNER, CAT);
      await fake.db.doc(`chat_groups/${first.groupId}`).delete();

      const second = await ensureCategoryChatWithDeps(fake.db, OWNER, OWNER, CAT);

      assertEqual(second.created, true, "created");
      // The id is DERIVED from (ownerId, categoryId), so a re-created chat
      // reuses it. That is the same property that makes two concurrent first
      // polls collide on one document instead of minting two.
      assertEqual(second.groupId, first.groupId, "same derived id");
      assertEqual(
        fake.read(`chat_groups/${second.groupId}`)?.sourceCategoryId,
        CAT,
        "pointer re-stamped",
      );
      assertEqual(chatGroupPaths(fake).length, 1, "chat_groups count");
    },
  },
  {
    name: "a one-person group is refused with a structured reason and writes nothing",
    fn: async () => {
      for (const listed of [[] as string[], [OWNER]]) {
        const fake = new FakeFirestore();
        seedPerson(fake, OWNER);
        seedCategory(fake, listed);

        const err = await capture(() =>
          ensureCategoryChatWithDeps(fake.db, OWNER, OWNER, CAT),
        );

        assertEqual(err.code, "failed-precondition", `refusal code for [${listed}]`);
        assertEqual(
          (err.details as { reason?: string } | undefined)?.reason,
          "group-too-small",
          `reason for [${listed}]`,
        );
        assertEqual(fake.writes.length, 0, `writes for [${listed}]`);
        assertEqual(chatGroupPaths(fake).length, 0, `chat_groups for [${listed}]`);
      }
    },
  },
  {
    name: "a stranger and a missing category get the byte-identical refusal",
    fn: async () => {
      const fake = new FakeFirestore();
      seedPerson(fake, OWNER);
      seedPerson(fake, FRIEND);
      seedPerson(fake, "stranger");
      seedCategory(fake, [OWNER, FRIEND]);

      const stranger = await capture(() =>
        ensureCategoryChatWithDeps(fake.db, "stranger", OWNER, CAT),
      );
      const missing = await capture(() =>
        ensureCategoryChatWithDeps(fake.db, "stranger", OWNER, "no-such-category"),
      );

      assertEqual(stranger.code, "permission-denied", "stranger code");
      assertEqual(missing.code, stranger.code, "codes match");
      assertEqual(missing.message, stranger.message, "messages match");
      assertEqual(chatGroupPaths(fake).length, 0, "nothing created");
    },
  },
  {
    // An admin removed them from the chat. They are still in the social group,
    // so category membership alone would let them walk back in and undo it.
    name: "someone removed from the chat cannot reconcile their way back in",
    fn: async () => {
      const fake = new FakeFirestore();
      seedPerson(fake, OWNER);
      seedPerson(fake, FRIEND);
      seedCategory(fake, [OWNER, FRIEND]);

      const first = await ensureCategoryChatWithDeps(fake.db, OWNER, OWNER, CAT);
      await fake.db.doc(`chat_groups/${first.groupId}`).update({
        memberIds: [OWNER],
        departedUserIds: [FRIEND],
      });

      const err = await capture(() =>
        ensureCategoryChatWithDeps(fake.db, FRIEND, OWNER, CAT),
      );

      assertEqual(err.code, "permission-denied", "refusal code");
      assertEqual(
        membersOf(fake, `chat_groups/${first.groupId}`).join(","),
        "owner",
        "roster unchanged",
      );
    },
  },
  {
    // `firestore.rules` still lets any participant delete a group conversation
    // (the app's refusal is UX, not a control). The pointer is sticky now, so
    // without this check the staging helpers' `tx.update` on a missing document
    // would wedge every future poll for this category behind a bare `internal`.
    name: "a deleted conversation is reported, not wedged behind a raw grpc error",
    fn: async () => {
      const fake = new FakeFirestore();
      seedPerson(fake, OWNER);
      seedPerson(fake, FRIEND);
      seedPerson(fake, "latecomer");
      seedCategory(fake, [OWNER, FRIEND]);

      const first = await ensureCategoryChatWithDeps(fake.db, OWNER, OWNER, CAT);
      await fake.db.doc(`conversations/${first.conversationId}`).delete();
      await fake.db
        .doc(`users/${OWNER}/friend_categories/${CAT}`)
        .update({ friendUserIds: [OWNER, FRIEND, "latecomer"] });

      const err = await capture(() =>
        ensureCategoryChatWithDeps(fake.db, OWNER, OWNER, CAT),
      );

      assertEqual(err.code, "failed-precondition", "refusal code");
      assertEqual(
        membersOf(fake, `chat_groups/${first.groupId}`).join(","),
        "friend,owner",
        "roster unchanged",
      );
    },
  },
  {
    // The owner gets NO exemption from the chat-membership gate. They are
    // seated at creation and the sync never evicts them, so an owner outside
    // the chat is one an admin removed — and letting them back in by editing
    // their own category would undo exactly what that admin decided.
    name: "an OWNER removed from the chat cannot reconcile their way back in",
    fn: async () => {
      const fake = new FakeFirestore();
      seedPerson(fake, OWNER);
      seedPerson(fake, FRIEND);
      seedPerson(fake, "third");
      seedCategory(fake, [OWNER, FRIEND, "third"]);

      const first = await ensureCategoryChatWithDeps(fake.db, OWNER, OWNER, CAT);
      await fake.db.doc(`chat_groups/${first.groupId}`).update({
        memberIds: [FRIEND, "third"],
        adminIds: [FRIEND],
        departedUserIds: [OWNER],
      });

      const err = await capture(() =>
        ensureCategoryChatWithDeps(fake.db, OWNER, OWNER, CAT),
      );

      assertEqual(err.code, "permission-denied", "refusal code");
      assertEqual(
        membersOf(fake, `chat_groups/${first.groupId}`).join(","),
        "friend,third",
        "roster unchanged",
      );
    },
  },
  {
    // Not cosmetic: the caller may leave the social group later, and `adminIds`
    // is immutable, so a chat created by a member with only that member as admin
    // would end up unmanageable.
    name: "the owner is seated as an admin beside the caller who created the chat",
    fn: async () => {
      const fake = new FakeFirestore();
      seedPerson(fake, OWNER);
      seedPerson(fake, FRIEND);
      seedCategory(fake, [OWNER, FRIEND]);

      const res = await ensureCategoryChatWithDeps(fake.db, FRIEND, OWNER, CAT);

      const admins = (
        (fake.read(`chat_groups/${res.groupId}`)?.adminIds as string[]) ?? []
      )
        .slice()
        .sort();
      assertEqual(admins.join(","), "friend,owner", "adminIds");
    },
  },
  {
    // Without a derived id both callers see an empty lookup and each mints a
    // chat; the loser is then an orphan group the app refuses to delete, which
    // is the exact harm this ticket removes. The fake runs a transaction to
    // completion before the next one starts, so the collision is staged by
    // creating the chat first and then re-entering the create branch.
    name: "a racing second create collides on the derived id instead of minting a second chat",
    fn: async () => {
      const fake = new FakeFirestore();
      seedPerson(fake, OWNER);
      seedPerson(fake, FRIEND);
      seedCategory(fake, [OWNER, FRIEND]);

      const first = await ensureCategoryChatWithDeps(fake.db, OWNER, OWNER, CAT);
      // Blind the lookup the way a concurrent caller would see it: the pointer
      // query has already run and returned nothing.
      await fake.db
        .doc(`chat_groups/${first.groupId}`)
        .update({ sourceCategoryId: "not-this-category" });

      const second = await ensureCategoryChatWithDeps(fake.db, FRIEND, OWNER, CAT);

      assertEqual(second.groupId, first.groupId, "same group");
      assertEqual(second.created, false, "fell through to reconcile");
      assertEqual(chatGroupPaths(fake).length, 1, "chat_groups count");
    },
  },
  {
    name: "the derived id does not leak either uid",
    fn: async () => {
      const fake = new FakeFirestore();
      seedPerson(fake, OWNER);
      seedPerson(fake, FRIEND);
      seedCategory(fake, [OWNER, FRIEND]);

      const res = await ensureCategoryChatWithDeps(fake.db, OWNER, OWNER, CAT);

      // The group id is also the CONVERSATION id, and a conversation id built
      // from raw uids ends up in log paths (BUT-1822).
      assertEqual(res.groupId.includes(OWNER), false, "owner uid absent");
      assertEqual(res.groupId.includes(CAT), false, "category id absent");
    },
  },
];

void runTests(
  "ensure-category-chat — resolve-or-create for the meal-vote poll",
  cases,
);
