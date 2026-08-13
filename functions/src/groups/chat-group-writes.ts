/**
 * BUT-1838: the ONE writer of chat-group membership.
 *
 * "Who is in this group, and since when" is stored in three places, because
 * three different readers need it and none of them can read the others:
 *
 * 1. `chat_groups/{groupId}.memberIds` — the SOURCE OF TRUTH. Server-written
 *    only; the gate runs before anything lands here.
 * 2. `conversations/{conversationId}.participantIds` + `.memberSince` — what
 *    `firestore.rules` can actually see. The messages read rule already `get()`s
 *    this document, so putting the join stamp here costs nothing extra; putting
 *    it on the group instead would cost a second `get()` per message read.
 * 3. `conversations/{conversationId}/participants/{uid}` — the roster row the
 *    client lists, whose `joinedAt` is the same fact a third time.
 *
 * Three copies of one fact is the shape this repo has been burned by
 * repeatedly (BUT-1798's dual-spelt membership field, BUT-1732's `grants`).
 * The mitigation is not fewer readers — each one is load-bearing — it is that
 * every copy is written HERE, in one transaction, from one value. Nothing else
 * in the codebase may write `memberIds`, `participantIds`, `memberSince` or
 * `joinedAt`. If you find yourself adding a fourth writer, you are adding the
 * drift.
 *
 * The stamp is an explicit `Timestamp`, not `FieldValue.serverTimestamp()`, for
 * exactly that reason: one value is computed once and written to all three
 * copies, so "they agree" is a property a test can assert byte-for-byte rather
 * than a property of how Firestore resolves sentinels.
 */

import * as admin from "firebase-admin";
import { Collections } from "../shared/collections";

/**
 * The uid-keyed maps a conversation document carries. `memberSince` is the
 * BUT-1838 addition and is the one `firestore.rules` reads to decide which
 * history a member may see — which is why the conversations UPDATE rule denies
 * any client diff that touches it. A member who could raise or lower their own
 * stamp could read the backlog they were never meant to see, or hide history
 * from someone else.
 */
export const PER_USER_CONVERSATION_MAPS = [
  "participantDisplayNames",
  "participantAvatarUrls",
  "lastReadTimestamps",
  "perUserSettings",
  "memberSince",
] as const;

export interface ChatGroupMember {
  uid: string;
  displayName: string;
  avatarUrl: string | null;
}

/** Roster-row shape. Mirrors `validParticipant()` in firestore.rules exactly. */
function rosterRow(
  conversationId: string,
  member: ChatGroupMember,
  joinedAt: admin.firestore.Timestamp,
): Record<string, unknown> {
  return {
    conversationId,
    participantId: member.uid,
    displayName: member.displayName,
    avatarUrl: member.avatarUrl,
    joinedAt,
    lastReadAt: joinedAt,
    // DESCRIPTIVE, never authorization. `chat_groups.adminIds` is the only
    // thing any code may consult to decide what someone may do; this field
    // exists because the roster's `hasOnly` validator requires it and the
    // client renders it. Same discipline as `socialData.grants` (BUT-1797):
    // one authoritative list, one descriptive echo, and the echo is never read
    // by a decision. Added 2026-08-13.
    role: "member",
    isMuted: false,
  };
}

/**
 * Stages the three documents a brand-new group is made of.
 *
 * Lives beside `stageMemberAdditions` rather than in the create callable, so the
 * module's promise — every copy of "who is in this group, and since when" is
 * written here — holds for the first write too. A create that built its own
 * documents would be the second writer, and the drift would start at birth.
 */
export function stageGroupCreation(
  tx: admin.firestore.Transaction,
  params: {
    db: admin.firestore.Firestore;
    groupId: string;
    conversationId: string;
    name: string;
    creatorUid: string;
    members: ChatGroupMember[];
    joinedAt: admin.firestore.Timestamp;
  },
): void {
  const { db, groupId, conversationId, name, creatorUid, members, joinedAt } =
    params;
  const groupRef = db.collection(Collections.chatGroups).doc(groupId);
  const convoRef = db.collection(Collections.conversations).doc(conversationId);

  const memberIds = members.map((m) => m.uid);
  const displayNames: Record<string, string> = {};
  const avatarUrls: Record<string, string | null> = {};
  const stamps: Record<string, admin.firestore.Timestamp> = {};
  const addedBy: Record<string, string> = {};
  for (const member of members) {
    displayNames[member.uid] = member.displayName;
    avatarUrls[member.uid] = member.avatarUrl;
    stamps[member.uid] = joinedAt;
    addedBy[member.uid] = creatorUid;
    tx.set(
      convoRef.collection(Collections.participants).doc(member.uid),
      rosterRow(conversationId, member, joinedAt),
    );
  }

  tx.set(groupRef, {
    name,
    memberIds,
    // The creator is the only admin at birth, and `adminIds` is immutable
    // afterwards: firestore.rules permits no client write to it and no callable
    // changes it. Promoting or demoting an admin is a feature that does not
    // exist yet; when it is built it needs its own gated callable, not a
    // widened update rule (that is precisely the metadata.creatorId smuggling
    // BUT-1788 had to close once already).
    adminIds: [creatorUid],
    memberDisplayNames: displayNames,
    memberAvatarUrls: avatarUrls,
    memberAddedBy: addedBy,
    conversationId,
    createdBy: creatorUid,
    createdAt: joinedAt,
    updatedAt: joinedAt,
  });

  tx.set(convoRef, {
    participantIds: memberIds,
    participantDisplayNames: displayNames,
    participantAvatarUrls: avatarUrls,
    lastReadTimestamps: stamps,
    // The history cut-off, from the same value as the roster rows above.
    memberSince: stamps,
    perUserSettings: {},
    // What tells `firestore.rules` this conversation is group-owned: the
    // history cut-off applies only where `groupId` is present, which is how the
    // one pre-existing direct conversation stays untouched by it.
    groupId,
    isGroup: true,
    title: name,
    lastMessage: null,
    metadata: { creatorId: creatorUid },
    createdAt: joinedAt,
    updatedAt: joinedAt,
  });
}

/**
 * Stages every write that adds members to a group, across all three documents.
 *
 * Callers pass a transaction because the group document must be read (for the
 * current membership and the member cap) in the same atomic step that writes it
 * — otherwise two concurrent invites each see the pre-state and the second
 * silently overwrites the first's stamps.
 */
export function stageMemberAdditions(
  tx: admin.firestore.Transaction,
  params: {
    db: admin.firestore.Firestore;
    groupId: string;
    conversationId: string;
    members: ChatGroupMember[];
    /** Who is seating them — the identity the safety backstop checks against. */
    addedBy: string;
    joinedAt: admin.firestore.Timestamp;
  },
): void {
  const { db, groupId, conversationId, members, addedBy, joinedAt } = params;
  if (members.length === 0) return;

  const groupRef = db.collection(Collections.chatGroups).doc(groupId);
  const convoRef = db.collection(Collections.conversations).doc(conversationId);

  const groupUpdate: Record<string, unknown> = {
    memberIds: admin.firestore.FieldValue.arrayUnion(
      ...members.map((m) => m.uid),
    ),
    updatedAt: joinedAt,
  };
  const convoUpdate: Record<string, unknown> = {
    participantIds: admin.firestore.FieldValue.arrayUnion(
      ...members.map((m) => m.uid),
    ),
    updatedAt: joinedAt,
  };
  for (const member of members) {
    groupUpdate[`memberDisplayNames.${member.uid}`] = member.displayName;
    groupUpdate[`memberAvatarUrls.${member.uid}`] = member.avatarUrl;
    groupUpdate[`memberAddedBy.${member.uid}`] = addedBy;
    convoUpdate[`participantDisplayNames.${member.uid}`] = member.displayName;
    convoUpdate[`participantAvatarUrls.${member.uid}`] = member.avatarUrl;
    convoUpdate[`lastReadTimestamps.${member.uid}`] = joinedAt;
    // The history cut-off. Written ONLY here, and only ever on the way in — an
    // existing member's stamp is never restamped, or rejoining a group would
    // silently erase the history they already had access to.
    convoUpdate[`memberSince.${member.uid}`] = joinedAt;
    tx.set(
      convoRef.collection(Collections.participants).doc(member.uid),
      rosterRow(conversationId, member, joinedAt),
    );
  }

  tx.update(groupRef, groupUpdate);
  tx.update(convoRef, convoUpdate);
}

/**
 * Stages every write that removes one member, across all three documents.
 *
 * `memberSince` goes with them. Leaving it behind would keep a record of when a
 * departed person joined on a document the group still reads — the residual
 * class BUT-1705 already had to clean up once for shared shopping lists — and
 * would silently pin their old cut-off if they ever rejoined.
 */
export function stageMemberRemoval(
  tx: admin.firestore.Transaction,
  params: {
    db: admin.firestore.Firestore;
    groupId: string;
    conversationId: string;
    uid: string;
    removedAt: admin.firestore.Timestamp;
  },
): void {
  const { db, groupId, conversationId, uid, removedAt } = params;
  const groupRef = db.collection(Collections.chatGroups).doc(groupId);
  const convoRef = db.collection(Collections.conversations).doc(conversationId);

  const groupUpdate: Record<string, unknown> = {
    memberIds: admin.firestore.FieldValue.arrayRemove(uid),
    // A departing admin loses the right with the membership. Kept in the same
    // write so there is never an instant where someone administers a group they
    // are not in.
    adminIds: admin.firestore.FieldValue.arrayRemove(uid),
    updatedAt: removedAt,
    [`memberDisplayNames.${uid}`]: admin.firestore.FieldValue.delete(),
    [`memberAvatarUrls.${uid}`]: admin.firestore.FieldValue.delete(),
    [`memberAddedBy.${uid}`]: admin.firestore.FieldValue.delete(),
  };
  const convoUpdate: Record<string, unknown> = {
    participantIds: admin.firestore.FieldValue.arrayRemove(uid),
    updatedAt: removedAt,
  };
  for (const map of PER_USER_CONVERSATION_MAPS) {
    convoUpdate[`${map}.${uid}`] = admin.firestore.FieldValue.delete();
  }

  tx.update(groupRef, groupUpdate);
  tx.update(convoRef, convoUpdate);
  tx.delete(convoRef.collection(Collections.participants).doc(uid));
}
