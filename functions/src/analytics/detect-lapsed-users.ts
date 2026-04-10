/**
 * Detect Lapsed Users
 *
 * Scheduled daily at 5 AM UTC. Identifies users who have been inactive
 * for 7, 14, or 30 days and writes win-back notifications.
 *
 * Firestore writes:
 * /analytics/lapsed_users/events/{auto} — lapsed user event record
 * /users/{userId}/notifications/{auto} — win-back notification
 */

import { onSchedule } from "firebase-functions/v2/scheduler";
import { logger } from "firebase-functions/logger";
import * as admin from "firebase-admin";
import { sendPushToUser } from "../shared/fcm-tokens";
import { BATCH_LIMIT } from "../shared/batch-update";

const getDb = () => admin.firestore();

const MS_PER_HOUR = 60 * 60 * 1000;
const MS_PER_DAY = 24 * MS_PER_HOUR;

interface LapsedThreshold {
  days: number;
  message: string;
  type: string;
}

const THRESHOLDS: LapsedThreshold[] = [
  {
    days: 7,
    message: "Vi saknar dig! Kolla in vad som är nytt",
    type: "win_back_mild",
  },
  {
    days: 14,
    message: "Dina recept väntar på dig",
    type: "win_back_moderate",
  },
  {
    days: 30,
    message: "Det var länge sedan! Kom tillbaka",
    type: "win_back_strong",
  },
];

export const detectLapsedUsers = onSchedule(
  { schedule: "0 5 * * *", timeZone: "UTC" },
  async () => {
    const db = getDb();
    const now = admin.firestore.Timestamp.now();
    const nowMs = now.toMillis();

    logger.info("Starting lapsed user detection...");

    try {
      let totalDetected = 0;

      for (const threshold of THRESHOLDS) {
        const targetMs = nowMs - threshold.days * MS_PER_DAY;
        const windowStart = admin.firestore.Timestamp.fromMillis(
          targetMs - 12 * MS_PER_HOUR
        );
        const windowEnd = admin.firestore.Timestamp.fromMillis(
          targetMs + 12 * MS_PER_HOUR
        );

        const usersSnapshot = await db
          .collection("users")
          .where("lastActiveAt", ">=", windowStart)
          .where("lastActiveAt", "<=", windowEnd)
          .get();

        if (usersSnapshot.empty) {
          logger.info(
            `No users lapsed at ${threshold.days} days`
          );
          continue;
        }

        let batch = db.batch();
        let batchCount = 0;
        let thresholdCount = 0;
        const userIdsToNotify: string[] = [];

        for (const userDoc of usersSnapshot.docs) {
          // Write lapsed user event
          const eventRef = db.collection("analytics").doc("lapsed_users").collection("events").doc();
          batch.set(eventRef, {
            userId: userDoc.id,
            daysInactive: threshold.days,
            detectedAt: now,
            notificationSent: true,
          });
          batchCount++;

          // Write win-back notification
          const notificationRef = db
            .collection("users")
            .doc(userDoc.id)
            .collection("notifications")
            .doc();
          batch.set(notificationRef, {
            type: threshold.type,
            message: threshold.message,
            createdAt: now,
            read: false,
          });
          batchCount++;

          userIdsToNotify.push(userDoc.id);
          thresholdCount++;

          if (batchCount >= BATCH_LIMIT - 2) {
            // Leave room for 3 ops per user
            await batch.commit();
            batch = db.batch();
            batchCount = 0;
          }
        }

        if (batchCount > 0) {
          await batch.commit();
        }

        // Send FCM push notifications to lapsed users (concurrent batches of 10)
        let pushSuccessCount = 0;
        for (let i = 0; i < userIdsToNotify.length; i += 10) {
          const batch = userIdsToNotify.slice(i, i + 10);
          const results = await Promise.allSettled(
            batch.map((userId) =>
              sendPushToUser(
                userId,
                { title: "Butlery", body: threshold.message },
                { type: threshold.type }
              )
            )
          );
          for (const result of results) {
            if (result.status === "fulfilled" && result.value.successCount > 0) {
              pushSuccessCount++;
            }
          }
        }

        totalDetected += thresholdCount;
        logger.info(
          `Detected ${thresholdCount} users lapsed at ${threshold.days} days, ` +
          `${pushSuccessCount} push notifications delivered`
        );
      }

      logger.info(
        `Lapsed user detection complete: ${totalDetected} total events`
      );
    } catch (error) {
      logger.error("Failed to detect lapsed users:", error);
      throw error;
    }

  }
);
