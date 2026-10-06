/**
 * BUT-2270: send a group's invitations in one server call.
 *
 * The client wrote one `social_requests` row per invitee, and the create rule
 * allows one row per 10 seconds (`rateLimitStamped('social_requests', 10, …)`),
 * so inviting two friends sent one invitation and silently dropped the rest.
 * The rule stays as it is for friend requests; group invitations come here.
 *
 * Everything the create rule checked is re-checked, because the Admin SDK
 * bypasses rules: the age claim, account maturity, and that the invitee has
 * not blocked the caller. Added on top: the caller owns the group, and each
 * invitee is a friend on BOTH sides, which is what `acceptGroupInvitation`
 * demands before it seats anyone.
 *
 * Region: inherits europe-west1 via `setGlobalOptions` in index.ts.
 * An invitee who already has an unexpired pending invitation to this group
 * is skipped, not invited twice.
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
import { resolveMemberProfiles } from "../groups/member-profiles";

const getDb = () => admin.firestore();

export const MAX_INVITEES_PER_CALL = 50;
export const MAX_MESSAGE_LENGTH = 500;

/** Mirrors `SocialRequest._expiryDuration` in the app. */
const EXPIRY_MS = 7 * 24 * 60 * 60 * 1000;

export type SkipReason =
  | "self"
  | "already_member"
  | "already_invited"
  | "not_friends"
  | "unavailable";

export interface SendGroupInvitationsRequest {
  groupId: string;
  userIds: string[];
  message?: string | null;
}

export interface SendGroupInvitationsResponse {
  sent: { userId: string; invitationId: string }[];
  skipped: { userId: string; reason: SkipReason }[];
}

export const sendGroupInvitations = onCall<SendGroupInvitationsRequest>(
  { enforceAppCheck: true },
  async (request): Promise<SendGroupInvitationsResponse> => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "Sign-in required.");
    }
    const groupId = request.data?.groupId;
    if (!isValidDocId(groupId)) {
      throw new HttpsError("invalid-argument", "groupId is required.");
    }
    const userIds = Array.isArray(request.data?.userIds)
      ? [...new Set(request.data.userIds)]
      : [];
    if (userIds.length === 0 || !userIds.every(isValidDocId)) {
      throw new HttpsError("invalid-argument", "userIds is malformed.");
    }
    if (userIds.length > MAX_INVITEES_PER_CALL) {
      throw new HttpsError(
        "invalid-argument",
        `At most ${MAX_INVITEES_PER_CALL} invitations per call.`,
      );
    }
    const rawMessage = request.data?.message;
    if (
      rawMessage != null &&
      (typeof rawMessage !== "string" ||
        rawMessage.length > MAX_MESSAGE_LENGTH)
    ) {
      throw new HttpsError("invalid-argument", "message is malformed.");
    }
    const message =
      typeof rawMessage === "string" && rawMessage.trim().length > 0
        ? rawMessage.trim()
        : null;

    const db = getDb();
    assertAgeCompliant(request.auth);
    await assertAccountMatured(db, request.auth);
    // `enforceRateLimit`, not `withRateLimit`: this spends no LLM budget, same
    // reasoning as `addChatGroupMembers` (ADR-0013).
    await enforceRateLimit(request.auth.uid, "sendGroupInvitations");

    return sendGroupInvitationsWithDeps(
      db,
      request.auth.uid,
      groupId,
      userIds,
      message,
    );
  },
);

/** Dependency-injected core, exposed for the emulator integration test. */
export async function sendGroupInvitationsWithDeps(
  db: admin.firestore.Firestore,
  callerUid: string,
  groupId: string,
  userIds: string[],
  message: string | null,
): Promise<SendGroupInvitationsResponse> {
  const groupRef = db
    .collection(Collections.users).doc(callerUid)
    .collection(Collections.friendCategories).doc(groupId);
  const groupSnap = await groupRef.get();
  const group = groupSnap.data() ?? {};
  // One answer for "no such group" and "not yours", so a group id cannot be
  // probed for existence.
  if (!groupSnap.exists || group.ownerId !== callerUid) {
    throw new HttpsError("permission-denied", "Not allowed.");
  }
  const members: unknown[] = Array.isArray(group.friendUserIds)
    ? group.friendUserIds
    : [];

  // Equality filters only, so the automatic single-field indexes serve it.
  const pending = await db
    .collection(Collections.socialRequests)
    .where("fromUserId", "==", callerUid)
    .where("groupId", "==", groupId)
    .where("status", "==", "pending")
    .get();
  // A pending row past `expiresAt` stays pending until the weekly cleanup job
  // runs, while the invitee's app already shows it as expired.
  const nowMs = Date.now();
  const alreadyInvited = new Set(
    pending.docs
      .filter((d) => {
        const expiresAt = d.get("expiresAt");
        return expiresAt instanceof admin.firestore.Timestamp &&
          expiresAt.toMillis() > nowMs;
      })
      .map((d) => d.get("toUserId")),
  );

  const sent: SendGroupInvitationsResponse["sent"] = [];
  const skipped: SendGroupInvitationsResponse["skipped"] = [];
  const candidates: string[] = [];
  for (const uid of userIds) {
    if (uid === callerUid) skipped.push({ userId: uid, reason: "self" });
    else if (members.includes(uid)) {
      skipped.push({ userId: uid, reason: "already_member" });
    } else if (alreadyInvited.has(uid)) {
      skipped.push({ userId: uid, reason: "already_invited" });
    } else candidates.push(uid);
  }

  if (candidates.length > 0) {
    const refs = candidates.flatMap((uid) => [
      db.collection(Collections.users).doc(callerUid)
        .collection("friends").doc(uid),
      db.collection(Collections.users).doc(uid)
        .collection("friends").doc(callerUid),
      db.collection(Collections.blocks).doc(`${uid}_${callerUid}`),
    ]);
    const snaps = await db.getAll(...refs);
    const [sender] = await resolveMemberProfiles(db, [callerUid]);
    const now = admin.firestore.Timestamp.now();
    const expiresAt = admin.firestore.Timestamp.fromMillis(
      now.toMillis() + EXPIRY_MS,
    );
    const batch = db.batch();

    candidates.forEach((uid, i) => {
      const [mine, theirs, block] = snaps.slice(i * 3, i * 3 + 3);
      if (block.exists) {
        // Same word as any other refusal: the sender must not learn they are
        // blocked.
        skipped.push({ userId: uid, reason: "unavailable" });
        return;
      }
      if (!mine.exists || !theirs.exists) {
        skipped.push({ userId: uid, reason: "not_friends" });
        return;
      }
      const ref = db.collection(Collections.socialRequests).doc();
      // The fields `SocialRequest.toFirestore` writes, so the app reads a
      // server-made invitation exactly like one it made itself.
      batch.set(ref, {
        type: "groupInvitation",
        fromUserId: callerUid,
        toUserId: uid,
        status: "pending",
        sentAt: now,
        expiresAt,
        respondedAt: null,
        message,
        groupId,
        groupName: typeof group.name === "string" ? group.name : "",
        groupEmoji: typeof group.emoji === "string" ? group.emoji : "",
        fromUserName: sender.displayName,
      });
      sent.push({ userId: uid, invitationId: ref.id });
    });

    if (sent.length > 0) await batch.commit();
  }

  logger.info("[sendGroupInvitations] done", {
    from_prefix: callerUid.slice(0, 6),
    groupId,
    sent: sent.length,
    skipped: skipped.map((s) => s.reason),
  });
  return { sent, skipped };
}
