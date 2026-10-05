/**
 * BUT-2265: server-side group-invitation acceptance.
 *
 * `users/{owner}/friend_categories/{groupId}` admits a client read or update
 * only from the owner or from someone already in `friendUserIds`. An invitee is
 * neither, so the client's own accept path (read the group, add itself) was
 * refused on both steps and nobody could ever join a group. The membership
 * write moves here, behind the Admin SDK, AFTER validating the
 * `social_requests` invitation, so the rules stay closed to non-members.
 *
 * The invitee must be a friend of the inviter. Invitations are only sent to
 * friends, and the accepted minor rule is "a minor may be added to a group by
 * any of their FRIENDS"; re-checking it here keeps a hand-written invitation
 * from a stranger from seating anyone.
 *
 * Region: inherits europe-west1 via `setGlobalOptions` in index.ts.
 * Idempotent: accepting again when already a member writes nothing new.
 */

import { onCall, HttpsError } from "firebase-functions/v2/https";
import { logger } from "firebase-functions/logger";
import * as admin from "firebase-admin";
import { isValidDocId } from "../shared/valid-doc-id";

const db = admin.firestore();

/** Mirrors the `friendUserIds.size() <= 200` cap in firestore.rules. */
export const MAX_GROUP_MEMBERS = 200;

export interface AcceptGroupInvitationRequest {
  /** Document id of the `social_requests` invitation being accepted. */
  invitationId: string;
}

export interface AcceptGroupInvitationResponse {
  success: boolean;
  /** True when the caller was already a member (a repeated tap). */
  alreadyMember: boolean;
  /** Owner of the group, so the client can read it once it is a member. */
  ownerId: string;
  groupId: string;
}

export const acceptGroupInvitation = onCall<AcceptGroupInvitationRequest>(
  {
    enforceAppCheck: true,
  },
  async (request): Promise<AcceptGroupInvitationResponse> => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "Sign-in required.");
    }
    const invitationId = request.data?.invitationId;
    if (!isValidDocId(invitationId)) {
      throw new HttpsError("invalid-argument", "invitationId is required.");
    }
    return acceptGroupInvitationWithDeps(db, request.auth.uid, invitationId);
  },
);

/**
 * DI core — exposed for the emulator integration test.
 *
 * Validates the invitation (exists, a group invitation, addressed to the
 * caller, still pending), the group (exists, owned by the inviter, below the
 * member cap) and the friendship, then in one transaction adds the caller to
 * `friendUserIds` and marks the invitation accepted.
 */
export async function acceptGroupInvitationWithDeps(
  database: admin.firestore.Firestore,
  callerUid: string,
  invitationId: string,
): Promise<AcceptGroupInvitationResponse> {
  const invitationRef = database.collection("social_requests").doc(invitationId);

  return database.runTransaction(async (tx) => {
    const invitationSnap = await tx.get(invitationRef);
    if (!invitationSnap.exists) {
      throw new HttpsError("not-found", "Invitation not found.");
    }
    const data = invitationSnap.data() ?? {};
    if (data.type !== "groupInvitation") {
      throw new HttpsError("failed-precondition", "Not a group invitation.");
    }
    const fromUserId = data.fromUserId as unknown;
    const toUserId = data.toUserId as unknown;
    const groupId = data.groupId as unknown;
    const status = data.status as unknown;
    if (
      !isValidDocId(fromUserId) ||
      !isValidDocId(toUserId) ||
      !isValidDocId(groupId)
    ) {
      throw new HttpsError("failed-precondition", "Malformed invitation.");
    }
    if (toUserId !== callerUid) {
      throw new HttpsError(
        "permission-denied",
        "Only the invited user can accept this invitation.",
      );
    }
    // `accepted` passes for a repeated tap; anything else is final.
    if (status !== "pending" && status !== "accepted") {
      throw new HttpsError(
        "failed-precondition",
        "Invitation is no longer pending.",
      );
    }

    const groupRef = database
      .collection("users").doc(fromUserId)
      .collection("friend_categories").doc(groupId);
    // The INVITER's copy: the caller can write its own friends list, so only
    // the inviter's side (written by the inviter or acceptFriendRequest)
    // proves the friendship.
    const friendRef = database
      .collection("users").doc(fromUserId)
      .collection("friends").doc(callerUid);

    const [groupSnap, friendSnap] = await Promise.all([
      tx.get(groupRef),
      tx.get(friendRef),
    ]);

    if (!groupSnap.exists) {
      throw new HttpsError("not-found", "Group not found.");
    }
    const group = groupSnap.data() ?? {};
    if (group.ownerId !== fromUserId) {
      throw new HttpsError(
        "failed-precondition",
        "Invitation does not come from the group's owner.",
      );
    }
    if (!friendSnap.exists) {
      throw new HttpsError(
        "permission-denied",
        "Only a friend's invitation can be accepted.",
      );
    }

    const members = Array.isArray(group.friendUserIds) ?
      (group.friendUserIds as unknown[]) :
      [];
    const alreadyMember = members.includes(callerUid);

    // A spent invitation repeats a tap, never a join: someone removed from
    // the group, or who left, must not be re-seated by their old invitation.
    if (status === "accepted" && !alreadyMember) {
      throw new HttpsError(
        "failed-precondition",
        "Invitation is no longer pending.",
      );
    }

    if (!alreadyMember) {
      if (members.length >= MAX_GROUP_MEMBERS) {
        throw new HttpsError("resource-exhausted", "Group is full.");
      }
      tx.update(groupRef, {
        friendUserIds: admin.firestore.FieldValue.arrayUnion(callerUid),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });
    }
    if (status !== "accepted") {
      tx.update(invitationRef, {
        status: "accepted",
        respondedAt: admin.firestore.FieldValue.serverTimestamp(),
      });
    }

    logger.info("[acceptGroupInvitation] accepted", {
      invitationId,
      from_prefix: fromUserId.slice(0, 6),
      to_prefix: callerUid.slice(0, 6),
      alreadyMember,
    });

    return { success: true, alreadyMember, ownerId: fromUserId, groupId };
  });
}
