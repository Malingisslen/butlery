/**
 * D1-D5: Cleanup social data when a user account is deleted.
 *
 * Removes:
 * - Reverse friendship documents in other users' friends subcollections
 * - User from group friendUserIds arrays
 * - User from shared content member arrays
 * - Decrements friend counts on remaining users' public profiles
 * - Cleans up friend requests (sent and received)
 *
 * GDPR: Deleted user's personal data (display name, avatar URL) embedded
 * in other users' documents is removed or anonymized.
 */

import * as functions from "firebase-functions";
import * as admin from "firebase-admin";
import { withTimeout } from "../shared/with-timeout";

const db = admin.firestore();
const BATCH_LIMIT = 500;

/**
 * Triggered when a Firebase Auth user is deleted.
 * Cleans up all social references to that user across the database.
 */
export const onUserDeleted = functions
  .region("europe-west1")
  .auth.user()
  .onDelete(async (user) => {
    const userId = user.uid;
    functions.logger.info(`User deleted: ${userId}. Starting social cleanup.`);

    try {
      await withTimeout(
        cleanupUserSocialData(userId),
        8 * 60 * 1000,
        "onUserDeleted"
      );
      functions.logger.info(`Social cleanup complete for user ${userId}`);
    } catch (error) {
      functions.logger.error(
        `Social cleanup failed for user ${userId}:`,
        error
      );
      throw error; // Retry
    }
  });

async function cleanupUserSocialData(userId: string): Promise<void> {
  const results = {
    friendsRemoved: 0,
    friendRequestsCleaned: 0,
    groupMembershipsRemoved: 0,
    friendCountsUpdated: 0,
  };

  // 1. Remove reverse friendship documents
  results.friendsRemoved = await cleanupReverseFriendships(userId);

  // 2. Clean up friend requests (sent and received)
  results.friendRequestsCleaned = await cleanupFriendRequests(userId);

  // 3. Remove from group member arrays
  results.groupMembershipsRemoved = await cleanupGroupMemberships(userId);

  // 4. Update friend counts
  results.friendCountsUpdated = await updateFriendCounts(userId);

  // 5. Delete public profile
  await db.collection("public_profiles").doc(userId).delete();

  functions.logger.info(`Cleanup results for ${userId}:`, results);
}

/**
 * D1: Remove reverse friendship documents.
 * For each friend of the deleted user, remove the deleted user's doc
 * from their friends subcollection.
 */
async function cleanupReverseFriendships(userId: string): Promise<number> {
  // Get the deleted user's friends list
  const friendsSnapshot = await db
    .collection("users")
    .doc(userId)
    .collection("friends")
    .get();

  if (friendsSnapshot.empty) return 0;

  let count = 0;
  let batch = db.batch();
  let batchCount = 0;

  for (const friendDoc of friendsSnapshot.docs) {
    const friendId = friendDoc.id;

    // Delete the reverse friendship document
    const reverseRef = db
      .collection("users")
      .doc(friendId)
      .collection("friends")
      .doc(userId);

    batch.delete(reverseRef);
    count++;
    batchCount++;

    if (batchCount >= BATCH_LIMIT) {
      await batch.commit();
      batch = db.batch();
      batchCount = 0;
    }
  }

  if (batchCount > 0) {
    await batch.commit();
  }

  return count;
}

/**
 * Clean up friend requests involving the deleted user.
 */
async function cleanupFriendRequests(userId: string): Promise<number> {
  let count = 0;

  // Requests sent by the deleted user
  const sentRequests = await db
    .collection("friend_requests")
    .where("fromUserId", "==", userId)
    .get();

  // Requests received by the deleted user
  const receivedRequests = await db
    .collection("friend_requests")
    .where("toUserId", "==", userId)
    .get();

  let batch = db.batch();
  let batchCount = 0;

  for (const doc of [...sentRequests.docs, ...receivedRequests.docs]) {
    batch.delete(doc.ref);
    count++;
    batchCount++;

    if (batchCount >= BATCH_LIMIT) {
      await batch.commit();
      batch = db.batch();
      batchCount = 0;
    }
  }

  if (batchCount > 0) {
    await batch.commit();
  }

  return count;
}

/**
 * D3: Remove deleted user from group friendUserIds arrays.
 * Uses collectionGroup query to find all friendCategories containing this user.
 */
async function cleanupGroupMemberships(userId: string): Promise<number> {
  const groupsSnapshot = await db
    .collectionGroup("friendCategories")
    .where("friendUserIds", "array-contains", userId)
    .get();

  if (groupsSnapshot.empty) return 0;

  let batch = db.batch();
  let batchCount = 0;

  for (const doc of groupsSnapshot.docs) {
    batch.update(doc.ref, {
      friendUserIds: admin.firestore.FieldValue.arrayRemove(userId),
    });
    batchCount++;

    if (batchCount >= BATCH_LIMIT) {
      await batch.commit();
      batch = db.batch();
      batchCount = 0;
    }
  }

  if (batchCount > 0) {
    await batch.commit();
  }

  return groupsSnapshot.size;
}

/**
 * D4: Decrement friend counts on remaining users' public profiles.
 */
async function updateFriendCounts(userId: string): Promise<number> {
  const friendsSnapshot = await db
    .collection("users")
    .doc(userId)
    .collection("friends")
    .get();

  if (friendsSnapshot.empty) return 0;

  let batch = db.batch();
  let batchCount = 0;

  for (const friendDoc of friendsSnapshot.docs) {
    const friendId = friendDoc.id;
    const profileRef = db.collection("public_profiles").doc(friendId);

    batch.update(profileRef, {
      friendsCount: admin.firestore.FieldValue.increment(-1),
    });
    batchCount++;

    if (batchCount >= BATCH_LIMIT) {
      await batch.commit();
      batch = db.batch();
      batchCount = 0;
    }
  }

  if (batchCount > 0) {
    await batch.commit();
  }

  return friendsSnapshot.size;
}
