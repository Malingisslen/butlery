/**
 * BUT-2321: the owner of a friend group leaves it by handing it to a member.
 *
 * A group's owner is decided by WHERE it is stored
 * (`users/{ownerId}/friend_categories/{groupId}`), not by its `ownerId` field,
 * so a handover moves the document to the new owner's account under the same
 * id. Everything that names the group by id alone (shared recipes, lists,
 * menus, pings, cooking sessions) follows without a write. What names it by its
 * owner is re-pointed in the same transaction:
 *  - the group chat (`sourceCategoryOwnerId`, `createdBy`, `adminIds`), so the
 *    next `ensureCategoryChat` finds the same chat instead of making another;
 *  - a household linked to the group (Malin, 2026-10-09: the household follows
 *    the group). The new owner must already be a member of it, because nobody
 *    is put in a household by someone else (DPIA R3). The old owner leaves it
 *    and their allergen share is deleted in the same commit (DPIA R7).
 *
 * The old owner leaves the group. Their unanswered invitations to it are
 * cancelled; accepting one would fail anyway, because it is read from the
 * sender's account. A group with an open report is not handed over, so a
 * handover cannot move a group out from under a moderation case.
 *
 * The old document is deleted last. `onHouseholdGroupWritten` fires on that
 * delete, and finds nothing linked to the old owner any more.
 *
 * Region: inherits europe-west1 via `setGlobalOptions` in index.ts.
 */

import { onCall, HttpsError } from "firebase-functions/v2/https";
import { logger } from "firebase-functions/logger";
import * as admin from "firebase-admin";
import { Collections } from "../shared/collections";
import { assertAgeCompliant } from "../shared/caller-eligibility";
import { enforceRateLimit } from "../middleware/rate_limiter";
import { isValidDocId } from "../shared/valid-doc-id";
import { OPEN_REPORT_STATUSES, REPORTS } from "../moderation/report-status";
import {
  groupDocRef,
  isOwnedLink,
  linkedHouseholdsQuery,
  memberIdsOf,
  membersOf,
  shareDocRef,
} from "../family/group-household";
import {
  SystemGroupEvent,
  writeGroupSystemMessage,
} from "./group-system-message";
import { resolveMemberProfiles } from "./member-profiles";

export interface HandOverGroupRequest {
  groupId: string;
  newOwnerId: string;
}

export type HandOverGroupResponse = Record<string, never>;

export interface HandOverGroupDeps {
  /** Whether [uid]'s account carries the age-verification claim. */
  isAgeCompliant: (uid: string) => Promise<boolean>;
}

/** Upper bound on the pending invitations one handover cancels. */
const MAX_CANCELLED_INVITATIONS = 100;

/** The fields `FriendCategory.toFirestore` writes, and nothing else. */
const GROUP_FIELDS = [
  "name",
  "description",
  "emoji",
  "createdAt",
  "isHousehold",
] as const;

export const handOverGroup = onCall<HandOverGroupRequest>(
  { enforceAppCheck: true },
  async (request): Promise<HandOverGroupResponse> => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "Sign-in required.");
    }
    const groupId = request.data?.groupId;
    const newOwnerId = request.data?.newOwnerId;
    if (!isValidDocId(groupId) || !isValidDocId(newOwnerId)) {
      throw new HttpsError("invalid-argument", "groupId and newOwnerId are required.");
    }
    assertAgeCompliant(request.auth);
    await enforceRateLimit(request.auth.uid, "handOverGroup");
    return handOverGroupWithDeps(
      admin.firestore(),
      request.auth.uid,
      { groupId, newOwnerId },
      {
        isAgeCompliant: async (uid) => {
          try {
            return (await admin.auth().getUser(uid)).customClaims?.ageCompliant === true;
          } catch (err) {
            const code = (err as { code?: string }).code;
            if (code === "auth/user-not-found" || code === "auth/invalid-uid") return false;
            throw err;
          }
        },
      },
    );
  },
);

function stringList(value: unknown): string[] {
  return Array.isArray(value)
    ? value.filter((v): v is string => typeof v === "string")
    : [];
}

/** Dependency-injected core, exposed for the emulator integration test. */
export async function handOverGroupWithDeps(
  db: admin.firestore.Firestore,
  callerUid: string,
  request: HandOverGroupRequest,
  deps: HandOverGroupDeps,
): Promise<HandOverGroupResponse> {
  const { groupId, newOwnerId } = request;
  if (newOwnerId === callerUid) {
    throw new HttpsError("invalid-argument", "The owner cannot hand over to themselves.");
  }
  const oldRef = groupDocRef(db, { ownerId: callerUid, groupId });
  const newRef = groupDocRef(db, { ownerId: newOwnerId, groupId });
  const oldLink = { ownerId: callerUid, groupId };
  const now = admin.firestore.Timestamp.now();

  // Outside the transaction: an Auth read cannot be part of it, and the claim
  // only changes by a deliberate server action.
  const newOwnerEligible = await deps.isAgeCompliant(newOwnerId);

  const result = await db.runTransaction(async (tx) => {
    const [oldSnap, newSnap] = await Promise.all([tx.get(oldRef), tx.get(newRef)]);
    const group = oldSnap.data();

    if (!oldSnap.exists) {
      throw new HttpsError("permission-denied", "Not allowed.");
    }
    // Owner by path AND by field: a group where the two disagree was moved by
    // the old field-only transfer and is not handed over again from here.
    const members = stringList(group?.friendUserIds);
    if (group?.ownerId !== callerUid || !members.includes(newOwnerId)) {
      throw new HttpsError("permission-denied", "Not allowed.");
    }
    if (group?.isDefault === true) {
      throw new HttpsError("failed-precondition", "default-group");
    }
    if (newSnap.exists) {
      throw new HttpsError("failed-precondition", "id-taken");
    }
    if (!newOwnerEligible) {
      throw new HttpsError("failed-precondition", "new-owner-not-eligible");
    }

    const [reports, chats, households, invitations] = await Promise.all([
      tx.get(db.collection(REPORTS)
        .where("contentType", "==", "group")
        .where("contentId", "==", groupId)
        .where("contentOwnerId", "==", callerUid)
        .where("status", "in", [...OPEN_REPORT_STATUSES])
        .limit(1)),
      tx.get(db.collection(Collections.chatGroups)
        .where("sourceCategoryId", "==", groupId)
        .where("sourceCategoryOwnerId", "==", callerUid)),
      tx.get(linkedHouseholdsQuery(db, oldLink)),
      tx.get(db.collection(Collections.socialRequests)
        .where("fromUserId", "==", callerUid)
        .where("groupId", "==", groupId)
        .where("status", "==", "pending")
        .limit(MAX_CANCELLED_INVITATIONS)),
    ]);
    if (!reports.empty) {
      throw new HttpsError("failed-precondition", "open-report");
    }
    const linked = households.docs.filter((d) => isOwnedLink(d.data(), oldLink));
    if (linked.some((d) => !memberIdsOf(d.data()).includes(newOwnerId))) {
      throw new HttpsError("failed-precondition", "new-owner-not-in-household");
    }

    const moved: Record<string, unknown> = {
      ownerId: newOwnerId,
      friendUserIds: members.filter((id) => id !== callerUid),
      sortOrder: 0,
      isDefault: false,
      updatedAt: now,
    };
    for (const field of GROUP_FIELDS) {
      if (group?.[field] !== undefined) moved[field] = group[field];
    }
    tx.create(newRef, moved);

    let conversationId: string | null = null;
    for (const chat of chats.docs) {
      const data = chat.data();
      const chatMembers = stringList(data.memberIds);
      const admins = stringList(data.adminIds).filter((id) => id !== callerUid);
      if (chatMembers.includes(newOwnerId) && !admins.includes(newOwnerId)) {
        admins.push(newOwnerId);
      }
      tx.update(chat.ref, {
        sourceCategoryOwnerId: newOwnerId,
        createdBy: newOwnerId,
        // An admin list may not go empty; the old owner then stays until the
        // next roster sync removes them from the chat.
        adminIds: admins.length > 0 ? admins : stringList(data.adminIds),
        updatedAt: now,
      });
      if (typeof data.conversationId === "string") {
        conversationId = data.conversationId;
      }
    }

    for (const household of linked) {
      const data = household.data();
      tx.update(household.ref, {
        createdBy: newOwnerId,
        sourceGroupOwnerId: newOwnerId,
        members: membersOf(data)
          .filter((m) => m.userId !== callerUid)
          .map((m) => m.userId === newOwnerId ? { ...m, permission: "admin" } : m),
        memberUserIds: memberIdsOf(data).filter((id) => id !== callerUid),
        [`memberPermissions.${callerUid}`]: admin.firestore.FieldValue.delete(),
        [`memberPermissions.${newOwnerId}`]: "admin",
        updatedAt: now,
      });
      tx.delete(shareDocRef(db, household.id, callerUid));
    }

    for (const invitation of invitations.docs) {
      tx.update(invitation.ref, { status: "cancelled", respondedAt: now });
    }

    tx.delete(oldRef);
    return { conversationId };
  });

  if (result.conversationId) {
    // The message the new owner gets. Best effort: the handover has
    // committed, and a missing chat row must not report it as failed.
    try {
      const [newOwner] = await resolveMemberProfiles(db, [newOwnerId]);
      await writeGroupSystemMessage(db, {
        conversationId: result.conversationId,
        event: SystemGroupEvent.ownerHandedOver,
        subjectUserId: newOwnerId,
        actorDisplayName: newOwner.displayName,
      });
    } catch (err) {
      logger.warn("[handOverGroup] system message not written", {
        groupId,
        error: (err as Error).message,
      });
    }
  }

  logger.info("[handOverGroup] done", {
    event: "group_handover",
    groupId,
  });
  return {};
}
