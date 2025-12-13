/**
 * Rate Limit Cleanup Cloud Function
 *
 * Scheduled to run weekly on Sundays at 3 AM UTC to delete old rate limit
 * records from user subcollections.
 *
 * Old records are those that haven't been updated in 90+ days.
 */

import * as functions from "firebase-functions";
import * as admin from "firebase-admin";

/**
 * Weekly cleanup of old rate limit records
 *
 * Schedule: 0 3 * * 0 (Weekly on Sundays at 3 AM UTC)
 * Region: europe-west1 (Stockholm)
 *
 * Processing:
 * - Iterates through all users
 * - Checks each user's rateLimits subcollection
 * - Deletes records older than 90 days
 */
export const cleanupOldRateLimits = functions
  .region("europe-west1")
  .pubsub.schedule("0 3 * * 0")  // Weekly on Sundays at 3 AM UTC
  .timeZone("UTC")
  .onRun(async () => {
    const db = admin.firestore();
    const cutoffDate = new Date();
    cutoffDate.setDate(cutoffDate.getDate() - 90);  // 90 days ago

    functions.logger.info(
      `Starting rate limit cleanup, deleting records older than ${cutoffDate.toISOString()}`
    );

    const usersRef = db.collection("users");
    const usersSnapshot = await usersRef.get();

    if (usersSnapshot.empty) {
      functions.logger.info("No users found");
      return null;
    }

    let deletedCount = 0;
    let processedUsers = 0;

    for (const userDoc of usersSnapshot.docs) {
      const rateLimitsRef = userDoc.ref.collection("rateLimits");
      const rateLimitsSnapshot = await rateLimitsRef.get();

      for (const limitDoc of rateLimitsSnapshot.docs) {
        const data = limitDoc.data();

        // Check the most recent window start timestamp
        const lastUpdate = data.dayWindowStart?.toDate() ||
                          data.monthWindowStart?.toDate();

        if (lastUpdate && lastUpdate < cutoffDate) {
          await limitDoc.ref.delete();
          deletedCount++;
        }
      }

      processedUsers++;

      // Log progress every 100 users
      if (processedUsers % 100 === 0) {
        functions.logger.info(
          `Processed ${processedUsers} users, deleted ${deletedCount} records so far`
        );
      }
    }

    functions.logger.info(
      `Rate limit cleanup complete: deleted ${deletedCount} old records from ${processedUsers} users`
    );

    return null;
  });
