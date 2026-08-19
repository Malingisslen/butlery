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
import {
  stageCascadeAuditEntry,
  writeCascadeAuditEntry,
} from "./cascade-audit-log";

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

/** Per-step counts returned by the cleanup core so tests can assert effects. */
export interface UserSocialCleanupResult {
  friendsRemoved: number;
  socialRequestsCleaned: number;
  groupMembershipsRemoved: number;
  friendCountsUpdated: number;
  feedbackCleaned: number;
  presenceRowsRemoved: number;
  notificationQueuesPurged: number;
  legacySharedWithScrubbed: number;
  contentGuardSubcollectionsPurged: number;
  shareDisplayNameTombstoned: number;
  reportsAnonymized: number;
  recipeCookEventsPurged: number;
}

/**
 * Testable core for the user-deletion social cascade.
 *
 * The `onUserDeleted` trigger delegates here; exposed for integration tests
 * that run it against a real Firestore emulator. The cascade reads/writes via
 * the module-level `db = admin.firestore()`, which — when the test sets
 * `FIRESTORE_EMULATOR_HOST` before `admin.initializeApp` and requires this
 * module afterwards — is already emulator-bound. So no Firestore parameter is
 * needed; this is a pure extraction (formerly the private
 * `cleanupUserSocialData`) that now returns its `results` summary.
 */
export async function cleanupUserSocialData(
  userId: string
): Promise<UserSocialCleanupResult> {
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
    recipeCookEventsPurged: 0,
  };

  // Fetch friends list once (used by the merged friendship + friend-count step)
  const friendsSnapshot = await db
    .collection("users")
    .doc(userId)
    .collection("friends")
    .get();

  // 1 + 4 (BUT-1506). Remove reverse friendship docs AND decrement each
  // remaining friend's public friend count in ONE idempotent pass. These used
  // to be two separate steps keyed off the same top-of-function
  // `friendsSnapshot`; because `friendsCount: increment(-1)` is not
  // idempotent, a cascade that threw mid-run and was retried by the
  // onUserDeleted trigger decremented every count a second time. Merging them
  // makes the reverse-friendship doc the "not yet processed" token: the delete
  // and the decrement commit in the same atomic batch, and a friend whose
  // reverse doc is already gone (deleted on a prior attempt) is skipped.
  const friendCleanup = await cleanupFriendshipsAndDecrementCounts(
    userId,
    friendsSnapshot,
  );
  results.friendsRemoved = friendCleanup.friendsRemoved;

  // 2. Clean up social requests (sent and received) — formerly friend_requests
  results.socialRequestsCleaned = await cleanupSocialRequests(userId);

  // 3. Remove from group member arrays
  results.groupMembershipsRemoved = await cleanupGroupMemberships(userId);

  // 4. Friend counts were decremented atomically alongside the reverse-
  //    friendship deletes in step 1 (see BUT-1506) — nothing more to do here.
  results.friendCountsUpdated = friendCleanup.friendCountsUpdated;

  // 5. Clean up feedback submissions and screenshots
  results.feedbackCleaned = await cleanupFeedback(userId);

  // 6. GDPR: Remove userId from learned ingredient aliases
  await cleanUserFromLearnedAliases(userId);

  // 7. Delete public profile
  // BUT-886: own-data delete — audit row records the cascade for GDPR Art. 17
  // traceability. Standalone (single doc, no batch context here).
  await db.collection("public_profiles").doc(userId).delete();
  await writeCascadeAuditEntry(db, {
    subjectUserId: userId,
    targetUid: null,
    operation: "cascade_delete",
    resourceType: "public_profiles",
    resourceId: userId,
  });

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
  //       - users/{uid}/recentContentHashes/{rolling,chat}: rolling SHA-1
  //         hashes of comment/chat content the user wrote. Two docs since
  //         BUT-1898 split the surfaces; the sweep enumerates, so the count
  //         does not matter to it. SHA-1 + truncation is
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

  // 14. GDPR (BUT-838): purge the per-user recipe cook-event log at
  //     recipe_cook_events/{userId}/... — one event doc per cook action
  //     (timestamped, recipe-linked behavioral data = linked PII).
  //     Firestore never cascade-deletes a doc's subcollections, so an
  //     explicit purge is required for Right-to-Erasure.
  results.recipeCookEventsPurged = await cleanupRecipeCookEvents(userId);

  v1.logger.info(`Cleanup results for ${userId}:`, results);

  return results;
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
      // BUT-886: anonymize cascade — the user's denormalized PII is being
      // scrubbed from shared_content docs THEY authored. Recipients of those
      // shares will see the tombstone in place of the deleted name/avatar.
      // targetUid: null (own-data PII removal across own docs).
      stageCascadeAuditEntry(database, batch, {
        subjectUserId: userId,
        targetUid: null,
        operation: "cascade_anonymize",
        resourceType: "shared_content",
        resourceId: doc.id,
        extra: { fields: ["sharedByDisplayName", "sharedByAvatarUrl"] },
      });
    },
    {
      label: `BUT-466: sharedByDisplayName tombstone for ${userId}`,
      // BUT-886: mutate stages update + audit = 2 ops per item.
      opsPerItem: 2,
    }
  );
}

/**
 * BUT-651 / BUT-654: delete the per-user `notificationCounters` and
 * `recentContentHashes` subcollections under `users/{uid}/`.
 *
 * Both subcollections are bounded in size:
 *   - `notificationCounters` accumulates one doc per day; even a year-old
 *     account has < 400 docs.
 *   - `recentContentHashes` holds at most two docs (`rolling` for comments,
 *     `chat` since BUT-1898). It was one until 2026-08-19; the sweep
 *     enumerates the subcollection rather than naming ids, so the split
 *     needed no change here.
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
      for (const doc of snap.docs) {
        batch.delete(doc.ref);
        // BUT-886: own-data delete under users/{userId}/{subcoll}. Bounded
        // size (counters <400, recentContentHashes at most two docs since
        // BUT-1898 split comments from chat) — within the 500-op cap even
        // doubled for audit rows.
        stageCascadeAuditEntry(db, batch, {
          subjectUserId: userId,
          targetUid: null,
          operation: "cascade_delete",
          resourceType: `users/${subcoll}`,
          resourceId: doc.id,
        });
      }
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
      // BUT-886: each scrub mutates another user's shared_content doc.
      // Stage an audit row in the same batch; targetUid is the sharer
      // (the doc owner), pulled from doc.data().sharedByUserId.
      onItemOp: (batch, doc) => {
        const sharerUid = doc.data().sharedByUserId;
        stageCascadeAuditEntry(database, batch, {
          subjectUserId: userId,
          targetUid: typeof sharerUid === "string" ? sharerUid : null,
          operation: "cascade_delete",
          resourceType: "shared_content",
          resourceId: doc.id,
          extra: { field: "sharedWith", legacy: true },
        });
      },
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
    // BUT-886: stage an audit row per delete in the same batch. Own-data
    // delete — targetUid is null.
    total += await commitInChunks(
      database,
      snapshot.docs,
      (batch, doc) => {
        batch.delete(doc.ref);
        stageCascadeAuditEntry(database, batch, {
          subjectUserId: userId,
          targetUid: null,
          operation: "cascade_delete",
          resourceType: collection,
          resourceId: doc.id,
        });
      },
      {
        label: `BUT-647: ${collection} purge for ${userId}`,
        strict: true,
        // BUT-886: mutate stages delete + audit = 2 ops per item.
        opsPerItem: 2,
      }
    );
  }
  return total;
}

/**
 * BUT-838: GDPR cascade for the per-user recipe cook-event log.
 *
 * Assumed tree shape (the client write + firestore.rules block land with the
 * Dart-side half of BUT-838 this iteration):
 *
 *   recipe_cook_events/{userId}                  — per-user root doc (may be
 *                                                  a "ghost" path prefix if
 *                                                  the client only writes
 *                                                  event docs)
 *   recipe_cook_events/{userId}/events/{eventId} — one doc per cook action
 *
 * The event-subcollection name is DISCOVERED via `listCollections()` rather
 * than hard-coded: this half ships before the client writer, and discovery
 * keeps the cascade correct even if the subcollection name shifts between
 * `events` and something else before both halves land. `listCollections()`
 * also sees subcollections under ghost parents, so the purge works whether
 * or not the root doc exists.
 *
 * Rules assumption (owned by the Dart-side agent — do NOT add here): the
 * tree is owner-only (`request.auth.uid == userId` for read/create); client
 * delete is unnecessary because this admin cascade is the erasure path.
 *
 * Idempotency: re-runs see no subcollections + a missing root doc → 0.
 * Best-effort (BUT-753 rationale): a failure here must NOT re-throw out of
 * the cascade — onUserDeleted retries the WHOLE cascade and step 4's
 * `friendsCount: increment(-1)` is not idempotent. Residue is swept up by
 * the next delete event for the same uid or a manual sweep.
 */
async function cleanupRecipeCookEvents(userId: string): Promise<number> {
  return cleanupRecipeCookEventsWithDb(db, userId);
}

/** Test seam — accepts an injected Firestore so the cascade can run against a stub. */
export async function cleanupRecipeCookEventsWithDb(
  database: admin.firestore.Firestore,
  userId: string
): Promise<number> {
  const rootRef = database.collection("recipe_cook_events").doc(userId);
  let total = 0;

  try {
    const subcollections = await rootRef.listCollections();

    for (const subcoll of subcollections) {
      // Unbounded read is acceptable: one user's cook events accumulate at
      // human cooking pace (a few per day worst case → low thousands over
      // an account lifetime), well within the 540s/512MB budget.
      const snap = await subcoll.get();
      if (snap.empty) continue;

      // BUT-886: own-data delete — stage one audit row per event doc in the
      // same batch (2 ops/doc → chunk cap 250 via opsPerItem).
      total += await commitInChunks(
        database,
        snap.docs,
        (batch, doc) => {
          batch.delete(doc.ref);
          stageCascadeAuditEntry(database, batch, {
            subjectUserId: userId,
            targetUid: null,
            operation: "cascade_delete",
            resourceType: `recipe_cook_events/${subcoll.id}`,
            resourceId: doc.id,
          });
        },
        {
          label: `BUT-838: recipe_cook_events/${subcoll.id} purge for ${userId}`,
          // BUT-886: mutate stages delete + audit = 2 ops per item.
          opsPerItem: 2,
        }
      );
    }

    // Delete the per-user root doc (aggregate counters) only if it actually
    // exists — auditing the delete of a ghost parent would be noise.
    const rootSnap = await rootRef.get();
    if (rootSnap.exists) {
      await rootRef.delete();
      await writeCascadeAuditEntry(database, {
        subjectUserId: userId,
        targetUid: null,
        operation: "cascade_delete",
        resourceType: "recipe_cook_events",
        resourceId: userId,
      });
      total += 1;
    }
  } catch (err) {
    v1.logger.warn(
      `BUT-838: recipe_cook_events purge failed for ${userId}`,
      { err }
    );
  }

  return total;
}

/**
 * D1 + D4 (BUT-1506): remove reverse friendship docs AND decrement each
 * remaining friend's public friend count — idempotently under cascade retry.
 *
 * For every friend of the deleted user we (a) delete the reverse doc
 * `users/{friendId}/friends/{userId}` and (b) decrement
 * `public_profiles/{friendId}.friendsCount`. These MUST commit together,
 * because the reverse-friendship doc is the idempotency token: `friendsCount:
 * increment(-1)` is not idempotent, so when the cascade throws mid-run and the
 * `onUserDeleted` trigger retries the WHOLE function, an already-processed
 * friend must be skipped — which we detect by its reverse doc no longer
 * existing. Doing the delete and the decrement in the same atomic batch keeps
 * that token faithful (either both landed or neither did).
 *
 * We pre-read the reverse docs per chunk (via `getAll`) and only touch friends
 * whose reverse doc is still present. Each friend contributes 4 ops (reverse
 * delete + its audit + count decrement + its audit), so cap the chunk at
 * BATCH_LIMIT/4 friends to stay under the 500-op Firestore batch limit.
 *
 * BUT-455 / BUT-886: both cross-user writes stage an `audit_logs` row in the
 * same batch, so the audit row exists iff the mutation committed. Gating on
 * existence also self-heals a friendship where the reverse doc was already
 * missing — such a friend is never (double-)decremented.
 */
async function cleanupFriendshipsAndDecrementCounts(
  userId: string,
  friendsSnapshot: admin.firestore.QuerySnapshot,
): Promise<{ friendsRemoved: number; friendCountsUpdated: number }> {
  if (friendsSnapshot.empty) {
    return { friendsRemoved: 0, friendCountsUpdated: 0 };
  }

  // 4 ops per friend (reverse delete + audit + count decrement + audit).
  const FRIENDS_PER_BATCH = Math.floor(BATCH_LIMIT / 4);

  const friendIds = friendsSnapshot.docs.map((doc) => doc.id);
  let friendsRemoved = 0;
  let friendCountsUpdated = 0;

  for (let i = 0; i < friendIds.length; i += FRIENDS_PER_BATCH) {
    const chunk = friendIds.slice(i, i + FRIENDS_PER_BATCH);

    // Idempotency anchor: read the reverse-friendship docs for this chunk. A
    // missing reverse doc means this friend was already fully processed
    // (delete + decrement committed together) by an earlier attempt of a
    // retried cascade, so it must not be decremented again.
    const reverseRefs = chunk.map((friendId) =>
      db.collection("users").doc(friendId).collection("friends").doc(userId),
    );
    // BUT-1582: read each friend's public_profiles doc in the SAME getAll.
    // `batch.update` on a MISSING doc throws NOT_FOUND at commit and rolls back
    // the ENTIRE chunk (a poison pill), so one absent profile — an orphaned
    // edge, admin reset, legacy data, or a peer mid-deletion — would otherwise
    // starve every other friend's cleanup in the chunk and, because the trigger
    // retries the whole cascade, stall the deletion permanently.
    //
    // This getAll-then-batch is not atomic, so a narrow TOCTOU remains: a
    // profile deleted in the window between this read and the commit still
    // throws NOT_FOUND. That residual is bounded and self-healing — the trigger
    // retries the whole cascade, the re-read then sees the profile absent, the
    // guard below skips it, and the retry commits. A full close would need a
    // per-chunk transaction; not worth refactoring the batch-based cascade for a
    // millisecond race that recovers on the next retry (guard turns a permanent
    // deterministic stall into a rare transient one).
    const profileRefs = chunk.map((friendId) =>
      db.collection("public_profiles").doc(friendId),
    );
    const snaps = await db.getAll(...reverseRefs, ...profileRefs);
    const reverseSnaps = snaps.slice(0, chunk.length);
    const profileSnaps = snaps.slice(chunk.length);

    const batch = db.batch();
    let batchOps = 0;

    for (let j = 0; j < chunk.length; j++) {
      const reverseSnap = reverseSnaps[j];
      if (!reverseSnap.exists) continue; // already processed on a prior run

      const friendId = chunk[j];

      // (a) delete the reverse friendship doc — BUT-455 cross-user audit. The
      // reverse doc is the idempotency token, so it is always staged when
      // present, independent of whether the friend still has a public profile.
      batch.delete(reverseSnap.ref);
      stageCascadeAuditEntry(db, batch, {
        subjectUserId: userId,
        targetUid: friendId,
        operation: "cascade_delete",
        resourceType: "friends",
        resourceId: friendId,
        extra: { sourceCollection: `users/${friendId}/friends/${userId}` },
      });
      friendsRemoved++;
      batchOps++;

      // (b) decrement the friend's public friend count — BUT-886 audit — ONLY
      // when the profile exists (BUT-1582). A deliberately plain skip on absence:
      // no `set(..., {merge:true})`, which would resurrect a deleted peer's
      // profile with a negative count.
      if (!profileSnaps[j].exists) continue;

      batch.update(profileSnaps[j].ref, {
        friendsCount: admin.firestore.FieldValue.increment(-1),
      });
      stageCascadeAuditEntry(db, batch, {
        subjectUserId: userId,
        targetUid: friendId,
        operation: "cascade_delete",
        resourceType: "public_profiles",
        resourceId: friendId,
        extra: { field: "friendsCount", op: "decrement" },
      });
      friendCountsUpdated++;
    }

    if (batchOps > 0) {
      await batch.commit();
    }
  }

  return { friendsRemoved, friendCountsUpdated };
}

/**
 * Clean up social requests (renamed from friend_requests in BUT-761) involving
 * the deleted user.
 *
 * BUT-886: each request delete is a cross-user write — the request doc carries
 * both `fromUserId` and `toUserId`. We stage one audit_logs row per delete
 * with `targetUid` set to the OTHER party (the one whose participation in the
 * request is being scrubbed). Per-doc op count is 2 (delete + audit), so halve
 * the chunk cap to stay under the 500-op Firestore batch limit.
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

  const REQUESTS_PER_BATCH = Math.floor(BATCH_LIMIT / 2);

  let batch = db.batch();
  let batchCount = 0;

  for (const doc of [...sentRequests.docs, ...receivedRequests.docs]) {
    const data = doc.data();
    const otherParty =
      data.fromUserId === userId ? data.toUserId : data.fromUserId;
    batch.delete(doc.ref);
    stageCascadeAuditEntry(db, batch, {
      subjectUserId: userId,
      targetUid: typeof otherParty === "string" ? otherParty : null,
      operation: "cascade_delete",
      resourceType: Collections.socialRequests,
      resourceId: doc.id,
    });
    count++;
    batchCount++;

    if (batchCount >= REQUESTS_PER_BATCH) {
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
 *
 * BUT-886: each parent doc is a `users/{ownerUid}/friend_categories/{groupId}`
 * — the cascade mutates that owner's data. We stage an audit row per affected
 * doc in the same batch via the `onItemOp` hook.
 */
async function cleanupGroupMemberships(userId: string): Promise<number> {
  return cascadeArrayRemove(
    db.collectionGroup("friend_categories")
      .where("friendUserIds", "array-contains", userId),
    "friendUserIds",
    userId,
    db,
    {
      onItemOp: (batch, doc) => {
        // Path: users/{ownerUid}/friend_categories/{groupId}
        const ownerUid = doc.ref.parent.parent?.id ?? null;
        stageCascadeAuditEntry(db, batch, {
          subjectUserId: userId,
          targetUid: ownerUid,
          operation: "cascade_delete",
          resourceType: "friend_categories",
          resourceId: doc.id,
          extra: { field: "friendUserIds" },
        });
      },
    }
  );
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

  // BUT-886: each presence row delete is a cascade under another user's
  // recipePresence/shoppingPresence parent doc. Stage an audit row per
  // delete; halve the chunk cap since each row contributes 2 ops.
  const ROWS_PER_BATCH = Math.floor(BATCH_LIMIT / 2);

  let batch = database.batch();
  let batchCount = 0;
  let total = 0;

  for (const doc of snapshot.docs) {
    // Path: {recipePresence|shoppingPresence}/{parentId}/activeUsers/{userId}
    const parentRef = doc.ref.parent.parent;
    const parentCollection = parentRef?.parent.id ?? "unknown_presence";
    const parentId = parentRef?.id ?? "unknown";
    batch.delete(doc.ref);
    stageCascadeAuditEntry(database, batch, {
      subjectUserId: userId,
      targetUid: null,
      operation: "cascade_delete",
      resourceType: parentCollection,
      resourceId: parentId,
      extra: { subCollection: "activeUsers", rowId: doc.id },
    });
    batchCount++;
    total++;

    if (batchCount >= ROWS_PER_BATCH) {
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
      // BUT-886: anonymize cascade — the deleted user's id is being scrubbed
      // from /reports rows authored by other users (reporters). The report
      // itself is moderation evidence retained for the reporter's GDPR
      // access right; targetUid is null since the reporter is not the
      // direct subject of the anonymization.
      stageCascadeAuditEntry(database, batch, {
        subjectUserId: userId,
        targetUid: null,
        operation: "cascade_anonymize",
        resourceType: "reports",
        resourceId: doc.id,
        extra: { field: "contentOwnerId" },
      });
    },
    {
      label: `BUT-781: report anonymize for ${userId}`,
      // BUT-886: mutate stages update + audit = 2 ops per item.
      opsPerItem: 2,
    }
  );
}

/**
 * Clean up feedback submissions and screenshots for the deleted user.
 *
 * BUT-886: own-data delete (feedback authored by the deleted user). Stage
 * an audit row per delete in the same batch; halve the chunk cap since each
 * doc contributes 2 ops. Storage delete (screenshots) is a single bucket
 * operation and gets a separate standalone audit entry.
 */
async function cleanupFeedback(userId: string): Promise<number> {
  const feedbackDocs = await db
    .collection('feedback')
    .where('userId', '==', userId)
    .get();

  if (feedbackDocs.empty) return 0;

  const FEEDBACK_PER_BATCH = Math.floor(BATCH_LIMIT / 2);

  let batch = db.batch();
  let batchCount = 0;

  for (const doc of feedbackDocs.docs) {
    batch.delete(doc.ref);
    stageCascadeAuditEntry(db, batch, {
      subjectUserId: userId,
      targetUid: null,
      operation: "cascade_delete",
      resourceType: "feedback",
      resourceId: doc.id,
    });
    batchCount++;
    if (batchCount >= FEEDBACK_PER_BATCH) {
      await batch.commit();
      batch = db.batch();
      batchCount = 0;
    }
  }

  if (batchCount > 0) {
    await batch.commit();
  }

  // Also delete feedback screenshots from Storage.
  // BUT-886: standalone audit entry for the bucket-level delete since
  // this isn't part of a Firestore batch.
  try {
    await admin.storage().bucket().deleteFiles({
      prefix: `feedback/${userId}/`,
    });
    await writeCascadeAuditEntry(db, {
      subjectUserId: userId,
      targetUid: null,
      operation: "cascade_delete",
      resourceType: "storage:feedback",
      resourceId: `feedback/${userId}/`,
    });
  } catch (error) {
    v1.logger.warn(`Failed to delete feedback storage for ${userId}: ${error}`);
  }

  return feedbackDocs.size;
}
