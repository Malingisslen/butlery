/**
 * I5: Clean up expired friend requests.
 *
 * Friend requests have a 7-day expiry (matching the isExpired getter on the
 * FriendRequest model). This scheduled function deletes requests that have
 * been pending for more than 7 days.
 */

import { onSchedule } from "firebase-functions/v2/scheduler";
import { logger } from "firebase-functions/logger";
import * as admin from "firebase-admin";
import { batchUpdateQuery } from "../shared/batch-update";
import { Collections } from "../shared/collections";

const db = admin.firestore();

/**
 * Runs weekly on Sundays at 4 AM. Deletes pending friend requests
 * older than 7 days.
 */
export const cleanupExpiredFriendRequests = onSchedule(
  { schedule: "0 4 * * 0", timeZone: "Europe/Stockholm" },
  async () => {
    logger.info("Starting expired friend request cleanup");

    const sevenDaysAgo = admin.firestore.Timestamp.fromDate(
      new Date(Date.now() - 7 * 24 * 60 * 60 * 1000)
    );

    try {
      const query = db
        .collection(Collections.friendRequests)
        .where("status", "==", "pending")
        .where("sentAt", "<", sevenDaysAgo);

      const totalExpired = await batchUpdateQuery(
        query,
        {
          status: "expired",
          expiredAt: admin.firestore.FieldValue.serverTimestamp(),
        },
        db
      );

      logger.info(
        `Expired ${totalExpired} friend requests older than 7 days`
      );

      // Log cleanup event
      await db.collection("system_events").add({
        type: "cleanup_expired_friend_requests",
        timestamp: admin.firestore.FieldValue.serverTimestamp(),
        details: { expiredCount: totalExpired },
      });
    } catch (error) {
      logger.error("Failed to cleanup expired friend requests:", error);
      throw error;
    }
  }
);
