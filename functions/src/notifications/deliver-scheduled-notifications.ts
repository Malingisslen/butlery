/**
 * Drainer for the delayed-notification queue (BUT-647).
 *
 * Runs every 5 minutes, picks up `scheduled_notifications` docs whose
 * `deliverAt` is past, sends each via the same FCM path as live pushes,
 * then flips `status` to `delivered`.
 *
 * Idempotency: a transaction reads the doc and, if still `pending`,
 * marks it `delivered`. A retry that picks up an already-delivered doc
 * is a no-op. We mark BEFORE the send, so a partial failure mid-batch
 * does not deliver twice. Pushes are at-most-once-ish anyway (FCM
 * doesn't promise exactly-once); a missed delivery here is acceptable.
 *
 * **Poison-pill protection (M1 fix)**: a permanently-failing FCM token
 * (expired, invalid recipient) would otherwise loop pending → delivered
 * → pending → ... forever. After `MAX_ATTEMPTS` rollback retries we
 * mark `status: "failed"` and stop, emitting a
 * `scheduled_notification_max_attempts_exceeded` analytics event so ops
 * sees the doc is parked.
 *
 * **Composite index required (H1)**: the driving query
 * `where('status', '==', 'pending').where('deliverAt', '<=', now)` is a
 * composite that needs an index in `firestore.indexes.json`. Missing
 * index ⇒ `FAILED_PRECONDITION` on first run.
 *
 * Scale: processes up to 200 due-notifications per run. At 5-min cadence
 * that's 2400/hour — comfortably above any realistic delayed-push rate
 * for our beta size.
 */

import { onSchedule } from "firebase-functions/v2/scheduler";
import { logger } from "firebase-functions/logger";
import * as admin from "firebase-admin";
import { sendPushToUserRespectingPreferences } from "../shared/preference-aware-push";
import { logAnalyticsEvent } from "../shared/analytics-server";

const MAX_PER_RUN = 200;
/** After this many delivery attempts a doc is parked at `failed`. */
export const MAX_ATTEMPTS = 5;

export interface DeliverDeps {
  db?: admin.firestore.Firestore;
  now?: Date;
  /** Test seam — defaults to the prefs-aware FCM helper. */
  send?: typeof sendPushToUserRespectingPreferences;
}

export interface DeliverResult {
  delivered: number;
  skipped: number;
  failed: number;
  parked: number;
  total: number;
}

export async function runDeliverScheduledNotifications(
  deps: DeliverDeps = {}
): Promise<DeliverResult> {
  const db = deps.db ?? admin.firestore();
  const now = deps.now ?? new Date();
  const send = deps.send ?? sendPushToUserRespectingPreferences;
  const nowTs = admin.firestore.Timestamp.fromDate(now);

  const dueSnap = await db
    .collection("scheduled_notifications")
    .where("status", "==", "pending")
    .where("deliverAt", "<=", nowTs)
    .limit(MAX_PER_RUN)
    .get();

  if (dueSnap.empty) {
    logger.info("deliver_scheduled_notifications: nothing due");
    return { delivered: 0, skipped: 0, failed: 0, parked: 0, total: 0 };
  }

  let delivered = 0;
  let skipped = 0;
  let failed = 0;
  let parked = 0;

  for (const doc of dueSnap.docs) {
    // Transaction-flip pending → delivered to claim the doc and bump
    // the attempt counter atomically. Returns the pre-increment attempt
    // count so the post-send rollback path can decide whether to park.
    const claimResult = await db.runTransaction(async (tx) => {
      const fresh = await tx.get(doc.ref);
      if (!fresh.exists) return null;
      const d = fresh.data() ?? {};
      if (d.status !== "pending") return null;
      const attemptsBefore = (d.attempts as number | undefined) ?? 0;
      tx.update(doc.ref, {
        status: "delivered",
        deliveredAt: admin.firestore.Timestamp.fromDate(now),
        attempts: attemptsBefore + 1,
      });
      return { attemptsBefore };
    });

    if (!claimResult) {
      skipped++;
      continue;
    }

    const data = doc.data() ?? {};
    const userId = data.userId as string | undefined;
    const notificationType = (data.notificationType as string | undefined) ?? "unknown";
    const payload = data.payload as
      | {
          title: string;
          body: string;
          data: Record<string, string>;
        }
      | undefined;

    if (!userId || !payload) {
      logger.warn("deliver_scheduled_notifications: malformed doc", {
        docId: doc.id,
      });
      // Park immediately — malformed docs will never succeed.
      await doc.ref.update({ status: "failed", failureReason: "malformed" });
      failed++;
      parked++;
      continue;
    }

    try {
      await send(
        userId,
        { title: payload.title, body: payload.body },
        "reEngagement",
        payload.data
      );
      delivered++;
    } catch (err) {
      // Already-incremented attempt count: the transaction above stamped
      // `attemptsBefore + 1`. We compare that against MAX_ATTEMPTS to
      // decide rollback-vs-park.
      const attemptsAfter = claimResult.attemptsBefore + 1;
      logger.error("deliver_scheduled_notifications: send failed", {
        docId: doc.id,
        userId,
        notificationType,
        attempts: attemptsAfter,
        err,
      });

      if (attemptsAfter >= MAX_ATTEMPTS) {
        // Park. No rollback to `pending` — leave at `failed` so the
        // drainer never picks this up again.
        await doc.ref.update({
          status: "failed",
          failureReason: "max_attempts_exceeded",
        });
        logAnalyticsEvent("scheduled_notification_max_attempts_exceeded", {
          userId,
          notificationType,
          attempts: attemptsAfter,
        });
        parked++;
      } else {
        // Roll back so a future run can retry. Attempt count stays
        // bumped — that's the loop guard.
        await doc.ref.update({ status: "pending" });
      }
      failed++;
    }
  }

  logger.info("deliver_scheduled_notifications: complete", {
    delivered,
    skipped,
    failed,
    parked,
    total: dueSnap.size,
  });

  return { delivered, skipped, failed, parked, total: dueSnap.size };
}

export const deliverScheduledNotifications = onSchedule(
  { schedule: "every 5 minutes", timeZone: "UTC" },
  async () => {
    await runDeliverScheduledNotifications();
  }
);
