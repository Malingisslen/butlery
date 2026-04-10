/**
 * Track Day-N Retention
 *
 * Scheduled daily at 4 AM UTC. For each user, computes days since signup
 * and writes a retention event if the user hits day 1, 7, or 30.
 *
 * Firestore writes:
 * /analytics/retention/events/{auto} — {userId, day, timestamp, wasActive}
 */

import { onSchedule } from "firebase-functions/v2/scheduler";
import { logger } from "firebase-functions/logger";
import * as admin from "firebase-admin";

const getDb = () => admin.firestore();

const RETENTION_DAYS = [1, 7, 30];
const MS_PER_DAY = 24 * 60 * 60 * 1000;
const BATCH_LIMIT = 500;

export const trackDayNRetention = onSchedule(
  { schedule: "0 4 * * *", timeZone: "UTC" },
  async () => {
    const db = getDb();
    const now = admin.firestore.Timestamp.now();
    const nowMs = now.toMillis();

    logger.info("Starting day-N retention tracking...");

    try {
      let processedUsers = 0;
      let eventsWritten = 0;
      let batch = db.batch();
      let batchCount = 0;

      const PAGE_SIZE = 500;
      let query = db
        .collection("users")
        .where("lastActiveAt", "!=", null)
        .orderBy("lastActiveAt")
        .limit(PAGE_SIZE);
      let usersSnapshot = await query.get();

      while (usersSnapshot.size > 0) {
        for (const userDoc of usersSnapshot.docs) {
          const data = userDoc.data();
          const joinedAt = data.joinedAt as admin.firestore.Timestamp | undefined;
          const lastActiveAt = data.lastActiveAt as admin.firestore.Timestamp | undefined;

          if (!joinedAt || !lastActiveAt) {
            continue;
          }

          const daysSinceSignup = Math.floor(
            (nowMs - joinedAt.toMillis()) / MS_PER_DAY
          );

          if (!RETENTION_DAYS.includes(daysSinceSignup)) {
            continue;
          }

          const wasActiveWithin24h =
            nowMs - lastActiveAt.toMillis() < MS_PER_DAY;

          const eventRef = db.collection("analytics").doc("retention").collection("events").doc();
          batch.set(eventRef, {
            userId: userDoc.id,
            day: daysSinceSignup,
            timestamp: now,
            wasActive: wasActiveWithin24h,
          });

          batchCount++;
          eventsWritten++;

          if (batchCount >= BATCH_LIMIT) {
            await batch.commit();
            batch = db.batch();
            batchCount = 0;
          }

          processedUsers++;
        }

        const lastDoc = usersSnapshot.docs[usersSnapshot.docs.length - 1];
        usersSnapshot = await query.startAfter(lastDoc).get();
      }

      if (batchCount > 0) {
        await batch.commit();
      }

      logger.info(
        `Processed ${processedUsers} users, wrote ${eventsWritten} retention events`
      );
    } catch (error) {
      logger.error("Failed to track retention:", error);
      throw error;
    }

  }
);
