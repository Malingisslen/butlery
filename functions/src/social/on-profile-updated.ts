/**
 * Propagate displayName/avatarUrl changes across denormalized copies.
 *
 * Triggered when a public_profiles/{userId} document is updated.
 * Updates denormalized copies in messages, conversations, recipe_comments,
 * friends subcollections, shared content members, realtime resources,
 * shared recipes, shopping lists, and group invitations.
 *
 * Safety: the genuinely-unbounded fan-out collections (messages, conversations,
 * recipe_comments, the `members` collection group, shared_recipes, realtime
 * resources, shopping lists) are paged with a per-collection documentId cursor
 * via `batchUpdateQueryPaginated` — the full result set is never held in memory
 * at once, so a prolific user can't OOM or blow the 540s timeout. Collections
 * bounded by the acting user's own subcollection (friends) or their own pending
 * outbox (group_invitations) keep the single-read + chunked-write path.
 * Steps run in parallel via Promise.all; each catches independently so one
 * failing collection can't abort the rest.
 */

import { onDocumentUpdated } from "firebase-functions/v2/firestore";
import { logger } from "firebase-functions/logger";
import * as admin from "firebase-admin";
import { hashUid } from "../shared/hash-uid";
import {
  batchUpdateQuery,
  batchUpdateQueryPaginated,
  batchUpdateRefs,
} from "../shared/batch-update";
import { Collections } from "../shared/collections";

const getDb = () => admin.firestore();

export const onProfileUpdated = onDocumentUpdated(
  { document: `${Collections.publicProfiles}/{userId}`, timeoutSeconds: 540 },
  async (event) => {
    const userId = event.params.userId;
    const before = event.data!.before.data();
    const after = event.data!.after.data();

    await propagateProfileUpdate(
      getDb(),
      userId,
      before.displayName as string | undefined,
      after.displayName as string | undefined,
      before.avatarUrl as string | undefined,
      after.avatarUrl as string | undefined
    );
  }
);

/**
 * DI core (testable without the trigger wrapper): fan the name/avatar change
 * out to every denormalized copy. Returns the total number of docs updated.
 * A no-op change (neither name nor avatar differs) writes nothing and reads
 * nothing.
 */
export async function propagateProfileUpdate(
  db: admin.firestore.Firestore,
  userId: string,
  oldName: string | undefined,
  newName: string | undefined,
  oldAvatar: string | undefined,
  newAvatar: string | undefined
): Promise<number> {
  const nameChanged = oldName !== newName;
  const avatarChanged = oldAvatar !== newAvatar;

  if (!nameChanged && !avatarChanged) {
    return 0;
  }

  const userHash = hashUid(userId);
  logger.info(
    `Profile updated for ${userHash}: name=${nameChanged}, avatar=${avatarChanged}`
  );

  const messageUpdates: Record<string, unknown> = {};
  if (nameChanged) messageUpdates["senderDisplayName"] = newName;
  if (avatarChanged) messageUpdates["senderAvatarUrl"] = newAvatar;

  const memberUpdates: Record<string, unknown> = {};
  if (nameChanged) memberUpdates["displayName"] = newName;
  if (avatarChanged) memberUpdates["avatarUrl"] = newAvatar;

  const commentUpdates: Record<string, unknown> = {};
  if (nameChanged) commentUpdates["authorDisplayName"] = newName;
  if (avatarChanged) commentUpdates["authorAvatarUrl"] = newAvatar;

  // The conversation denorm keys are `<map>.<userId>`; userId is constant for
  // the whole invocation, so the update map is identical across every matched
  // doc — no per-doc callback needed, which lets it use the paged writer.
  const conversationUpdates: Record<string, unknown> = {};
  if (nameChanged) conversationUpdates[`participantDisplayNames.${userId}`] = newName;
  if (avatarChanged) conversationUpdates[`participantAvatarUrls.${userId}`] = newAvatar;

  const steps: Array<Promise<number>> = [
    batchUpdateQueryPaginated(
      db.collection(Collections.messages).where("senderId", "==", userId),
      messageUpdates,
      db
    ).catch((e) => { logger.error(`Failed to update messages for ${userHash}`, e); return 0; }),

    batchUpdateQueryPaginated(
      db.collection(Collections.conversations).where("participantIds", "array-contains", userId),
      conversationUpdates,
      db
    ).catch((e) => { logger.error(`Failed to update conversations for ${userHash}`, e); return 0; }),

    batchUpdateQueryPaginated(
      db.collection(Collections.recipeComments).where("authorId", "==", userId),
      commentUpdates,
      db
    ).catch((e) => { logger.error(`Failed to update recipe_comments for ${userHash}`, e); return 0; }),

    batchUpdateQueryPaginated(
      db.collectionGroup("members").where("userId", "==", userId),
      memberUpdates,
      db
    ).catch((e) => { logger.error(`Failed to update members for ${userHash}`, e); return 0; }),
  ];

  if (nameChanged) {
    // Friends subcollection — bounded by the acting user's OWN friend count
    // (their friends/ subcollection), so a single read + chunked ref writes
    // stays memory-safe without a cursor.
    steps.push(
      (async () => {
        const friendsSnapshot = await db.collection(Collections.users).doc(userId).collection("friends").get();
        if (friendsSnapshot.empty) return 0;
        return batchUpdateRefs(
          friendsSnapshot.docs.map((friendDoc) =>
            db.collection(Collections.users).doc(friendDoc.id).collection("friends").doc(userId)
          ),
          () => ({ displayNameLower: newName?.toLowerCase() }),
          db
        );
      })().catch((e) => { logger.error(`Failed to update friends for ${userHash}`, e); return 0; })
    );

    // Realtime resources — owner + last-editor denorm names.
    for (const col of [Collections.realtimeRecipes, Collections.realtimeMenus]) {
      steps.push(
        paginatedDualUpdate(db, col, userId,
          { queryField: "ownerId", updateField: "ownerDisplayName" },
          { queryField: "lastEditedBy", updateField: "lastEditedByDisplayName" },
          newName)
          .catch((e) => { logger.error(`Failed to update ${col} for ${userHash}`, e); return 0; })
      );
    }

    steps.push(
      batchUpdateQueryPaginated(
        db.collection(Collections.sharedRecipes).where("socialData.ownerId", "==", userId),
        { "socialData.ownerDisplayName": newName },
        db
      ).catch((e) => { logger.error(`Failed to update shared_recipes for ${userHash}`, e); return 0; })
    );

    // Shopping lists — owner + last-activity denorm names.
    for (const col of [Collections.unifiedShoppingLists, Collections.unifiedSharedShoppingLists]) {
      steps.push(
        paginatedDualUpdate(db, col, userId,
          { queryField: "ownerId", updateField: "ownerDisplayName" },
          { queryField: "lastActivityByUserId", updateField: "lastActivityByDisplayName" },
          newName)
          .catch((e) => { logger.error(`Failed to update ${col} for ${userHash}`, e); return 0; })
      );
    }

    // Group invitations — bounded by the acting user's OWN pending outbox
    // (fromUserId == userId, status == pending). Bounded and, being a
    // two-equality filter, kept on the plain reader so no orderBy(__name__) +
    // composite-index requirement is introduced.
    steps.push(
      batchUpdateQuery(
        db.collection(Collections.groupInvitations)
          .where("fromUserId", "==", userId)
          .where("status", "==", "pending"),
        { fromUserName: newName },
        db
      ).catch((e) => { logger.error(`Failed to update group_invitations for ${userHash}`, e); return 0; })
    );
  }

  const results = await Promise.all(steps);
  const totalUpdated = results.reduce((sum, n) => sum + n, 0);

  logger.info(
    `Profile propagation complete for ${userHash}: ${totalUpdated} documents updated`
  );

  return totalUpdated;
}

interface DualFieldPair {
  queryField: string;
  updateField: string;
}

/**
 * Update a collection that denormalizes the user's name under two independent
 * fields (e.g. owner + last-editor). Each field's query is paged separately
 * with a documentId cursor via `batchUpdateQueryPaginated`, so neither result
 * set is ever fully held in memory.
 *
 * Unlike the previous merge-by-doc-id approach, a doc matching BOTH queries
 * (owner == last-editor, common) is written once per pass. That is a second
 * write to a DIFFERENT field, so the resulting document state is identical;
 * the extra write is a negligible cost on the rare profile-name-change event,
 * paid to keep the read memory-bounded. The two passes touch disjoint fields
 * from the ones they filter on, so each cursor is stable.
 *
 * Returns the sum of docs updated across both passes (overlap docs counted
 * twice, matching the write count).
 */
async function paginatedDualUpdate(
  db: admin.firestore.Firestore,
  collection: string,
  userId: string,
  primary: DualFieldPair,
  secondary: DualFieldPair,
  newName: string | undefined
): Promise<number> {
  const [primaryUpdated, secondaryUpdated] = await Promise.all([
    batchUpdateQueryPaginated(
      db.collection(collection).where(primary.queryField, "==", userId),
      { [primary.updateField]: newName },
      db
    ),
    batchUpdateQueryPaginated(
      db.collection(collection).where(secondary.queryField, "==", userId),
      { [secondary.updateField]: newName },
      db
    ),
  ]);

  return primaryUpdated + secondaryUpdated;
}
