/**
 * BUT-2267: keeps a group-linked household's members inside its group.
 *
 * Fires on every write of `users/{ownerId}/friend_categories/{groupId}`. A
 * member the group no longer holds is removed from the linked household, and
 * their allergen share for that household is deleted in the same batch (DPIA
 * R7). That one rule covers leaving the group, being removed from it, the owner
 * un-marking it as household and the owner deleting it. When the group is
 * gone or no longer a household, the link is dropped too, so the owner's
 * household is an ordinary one again. The owner is never removed.
 *
 * Recompute, never delta: the group is re-read inside the transaction rather
 * than taken from the event, so an out-of-order or repeated event converges on
 * the group as it is now.
 *
 * Region: inherits europe-west1 via `setGlobalOptions` in index.ts.
 */

import { onDocumentWritten } from "firebase-functions/v2/firestore";
import { logger } from "firebase-functions/logger";
import * as admin from "firebase-admin";
import { Collections } from "../shared/collections";
import {
  GroupRef,
  groupDocRef,
  isOwnedLink,
  linkedHouseholdsQuery,
  memberIdsOf,
  membersOf,
  shareDocRef,
} from "./group-household";

export interface ReconcileResult {
  householdIds: string[];
  removed: string[];
  unlinked: boolean;
}

/** Dependency-injected core, exposed for the emulator integration test. */
export async function reconcileGroupHousehold(
  db: admin.firestore.Firestore,
  ref: GroupRef,
): Promise<ReconcileResult> {
  return db.runTransaction(async (tx) => {
    const groupSnap = await tx.get(groupDocRef(db, ref));
    const group = groupSnap.data();
    const stillHousehold = groupSnap.exists && group?.isHousehold === true;
    const allowed = new Set<string>([ref.ownerId]);
    if (stillHousehold && Array.isArray(group?.friendUserIds)) {
      for (const id of group?.friendUserIds as unknown[]) {
        if (typeof id === "string") allowed.add(id);
      }
    }

    const linked = (await tx.get(linkedHouseholdsQuery(db, ref))).docs
      .filter((d) => isOwnedLink(d.data(), ref));
    const removed: string[] = [];
    for (const doc of linked) {
      const data = doc.data();
      const departing = memberIdsOf(data).filter((id) => !allowed.has(id));
      if (departing.length === 0 && stillHousehold) continue;

      const update: Record<string, unknown> = {
        members: membersOf(data).filter((m) => !departing.includes(m.userId)),
        memberUserIds: memberIdsOf(data).filter((id) => !departing.includes(id)),
        updatedAt: admin.firestore.Timestamp.now(),
      };
      for (const id of departing) {
        update[`memberPermissions.${id}`] = admin.firestore.FieldValue.delete();
        // Deleting a share that does not exist is a no-op, so no read first.
        tx.delete(shareDocRef(db, doc.id, id));
      }
      if (!stillHousehold) {
        update.sourceGroupId = admin.firestore.FieldValue.delete();
        update.sourceGroupOwnerId = admin.firestore.FieldValue.delete();
      }
      tx.update(doc.ref, update);
      removed.push(...departing);
    }
    return {
      householdIds: linked.map((d) => d.id),
      removed,
      unlinked: !stillHousehold && linked.length > 0,
    };
  });
}

export const onHouseholdGroupWritten = onDocumentWritten(
  {
    document: `${Collections.users}/{ownerId}/${Collections.friendCategories}/{groupId}`,
    // A dropped event leaves a departed member reading the household's shares
    // and their own share readable by it, so a failed run is retried.
    retry: true,
  },
  async (event) => {
    const before = event.data?.before?.data();
    const after = event.data?.after?.data();
    // Only a group that is or was a household can have a linked household.
    // Most group writes are neither, and this keeps them free of any read.
    if (before?.isHousehold !== true && after?.isHousehold !== true) return;

    const ref = { ownerId: event.params.ownerId, groupId: event.params.groupId };
    const result = await reconcileGroupHousehold(admin.firestore(), ref);
    if (result.removed.length > 0 || result.unlinked) {
      logger.info("[onHouseholdGroupWritten] reconciled", {
        owner_prefix: ref.ownerId.slice(0, 6),
        groupId: ref.groupId,
        households: result.householdIds.length,
        removed: result.removed.length,
        unlinked: result.unlinked,
      });
    }
  },
);
