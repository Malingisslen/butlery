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
import { cascadeArrayRemove, commitInChunks } from "../shared/batch-update";

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
    socialRequestsCleaned: 0,
    groupMembershipsRemoved: 0,
    friendCountsUpdated: 0,
    feedbackCleaned: 0,
    presenceRowsRemoved: 0,
    notificationQueuesPurged: 0,
    legacySharedWithScrubbed: 0,
    contentGuardSubcollectionsPurged: 0,
    shareDisplayNameTombstoned: 0,
    reportsAnonymized: 0,
  };

  // Fetch friends list once (used by steps 1 and 4)
  const friendsSnapshot = await db
    .collection("users")
    .doc(userId)
    .collection("friends")
    .get();

  // 1. Remove reverse friendship documents
  results.friendsRemoved = await cleanupReverseFriendships(userId, friendsSnapshot);

  // 2. Clean up social requests (sent and received) — formerly friend_requests
  results.socialRequestsCleaned = await cleanupSocialRequests(userId);

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

  // 9. GDPR (BUT-647 / BUT-645 — security review C2): purge per-user rows
  //    from the two notification analytics/queue collections. Both carry
  //    `userId`, and `scheduled_notifications` additionally carries the
  //    push payload (title/body) which can include comment snippets,
  //    recipe titles, friend display names — all linked PII. TTL alone
  //    isn't sufficient for Right-to-Erasure; we have to delete on demand.
  //
  //    Also purges `notification_opened_events` (added in C1 fix) which
  //    keys by `userId`.
  results.notificationQueuesPurged =
    await cleanupNotificationQueues(userId);

  // 10. BUT-753: scrub legacy `sharedWith` flat-array entries on
  //     `shared_content` docs. The user-driven path (SocialDeletionOperations
  //     .removeFromSharedContent) cannot do this — firestore.rules:515-518
  //     gates `update` on owner OR member-subcollection presence; a recipient
  //     who only appears in the legacy `sharedWith` array satisfies neither
  //     and the client write would permission-deny. Admin context bypasses
  //     rules so we can safely scrub.
  results.legacySharedWithScrubbed = await cleanupLegacySharedWithArrays(userId);

  // 11. GDPR (BUT-651 / BUT-654): purge per-user subcollections introduced by
  //     the moderation sprint:
  //       - users/{uid}/notificationCounters/{YYYY-MM-DD}: per-day push
  //         fatigue counters. PII-linked via path.
  //       - users/{uid}/recentContentHashes/rolling: rolling SHA-1 hashes
  //         of comment/chat content the user wrote. SHA-1 + truncation is
  //         not reversible without the original text, but the doc still
  //         records authorship metadata under the user path → linked PII.
  //     Firestore does not cascade-delete subcollections when the parent
  //     `users/{uid}` is deleted, so an explicit purge is required for
  //     Right-to-Erasure.
  results.contentGuardSubcollectionsPurged =
      await cleanupContentGuardSubcollections(userId);

  // 12. BUT-466: tombstone denormalised sharer-PII on top-level
  //     `shared_content` docs. Rules block recipient/self updates on these
  //     docs, so the admin path is the only writer that can scrub them.
  results.shareDisplayNameTombstoned =
      await tombstoneSharedByDisplayName(userId);

  // 13. BUT-781: anonymize reports where the deleted user was the reported
  //     `contentOwnerId`. We don't delete — reports are moderation evidence
  //     and reporters retain their right to read their own submissions. We
  //     only erase the linked PII (contentOwnerId → null + tombstone date).
  results.reportsAnonymized =
      await anonymizeReportsByContentOwner(userId);

  v1.logger.info(`Cleanup results for ${userId}:`, results);
}

// Swedish locale string — matches the app's UI language. Recipient UIs
// will render this in place of the deleted user's name.
const SHARED_BY_DISPLAY_NAME_TOMBSTONE = "[Raderad användare]";

async function tombstoneSharedByDisplayName(userId: string): Promise<number> {
  return tombstoneSharedByDisplayNameWithDb(db, userId);
}

/**
 * Test seam — injected Firestore lets the cascade run against a stub.
 * Idempotency: skip docs already at tombstone (display name) AND null
 * (avatar). Best-effort per chunk: commit failure logs warn + continues.
 */
export async function tombstoneSharedByDisplayNameWithDb(
  database: admin.firestore.Firestore,
  userId: string
): Promise<number> {
  const snapshot = await database
    .collection("shared_content")
    .where("sharedByUserId", "==", userId)
    .get();

  if (snapshot.empty) return 0;

  // Pre-filter already-tombstoned docs so the queued count reflects real work.
  const docsToUpdate = snapshot.docs.filter((doc) => {
    const data = doc.data();
    const displayNameAlreadyTombstoned =
      data.sharedByDisplayName === SHARED_BY_DISPLAY_NAME_TOMBSTONE;
    const avatarAlreadyCleared =
      data.sharedByAvatarUrl === null || data.sharedByAvatarUrl === undefined;
    return !(displayNameAlreadyTombstoned && avatarAlreadyCleared);
  });

  return commitInChunks(
    database,
    docsToUpdate,
    (batch, doc) => {
      batch.update(doc.ref, {
        sharedByDisplayName: SHARED_BY_DISPLAY_NAME_TOMBSTONE,
        sharedByAvatarUrl: null,
      });
    },
    { label: `BUT-466: sharedByDisplayName tombstone for ${userId}` }
  );
}

/**
 * BUT-651 / BUT-654: delete the per-user `notificationCounters` and
 * `recentContentHashes` subcollections under `users/{uid}/`.
 *
 * Both subcollections are bounded in size:
 *   - `notificationCounters` accumulates one doc per day; even a year-old
 *     account has < 400 docs.
 *   - `recentContentHashes` is a single `rolling` doc.
 * A single batch (≤ 500 ops) is sufficient. Best-effort per subcollection:
 * one failure logs a warn and proceeds — partial cleanup beats total
 * failure for GDPR cascade purposes.
 */
async function cleanupContentGuardSubcollections(
    userId: string,
): Promise<number> {
  const userRef = db.collection("users").doc(userId);

  async function purge(subcoll: string): Promise<number> {
    try {
      const snap = await userRef.collection(subcoll).get();
      if (snap.empty) return 0;
      const batch = db.batch();
      for (const doc of snap.docs) batch.delete(doc.ref);
      await batch.commit();
      return snap.size;
    } catch (err) {
      v1.logger.warn(
          `BUT-651/654: failed to purge users/${userId}/${subcoll}`,
          {err},
      );
      return 0;
    }
  }

  // Independent subcollections — purge concurrently.
  const counts = await Promise.all([
    purge("notificationCounters"),
    purge("recentContentHashes"),
  ]);
  return counts.reduce((a, b) => a + b, 0);
}

/**
 * BUT-753: scrub legacy `sharedWith` flat-array entries from top-level
 * `shared_content` documents. Modern shares track recipients via the
 * `members` subcollection + `sharedToUserIds` array (handled by the
 * client-driven path in `SocialDeletionOperations.removeFromSharedContent`).
 * Pre-migration docs may still carry a parallel `sharedWith: [...uid]`
 * array that the rules-restricted client cannot touch.
 *
 * Idempotency: `array-contains` query returns nothing once scrubbed, AND
 * `arrayRemove(userId)` is a no-op when the value is absent — so re-runs
 * are free of side-effects regardless of which guarantee fails first.
 *
 * Best-effort per chunk: a failed batch commit logs a warn and continues
 * with the next chunk. Partial cleanup beats total failure (the unscrubbed
 * docs will be retried on the next user-delete event for the same uid, or
 * on the next manual sweep).
 *
 * Returns the number of docs queued for update (i.e. matched by the
 * array-contains query). A successful re-run on already-scrubbed data
 * returns 0.
 */
async function cleanupLegacySharedWithArrays(userId: string): Promise<number> {
  return cleanupLegacySharedWithArraysWithDb(db, userId);
}

/**
 * Test seam — accepts an injected Firestore so the BUT-753 cascade can be
 * exercised against a stub without an emulator. Only the `shared_content`
 * top-level collection is scanned; `firestore.rules` has no other
 * collection that historically used a flat `sharedWith` array, so a
 * collectionGroup sweep would just be cost without coverage.
 */
export async function cleanupLegacySharedWithArraysWithDb(
  database: admin.firestore.Firestore,
  userId: string
): Promise<number> {
  return cascadeArrayRemove(
    database.collection("shared_content").where("sharedWith", "array-contains", userId),
    "sharedWith",
    userId,
    database,
    {
      bestEffort: true,
      onChunkFailure: (err) =>
        v1.logger.warn(
          `BUT-753: legacy sharedWith chunk commit failed for ${userId}`,
          { err }
        ),
    }
  );
}

/**
 * BUT-647 / BUT-645 (security-review C2): cascade-delete user rows in
 * the three notification-related queues/streams.
 *
 *   - `scheduled_notifications` — pending/delivered delayed pushes.
 *     Carries title+body PII.
 *   - `notification_send_events` — per-send analytics row. Carries
 *     `userId` + type only, but still PII-linked.
 *   - `notification_opened_events` — per-tap analytics row from
 *     `recordNotificationOpened`. Same shape as send-events.
 *
 * Returns the total number of docs deleted across all three.
 */
async function cleanupNotificationQueues(userId: string): Promise<number> {
  return cleanupNotificationQueuesWithDb(db, userId);
}

/**
 * Test seam — accepts an injected Firestore so the cascade can be
 * exercised against a stub.
 */
export async function cleanupNotificationQueuesWithDb(
  database: admin.firestore.Firestore,
  userId: string
): Promise<number> {
  const collections = [
    "scheduled_notifications",
    "notification_send_events",
    "notification_opened_events",
  ] as const;

  let total = 0;
  for (const collection of collections) {
    const snapshot = await database
      .collection(collection)
      .where("userId", "==", userId)
      .get();
    if (snapshot.empty) continue;

    // Strict semantics preserved: prior loop didn't catch — a failed commit
    // bubbled up, the cascade aborted, and onUserDeleted retried.
    total += await commitInChunks(
      database,
      snapshot.docs,
      (batch, doc) => batch.delete(doc.ref),
      {
        label: `BUT-647: ${collection} purge for ${userId}`,
        strict: true,
      }
    );
  }
  return total;
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
 * Clean up social requests (renamed from friend_requests in BUT-761) involving
 * the deleted user.
 */
async function cleanupSocialRequests(userId: string): Promise<number> {
  let count = 0;

  // Requests sent by the deleted user
  const sentRequests = await db
    .collection(Collections.socialRequests)
    .where("fromUserId", "==", userId)
    .get();

  // Requests received by the deleted user
  const receivedRequests = await db
    .collection(Collections.socialRequests)
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
 *
 * Strict mode: a failed chunk aborts the cascade. The reverse-friendship
 * cleanup (D1) and friend-count decrement (D4) depend on a converged
 * friendUserIds state; partial cleanup here would leave stale references
 * that the rest of the cascade can't compensate for.
 */
async function cleanupGroupMemberships(userId: string): Promise<number> {
  return cascadeArrayRemove(
    db.collectionGroup("friend_categories")
      .where("friendUserIds", "array-contains", userId),
    "friendUserIds",
    userId,
    db
  );
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
 * BUT-781: anonymize /reports rows where the deleted user was the reported
 * `contentOwnerId`. The reports themselves are moderation evidence (and the
 * reporter retains read access to their own submissions), so deletion would
 * destroy a record the reporter is GDPR-entitled to access. Anonymizing
 * removes the linked PII (contentOwnerId → null, plus a `contentOwnerAnonymizedAt`
 * tombstone for audit) while keeping the rest of the row intact.
 *
 * Best-effort per chunk: a failed batch commit logs a warn and continues.
 */
async function anonymizeReportsByContentOwner(userId: string): Promise<number> {
  return anonymizeReportsByContentOwnerWithDb(db, userId);
}

/** Test seam — accepts an injected Firestore so the cascade can run against a stub. */
export async function anonymizeReportsByContentOwnerWithDb(
  database: admin.firestore.Firestore,
  userId: string
): Promise<number> {
  const snapshot = await database
    .collection("reports")
    .where("contentOwnerId", "==", userId)
    .get();
  if (snapshot.empty) return 0;

  return commitInChunks(
    database,
    snapshot.docs,
    (batch, doc) => {
      batch.update(doc.ref, {
        contentOwnerId: null,
        contentOwnerAnonymizedAt: admin.firestore.FieldValue.serverTimestamp(),
      });
    },
    { label: `BUT-781: report anonymize for ${userId}` }
  );
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
