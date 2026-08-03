/**
 * Send Weekly Activity Digest
 *
 * Runs every Monday 08:00 UTC as the FIRST task in `weeklyReports` (see
 * `functions/src/scheduled/maintenance-dispatchers.ts`); it no longer owns a
 * Cloud Scheduler job of its own. It is deliberately first in that chain
 * because it is the only user-facing task in it — its send time is preserved
 * to the minute, and `northStarWeekly` (a report) runs after it.
 *
 * For each recently active user, aggregates their weekly activity (new
 * recipes, comments) and writes a notification to their notifications
 * subcollection.
 *
 * Firestore writes:
 * /users/{userId}/notifications/{auto} — activity_digest notification
 */

import { logger } from "firebase-functions/logger";
import * as admin from "firebase-admin";
import { Collections } from "../shared/collections";
import { sendPushToUserRespectingPreferences } from "../shared/preference-aware-push";
import { BATCH_LIMIT } from "../shared/batch-update";
import { buildNotificationPayload } from "../shared/notification-payload";
import { evaluateSendGate } from "../shared/notification-gate";
import { recordNotificationSendEvent } from "../shared/notification-send-events";

const getDb = () => admin.firestore();

const USER_BATCH_SIZE = 100;

/** Injection seam for tests — mirrors `RunDeps` in `daily-snapshots.ts`. */
export interface RunDeps {
  db?: admin.firestore.Firestore;
  now?: Date;
}

export async function runWeeklyActivityDigest(
  deps: RunDeps = {},
): Promise<void> {
  {
    const db = deps.db ?? getDb();
    const now =
      deps.now != null
        ? admin.firestore.Timestamp.fromMillis(deps.now.getTime())
        : admin.firestore.Timestamp.now();
    const sevenDaysAgo = admin.firestore.Timestamp.fromMillis(
      now.toMillis() - 7 * 24 * 60 * 60 * 1000
    );

    logger.info("Starting weekly activity digest...");

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
          const usersToNotifyViaPush: Array<{
            userId: string;
            newRecipeCount: number;
            newCommentCount: number;
            newRatingCount: number;
            newShareCount: number;
          }> = [];

          for (const userDoc of userBatch) {
            const userId = userDoc.id;

            // Check user preference — only send to users who opted in
            const prefsDoc = await db
              .collection("user_notification_preferences")
              .doc(userId)
              .get();
            const digestFrequency = prefsDoc.exists
              ? prefsDoc.data()?.digestFrequency ?? "never"
              : "never";

            if (digestFrequency === "never") {
              usersSkipped++;
              continue;
            }

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
            usersToNotifyViaPush.push({
              userId, newRecipeCount, newCommentCount, newRatingCount, newShareCount,
            });

            if (batchCount >= BATCH_LIMIT) {
              await batch.commit();
              batch = db.batch();
              batchCount = 0;
            }
          }

          if (batchCount > 0) {
            await batch.commit();
          }

          // Send FCM push notifications for this sub-batch (concurrent batches of 10).
          // Routes through the preference-aware helper so the master notification
          // toggle and Europe/Stockholm quiet hours are honored. BUT-1427: the push
          // is gated on the dedicated `digest` category (default-on) instead of
          // `reEngagement`, so turning win-back pings off no longer silences the
          // weekly digest. The per-frequency opt-out is the `digestFrequency !==
          // "never"` check above.
          for (let i = 0; i < usersToNotifyViaPush.length; i += 10) {
            const pushBatch = usersToNotifyViaPush.slice(i, i + 10);
            await Promise.allSettled(
              pushBatch.map(async (entry) => {
                const totalActivity =
                  entry.newRecipeCount + entry.newCommentCount +
                  entry.newRatingCount + entry.newShareCount;
                const title = "Veckans sammanfattning";
                const body = `Du hade ${totalActivity} aktivitet${totalActivity !== 1 ? "er" : ""} den här veckan`;
                const data = buildNotificationPayload({
                  route: "/winback",
                  targetId: "",
                  notificationType: "activity_digest",
                  additionalData: { type: "activity_digest" },
                });
                // BUT-647 + BUT-645: gate. Digest is low-importance, so
                // a user inside their quiet window will be DROPPED (the
                // notification doc was already written above).
                const decision = await evaluateSendGate({
                  userId: entry.userId,
                  notificationType: "activity_digest",
                  payload: { title, body, data },
                });
                if (decision.action !== "proceed") return;
                const result = await sendPushToUserRespectingPreferences(
                  entry.userId,
                  { title, body },
                  "digest",
                  // BUT-1427: gated on the user's digest preference, not their
                  // win-back preference. Opens the notifications inbox via the
                  // same route as win-back; `notificationType` distinguishes it
                  // for analytics attribution.
                  data
                );
                if (result.sent) {
                  await recordNotificationSendEvent({
                    userId: entry.userId,
                    notificationType: "activity_digest",
                    channel: "fcm",
                  });
                }
              })
            );
          }
        }

        const lastDoc = usersSnapshot.docs[usersSnapshot.docs.length - 1];
        usersSnapshot = await userQuery.startAfter(lastDoc).get();
      }

      logger.info(
        `Weekly digest complete: ${usersNotified} users notified, ${usersSkipped} skipped (no activity)`
      );
    } catch (error) {
      logger.error("Failed to send weekly activity digest:", error);
      throw error;
    }

  }
}
