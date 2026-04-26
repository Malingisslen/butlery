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

import * as v1 from "firebase-functions/v1";
import * as admin from "firebase-admin";
import { Collections } from "../shared/collections";
import { withTimeout } from "../shared/with-timeout";
import { cleanUserFromLearnedAliases } from "../analytics/analyze-corrections";

const db = admin.firestore();
const BATCH_LIMIT = 500;

/**
 * Triggered when a Firebase Auth user is deleted.
 * Cleans up all social references to that user across the database.
 */
export const onUserDeleted = v1
  .region("europe-west1")
  .runWith({ timeoutSeconds: 540, memory: "512MB" })
  .auth.user()
  .onDelete(async (user) => {
    const userId = user.uid;
    v1.logger.info(`User deleted: ${userId}. Starting social cleanup.`);

    try {
      await withTimeout(
        cleanupUserSocialData(userId),
        8 * 60 * 1000,
        "onUserDeleted"
      );
      v1.logger.info(`Social cleanup complete for user ${userId}`);
    } catch (error) {
      v1.logger.error(
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
    feedbackCleaned: 0,
    presenceRowsRemoved: 0,
  };

  // Fetch friends list once (used by steps 1 and 4)
  const friendsSnapshot = await db
    .collection("users")
    .doc(userId)
    .collection("friends")
    .get();

  // 1. Remove reverse friendship documents
  results.friendsRemoved = await cleanupReverseFriendships(userId, friendsSnapshot);

  // 2. Clean up friend requests (sent and received)
  results.friendRequestsCleaned = await cleanupFriendRequests(userId);

  // 3. Remove from group member arrays
  results.groupMembershipsRemoved = await cleanupGroupMemberships(userId);

  // 4. Update friend counts
  results.friendCountsUpdated = await updateFriendCounts(friendsSnapshot);

  // 5. Clean up feedback submissions and screenshots
  results.feedbackCleaned = await cleanupFeedback(userId);

  // 6. GDPR: Remove userId from learned ingredient aliases
  await cleanUserFromLearnedAliases(userId);

  // 7. Delete public profile
  await db.collection("public_profiles").doc(userId).delete();

  // 8. GDPR (BUT-477): purge per-user presence rows across all collaborative
  //    surfaces. Per-doc TTL would catch these within 60s, but GDPR Right-to-
  //    Erasure obliges us to delete on request — we don't get to wait for
  //    the sweeper. Cooking-session presence lives in RTDB and self-clears
  //    via onDisconnect, so it isn't included here.
  results.presenceRowsRemoved = await cleanupPresenceRows(userId);

  v1.logger.info(`Cleanup results for ${userId}:`, results);
}

/**
 * D1: Remove reverse friendship documents.
 * For each friend of the deleted user, remove the deleted user's doc
 * from their friends subcollection.
 */
async function cleanupReverseFriendships(
  userId: string,
  friendsSnapshot: admin.firestore.QuerySnapshot
): Promise<number> {
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
    .collection(Collections.friendRequests)
    .where("fromUserId", "==", userId)
    .get();

  // Requests received by the deleted user
  const receivedRequests = await db
    .collection(Collections.friendRequests)
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
    .collectionGroup("friend_categories")
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
async function updateFriendCounts(
  friendsSnapshot: admin.firestore.QuerySnapshot
): Promise<number> {
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

/**
 * BUT-477: Purge per-user presence rows from collaborative surfaces.
 *
 * Two Firestore presence collections own per-user rows keyed by `userId`:
 *   - `recipePresence/{recipeId}/activeUsers/{userId}`
 *   - `shoppingPresence/{listId}/activeUsers/{userId}`
 *
 * We use a `collectionGroup('activeUsers')` + `where('userId', '==', userId)`
 * sweep to find every row this user owns across all parent docs, then delete
 * in batches.
 *
 * GDPR rationale: presence rows contain `userId`, `displayName`, and
 * `avatarUrl` — all linked PII. Right-to-Erasure cannot wait for the 60-s
 * TTL sweeper.
 *
 * RTDB cooking-session presence (`cooking_sessions/{groupId}/{userId}`) is
 * intentionally NOT included: those rows self-clear via `onDisconnect()`
 * within seconds of the user going offline (see
 * `firebase_cooking_session_repository.dart`). Account deletion implies the
 * device is no longer connected, so RTDB has already cleaned up.
 */
async function cleanupPresenceRows(userId: string): Promise<number> {
  return cleanupPresenceRowsWithDb(db, userId);
}

/**
 * Test seam — accepts an injected Firestore instance so the BUT-477
 * cascade can be exercised against a stub without a live emulator.
 *
 * Exported for use only from `__tests__/`. Non-test callers should use
 * `cleanupPresenceRows(userId)` which closes over the module-level
 * `db = admin.firestore()`.
 */
export async function cleanupPresenceRowsWithDb(
  database: admin.firestore.Firestore,
  userId: string
): Promise<number> {
  const snapshot = await database
    .collectionGroup("activeUsers")
    .where("userId", "==", userId)
    .get();

  if (snapshot.empty) return 0;

  let batch = database.batch();
  let batchCount = 0;
  let total = 0;

  for (const doc of snapshot.docs) {
    batch.delete(doc.ref);
    batchCount++;
    total++;

    if (batchCount >= BATCH_LIMIT) {
      await batch.commit();
      batch = database.batch();
      batchCount = 0;
    }
  }

  if (batchCount > 0) {
    await batch.commit();
  }

  return total;
}

/**
 * Clean up feedback submissions and screenshots for the deleted user.
 */
async function cleanupFeedback(userId: string): Promise<number> {
  const feedbackDocs = await db
    .collection('feedback')
    .where('userId', '==', userId)
    .get();

  if (feedbackDocs.empty) return 0;

  let batch = db.batch();
  let batchCount = 0;

  for (const doc of feedbackDocs.docs) {
    batch.delete(doc.ref);
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

  // Also delete feedback screenshots from Storage
  try {
    await admin.storage().bucket().deleteFiles({
      prefix: `feedback/${userId}/`,
    });
  } catch (error) {
    v1.logger.warn(`Failed to delete feedback storage for ${userId}: ${error}`);
  }

  return feedbackDocs.size;
}
