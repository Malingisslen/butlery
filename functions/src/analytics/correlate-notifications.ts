/**
 * Correlate Notification Effectiveness
 *
 * Runs daily as a task inside `dailyAnalytics` (see
 * `functions/src/scheduled/maintenance-dispatchers.ts`); it no longer owns a
 * Cloud Scheduler job of its own. Checks notifications sent in the past 24h to
 * determine if users became active within 2 hours of receiving them. Writes
 * per-notification correlation data and a daily summary by type.
 *
 * It reads `notification_history` and `users.lastActiveAt` only — NOT the daily
 * snapshot docs. It is ordered late in the chain out of caution, not because it
 * consumes a producer.
 *
 * Firestore writes:
 * /analytics/notifications/effectiveness/{auto} — per-notification correlation
 * /analytics/notifications/summary/{date} — daily aggregate by type
 */

import { logger } from "firebase-functions/logger";
import * as admin from "firebase-admin";

const getDb = () => admin.firestore();

/** Injection seam for tests — mirrors `RunDeps` in `daily-snapshots.ts`. */
export interface RunDeps {
  db?: admin.firestore.Firestore;
  now?: Date;
}

const MS_PER_HOUR = 60 * 60 * 1000;
const BATCH_LIMIT = 500;
// Page size for streaming the past-24h notification_history. Each page is
// processed end-to-end (fetch its users, write its correlations) and then
// discarded, so peak memory is one page rather than a full day of sends.
const PAGE_SIZE = 500;
// Max refs per Firestore getAll() call.
const GETALL_LIMIT = 100;

interface TypeStats {
  sent: number;
  opened: number;
  rate: number;
}

export async function runCorrelateNotificationEffectiveness(
  deps: RunDeps = {},
): Promise<void> {
  {
    const db = deps.db ?? getDb();
    const now =
      deps.now != null
        ? admin.firestore.Timestamp.fromMillis(deps.now.getTime())
        : admin.firestore.Timestamp.now();
    const nowMs = now.toMillis();
    const twentyFourHoursAgo = admin.firestore.Timestamp.fromMillis(
      nowMs - 24 * MS_PER_HOUR
    );

    logger.info("Starting notification effectiveness correlation...");

    try {
      // Stream notification_history from the past 24h, ordered by sentAt (the
      // range field, so the cursor needs only the automatic single-field
      // index). Each page is processed end-to-end and discarded.
      const base = db
        .collection("notification_history")
        .where("sentAt", ">=", twentyFourHoursAgo)
        .select("userId", "sentAt", "type")
        .orderBy("sentAt");

      const typeStats: Record<string, TypeStats> = {};
      let totalProcessed = 0;
      let anyNotifications = false;
      let lastDoc: admin.firestore.QueryDocumentSnapshot | undefined;

      for (;;) {
        let pageQuery = base.limit(PAGE_SIZE);
        if (lastDoc) {
          pageQuery = pageQuery.startAfter(lastDoc);
        }
        const page = await pageQuery.get();
        if (page.empty) break;
        anyNotifications = true;

        // Batch-fetch only this page's referenced users to avoid N+1 queries.
        const pageUserIds = [
          ...new Set(
            page.docs.map((d) => d.data().userId as string).filter(Boolean)
          ),
        ];
        const userMap = new Map<string, FirebaseFirestore.DocumentData>();
        for (let i = 0; i < pageUserIds.length; i += GETALL_LIMIT) {
          const chunk = pageUserIds
            .slice(i, i + GETALL_LIMIT)
            .map((id) => db.collection("users").doc(id));
          // Only lastActiveAt is consumed below — fetch just that field
          // (data-minimization; avoids pulling email/fcmToken/prefs into memory).
          const userDocs = await db.getAll(...chunk, {
            fieldMask: ["lastActiveAt"],
          });
          for (const doc of userDocs) {
            if (doc.exists) {
              userMap.set(doc.id, doc.data()!);
            }
          }
        }

        let batch = db.batch();
        let batchCount = 0;

        for (const notifDoc of page.docs) {
          const notifData = notifDoc.data();
          const userId = notifData.userId as string;
          const sentAt = notifData.sentAt as admin.firestore.Timestamp;
          const notifType = (notifData.type as string) || "unknown";

          if (!userId || !sentAt) {
            continue;
          }

          // Look up user from this page's pre-fetched map
          const userData = userMap.get(userId);
          const lastActiveAt = userData?.lastActiveAt as
            | admin.firestore.Timestamp
            | undefined;

          let wasOpened = false;
          let openedWithinHours: number | null = null;

          if (lastActiveAt) {
            const timeDiffMs = lastActiveAt.toMillis() - sentAt.toMillis();
            if (timeDiffMs >= 0 && timeDiffMs <= 2 * MS_PER_HOUR) {
              wasOpened = true;
              openedWithinHours =
                Math.round((timeDiffMs / MS_PER_HOUR) * 100) / 100;
            }
          }

          // Write correlation record, keyed by the notification it describes.
          //
          // An auto-id here made the task non-idempotent, and moving it into a
          // dispatcher chain made that reachable without a hand re-fire: the
          // 24h window ends at `now`, and `now` is 06:00 plus the runtime of
          // nine preceding tasks rather than a fixed hour. A longer chain
          // re-processes the overlap into duplicate rows; a shorter one drops
          // the gap. A deterministic id makes the re-processing a harmless
          // overwrite. `notificationId` is already the first payload field, so
          // the id carries nothing the row did not already state.
          const correlationRef = db
            .collection("analytics")
            .doc("notifications")
            .collection("effectiveness")
            .doc(notifDoc.id);
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

        if (batchCount > 0) {
          await batch.commit();
        }

        lastDoc = page.docs[page.docs.length - 1];
        if (page.size < PAGE_SIZE) break;
      }

      if (!anyNotifications) {
        logger.info("No notifications sent in the past 24 hours");
        return;
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
        .collection("analytics")
        .doc("notifications")
        .collection("summary")
        .doc(dateStr);
      await summaryRef.set({
        date: dateStr,
        types: typeStats,
        totalProcessed,
        createdAt: now,
      });

      logger.info(
        `Notification correlation complete: ${totalProcessed} notifications processed, ` +
          `${Object.keys(typeStats).length} types summarized`
      );
    } catch (error) {
      logger.error(
        "Failed to correlate notification effectiveness:",
        error
      );
      throw error;
    }

  }
}
