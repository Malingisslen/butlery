/**
 * I5: Clean up expired friend requests.
 *
 * Friend requests have a 7-day expiry (matching the isExpired getter on the
 * FriendRequest model). This scheduled function deletes requests that have
 * been pending for more than 7 days.
 */

import * as functions from "firebase-functions";
import * as admin from "firebase-admin";

const db = admin.firestore();

/**
 * Runs weekly on Sundays at 4 AM. Deletes pending friend requests
 * older than 7 days.
 */
export const cleanupExpiredFriendRequests = functions
  .region("europe-west1")
  .pubsub.schedule("0 4 * * 0")
  .timeZone("Europe/Stockholm")
  .onRun(async () => {
    functions.logger.info("Starting expired friend request cleanup");

    const sevenDaysAgo = admin.firestore.Timestamp.fromDate(
      new Date(Date.now() - 7 * 24 * 60 * 60 * 1000)
    );

    try {
      const expiredRequests = await db
        .collection("friend_requests")
        .where("status", "==", "pending")
        .where("sentAt", "<", sevenDaysAgo)
        .get();

      if (expiredRequests.empty) {
        functions.logger.info("No expired friend requests found");
        return;
      }

      let batch = db.batch();
      let batchCount = 0;
      let totalDeleted = 0;

      for (const doc of expiredRequests.docs) {
        batch.update(doc.ref, {
          status: "expired",
          expiredAt: admin.firestore.FieldValue.serverTimestamp(),
        });
        batchCount++;
        totalDeleted++;

        if (batchCount >= 500) {
          await batch.commit();
          batch = db.batch();
          batchCount = 0;
        }
      }

      if (batchCount > 0) {
        await batch.commit();
      }

      functions.logger.info(
        `Expired ${totalDeleted} friend requests older than 7 days`
      );

      // Log cleanup event
      await db.collection("system_events").add({
        type: "cleanup_expired_friend_requests",
        timestamp: admin.firestore.FieldValue.serverTimestamp(),
        details: { expiredCount: totalDeleted },
      });
    } catch (error) {
      functions.logger.error("Failed to cleanup expired friend requests:", error);
      throw error;
    }
  });
