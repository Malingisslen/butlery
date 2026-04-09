/**
 * Rate Limit Cleanup Cloud Function
 *
 * Scheduled to run weekly on Sundays at 3 AM UTC to delete old rate limit
 * records from user subcollections.
 *
 * Old records are those that haven't been updated in 90+ days.
 *
 * CRIT-7: Uses batched deletes and pagination to prevent timeouts on large user bases.
 */

import * as functions from "firebase-functions";
import * as admin from "firebase-admin";

// CRIT-7: Constants for safe batch processing
const BATCH_SIZE = 500; // Firestore maximum per batch commit
const USER_CHUNK_SIZE = 1000; // Process users in chunks to prevent memory issues
const MAX_EXECUTION_TIME_MS = 8 * 60 * 1000; // 8 minutes (Cloud Functions timeout is 9 min)

/**
 * Weekly cleanup of old rate limit records
 *
 * Schedule: 0 3 * * 0 (Weekly on Sundays at 3 AM UTC)
 * Region: europe-west1 (Belgium)
 *
 * CRIT-7: Processing with safety limits:
 * - Processes users in chunks of 1000
 * - Uses batched deletes (500 per batch)
 * - Has timeout protection (8 minutes)
 */
export const cleanupOldRateLimits = functions
  .region("europe-west1")
  .pubsub.schedule("0 3 * * 0")  // Weekly on Sundays at 3 AM UTC
  .timeZone("UTC")
  .onRun(async () => {
    const startTime = Date.now();
    const db = admin.firestore();
    const cutoffDate = new Date();
    cutoffDate.setDate(cutoffDate.getDate() - 90);  // 90 days ago

    functions.logger.info(
      `Starting rate limit cleanup, deleting records older than ${cutoffDate.toISOString()}`
    );

    let deletedCount = 0;
    let processedUsers = 0;
    let lastUserDoc: admin.firestore.DocumentSnapshot | null = null;
    let hasMoreUsers = true;

    // CRIT-7: Process users in chunks with pagination
    while (hasMoreUsers) {
      // Check timeout
      if (Date.now() - startTime > MAX_EXECUTION_TIME_MS) {
        functions.logger.warn(
          `CRIT-7: Approaching timeout after ${processedUsers} users, ${deletedCount} deletes. ` +
          `Will continue in next scheduled run.`
        );
        break;
      }

      // Build paginated query
      let usersQuery = db.collection("users")
        .orderBy("__name__")
        .limit(USER_CHUNK_SIZE);

      if (lastUserDoc) {
        usersQuery = usersQuery.startAfter(lastUserDoc);
      }

      const usersSnapshot = await usersQuery.get();

      if (usersSnapshot.empty) {
        hasMoreUsers = false;
        break;
      }

      // CRIT-7: Collect all deletions, then batch commit
      const docsToDelete: admin.firestore.DocumentReference[] = [];

      for (const userDoc of usersSnapshot.docs) {
        const rateLimitsRef = userDoc.ref.collection("rate_limits");
        const rateLimitsSnapshot = await rateLimitsRef.get();

        for (const limitDoc of rateLimitsSnapshot.docs) {
          const data = limitDoc.data();

          // Check the last write timestamp (written by Firestore rules rateLimitWrite)
          const lastUpdate = data.lastWrite?.toDate();

          if (lastUpdate && lastUpdate < cutoffDate) {
            docsToDelete.push(limitDoc.ref);
          }
        }

        processedUsers++;
        lastUserDoc = userDoc;
      }

      // CRIT-7: Batch delete collected documents
      if (docsToDelete.length > 0) {
        let batch = db.batch();
        let batchCount = 0;

        for (const docRef of docsToDelete) {
          batch.delete(docRef);
          batchCount++;

          if (batchCount >= BATCH_SIZE) {
            await batch.commit();
            deletedCount += batchCount;
            functions.logger.debug(`Committed batch of ${batchCount} deletes`);
            batch = db.batch();
            batchCount = 0;
          }
        }

        // Commit remaining
        if (batchCount > 0) {
          await batch.commit();
          deletedCount += batchCount;
          functions.logger.debug(`Committed final batch of ${batchCount} deletes`);
        }
      }

      // Log progress
      functions.logger.info(
        `Processed ${processedUsers} users, deleted ${deletedCount} records so far`
      );

      // Check if we got fewer than requested (end of collection)
      if (usersSnapshot.size < USER_CHUNK_SIZE) {
        hasMoreUsers = false;
      }
    }

    const elapsedMs = Date.now() - startTime;
    functions.logger.info(
      `Rate limit cleanup complete: deleted ${deletedCount} old records ` +
      `from ${processedUsers} users in ${(elapsedMs / 1000).toFixed(1)}s`
    );

    return null;
  });
