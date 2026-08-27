/**
 * BUT-1856: resolve-or-create the ONE chat group backing a social group.
 *
 * **The problem.** `SocialGroupDetailViewModel.startMealVotePoll` called
 * `createChatGroup` on every "Vad ska vi äta?" poll. Since BUT-1838 that
 * callable writes a durable group object — a `chat_groups` document, a
 * conversation, a roster row per member and a system message — and the app
 * refuses to delete a conversation carrying a `groupId`. Weekly polls therefore
 * minted a chat per vote that nobody could remove.
 *
 * **Where the link lives, and why not on the category.** The pointer is two
 * fields on `chat_groups` — `sourceCategoryId` and `sourceCategoryOwnerId` —
 * rather than one field on the `FriendCategory`. The category is owner-writable
 * with a full-document `set()`, so a client holding a stale copy would silently
 * erase a pointer stored there, and a non-owner member could never write one at
 * all (`firestore.rules` limits them to `friendUserIds` + `updatedAt`). A
 * `chat_groups` document, by contrast, is Admin-SDK-only for create and delete
 * and `hasOnly(['name','updatedAt'])` for client updates, so the pointer cannot
 * be forged or clobbered and needs no rules change.
 *
 * **Why the owner is half the key.** A category id is a UUID the CLIENT picks
 * (`Uuid().v4()`, written with `.doc(category.id).set(...)`) and the rules place
 * no constraint on the document id. Every member can read the id through the
 * `friend_categories` collection-group rule. Keyed on the category id alone, an
 * ex-member could create a category with the SAME id under their own uid, pass
 * the ownership check honestly, and be handed the victim's chat group — after
 * which the roster sync would evict everyone and seat them. Both fields are
 * matched, always.
 *
 * **Who the gate is checked against.** The caller, never the category owner.
 * Seating the owner as the gate's subject would let a member who is a stranger
 * to a minor in the group put that minor in a chat with themselves, on the
 * owner's friendships, with the owner never acting — the exact case BUT-1838
 * closed by running the check per PERSON per INVITE. The owner is seated as an
 * admin beside the caller, which is a different question: it guarantees the chat
 * keeps an administrator when whoever started the first poll leaves.
 *
 * Region: inherits europe-west1 via `setGlobalOptions` in index.ts.
 */

import { onCall, HttpsError } from "firebase-functions/v2/https";
import { logger } from "firebase-functions/logger";
import * as admin from "firebase-admin";
import { createHash } from "crypto";
import { Collections } from "../shared/collections";
import {
  assertAccountMatured,
  assertAgeCompliant,
} from "../shared/caller-eligibility";
import { checkRateLimit } from "../middleware/rate_limiter";
import { isValidDocId } from "../shared/valid-doc-id";
import {
  findInadmissibleMembers,
  MAX_CHAT_GROUP_MEMBERS,
} from "./minor-membership-gate";
import {
  stageMemberAdditions,
  stageMemberRemoval,
  type ChatGroupMember,
} from "./chat-group-writes";
import { resolveMemberProfiles } from "./member-profiles";
import {
  createChatGroupWithDeps,
  MAX_GROUP_NAME_LENGTH,
} from "./create-chat-group";
import {
  writeGroupSystemMessage,
  SystemGroupEvent,
} from "./group-system-message";

const getDb = () => admin.firestore();

/** Shown when a social group has no name of its own to borrow. */
const FALLBACK_GROUP_NAME = "Matgruppen";

/**
 * The chat group's document id, derived from the social group so two concurrent
 * first polls collide on one document instead of minting two chats.
 *
 * HASHED, not concatenated: this id is also the CONVERSATION id, and a
 * conversation id built from raw uids ends up in log paths and error strings —
 * the leak BUT-1822 had to go back and mask for `direct_<uidA>_<uidB>`. It is
 * not a secret either way: anyone who can call this already knows both halves.
 */
function categoryChatId(ownerId: string, categoryId: string): string {
  return createHash("sha256")
    .update(`${ownerId}:${categoryId}`)
    .digest("hex")
    .slice(0, 20);
}

export interface EnsureCategoryChatRequest {
  categoryId: string;
  /** Owner of the social group — half of the pointer key, and the path segment. */
  ownerId: string;
}

export interface EnsureCategoryChatResponse {
  groupId: string;
  /** Equal to `groupId` by construction; both are returned so callers need not know that. */
  conversationId: string;
  /** True only when this call minted the chat. */
  created: boolean;
  addedUserIds: string[];
  removedUserIds: string[];
  memberCount: number;
}

/**
 * The single answer for "no such category", "not your category" and "you were
 * removed from this chat". Distinguishing them would confirm that a category id
 * exists and who is in it, to somebody the answer is already no for.
 */
function notAllowed(): HttpsError {
  return new HttpsError("permission-denied", "Not allowed.");
}

/**
 * BUT-1929. A site that discovers a deleted group conversation throws THIS,
 * so the client sees one shape wherever it is found. The `reason` detail is the whole point: without
 * it `ChatGroupErrorMapper` cannot tell this apart from any other
 * `failed-precondition` and falls through to its generic text, which is what
 * the in-transaction site did for its whole life.
 */
function conversationDeleted(): HttpsError {
  return new HttpsError(
    "failed-precondition",
    "Group conversation no longer exists.",
    { reason: "conversation-deleted" },
  );
}

/**
 * The roster a category implies. The owner is normally already inside
 * `friendUserIds` — creation seats them there and `migrateOwnersAsMembers()`
 * re-appends them on every login, so the uid can appear twice — which is why
 * this de-duplicates rather than concatenating.
 */
function rosterOf(data: admin.firestore.DocumentData, ownerId: string): string[] {
  const listed = Array.isArray(data.friendUserIds)
    ? (data.friendUserIds as unknown[])
    : [];
  return [...new Set([ownerId, ...listed])].filter(isValidDocId);
}

export const ensureCategoryChat = onCall<EnsureCategoryChatRequest>(
  { enforceAppCheck: true },
  async (request): Promise<EnsureCategoryChatResponse> => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "Sign-in required.");
    }
    const callerUid = request.auth.uid;

    const categoryId = request.data?.categoryId ?? "";
    const ownerId = request.data?.ownerId ?? "";
    if (!isValidDocId(categoryId) || !isValidDocId(ownerId)) {
      throw new HttpsError("invalid-argument", "Malformed group reference.");
    }

    const db = getDb();
    // Both eligibility checks run against the CALLER. This callable acts partly
    // on the owner's behalf — it borrows their group's roster and seats them as
    // an admin — and an age or maturity gate evaluated against the owner would
    // be the caller borrowing someone else's clearance.
    assertAgeCompliant(request.auth);
    await assertAccountMatured(db, request.auth);

    // Caller-keyed for the same reason, plus a practical one: an owner-keyed
    // bucket lets one member exhaust the budget for everybody in the group.
    const limit = await checkRateLimit(callerUid, "ensureCategoryChat");
    if (!limit.allowed) {
      throw new HttpsError("resource-exhausted", limit.reason ?? "Slow down.");
    }

    return ensureCategoryChatWithDeps(db, callerUid, ownerId, categoryId);
  },
);

/** Dependency-injected core — exposed for tests with a fake Firestore. */
export async function ensureCategoryChatWithDeps(
  db: admin.firestore.Firestore,
  callerUid: string,
  ownerId: string,
  categoryId: string,
): Promise<EnsureCategoryChatResponse> {
  const categoryRef = db
    .collection(Collections.users)
    .doc(ownerId)
    .collection(Collections.friendCategories)
    .doc(categoryId);

  const categorySnap = await categoryRef.get();
  if (!categorySnap.exists) {
    // Includes the transferred-group case: `transferOwnership` moves the
    // `ownerId` FIELD and leaves the document under the old owner's path, so a
    // transferred category is not found here. Those groups are already
    // un-editable by their new owner for the same reason: `firestore.rules`
    // reads the path segment. The poll, however, DID work before this change,
    // because the old path never read the category at all — BUT-1924.
    throw notAllowed();
  }
  const categoryData = categorySnap.data() as admin.firestore.DocumentData;
  const roster = rosterOf(categoryData, ownerId);
  if (!roster.includes(callerUid)) throw notAllowed();

  if (roster.length < 2) {
    // Structured, not a message the client greps. `createChatGroup` refuses the
    // same shape with `invalid-argument`; this one exists so the app can say
    // "you need one more person" in Swedish instead of surfacing that.
    throw new HttpsError(
      "failed-precondition",
      "This group has no other members.",
      { reason: "group-too-small" },
    );
  }
  if (roster.length > MAX_CHAT_GROUP_MEMBERS) {
    throw new HttpsError(
      "invalid-argument",
      `A group can hold at most ${MAX_CHAT_GROUP_MEMBERS} members.`,
    );
  }

  const existing = await db
    .collection(Collections.chatGroups)
    .where("sourceCategoryId", "==", categoryId)
    .where("sourceCategoryOwnerId", "==", ownerId)
    .limit(1)
    .get();

  if (existing.empty) {
    // Covers three cases with one behaviour: never created, torn down when it
    // emptied, and created before this feature existed (no pointer fields at
    // all). All three mean "no chat backs this category", and re-creating
    // re-stamps the pointer.
    const name =
      (typeof categoryData.name === "string" ? categoryData.name : "")
        .trim()
        .slice(0, MAX_GROUP_NAME_LENGTH) || FALLBACK_GROUP_NAME;

    let created;
    try {
      created = await createChatGroupWithDeps(db, callerUid, name, roster, {
        adminUids: [callerUid, ownerId],
        sourceCategory: { categoryId, ownerId },
        groupId: categoryChatId(ownerId, categoryId),
      });
    } catch (e) {
      // Two members pressing the poll button inside one round-trip both see an
      // empty lookup. The derived id makes them collide on the document instead
      // of each minting a chat — and the loser reconciles into the winner's,
      // rather than leaving an orphan group the app refuses to delete, which is
      // the exact harm this ticket exists to remove.
      if ((e as { code?: string } | null)?.code !== "already-exists") throw e;
      const raced = await db
        .collection(Collections.chatGroups)
        .doc(categoryChatId(ownerId, categoryId))
        .get();
      if (!raced.exists) throw e;
      return reconcile(
        db,
        callerUid,
        ownerId,
        categoryRef,
        raced as admin.firestore.QueryDocumentSnapshot,
      );
    }
    return {
      groupId: created.groupId,
      conversationId: created.conversationId,
      created: true,
      addedUserIds: roster.filter((u) => u !== callerUid),
      removedUserIds: [],
      memberCount: created.memberCount,
    };
  }

  return reconcile(db, callerUid, ownerId, categoryRef, existing.docs[0]);
}

/**
 * Bring an existing chat's roster in line with the social group.
 *
 * Adds anyone new, removes anyone the owner dropped from the category, and
 * writes NOTHING when the two already agree — the steady state, and the reason
 * a poll button cannot be used to spam a group with membership rows.
 */
async function reconcile(
  db: admin.firestore.Firestore,
  callerUid: string,
  ownerId: string,
  categoryRef: admin.firestore.DocumentReference,
  groupDoc: admin.firestore.QueryDocumentSnapshot,
): Promise<EnsureCategoryChatResponse> {
  const groupId = groupDoc.id;
  const data = groupDoc.data();

  const memberIds: string[] = Array.isArray(data.memberIds)
    ? (data.memberIds as unknown[]).filter(isValidDocId)
    : [];
  // Membership of the CHAT, not of the category, and it is a separate gate on
  // purpose: an admin who removed somebody from this chat must not have that
  // undone by the removed person pressing the poll button while still listed in
  // the social group. The owner gets NO exemption — they are seated at creation
  // and the sync never evicts them, so an owner outside the chat is one somebody
  // took out, which is precisely the case to refuse.
  if (!memberIds.includes(callerUid)) throw notAllowed();

  // Below the membership gate on purpose: this refusal is distinguishable from
  // `notAllowed()`, so answering it to a non-member would confirm the group
  // exists. No code path produces the shape.
  const rawConversationId = data.conversationId;
  if (!isValidDocId(rawConversationId)) {
    throw new HttpsError("failed-precondition", "Group has no conversation.");
  }
  const conversationId: string = rawConversationId;

  const departed: string[] = Array.isArray(data.departedUserIds)
    ? (data.departedUserIds as unknown[]).filter(isValidDocId)
    : [];

  const categorySnap = await categoryRef.get();
  if (!categorySnap.exists) throw notAllowed();
  const roster = rosterOf(
    categorySnap.data() as admin.firestore.DocumentData,
    ownerId,
  );

  // Anyone who left this chat, or was removed from it, stays out. The category
  // still lists them, so without this the next poll would seat them again —
  // which would make "leave the chat" mean nothing at all, and for a minor that
  // is the one exit that has to hold.
  const toAdd = roster.filter(
    (u) => !memberIds.includes(u) && !departed.includes(u),
  );
  // Only seats the SYNC made. Somebody an admin invited through the group screen
  // is a decision this mechanism must not undo — the mirror of `departedUserIds`,
  // which stops it undoing an explicit removal.
  const categorySeated: string[] = Array.isArray(data.categorySeatedUserIds)
    ? (data.categorySeatedUserIds as unknown[]).filter(isValidDocId)
    : [];
  const toRemove = memberIds.filter(
    (u) => categorySeated.includes(u) && !roster.includes(u) && u !== ownerId,
  );

  if (toAdd.length === 0 && toRemove.length === 0) {
    // BUT-1929. The transaction below carries the same check, but the steady
    // state — no roster drift — returns before ever opening one, so a caller
    // whose conversation was deleted got the dead id handed straight back and
    // every later poll for this category repeated it. The read is paid on the
    // COMMON path, which is the cost of the check being reachable at all.
    const convoSnap = await db
      .collection(Collections.conversations)
      .doc(conversationId)
      .get();
    if (!convoSnap.exists) throw conversationDeleted();
    return {
      groupId,
      conversationId,
      created: false,
      addedUserIds: [],
      removedUserIds: [],
      memberCount: memberIds.length,
    };
  }

  if (memberIds.length + toAdd.length > MAX_CHAT_GROUP_MEMBERS) {
    throw new HttpsError(
      "invalid-argument",
      `A group can hold at most ${MAX_CHAT_GROUP_MEMBERS} members.`,
    );
  }

  // THE GATE, against the caller, before any write — and a refusal fails the
  // WHOLE call. Dropping a blocked member and proceeding would ship a poll the
  // group can see and one child cannot, which reads as a bug rather than a
  // safety decision.
  if (toAdd.length > 0) {
    const blocked = await findInadmissibleMembers(db, callerUid, toAdd);
    if (blocked.length > 0) {
      throw new HttpsError(
        "permission-denied",
        "Some people could not be added to this group.",
        { blockedUserIds: blocked },
      );
    }
  }

  const profiles: ChatGroupMember[] =
    toAdd.length > 0 ? await resolveMemberProfiles(db, toAdd) : [];
  const stamp = admin.firestore.Timestamp.now();

  // What the transaction actually did, which is not necessarily what was asked:
  // a concurrent invite or departure can move the roster between the read above
  // and the commit. Hoisted out of the closure because Firestore may run it more
  // than once — the last assignment is the one that committed.
  let seated: ChatGroupMember[] = [];
  let evicted: string[] = [];
  let memberCountAfter = memberIds.length;

  await db.runTransaction(async (tx) => {
    // Both halves are re-read inside the transaction. The group's roster can
    // move under a concurrent invite; the CATEGORY's can move because the owner
    // just removed somebody, and seating them anyway on a read taken a moment
    // earlier is the one race with a safety cost.
    const [fresh, freshCategory, freshConvo] = await Promise.all([
      tx.get(groupDoc.ref),
      tx.get(categoryRef),
      tx.get(db.collection(Collections.conversations).doc(conversationId)),
    ]);
    if (!fresh.exists) {
      throw new HttpsError("failed-precondition", "Group no longer exists.");
    }
    // The staging helpers `tx.update` the conversation, which rejects grpc 5 on
    // a missing document. `firestore.rules` still lets any participant delete a
    // group conversation (the client's refusal is UX, not a control), and the
    // pointer is sticky now, so one deletion would otherwise wedge every future
    // poll for this category behind a bare `internal`.
    if (!freshConvo.exists) {
      throw conversationDeleted();
    }
    if (!freshCategory.exists) throw notAllowed();
    const freshRoster = rosterOf(
      freshCategory.data() as admin.firestore.DocumentData,
      ownerId,
    );
    const freshMembers: string[] = Array.isArray(fresh.get("memberIds"))
      ? (fresh.get("memberIds") as unknown[]).filter(isValidDocId)
      : [];
    const freshDeparted: string[] = Array.isArray(fresh.get("departedUserIds"))
      ? (fresh.get("departedUserIds") as unknown[]).filter(isValidDocId)
      : [];
    const freshSeated: string[] = Array.isArray(
      fresh.get("categorySeatedUserIds"),
    )
      ? (fresh.get("categorySeatedUserIds") as unknown[]).filter(isValidDocId)
      : [];

    // Only candidates the gate already cleared, and only those the category
    // still names — never a uid discovered by the fresh read, which nothing has
    // checked.
    seated = profiles.filter(
      (m) =>
        freshRoster.includes(m.uid) &&
        !freshMembers.includes(m.uid) &&
        !freshDeparted.includes(m.uid),
    );
    evicted = freshMembers.filter(
      (u) =>
        freshSeated.includes(u) && !freshRoster.includes(u) && u !== ownerId,
    );
    memberCountAfter = freshMembers.length + seated.length - evicted.length;
    if (seated.length === 0 && evicted.length === 0) return;
    // An empty group is a one-way door: the member-facing rules on both
    // documents gate on membership, so no ordinary user could then read, update
    // or delete either. The roster is re-read inside this transaction and can
    // have moved since the checks above, so do not treat this as dead code.
    if (memberCountAfter <= 0) {
      throw new HttpsError(
        "failed-precondition",
        "Sync would empty the group.",
      );
    }
    if (memberCountAfter > MAX_CHAT_GROUP_MEMBERS) {
      throw new HttpsError(
        "invalid-argument",
        `A group can hold at most ${MAX_CHAT_GROUP_MEMBERS} members.`,
      );
    }

    if (seated.length > 0) {
      stageMemberAdditions(tx, {
        db,
        groupId,
        conversationId,
        members: seated,
        addedBy: callerUid,
        joinedAt: stamp,
        categorySeated: true,
      });
    }
    for (const uid of evicted) {
      // No tombstone: this removal MIRRORS the category. Putting somebody back
      // into the social group must put them back into its chat, and a tombstone
      // here would make that impossible.
      stageMemberRemoval(tx, {
        db,
        groupId,
        conversationId,
        uid,
        removedAt: stamp,
      });
    }
  });

  // Outside the transaction: a failed courtesy row must not undo a membership
  // change. Every other membership write in this module announces itself, and a
  // sync that moved people silently would be the odd one out.
  await Promise.all([
    ...seated.map((member) =>
      writeGroupSystemMessage(db, {
        conversationId,
        event: SystemGroupEvent.memberAdded,
        subjectUserId: member.uid,
        actorDisplayName: member.displayName,
      }).catch((e) => logSystemMessageFailure(groupId, e)),
    ),
    ...evicted.map((uid) =>
      writeGroupSystemMessage(db, {
        conversationId,
        event: SystemGroupEvent.memberLeft,
        subjectUserId: uid,
        actorDisplayName: displayNameOf(data, uid),
      }).catch((e) => logSystemMessageFailure(groupId, e)),
    ),
  ]);

  logger.info("[ensureCategoryChat] reconciled", {
    groupId,
    added: seated.length,
    removed: evicted.length,
  });

  return {
    groupId,
    conversationId,
    created: false,
    addedUserIds: seated.map((m) => m.uid),
    removedUserIds: evicted,
    memberCount: memberCountAfter,
  };
}

function displayNameOf(
  data: admin.firestore.DocumentData,
  uid: string,
): string {
  const names = data.memberDisplayNames as Record<string, unknown> | undefined;
  const raw = names?.[uid];
  return typeof raw === "string" && raw.length > 0 ? raw : "?";
}

function logSystemMessageFailure(groupId: string, e: unknown): void {
  logger.error("[ensureCategoryChat] system message write failed", {
    groupId,
    errCode: (e as { code?: number | string } | null)?.code ?? "unknown",
    errName: (e as Error | null)?.name,
  });
}
