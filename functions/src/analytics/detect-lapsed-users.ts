/**
 * Detect Lapsed Users
 *
 * Scheduled daily at 5 AM UTC. Identifies users who have been inactive
 * for 7, 14, or 30 days and writes win-back notifications.
 *
 * Firestore writes:
 * /lapsed_user_events/{auto} — lapsed user event record
 * /users/{userId}/notifications/{auto} — win-back notification
 */

import * as functions from "firebase-functions";
import * as admin from "firebase-admin";

const getDb = () => admin.firestore();

const MS_PER_HOUR = 60 * 60 * 1000;
const MS_PER_DAY = 24 * MS_PER_HOUR;
const BATCH_LIMIT = 500;

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

export const detectLapsedUsers = functions
  .region("europe-west1")
  .pubsub.schedule("0 5 * * *")
  .timeZone("UTC")
  .onRun(async () => {
    const db = getDb();
    const now = admin.firestore.Timestamp.now();
    const nowMs = now.toMillis();

    functions.logger.info("Starting lapsed user detection...");

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
          functions.logger.info(
            `No users lapsed at ${threshold.days} days`
          );
          continue;
        }

        let batch = db.batch();
        let batchCount = 0;
        let thresholdCount = 0;

        for (const userDoc of usersSnapshot.docs) {
          // Write lapsed user event
          const eventRef = db.collection("lapsed_user_events").doc();
          batch.set(eventRef, {
            userId: userDoc.id,
            daysInactive: threshold.days,
            detectedAt: now,
            notificationSent: false,
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

          // Update event to mark notification as sent
          batch.update(eventRef, { notificationSent: true });
          batchCount++;

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

        totalDetected += thresholdCount;
        functions.logger.info(
          `Detected ${thresholdCount} users lapsed at ${threshold.days} days`
        );
      }

      functions.logger.info(
        `Lapsed user detection complete: ${totalDetected} total events`
      );
    } catch (error) {
      functions.logger.error("Failed to detect lapsed users:", error);
    }

    return null;
  });
