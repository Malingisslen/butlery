/**
 * Propagate displayName/avatarUrl changes across denormalized copies.
 *
 * Triggered when a public_profiles/{userId} document is updated.
 * Updates denormalized copies in messages, conversations, recipe_comments,
 * friends subcollections, shared content members, realtime resources,
 * shared recipes, shopping lists, and group invitations.
 *
 * Safety: paginated batches (500-op limit), skips if no name/avatar change,
 * uses hashUid for GDPR-safe logging. Steps run in parallel via Promise.all.
 */

import * as functions from "firebase-functions";
import * as admin from "firebase-admin";
import { hashUid } from "../shared/hash-uid";
import { batchUpdateQuery, batchUpdateDocs, batchUpdateRefs } from "../shared/batch-update";
import { Collections } from "../shared/collections";

const getDb = () => admin.firestore();

export const onProfileUpdated = functions
  .runWith({ timeoutSeconds: 540 })
  .region("europe-west1")
  .firestore.document(`${Collections.publicProfiles}/{userId}`)
  .onUpdate(async (change, context) => {
    const userId = context.params.userId;
    const before = change.before.data();
    const after = change.after.data();

    const oldName = before.displayName as string | undefined;
    const newName = after.displayName as string | undefined;
    const oldAvatar = before.avatarUrl as string | undefined;
    const newAvatar = after.avatarUrl as string | undefined;

    const nameChanged = oldName !== newName;
    const avatarChanged = oldAvatar !== newAvatar;

    if (!nameChanged && !avatarChanged) {
      return;
    }

    const userHash = hashUid(userId);
    functions.logger.info(
      `Profile updated for ${userHash}: name=${nameChanged}, avatar=${avatarChanged}`
    );

    const db = getDb();

    const messageUpdates: Record<string, unknown> = {};
    if (nameChanged) messageUpdates["senderDisplayName"] = newName;
    if (avatarChanged) messageUpdates["senderAvatarUrl"] = newAvatar;

    const memberUpdates: Record<string, unknown> = {};
    if (nameChanged) memberUpdates["displayName"] = newName;
    if (avatarChanged) memberUpdates["avatarUrl"] = newAvatar;

    const commentUpdates: Record<string, unknown> = {};
    if (nameChanged) commentUpdates["authorDisplayName"] = newName;
    if (avatarChanged) commentUpdates["authorAvatarUrl"] = newAvatar;

    const steps: Array<Promise<number>> = [
      batchUpdateQuery(
        db.collection(Collections.messages).where("senderId", "==", userId),
        messageUpdates,
        db
      ).catch((e) => { functions.logger.error(`Failed to update messages for ${userHash}`, e); return 0; }),

      batchUpdateDocs(
        db.collection(Collections.conversations).where("participantIds", "array-contains", userId),
        db,
        () => {
          const updates: Record<string, unknown> = {};
          if (nameChanged) updates[`participantDisplayNames.${userId}`] = newName;
          if (avatarChanged) updates[`participantAvatarUrls.${userId}`] = newAvatar;
          return updates;
        }
      ).catch((e) => { functions.logger.error(`Failed to update conversations for ${userHash}`, e); return 0; }),

      batchUpdateQuery(
        db.collection(Collections.recipeComments).where("authorId", "==", userId),
        commentUpdates,
        db
      ).catch((e) => { functions.logger.error(`Failed to update recipe_comments for ${userHash}`, e); return 0; }),

      batchUpdateQuery(
        db.collectionGroup("members").where("userId", "==", userId),
        memberUpdates,
        db
      ).catch((e) => { functions.logger.error(`Failed to update members for ${userHash}`, e); return 0; }),
    ];

    if (nameChanged) {
      // Friends subcollections
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
        })().catch((e) => { functions.logger.error(`Failed to update friends for ${userHash}`, e); return 0; })
      );

      // Realtime resources — merged owner+editor updates to avoid double-write
      for (const col of [Collections.realtimeRecipes, Collections.realtimeMenus]) {
        steps.push(
          mergedDualUpdate(db, col, userId,
            { queryField: "ownerId", updateField: "ownerDisplayName" },
            { queryField: "lastEditedBy", updateField: "lastEditedByDisplayName" },
            newName)
            .catch((e) => { functions.logger.error(`Failed to update ${col} for ${userHash}`, e); return 0; })
        );
      }

      steps.push(
        batchUpdateQuery(
          db.collection(Collections.sharedRecipes).where("socialData.ownerId", "==", userId),
          { "socialData.ownerDisplayName": newName },
          db
        ).catch((e) => { functions.logger.error(`Failed to update shared_recipes for ${userHash}`, e); return 0; })
      );

      // Shopping lists — merged owner+activity updates to avoid double-write
      for (const col of [Collections.unifiedShoppingLists, Collections.unifiedSharedShoppingLists]) {
        steps.push(
          mergedDualUpdate(db, col, userId,
            { queryField: "ownerId", updateField: "ownerDisplayName" },
            { queryField: "lastActivityByUserId", updateField: "lastActivityByDisplayName" },
            newName)
            .catch((e) => { functions.logger.error(`Failed to update ${col} for ${userHash}`, e); return 0; })
        );
      }

      steps.push(
        batchUpdateQuery(
          db.collection(Collections.groupInvitations)
            .where("fromUserId", "==", userId)
            .where("status", "==", "pending"),
          { fromUserName: newName },
          db
        ).catch((e) => { functions.logger.error(`Failed to update group_invitations for ${userHash}`, e); return 0; })
      );
    }

    const results = await Promise.all(steps);
    const totalUpdated = results.reduce((sum, n) => sum + n, 0);

    functions.logger.info(
      `Profile propagation complete for ${userHash}: ${totalUpdated} documents updated`
    );
  });

interface DualFieldPair {
  queryField: string;
  updateField: string;
}

/**
 * Fetch docs matching two independent queries on the same collection,
 * merge their update maps by doc ID, and write each doc exactly once.
 * Avoids double-write when a doc matches both queries (e.g., owner == last-editor).
 */
async function mergedDualUpdate(
  db: admin.firestore.Firestore,
  collection: string,
  userId: string,
  primary: DualFieldPair,
  secondary: DualFieldPair,
  newName: string | undefined
): Promise<number> {
  const [primarySnap, secondarySnap] = await Promise.all([
    db.collection(collection).where(primary.queryField, "==", userId).get(),
    db.collection(collection).where(secondary.queryField, "==", userId).get(),
  ]);

  const merged = new Map<string, { ref: admin.firestore.DocumentReference; updates: Record<string, unknown> }>();

  for (const doc of primarySnap.docs) {
    merged.set(doc.id, { ref: doc.ref, updates: { [primary.updateField]: newName } });
  }
  for (const doc of secondarySnap.docs) {
    const existing = merged.get(doc.id);
    if (existing) {
      existing.updates[secondary.updateField] = newName;
    } else {
      merged.set(doc.id, { ref: doc.ref, updates: { [secondary.updateField]: newName } });
    }
  }

  if (merged.size === 0) return 0;

  const entries = Array.from(merged.values());
  return batchUpdateRefs(
    entries.map((e) => e.ref),
    (ref) => merged.get(ref.id)?.updates ?? {},
    db
  );
}
