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
import { Collections } from "../shared/collections";

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
      let usersNotified = 0;
      let usersSkipped = 0;

      const PAGE_SIZE = 500;
      let userQuery = db
        .collection("users")
        .where("lastActiveAt", ">=", sevenDaysAgo)
        .orderBy("lastActiveAt")
        .limit(PAGE_SIZE);
      let usersSnapshot = await userQuery.get();

      while (usersSnapshot.size > 0) {
        // Process users in sub-batches for per-user queries
        for (let i = 0; i < usersSnapshot.docs.length; i += USER_BATCH_SIZE) {
          const userBatch = usersSnapshot.docs.slice(i, i + USER_BATCH_SIZE);
          let batch = db.batch();
          let batchCount = 0;

          for (const userDoc of userBatch) {
          const userId = userDoc.id;

          // Count activity in past 7 days (parallel queries)
          const [recipesSnapshot, commentsSnapshot, ratingsSnapshot, sharedSnapshot] =
            await Promise.all([
              db.collection("users").doc(userId).collection("recipes")
                .where("core.createdAt", ">=", sevenDaysAgo).get(),
              db.collection(Collections.recipeComments)
                .where("authorId", "==", userId)
                .where("createdAt", ">=", sevenDaysAgo).get(),
              db.collection("recipe_ratings")
                .where("userId", "==", userId)
                .where("createdAt", ">=", sevenDaysAgo).get(),
              db.collection(Collections.sharedRecipes)
                .where("sharedByUserId", "==", userId)
                .where("sharedAt", ">=", sevenDaysAgo).get(),
            ]);
          const newRecipeCount = recipesSnapshot.size;
          const newCommentCount = commentsSnapshot.size;
          const newRatingCount = ratingsSnapshot.size;
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

        const lastDoc = usersSnapshot.docs[usersSnapshot.docs.length - 1];
        usersSnapshot = await userQuery.startAfter(lastDoc).get();
      }

      functions.logger.info(
        `Weekly digest complete: ${usersNotified} users notified, ${usersSkipped} skipped (no activity)`
      );
    } catch (error) {
      functions.logger.error("Failed to send weekly activity digest:", error);
      throw error;
    }

    return null;
  });
