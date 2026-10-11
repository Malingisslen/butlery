/**
 * BUT-2089: invite friends to a shared shopping list.
 *
 * Nobody is put on a shared list by someone else any more (Malin, 2026-10-10):
 * the rules refuse a client write that adds a key to `memberPermissions`, so a
 * seat is offered here as a `social_requests` row of type `listInvitation` and
 * taken only by the invitee, through `acceptListInvitation`. Clients cannot
 * create that type themselves; the create rule refuses it.
 *
 * The caller must be the list's owner or an `admin` on it, as for the direct
 * add this replaces (BUT-2013). Each invitee must be a friend on BOTH sides,
 * which is also what satisfies the minors gate (BUT-1838's "a minor may be
 * added by any of their friends"), and is skipped as `unavailable` when either
 * has blocked the other or when they declined this inviter's invitation to
 * this list in the last 30 days. Block and decline share the word with every
 * other refusal the inviter must not be able to tell apart.
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
import { resolveMemberProfiles } from "../groups/member-profiles";

export const MAX_INVITEES_PER_CALL = 50;

/** Mirrors the `memberPermissions.size() <= 200` bound in firestore.rules. */
export const MAX_LIST_MEMBERS = 200;

export const MAX_LIST_NAME_LENGTH = 100;

/** Mirrors `SocialRequest._expiryDuration` in the app. */
const EXPIRY_MS = 7 * 24 * 60 * 60 * 1000;

export const DECLINE_MEMORY_MS = 30 * 24 * 60 * 60 * 1000;

export const INVITABLE_PERMISSIONS = ["view", "edit"] as const;
export type InvitablePermission = typeof INVITABLE_PERMISSIONS[number];

export type ListSkipReason =
  | "self"
  | "already_member"
  | "already_invited"
  | "not_friends"
  | "unavailable";

export interface SendListInvitationsRequest {
  listId: string;
  userIds: string[];
  permission?: InvitablePermission;
}

export interface SendListInvitationsResponse {
  sent: { userId: string; invitationId: string }[];
  skipped: { userId: string; reason: ListSkipReason }[];
}

export function isInvitablePermission(value: unknown): value is InvitablePermission {
  return typeof value === "string" &&
    (INVITABLE_PERMISSIONS as readonly string[]).includes(value);
}

/** Whether [uid] may invite to (and stay the inviter of) this list. */
export function mayInvite(list: admin.firestore.DocumentData, uid: string): boolean {
  if (list.ownerId === uid) return true;
  const perms = list.memberPermissions;
  return typeof perms === "object" && perms !== null &&
    (perms as Record<string, unknown>)[uid] === "admin";
}

export function memberKeys(list: admin.firestore.DocumentData): string[] {
  const perms = list.memberPermissions;
  return typeof perms === "object" && perms !== null ? Object.keys(perms) : [];
}

export const sendListInvitations = onCall<SendListInvitationsRequest>(
  { enforceAppCheck: true },
  async (request): Promise<SendListInvitationsResponse> => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "Sign-in required.");
    }
    const listId = request.data?.listId;
    if (!isValidDocId(listId)) {
      throw new HttpsError("invalid-argument", "listId is required.");
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
    const rawPermission = request.data?.permission ?? "edit";
    if (!isInvitablePermission(rawPermission)) {
      throw new HttpsError("invalid-argument", "permission is malformed.");
    }

    const db = admin.firestore();
    assertAgeCompliant(request.auth);
    await assertAccountMatured(db, request.auth);
    await enforceRateLimit(request.auth.uid, "sendListInvitations");

    return sendListInvitationsWithDeps(
      db,
      request.auth.uid,
      listId,
      userIds,
      rawPermission,
    );
  },
);

/** Dependency-injected core, exposed for the emulator integration test. */
export async function sendListInvitationsWithDeps(
  db: admin.firestore.Firestore,
  callerUid: string,
  listId: string,
  userIds: string[],
  permission: InvitablePermission,
): Promise<SendListInvitationsResponse> {
  const listSnap = await db
    .collection(Collections.unifiedSharedShoppingLists).doc(listId).get();
  const list = listSnap.data() ?? {};
  // One answer for "no such list" and "not yours to invite to", so a list id
  // cannot be probed for existence.
  if (!listSnap.exists || !mayInvite(list, callerUid)) {
    throw new HttpsError("permission-denied", "Not allowed.");
  }
  const members = memberKeys(list);
  if (members.length >= MAX_LIST_MEMBERS) {
    throw new HttpsError("resource-exhausted", "List is full.");
  }

  // Equality filters only, so the automatic single-field indexes serve them.
  const [pending, declined] = await Promise.all([
    db.collection(Collections.socialRequests)
      .where("listId", "==", listId)
      .where("status", "==", "pending")
      .get(),
    db.collection(Collections.socialRequests)
      .where("fromUserId", "==", callerUid)
      .where("listId", "==", listId)
      .where("status", "==", "rejected")
      .get(),
  ]);
  const nowMs = Date.now();
  // A pending row past `expiresAt` stays pending until the weekly cleanup job
  // runs, while the invitee's app already shows it as expired. Any inviter's
  // live invitation counts: a second admin does not send a second card.
  const alreadyInvited = new Set(
    pending.docs
      .filter((d) => d.get("type") === "listInvitation")
      .filter((d) => {
        const expiresAt = d.get("expiresAt");
        return expiresAt instanceof admin.firestore.Timestamp &&
          expiresAt.toMillis() > nowMs;
      })
      .map((d) => d.get("toUserId")),
  );
  // A decline without a usable time counts as recent: the invitee's no is
  // what this protects, not the inviter's retry.
  const recentlyDeclined = new Set(
    declined.docs
      .filter((d) => d.get("type") === "listInvitation")
      .filter((d) => {
        const respondedAt = d.get("respondedAt");
        return !(respondedAt instanceof admin.firestore.Timestamp) ||
          nowMs - respondedAt.toMillis() < DECLINE_MEMORY_MS;
      })
      .map((d) => d.get("toUserId")),
  );

  const sent: SendListInvitationsResponse["sent"] = [];
  const skipped: SendListInvitationsResponse["skipped"] = [];
  const candidates: string[] = [];
  for (const uid of userIds) {
    if (uid === callerUid) skipped.push({ userId: uid, reason: "self" });
    else if (members.includes(uid)) {
      skipped.push({ userId: uid, reason: "already_member" });
    } else if (alreadyInvited.has(uid)) {
      skipped.push({ userId: uid, reason: "already_invited" });
    } else if (recentlyDeclined.has(uid)) {
      skipped.push({ userId: uid, reason: "unavailable" });
    } else candidates.push(uid);
  }

  if (candidates.length > 0) {
    const refs = candidates.flatMap((uid) => [
      db.collection(Collections.users).doc(callerUid)
        .collection("friends").doc(uid),
      db.collection(Collections.users).doc(uid)
        .collection("friends").doc(callerUid),
      db.collection(Collections.blocks).doc(`${uid}_${callerUid}`),
      db.collection(Collections.blocks).doc(`${callerUid}_${uid}`),
    ]);
    const snaps = await db.getAll(...refs);
    const [sender] = await resolveMemberProfiles(db, [callerUid]);
    const now = admin.firestore.Timestamp.now();
    const expiresAt = admin.firestore.Timestamp.fromMillis(
      now.toMillis() + EXPIRY_MS,
    );
    const listName = typeof list.name === "string"
      ? Array.from(list.name).slice(0, MAX_LIST_NAME_LENGTH).join("")
      : "";
    const batch = db.batch();

    candidates.forEach((uid, i) => {
      const [mine, theirs, blockedByThem, blockedByMe] =
        snaps.slice(i * 4, i * 4 + 4);
      if (blockedByThem.exists || blockedByMe.exists) {
        skipped.push({ userId: uid, reason: "unavailable" });
        return;
      }
      if (!mine.exists || !theirs.exists) {
        skipped.push({ userId: uid, reason: "not_friends" });
        return;
      }
      const ref = db.collection(Collections.socialRequests).doc();
      // The fields `SocialRequest.toFirestore` writes for this type.
      batch.set(ref, {
        type: "listInvitation",
        fromUserId: callerUid,
        toUserId: uid,
        status: "pending",
        sentAt: now,
        expiresAt,
        respondedAt: null,
        message: null,
        listId,
        listName,
        permission,
        fromUserName: sender.displayName,
      });
      sent.push({ userId: uid, invitationId: ref.id });
    });

    if (sent.length > 0) await batch.commit();
  }

  logger.info("[sendListInvitations] done", {
    from_prefix: callerUid.slice(0, 6),
    listId,
    sent: sent.length,
    skipped: skipped.map((s) => s.reason),
  });
  return { sent, skipped };
}
