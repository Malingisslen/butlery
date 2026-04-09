/**
 * Cache Cleanup Cloud Function
 *
 * Scheduled to run daily at 2 AM UTC to delete expired cache entries
 * from the globalRecipeCache collection.
 *
 * Expiration is calculated based on:
 * - cachedAt timestamp (when entry was cached)
 * - ttlDays field (default 90 days if not specified)
 */

import * as functions from "firebase-functions";
import * as admin from "firebase-admin";

/**
 * Daily cleanup of expired cache entries
 *
 * Schedule: 0 2 * * * (Daily at 2 AM UTC)
 * Region: europe-west1 (Belgium)
 *
 * Batch processing:
 * - Processes all cache entries
 * - Commits deletions in batches of 500
 * - Logs total deleted count
 */
export const cleanupExpiredCache = functions
  .region("europe-west1")
  .pubsub.schedule("0 2 * * *")  // Daily at 2 AM UTC
  .timeZone("UTC")
  .onRun(async () => {
    const db = admin.firestore();
    const now = Date.now();
    const collectionRef = db.collection("globalRecipeCache");

    functions.logger.info("Starting cache cleanup...");

    // Query all cache entries
    const snapshot = await collectionRef.get();

    if (snapshot.empty) {
      functions.logger.info("No cache entries found");
      return null;
    }

    let deletedCount = 0;
    let batch = db.batch();
    let batchCount = 0;

    for (const doc of snapshot.docs) {
      const data = doc.data();
      const cachedAt = data.cachedAt?.toMillis() || 0;
      const ttlDays = data.ttlDays || 90;  // Default 90 days if not specified
      const expiryTime = cachedAt + (ttlDays * 24 * 60 * 60 * 1000);

      if (expiryTime < now) {
        batch.delete(doc.ref);
        batchCount++;
        deletedCount++;

        // Commit every 500 operations (Firestore batch limit)
        if (batchCount >= 500) {
          await batch.commit();
          batch = db.batch();
          batchCount = 0;
          functions.logger.info(`Committed batch of 500 deletions`);
        }
      }
    }

    // Commit remaining deletions
    if (batchCount > 0) {
      await batch.commit();
    }

    functions.logger.info(
      `Cache cleanup complete: deleted ${deletedCount} expired entries out of ${snapshot.size} total`
    );

    return null;
  });
