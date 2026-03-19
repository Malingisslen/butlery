/**
 * Send Weekly Activity Digest
 *
 * Scheduled every Monday at 8 AM UTC. For each recently active user,
 * aggregates their weekly activity (new recipes, comments) and writes
 * a notification to their notifications subcollection.
 *
 * Firestore writes:
 * /users/{userId}/notifications/{auto} — activity_digest notification
 */

import * as functions from "firebase-functions";
import * as admin from "firebase-admin";

const getDb = () => admin.firestore();

const USER_BATCH_SIZE = 100;
const BATCH_LIMIT = 500;

export const sendWeeklyActivityDigest = functions
  .region("europe-west1")
  .pubsub.schedule("0 8 * * 1")
  .timeZone("UTC")
  .onRun(async () => {
    const db = getDb();
    const now = admin.firestore.Timestamp.now();
    const sevenDaysAgo = admin.firestore.Timestamp.fromMillis(
      now.toMillis() - 7 * 24 * 60 * 60 * 1000
    );

    functions.logger.info("Starting weekly activity digest...");

    try {
      const usersSnapshot = await db
        .collection("users")
        .where("lastActiveAt", ">=", sevenDaysAgo)
        .get();

      if (usersSnapshot.empty) {
        functions.logger.info("No active users in the past 7 days");
        return null;
      }

      let usersNotified = 0;
      let usersSkipped = 0;

      // Process users in batches
      for (let i = 0; i < usersSnapshot.docs.length; i += USER_BATCH_SIZE) {
        const userBatch = usersSnapshot.docs.slice(i, i + USER_BATCH_SIZE);
        let batch = db.batch();
        let batchCount = 0;

        for (const userDoc of userBatch) {
          const userId = userDoc.id;

          // Count new recipes in the past 7 days
          const recipesSnapshot = await db
            .collection("users")
            .doc(userId)
            .collection("recipes")
            .where("core.createdAt", ">=", sevenDaysAgo)
            .get();
          const newRecipeCount = recipesSnapshot.size;

          // Count new comments authored in the past 7 days
          const commentsSnapshot = await db
            .collection("recipe_comments")
            .where("authorId", "==", userId)
            .where("createdAt", ">=", sevenDaysAgo)
            .get();
          const newCommentCount = commentsSnapshot.size;

          // Count new ratings in the past 7 days
          const ratingsSnapshot = await db
            .collection("recipe_ratings")
            .where("userId", "==", userId)
            .where("createdAt", ">=", sevenDaysAgo)
            .get();
          const newRatingCount = ratingsSnapshot.size;

          // Count shared recipes in the past 7 days
          const sharedSnapshot = await db
            .collection("shared_recipes")
            .where("sharedByUserId", "==", userId)
            .where("sharedAt", ">=", sevenDaysAgo)
            .get();
          const newShareCount = sharedSnapshot.size;

          if (
            newRecipeCount === 0 &&
            newCommentCount === 0 &&
            newRatingCount === 0 &&
            newShareCount === 0
          ) {
            usersSkipped++;
            continue;
          }

          const notificationRef = db
            .collection("users")
            .doc(userId)
            .collection("notifications")
            .doc();

          batch.set(notificationRef, {
            type: "activity_digest",
            newRecipeCount,
            newCommentCount,
            newRatingCount,
            newShareCount,
            period: "weekly",
            createdAt: now,
            read: false,
          });

          batchCount++;
          usersNotified++;

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

      functions.logger.info(
        `Weekly digest complete: ${usersNotified} users notified, ${usersSkipped} skipped (no activity)`
      );
    } catch (error) {
      functions.logger.error("Failed to send weekly activity digest:", error);
    }

    return null;
  });
