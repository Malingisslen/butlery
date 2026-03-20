/**
 * Propagate displayName/avatarUrl changes across denormalized copies.
 *
 * Triggered when a public_profiles/{userId} document is updated.
 * Updates denormalized copies in messages, conversations, recipe_comments,
 * friends subcollections, and shared content members.
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
    const errors: Error[] = [];

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
      errors.push(e as Error);
    }

    // 2. Update conversations where participantIds contains userId
    try {
      const convUpdates: Record<string, unknown> = {};
      if (nameChanged) convUpdates[`participantDisplayNames.${userId}`] = newName;
      if (avatarChanged) convUpdates[`participantAvatarUrls.${userId}`] = newAvatar;

      totalUpdated += await batchUpdateQuery(
        db.collection("conversations").where("participantIds", "array-contains", userId),
        convUpdates,
        db
      );
    } catch (e) {
      functions.logger.error(`Failed to update conversations for ${userHash}`, e);
      errors.push(e as Error);
    }

    // 3. Update recipe_comments where authorId == userId
    try {
      if (nameChanged) {
        totalUpdated += await batchUpdateQuery(
          db.collection("recipe_comments").where("authorId", "==", userId),
          { authorDisplayName: newName },
          db
        );
      }
    } catch (e) {
      functions.logger.error(`Failed to update recipe_comments for ${userHash}`, e);
      errors.push(e as Error);
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
          let batch = db.batch();
          let batchCount = 0;

          for (const friendDoc of friendsSnapshot.docs) {
            batch.update(
              db.collection("users").doc(friendDoc.id).collection("friends").doc(userId),
              { displayNameLower: newName?.toLowerCase() }
            );
            batchCount++;
            totalUpdated++;

            if (batchCount >= BATCH_LIMIT) {
              await batch.commit();
              batch = db.batch();
              batchCount = 0;
            }
          }

          if (batchCount > 0) {
            await batch.commit();
          }
        }
      }
    } catch (e) {
      functions.logger.error(`Failed to update friends for ${userHash}`, e);
      errors.push(e as Error);
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
      errors.push(e as Error);
    }

    functions.logger.info(
      `Profile propagation complete for ${userHash}: ${totalUpdated} documents updated, ${errors.length} errors`
    );

    if (errors.length > 0) {
      throw errors[0]; // Trigger Cloud Functions retry
    }
  });

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
