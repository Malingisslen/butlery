/**
 * Correlate Notification Effectiveness
 *
 * Scheduled daily at 6 AM UTC. Checks notifications sent in the past 24h
 * to determine if users became active within 2 hours of receiving them.
 * Writes per-notification correlation data and a daily summary by type.
 *
 * Firestore writes:
 * /notification_effectiveness/{auto} — per-notification correlation
 * /notification_effectiveness_summary/{date} — daily aggregate by type
 */

import * as functions from "firebase-functions";
import * as admin from "firebase-admin";

const getDb = () => admin.firestore();

const MS_PER_HOUR = 60 * 60 * 1000;
const BATCH_LIMIT = 500;

interface TypeStats {
  sent: number;
  opened: number;
  rate: number;
}

export const correlateNotificationEffectiveness = functions
  .region("europe-west1")
  .pubsub.schedule("0 6 * * *")
  .timeZone("UTC")
  .onRun(async () => {
    const db = getDb();
    const now = admin.firestore.Timestamp.now();
    const nowMs = now.toMillis();
    const twentyFourHoursAgo = admin.firestore.Timestamp.fromMillis(
      nowMs - 24 * MS_PER_HOUR
    );

    functions.logger.info("Starting notification effectiveness correlation...");

    try {
      // Query notification_history from the past 24h
      const notificationsSnapshot = await db
        .collection("notification_history")
        .where("sentAt", ">=", twentyFourHoursAgo)
        .get();

      if (notificationsSnapshot.empty) {
        functions.logger.info("No notifications sent in the past 24 hours");
        return null;
      }

      const typeStats: Record<string, TypeStats> = {};
      let totalProcessed = 0;
      let batch = db.batch();
      let batchCount = 0;

      for (const notifDoc of notificationsSnapshot.docs) {
        const notifData = notifDoc.data();
        const userId = notifData.userId as string;
        const sentAt = notifData.sentAt as admin.firestore.Timestamp;
        const notifType = (notifData.type as string) || "unknown";

        if (!userId || !sentAt) {
          continue;
        }

        // Check if user was active within 2 hours after notification
        const userDoc = await db.collection("users").doc(userId).get();
        const userData = userDoc.data();
        const lastActiveAt = userData?.lastActiveAt as
          | admin.firestore.Timestamp
          | undefined;

        let wasOpened = false;
        let openedWithinHours: number | null = null;

        if (lastActiveAt) {
          const timeDiffMs = lastActiveAt.toMillis() - sentAt.toMillis();
          if (timeDiffMs >= 0 && timeDiffMs <= 2 * MS_PER_HOUR) {
            wasOpened = true;
            openedWithinHours = Math.round((timeDiffMs / MS_PER_HOUR) * 100) / 100;
          }
        }

        // Write correlation record
        const correlationRef = db.collection("notification_effectiveness").doc();
        batch.set(correlationRef, {
          notificationId: notifDoc.id,
          userId,
          type: notifType,
          sentAt,
          wasOpened,
          openedWithinHours,
          correlatedAt: now,
        });

        batchCount++;
        totalProcessed++;

        // Accumulate type stats
        if (!typeStats[notifType]) {
          typeStats[notifType] = { sent: 0, opened: 0, rate: 0 };
        }
        typeStats[notifType].sent++;
        if (wasOpened) {
          typeStats[notifType].opened++;
        }

        if (batchCount >= BATCH_LIMIT) {
          await batch.commit();
          batch = db.batch();
          batchCount = 0;
        }
      }

      // Compute rates
      for (const type of Object.keys(typeStats)) {
        const stats = typeStats[type];
        stats.rate =
          stats.sent > 0
            ? Math.round((stats.opened / stats.sent) * 10000) / 10000
            : 0;
      }

      // Write daily summary
      const dateStr = new Date(nowMs).toISOString().slice(0, 10);
      const summaryRef = db
        .collection("notification_effectiveness_summary")
        .doc(dateStr);
      batch.set(summaryRef, {
        date: dateStr,
        types: typeStats,
        totalProcessed,
        createdAt: now,
      });
      batchCount++;

      if (batchCount > 0) {
        await batch.commit();
      }

      functions.logger.info(
        `Notification correlation complete: ${totalProcessed} notifications processed, ` +
          `${Object.keys(typeStats).length} types summarized`
      );
    } catch (error) {
      functions.logger.error(
        "Failed to correlate notification effectiveness:",
        error
      );
    }

    return null;
  });
