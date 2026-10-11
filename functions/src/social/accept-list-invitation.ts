/**
 * BUT-2089: the invitee takes the seat a `listInvitation` offers.
 *
 * The rules refuse a client write that adds someone else's key to
 * `memberPermissions`. Nothing on the invitation is trusted beyond its id and
 * what the server wrote there. In one transaction this re-reads the row, the
 * live list, both friend documents and both block documents, and seats the
 * caller only if the inviter is STILL the owner or an admin, the two are still
 * friends both ways and neither has blocked the other.
 *
 * Every refusal is the same word, so the invitee learns nothing about the
 * inviter's standing on the list or whether they blocked anyone. A repeated tap
 * by someone already seated is a success and writes nothing to the list.
 *
 * Region: inherits europe-west1 via `setGlobalOptions` in index.ts.
 */

import { onCall, HttpsError } from "firebase-functions/v2/https";
import { logger } from "firebase-functions/logger";
import * as admin from "firebase-admin";
import { Collections } from "../shared/collections";
import {
  assertAccountMatured,
  assertAgeCompliant,
} from "../shared/caller-eligibility";
import { enforceRateLimit } from "../middleware/rate_limiter";
import { isValidDocId } from "../shared/valid-doc-id";
import {
  MAX_LIST_MEMBERS,
  isInvitablePermission,
  mayInvite,
  memberKeys,
} from "./send-list-invitations";

export interface AcceptListInvitationRequest {
  invitationId: string;
}

export interface AcceptListInvitationResponse {
  success: boolean;
  /** True when the caller was already on the list (a repeated tap). */
  alreadyMember: boolean;
  listId: string;
}

export const acceptListInvitation = onCall<AcceptListInvitationRequest>(
  { enforceAppCheck: true },
  async (request): Promise<AcceptListInvitationResponse> => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "Sign-in required.");
    }
    const invitationId = request.data?.invitationId;
    if (!isValidDocId(invitationId)) {
      throw new HttpsError("invalid-argument", "invitationId is required.");
    }
    const db = admin.firestore();
    assertAgeCompliant(request.auth);
    await assertAccountMatured(db, request.auth);
    await enforceRateLimit(request.auth.uid, "acceptListInvitation");
    return acceptListInvitationWithDeps(db, request.auth.uid, invitationId);
  },
);

function unavailable(): HttpsError {
  return new HttpsError("failed-precondition", "Invitation is not available.");
}

/** Dependency-injected core, exposed for the emulator integration test. */
export async function acceptListInvitationWithDeps(
  db: admin.firestore.Firestore,
  callerUid: string,
  invitationId: string,
): Promise<AcceptListInvitationResponse> {
  const invitationRef = db.collection(Collections.socialRequests).doc(invitationId);

  const result = await db.runTransaction(async (tx) => {
    const invitationSnap = await tx.get(invitationRef);
    const row = invitationSnap.data() ?? {};
    const fromUserId = row.fromUserId as unknown;
    const listId = row.listId as unknown;
    if (
      !invitationSnap.exists ||
      row.type !== "listInvitation" ||
      row.toUserId !== callerUid ||
      !isValidDocId(fromUserId) ||
      !isValidDocId(listId)
    ) {
      throw unavailable();
    }

    const listRef = db.collection(Collections.unifiedSharedShoppingLists).doc(listId);
    const [listSnap, inviterSide, inviteeSide, blockedByInvitee, blockedByInviter] =
      await Promise.all([
        tx.get(listRef),
        tx.get(db.collection(Collections.users).doc(fromUserId)
          .collection("friends").doc(callerUid)),
        tx.get(db.collection(Collections.users).doc(callerUid)
          .collection("friends").doc(fromUserId)),
        tx.get(db.collection(Collections.blocks).doc(`${callerUid}_${fromUserId}`)),
        tx.get(db.collection(Collections.blocks).doc(`${fromUserId}_${callerUid}`)),
      ]);
    const list = listSnap.data() ?? {};
    const members = memberKeys(list);

    // A repeated tap. Only a seat that exists answers it: a row a client
    // flipped to `accepted` itself seats nobody.
    if (listSnap.exists && members.includes(callerUid)) {
      if (row.status === "pending") {
        tx.update(invitationRef, {
          status: "accepted",
          respondedAt: admin.firestore.FieldValue.serverTimestamp(),
        });
      }
      return { alreadyMember: true, listId };
    }

    const expiresAt = row.expiresAt;
    if (
      row.status !== "pending" ||
      !(expiresAt instanceof admin.firestore.Timestamp) ||
      expiresAt.toMillis() <= Date.now() ||
      !listSnap.exists ||
      !mayInvite(list, fromUserId) ||
      !inviterSide.exists ||
      !inviteeSide.exists ||
      blockedByInvitee.exists ||
      blockedByInviter.exists ||
      members.length >= MAX_LIST_MEMBERS
    ) {
      throw unavailable();
    }

    // The level the row names, narrowed to what an invitation may grant: an
    // admin seat is never offered, it is given later by someone on the list.
    const permission = isInvitablePermission(row.permission) ? row.permission : "view";
    tx.update(
      listRef,
      new admin.firestore.FieldPath("memberPermissions", callerUid), permission,
      "updatedAt", admin.firestore.FieldValue.serverTimestamp(),
    );
    tx.update(invitationRef, {
      status: "accepted",
      respondedAt: admin.firestore.FieldValue.serverTimestamp(),
    });
    return { alreadyMember: false, listId };
  });

  logger.info("[acceptListInvitation] done", {
    invitationId,
    to_prefix: callerUid.slice(0, 6),
    alreadyMember: result.alreadyMember,
  });
  return { success: true, ...result };
}
