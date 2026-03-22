/**
 * Propagate displayName/avatarUrl changes across denormalized copies.
 *
 * Triggered when a public_profiles/{userId} document is updated.
 * Updates denormalized copies in messages, conversations, recipe_comments,
 * friends subcollections, shared content members, realtime resources,
 * shared recipes, shopping lists, and group invitations.
 *
 * Safety: paginated batches (500-op limit), skips if no name/avatar change,
 * uses hashUid for GDPR-safe logging.
 */

import * as functions from "firebase-functions";
import * as admin from "firebase-admin";
import { hashUid } from "../shared/hash-uid";

const getDb = () => admin.firestore();
const BATCH_LIMIT = 500;

export const onProfileUpdated = functions
  .region("europe-west1")
  .firestore.document("public_profiles/{userId}")
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
    let totalUpdated = 0;

    // Build shared update maps
    const messageUpdates: Record<string, unknown> = {};
    if (nameChanged) messageUpdates["senderDisplayName"] = newName;
    if (avatarChanged) messageUpdates["senderAvatarUrl"] = newAvatar;

    const memberUpdates: Record<string, unknown> = {};
    if (nameChanged) memberUpdates["displayName"] = newName;
    if (avatarChanged) memberUpdates["avatarUrl"] = newAvatar;

    // 1. Update messages where senderId == userId
    try {
      totalUpdated += await batchUpdateQuery(
        db.collection("messages").where("senderId", "==", userId),
        messageUpdates,
        db
      );
    } catch (e) {
      functions.logger.error(`Failed to update messages for ${userHash}`, e);
    }

    // 2. Update conversations where participantIds contains userId
    try {
      totalUpdated += await batchUpdateDocs(
        db.collection("conversations").where("participantIds", "array-contains", userId),
        db,
        (doc) => {
          const updates: Record<string, unknown> = {};
          if (nameChanged) updates[`participantDisplayNames.${userId}`] = newName;
          if (avatarChanged) updates[`participantAvatarUrls.${userId}`] = newAvatar;
          return updates;
        }
      );
    } catch (e) {
      functions.logger.error(`Failed to update conversations for ${userHash}`, e);
    }

    // 3. Update recipe_comments where authorId == userId
    try {
      const commentUpdates: Record<string, unknown> = {};
      if (nameChanged) commentUpdates["authorDisplayName"] = newName;
      if (avatarChanged) commentUpdates["authorAvatarUrl"] = newAvatar;

      if (Object.keys(commentUpdates).length > 0) {
        totalUpdated += await batchUpdateQuery(
          db.collection("recipe_comments").where("authorId", "==", userId),
          commentUpdates,
          db
        );
      }
    } catch (e) {
      functions.logger.error(`Failed to update recipe_comments for ${userHash}`, e);
    }

    // 4. Update friends subcollections via friends list lookup
    try {
      if (nameChanged) {
        const friendsSnapshot = await db
          .collection("users")
          .doc(userId)
          .collection("friends")
          .get();

        if (!friendsSnapshot.empty) {
          totalUpdated += await batchUpdateDocs(
            null,
            db,
            (friendDoc) => ({ displayNameLower: newName?.toLowerCase() }),
            friendsSnapshot.docs.map((friendDoc) =>
              db.collection("users").doc(friendDoc.id).collection("friends").doc(userId)
            )
          );
        }
      }
    } catch (e) {
      functions.logger.error(`Failed to update friends for ${userHash}`, e);
    }

    // 5. Update shared content members subcollections (shared_recipes, shared_menus, etc.)
    try {
      totalUpdated += await batchUpdateQuery(
        db.collectionGroup("members").where("userId", "==", userId),
        memberUpdates,
        db
      );
    } catch (e) {
      functions.logger.error(`Failed to update members for ${userHash}`, e);
    }

    // 6. Update realtime_recipes + realtime_menus (owner + last-editor)
    for (const col of ["realtime_recipes", "realtime_menus"]) {
      try {
        if (nameChanged) {
          totalUpdated += await batchUpdateQuery(
            db.collection(col).where("ownerId", "==", userId),
            { ownerDisplayName: newName },
            db
          );
          totalUpdated += await batchUpdateQuery(
            db.collection(col).where("lastEditedBy", "==", userId),
            { lastEditedByDisplayName: newName },
            db
          );
        }
      } catch (e) {
        functions.logger.error(`Failed to update ${col} for ${userHash}`, e);
      }
    }

    // 7. Update shared_recipes — socialData.ownerDisplayName
    try {
      if (nameChanged) {
        totalUpdated += await batchUpdateQuery(
          db.collection("shared_recipes").where("socialData.ownerId", "==", userId),
          { "socialData.ownerDisplayName": newName },
          db
        );
      }
    } catch (e) {
      functions.logger.error(`Failed to update shared_recipes for ${userHash}`, e);
    }

    // 8. Update shopping lists (owner + last-activity)
    for (const col of ["unified_shopping_lists", "unified_shared_shopping_lists"]) {
      try {
        if (nameChanged) {
          totalUpdated += await batchUpdateQuery(
            db.collection(col).where("ownerId", "==", userId),
            { ownerDisplayName: newName },
            db
          );
          totalUpdated += await batchUpdateQuery(
            db.collection(col).where("lastActivityByUserId", "==", userId),
            { lastActivityByDisplayName: newName },
            db
          );
        }
      } catch (e) {
        functions.logger.error(`Failed to update ${col} for ${userHash}`, e);
      }
    }

    // 9. Update pending group_invitations
    try {
      if (nameChanged) {
        totalUpdated += await batchUpdateQuery(
          db.collection("group_invitations")
            .where("fromUserId", "==", userId)
            .where("status", "==", "pending"),
          { fromUserName: newName },
          db
        );
      }
    } catch (e) {
      functions.logger.error(`Failed to update group_invitations for ${userHash}`, e);
    }

    functions.logger.info(
      `Profile propagation complete for ${userHash}: ${totalUpdated} documents updated`
    );
  });

/**
 * Batch-update all docs matching a query with the same update map.
 */
async function batchUpdateQuery(
  query: admin.firestore.Query,
  updates: Record<string, unknown>,
  db: admin.firestore.Firestore
): Promise<number> {
  const snapshot = await query.get();
  if (snapshot.empty) return 0;

  let batch = db.batch();
  let batchCount = 0;
  let total = 0;

  for (const doc of snapshot.docs) {
    batch.update(doc.ref, updates);
    batchCount++;
    total++;

    if (batchCount >= BATCH_LIMIT) {
      await batch.commit();
      batch = db.batch();
      batchCount = 0;
    }
  }

  if (batchCount > 0) {
    await batch.commit();
  }

  return total;
}

/**
 * Batch-update docs with per-doc update maps, from either a query or explicit refs.
 */
async function batchUpdateDocs(
  query: admin.firestore.Query | null,
  db: admin.firestore.Firestore,
  getUpdates: (doc: admin.firestore.DocumentSnapshot) => Record<string, unknown>,
  refs?: admin.firestore.DocumentReference[]
): Promise<number> {
  const docs = refs
    ? refs.map((ref) => ({ ref } as admin.firestore.DocumentSnapshot))
    : (await query!.get()).docs;

  if (docs.length === 0) return 0;

  let batch = db.batch();
  let batchCount = 0;
  let total = 0;

  for (const doc of docs) {
    batch.update(doc.ref, getUpdates(doc));
    batchCount++;
    total++;

    if (batchCount >= BATCH_LIMIT) {
      await batch.commit();
      batch = db.batch();
      batchCount = 0;
    }
  }

  if (batchCount > 0) {
    await batch.commit();
  }

  return total;
}
