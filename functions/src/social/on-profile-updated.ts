/**
 * Propagate displayName/avatarUrl changes across denormalized copies.
 *
 * Triggered when a public_profiles/{userId} document is updated.
 * Updates denormalized copies in messages, conversations, recipe_comments,
 * friends subcollections, and shared_recipes members.
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

    // 1. Update messages where senderId == userId
    if (nameChanged || avatarChanged) {
      const updates: Record<string, unknown> = {};
      if (nameChanged) updates["senderDisplayName"] = newName;
      if (avatarChanged) updates["senderAvatarUrl"] = newAvatar;

      totalUpdated += await batchUpdateQuery(
        db.collection("messages").where("senderId", "==", userId),
        updates,
        db
      );
    }

    // 2. Update conversations where participantIds contains userId
    if (nameChanged || avatarChanged) {
      const convSnapshot = await db
        .collection("conversations")
        .where("participantIds", "array-contains", userId)
        .get();

      if (!convSnapshot.empty) {
        let batch = db.batch();
        let batchCount = 0;

        for (const doc of convSnapshot.docs) {
          const updates: Record<string, unknown> = {};
          if (nameChanged) {
            updates[`participantDisplayNames.${userId}`] = newName;
          }
          if (avatarChanged) {
            updates[`participantAvatarUrls.${userId}`] = newAvatar;
          }

          batch.update(doc.ref, updates);
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

    // 3. Update recipe_comments where authorId == userId
    if (nameChanged) {
      totalUpdated += await batchUpdateQuery(
        db.collection("recipe_comments").where("authorId", "==", userId),
        { authorDisplayName: newName },
        db
      );
    }

    // 4. Update friends subcollections via friends list lookup
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
          const friendId = friendDoc.id;
          const reverseRef = db
            .collection("users")
            .doc(friendId)
            .collection("friends")
            .doc(userId);

          batch.update(reverseRef, {
            displayNameLower: newName?.toLowerCase(),
          });
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

    // 5. Update shared_recipes members subcollections
    if (nameChanged || avatarChanged) {
      const memberDocs = await db
        .collectionGroup("members")
        .where("userId", "==", userId)
        .get();

      if (!memberDocs.empty) {
        let batch = db.batch();
        let batchCount = 0;

        for (const doc of memberDocs.docs) {
          const updates: Record<string, unknown> = {};
          if (nameChanged) updates["displayName"] = newName;
          if (avatarChanged) updates["avatarUrl"] = newAvatar;

          batch.update(doc.ref, updates);
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

    functions.logger.info(
      `Profile propagation complete for ${userHash}: ${totalUpdated} documents updated`
    );
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
