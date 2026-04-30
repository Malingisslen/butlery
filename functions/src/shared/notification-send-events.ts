/**
 * Notification send-events stream (BUT-645).
 *
 * Every server-side push attempt logs a row here. Used by:
 *   - `suppressLowPerformers` (weekly aggregator) to compute per-type CTR.
 *   - Ad-hoc BigQuery analysis (export already covers this collection).
 *
 * 30-day TTL via Firestore TTL policy on `expireAt` field. Schema:
 *   {
 *     userId: string,
 *     notificationType: string,
 *     sentAt: Timestamp,
 *     channel: "fcm" | "scheduled_queue",
 *     expireAt: Timestamp,        // sentAt + 30 days
 *   }
 *
 * **Manual setup required (one-shot, per environment)**: the TTL
 * policy itself is configured in the GCP console (or via gcloud):
 *   `gcloud firestore fields ttls update expireAt \
 *      --collection-group=notification_send_events --enable-ttl`
 * This module guarantees `expireAt` is written, but the policy that
 * actually deletes expired docs has to be enabled separately. GDPR
 * cascade on account deletion is handled by `on-user-deleted.ts`.
 */

import { logger } from "firebase-functions/logger";
import * as admin from "firebase-admin";

const TTL_DAYS = 30;
const MS_PER_DAY = 24 * 60 * 60 * 1000;

export type NotificationChannel = "fcm" | "scheduled_queue";

export interface NotificationSendEventOpts {
  userId: string;
  notificationType: string;
  channel: NotificationChannel;
  /** Test seam. */
  db?: admin.firestore.Firestore;
  /** Test seam. */
  now?: Date;
}

/**
 * Best-effort write — failures here do NOT block the actual push send.
 * Logged at warn so analytics gaps are visible.
 */
export async function recordNotificationSendEvent(
  opts: NotificationSendEventOpts
): Promise<void> {
  const db = opts.db ?? admin.firestore();
  const now = opts.now ?? new Date();
  const expireAt = new Date(now.getTime() + TTL_DAYS * MS_PER_DAY);
  try {
    await db.collection("notification_send_events").add({
      userId: opts.userId,
      notificationType: opts.notificationType,
      sentAt: admin.firestore.Timestamp.fromDate(now),
      channel: opts.channel,
      expireAt: admin.firestore.Timestamp.fromDate(expireAt),
    });
  } catch (err) {
    logger.warn("recordNotificationSendEvent failed (non-fatal)", {
      userId: opts.userId,
      notificationType: opts.notificationType,
      err,
    });
  }
}
