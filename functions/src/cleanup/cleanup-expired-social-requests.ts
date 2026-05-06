/**
 * I5: Clean up expired social requests.
 *
 * Social requests (renamed from friend_requests in BUT-761; CF refs migrated
 * in BUT-772) have a 7-day expiry matching the isExpired getter on the
 * SocialRequest model. This scheduled function expires requests that have
 * been pending for more than 7 days.
 */

import { onSchedule } from "firebase-functions/v2/scheduler";
import { logger } from "firebase-functions/logger";
import * as admin from "firebase-admin";
import { batchUpdateQuery } from "../shared/batch-update";
import { Collections } from "../shared/collections";

const db = admin.firestore();

/**
 * Runs weekly on Sundays at 4 AM. Marks pending social requests
 * older than 7 days as expired.
 */
export const cleanupExpiredSocialRequests = onSchedule(
  { schedule: "0 4 * * 0", timeZone: "Europe/Stockholm" },
  async () => {
    logger.info("Starting expired social request cleanup");

    const sevenDaysAgo = admin.firestore.Timestamp.fromDate(
      new Date(Date.now() - 7 * 24 * 60 * 60 * 1000)
    );

    try {
      const query = db
        .collection(Collections.socialRequests)
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
        `Expired ${totalExpired} social requests older than 7 days`
      );

      // Log cleanup event
      await db.collection("system_events").add({
        type: "cleanup_expired_social_requests",
        timestamp: admin.firestore.FieldValue.serverTimestamp(),
        details: { expiredCount: totalExpired },
      });
    } catch (error) {
      logger.error("Failed to cleanup expired social requests:", error);
      throw error;
    }
  }
);
