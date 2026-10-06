/**
 * BUT-2267: a member of a friend group marked as household joins the shared
 * household, so they can choose to share their allergens with it.
 *
 * Joining is the member's own act (DPIA R3): nobody is put in a household by
 * someone else. Who MAY join is decided by the group's owner, through who is in
 * the group and whether it is marked as household. Joining shares nothing;
 * sharing is a separate consent in the app's settings (Annex A).
 *
 * The household is the owner's existing one when it is not linked to a group
 * yet, so a member who joins sees the diner profiles the owner already made.
 * Otherwise a new household is created for the group. The caller is added as a
 * `view` member. Calling again when already a member changes nothing.
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
import {
  GroupRef,
  MAX_HOUSEHOLD_MEMBERS,
  groupDocRef,
  householdIdForGroup,
  isOwnedLink,
  linkedHouseholdsQuery,
  memberIdsOf,
  membersOf,
} from "./group-household";

export interface JoinGroupHouseholdRequest {
  ownerId: string;
  groupId: string;
}

export interface JoinGroupHouseholdResponse {
  householdId: string;
  /** True when the caller was already a member (a repeated tap). */
  alreadyMember: boolean;
}

export const joinGroupHousehold = onCall<JoinGroupHouseholdRequest>(
  { enforceAppCheck: true },
  async (request): Promise<JoinGroupHouseholdResponse> => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "Sign-in required.");
    }
    const ownerId = request.data?.ownerId;
    const groupId = request.data?.groupId;
    if (!isValidDocId(ownerId) || !isValidDocId(groupId)) {
      throw new HttpsError("invalid-argument", "ownerId and groupId are required.");
    }
    assertAgeCompliant(request.auth);
    await enforceRateLimit(request.auth.uid, "joinGroupHousehold");
    return joinGroupHouseholdWithDeps(
      admin.firestore(),
      request.auth.uid,
      { ownerId, groupId },
    );
  },
);

function millisOf(v: unknown): number {
  return v instanceof admin.firestore.Timestamp ? v.toMillis() : 0;
}

/** Dependency-injected core, exposed for the emulator integration test. */
export async function joinGroupHouseholdWithDeps(
  db: admin.firestore.Firestore,
  callerUid: string,
  ref: GroupRef,
): Promise<JoinGroupHouseholdResponse> {
  if (callerUid === ref.ownerId) {
    // The owner's household is theirs already; the trigger never touches the
    // owner, and neither does this.
    throw new HttpsError("invalid-argument", "The owner does not join.");
  }

  const result = await db.runTransaction(async (tx) => {
    // Read in the transaction, so a removal the trigger commits meanwhile
    // makes this retry against the group as it is now.
    const groupSnap = await tx.get(groupDocRef(db, ref));
    const group = groupSnap.data();
    const members: unknown[] = Array.isArray(group?.friendUserIds)
      ? group?.friendUserIds
      : [];
    // One answer for "no such group" and "not in it", so a non-member cannot
    // probe whether a group exists.
    if (!groupSnap.exists || group?.ownerId !== ref.ownerId ||
        !members.includes(callerUid)) {
      throw new HttpsError("permission-denied", "Not allowed.");
    }
    if (group?.isHousehold !== true) {
      throw new HttpsError("failed-precondition", "The group is not a household.");
    }

    const linked = (await tx.get(linkedHouseholdsQuery(db, ref))).docs
      .filter((d) => isOwnedLink(d.data(), ref));
    let target: admin.firestore.DocumentSnapshot | undefined = linked[0];
    if (!target) {
      // The owner's own household not yet linked to any group, oldest first,
      // so the same one is chosen on every call.
      const owned = (await tx.get(
        db.collection(Collections.households)
          .where("memberUserIds", "array-contains", ref.ownerId),
      )).docs
        .filter((d) => d.get("createdBy") === ref.ownerId &&
          d.get("sourceGroupId") == null &&
          d.get(`memberPermissions.${ref.ownerId}`) === "admin")
        .sort((a, b) => millisOf(a.get("createdAt")) -
          millisOf(b.get("createdAt")) || a.id.localeCompare(b.id));
      target = owned[0];
    }
    if (!target) {
      const fresh = await tx.get(
        db.collection(Collections.households).doc(householdIdForGroup(ref)),
      );
      // A deterministic id already taken by something that is not this
      // group's household is not ours to write into.
      if (fresh.exists && !isOwnedLink(fresh.data(), ref)) {
        throw new HttpsError("failed-precondition", "Household unavailable.");
      }
      target = fresh;
    }

    const data = target.data();
    const memberIds = memberIdsOf(data);
    if (memberIds.includes(callerUid)) {
      return { householdId: target.id, alreadyMember: true };
    }

    const now = admin.firestore.Timestamp.now();
    const owner = { userId: ref.ownerId, permission: "admin", addedAt: now };
    const caller = { userId: callerUid, permission: "view", addedAt: now };
    if (!target.exists) {
      tx.create(target.ref, {
        name: "Vårt hushåll",
        members: [owner, caller],
        memberUserIds: [ref.ownerId, callerUid],
        memberPermissions: { [ref.ownerId]: "admin", [callerUid]: "view" },
        createdBy: ref.ownerId,
        createdAt: now,
        updatedAt: now,
        schemaVersion: 1,
        sourceGroupOwnerId: ref.ownerId,
        sourceGroupId: ref.groupId,
      });
      return { householdId: target.id, alreadyMember: false };
    }

    if (memberIds.length >= MAX_HOUSEHOLD_MEMBERS) {
      throw new HttpsError("resource-exhausted", "The household is full.");
    }
    tx.update(target.ref, {
      members: [...membersOf(data), caller],
      memberUserIds: [...memberIds, callerUid],
      [`memberPermissions.${callerUid}`]: "view",
      sourceGroupOwnerId: ref.ownerId,
      sourceGroupId: ref.groupId,
      updatedAt: now,
    });
    return { householdId: target.id, alreadyMember: false };
  });

  logger.info("[joinGroupHousehold] done", {
    caller_prefix: callerUid.slice(0, 6),
    groupId: ref.groupId,
    alreadyMember: result.alreadyMember,
  });
  return result;
}
