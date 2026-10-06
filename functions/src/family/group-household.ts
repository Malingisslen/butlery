/**
 * BUT-2267: the link between a friend group marked as household
 * (`users/{ownerId}/friend_categories/{groupId}.isHousehold`) and the shared
 * `households/{id}` document that scopes allergen shares and diner profiles.
 *
 * The group decides WHO may be in the household; the household is where they
 * are. Two writers keep them in step, both through the Admin SDK, because the
 * client rules do not let anyone change a household's membership:
 *  - `joinGroupHousehold` (callable) adds a group member who asks to join;
 *  - `onHouseholdGroupWritten` (trigger) removes anyone the group no longer
 *    holds, and deletes their allergen share in the same batch (DPIA R7).
 */

import { createHash } from "crypto";
import * as admin from "firebase-admin";
import { Collections } from "../shared/collections";

/**
 * Most members a household linked to a group may hold. Matches
 * `FirebaseHouseholdAllergenShareRepository.maxHouseholdMembers` in the app,
 * whose share read DECLINES above it (the accepted deviation for
 * `getByHousehold`), so a household past it would put every member on the
 * common-allergen floor. A join that would cross it is refused instead.
 */
export const MAX_HOUSEHOLD_MEMBERS = 20;

export interface GroupRef {
  ownerId: string;
  groupId: string;
}

/** The fields this code reads from a household document. */
export interface HouseholdMemberEntry {
  userId: string;
  permission: string;
  addedAt?: unknown;
}

export function groupDocRef(
  db: admin.firestore.Firestore,
  ref: GroupRef,
): admin.firestore.DocumentReference {
  return db
    .collection(Collections.users).doc(ref.ownerId)
    .collection(Collections.friendCategories).doc(ref.groupId);
}

/**
 * The households that claim to be linked to [ref]. Only one written by the
 * group's owner counts: `createdBy` is immutable to clients, so a household
 * someone else created cannot borrow a stranger's group by naming it.
 */
export function linkedHouseholdsQuery(
  db: admin.firestore.Firestore,
  ref: GroupRef,
): admin.firestore.Query {
  // Equality filters only, so the automatic single-field indexes serve it.
  return db
    .collection(Collections.households)
    .where("sourceGroupOwnerId", "==", ref.ownerId)
    .where("sourceGroupId", "==", ref.groupId);
}

export function isOwnedLink(
  data: admin.firestore.DocumentData | undefined,
  ref: GroupRef,
): boolean {
  return data?.createdBy === ref.ownerId &&
    data?.sourceGroupOwnerId === ref.ownerId &&
    data?.sourceGroupId === ref.groupId;
}

/**
 * Id for a household created for a group. Deterministic so two concurrent
 * first joins collide on one document inside their transactions instead of
 * creating two households for the same group. Hex only: a household id must
 * not contain '_', which separates the halves of an allergen share's id.
 */
export function householdIdForGroup(ref: GroupRef): string {
  return createHash("sha256")
    .update(`${ref.ownerId}/${ref.groupId}`)
    .digest("hex")
    .slice(0, 32);
}

export function membersOf(
  data: admin.firestore.DocumentData | undefined,
): HouseholdMemberEntry[] {
  const raw = Array.isArray(data?.members) ? data?.members as unknown[] : [];
  return raw.filter((m): m is HouseholdMemberEntry =>
    !!m && typeof m === "object" &&
    typeof (m as HouseholdMemberEntry).userId === "string");
}

export function memberIdsOf(
  data: admin.firestore.DocumentData | undefined,
): string[] {
  const raw = Array.isArray(data?.memberUserIds)
    ? data?.memberUserIds as unknown[]
    : [];
  return raw.filter((id): id is string => typeof id === "string");
}

/** `{householdId}_{userId}`, the allergen share's document id. */
export function shareDocRef(
  db: admin.firestore.Firestore,
  householdId: string,
  userId: string,
): admin.firestore.DocumentReference {
  return db.collection(Collections.householdAllergenShares)
    .doc(`${householdId}_${userId}`);
}
