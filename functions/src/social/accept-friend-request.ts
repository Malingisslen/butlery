/**
 * Pre-release audit B1: server-side friend-request acceptance.
 *
 * **The hole this closes.** Accepting a friend request used to run as a
 * client Firestore transaction that wrote BOTH mutual friend docs —
 * `users/{from}/friends/{to}` AND `users/{to}/friends/{from}`. That required
 * a security rule allowing a user to write into ANOTHER user's `friends`
 * subcollection (`request.auth.uid == friendId`). With that rule, any signed-in
 * user could write `users/{victim}/friends/{self}` directly — no request, no
 * consent — and the `cook_snaps` and `activity_events` read rules gate friend
 * access purely on the existence of that friend doc. So a stranger could read a
 * victim's private cooking photos and activity feed.
 *
 * **New flow.** The mutual write moves here, behind Admin SDK (which bypasses
 * rules) AFTER validating the underlying `social_request`. The friends-write
 * rule is then tightened to `create/update: isOwner(userId)` so a client can
 * only ever write into its OWN list. Friend *removal* stays client-side (the
 * cross-user delete branch is unchanged and is not a privacy escalation).
 *
 * Region: inherits europe-west1 via `setGlobalOptions` in index.ts.
 * Idempotent: re-invocation when already friends does not double-count.
 */

import { onCall, HttpsError } from "firebase-functions/v2/https";
import { logger } from "firebase-functions/logger";
import * as admin from "firebase-admin";

const db = admin.firestore();

export interface AcceptFriendRequestRequest {
  /** Document id of the `social_requests` doc being accepted. */
  requestId: string;
}

export interface AcceptFriendRequestResponse {
  success: boolean;
  /** True when the mutual friendship already existed (idempotent re-accept). */
  alreadyFriends: boolean;
}

export const acceptFriendRequest = onCall<AcceptFriendRequestRequest>(
  {
    // BUT-760: user-facing social callable — App Check defense-in-depth.
    // Inert until App Check is flipped to Enforce in the console.
    enforceAppCheck: true,
  },
  async (request): Promise<AcceptFriendRequestResponse> => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "Sign-in required.");
    }
    const requestId = request.data?.requestId;
    if (typeof requestId !== "string" || requestId.length === 0) {
      throw new HttpsError("invalid-argument", "requestId is required.");
    }
    return acceptFriendRequestWithDeps(db, request.auth.uid, requestId);
  },
);

/**
 * DI core — exposed for unit tests with a fake Firestore.
 *
 * Validates the request (exists, pending, addressed to the caller), then in a
 * single transaction writes any missing friend docs, marks the request
 * accepted, and increments `friendsCount` only when BOTH docs are newly
 * created (so a partial-state recovery or re-accept never inflates counts).
 */
export async function acceptFriendRequestWithDeps(
  database: admin.firestore.Firestore,
  callerUid: string,
  requestId: string,
): Promise<AcceptFriendRequestResponse> {
  const requestRef = database.collection("social_requests").doc(requestId);

  return database.runTransaction(async (tx) => {
    const requestSnap = await tx.get(requestRef);
    if (!requestSnap.exists) {
      throw new HttpsError("not-found", "Friend request not found.");
    }
    const data = requestSnap.data() ?? {};
    const fromUserId = data.fromUserId as string | undefined;
    const toUserId = data.toUserId as string | undefined;
    const status = data.status as string | undefined;

    if (!fromUserId || !toUserId) {
      throw new HttpsError("failed-precondition", "Malformed friend request.");
    }
    // The consent gate the old rule lacked: only the recipient may accept.
    if (toUserId !== callerUid) {
      throw new HttpsError(
        "permission-denied",
        "Only the recipient can accept this request.",
      );
    }
    // `accepted` is allowed through for idempotent re-accept (e.g. a
    // double-tap — callables are not auto-retried, but the user can fire twice).
    // Only rejected/expired requests are a hard precondition failure.
    if (status !== "pending" && status !== "accepted") {
      throw new HttpsError(
        "failed-precondition",
        "Friend request is no longer pending.",
      );
    }

    const fromFriendRef = database
      .collection("users").doc(fromUserId)
      .collection("friends").doc(toUserId);
    const toFriendRef = database
      .collection("users").doc(toUserId)
      .collection("friends").doc(fromUserId);
    const fromProfileRef = database.collection("public_profiles").doc(fromUserId);
    const toProfileRef = database.collection("public_profiles").doc(toUserId);

    // All reads before any write (Firestore transaction requirement).
    const [fromFriendSnap, toFriendSnap, fromProfileSnap, toProfileSnap] =
      await Promise.all([
        tx.get(fromFriendRef),
        tx.get(toFriendRef),
        tx.get(fromProfileRef),
        tx.get(toProfileRef),
      ]);

    const alreadyFriends = fromFriendSnap.exists && toFriendSnap.exists;

    // Idempotent re-accept: already accepted AND already friends → no-op
    // success. Never re-writes or double-counts. (A partial state — accepted
    // but a friend doc missing — falls through below and self-heals.)
    if (status === "accepted" && alreadyFriends) {
      return { success: true, alreadyFriends: true };
    }

    const fromName = (
      (fromProfileSnap.data()?.displayName as string | undefined) ?? ""
    ).toLowerCase();
    const toName = (
      (toProfileSnap.data()?.displayName as string | undefined) ?? ""
    ).toLowerCase();

    const now = admin.firestore.FieldValue.serverTimestamp();

    let created = 0;
    // The doc in `from`'s list points at `to`, so it stores `to`'s name.
    if (!fromFriendSnap.exists) {
      tx.set(fromFriendRef, { addedAt: now, displayNameLower: toName });
      created++;
    }
    if (!toFriendSnap.exists) {
      tx.set(toFriendRef, { addedAt: now, displayNameLower: fromName });
      created++;
    }

    // Mark accepted regardless (idempotent — already-pending is the only path
    // that reaches here; re-running sets the same value).
    tx.update(requestRef, {
      status: "accepted",
      respondedAt: now,
    });

    // Only bump counts when the friendship is genuinely new on both sides.
    // set(merge) rather than update: a missing public_profiles doc (early-beta
    // account / signup race) would make update() throw NOT_FOUND and abort the
    // whole acceptance. merge upserts with identical increment semantics.
    if (created === 2) {
      tx.set(
        fromProfileRef,
        { friendsCount: admin.firestore.FieldValue.increment(1) },
        { merge: true },
      );
      tx.set(
        toProfileRef,
        { friendsCount: admin.firestore.FieldValue.increment(1) },
        { merge: true },
      );
    }

    logger.info("[acceptFriendRequest] accepted", {
      requestId,
      from_prefix: fromUserId.slice(0, 6),
      to_prefix: toUserId.slice(0, 6),
      created,
      alreadyFriends,
    });

    return { success: true, alreadyFriends };
  });
}
