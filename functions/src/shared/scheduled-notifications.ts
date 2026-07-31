/**
 * Delayed-notification queue (BUT-647).
 *
 * **Architectural deviation from spec**: the spec proposed Cloud Tasks for
 * delaying high-importance pushes past quiet hours. Two reasons we picked
 * a Firestore-backed queue instead:
 *
 *   1. No existing Cloud Tasks usage in `functions/src/` — adopting it
 *      means a new top-level dep (`@google-cloud/tasks`), an IAM role
 *      (`Cloud Tasks Enqueuer`), a queue resource to manage in
 *      `firebase.json`, and a separate HTTP receiver function. That's a
 *      lot of surface area for a feature that fires a few hundred times
 *      a night.
 *   2. At our beta scale (≤ a few hundred delayed pushes/night) a
 *      Firestore queue drained by a 5-min scheduler is cheaper and
 *      simpler. Pub/Sub-driven scheduler runs ~288 invocations/day; each
 *      invocation reads ~ten docs and writes a few. Comfortably below
 *      free-tier.
 *
 * If volume grows past ~10k delayed pushes/night, swap this for Cloud
 * Tasks (a single file, replacing `enqueueScheduledNotification` and
 * deleting `deliverScheduledNotifications`).
 *
 * Storage: `scheduled_notifications/{auto}` with shape:
 *   {
 *     userId: string,
 *     notificationType: string,
 *     deliverAt: Timestamp,
 *     payload: {                    // mirrors NotificationRequest shape
 *       title: string,
 *       body: string,
 *       data: Record<string, string>,
 *     },
 *     status: "pending" | "delivered" | "failed",
 *     createdAt: Timestamp,
 *     deliveredAt?: Timestamp,
 *     failureReason?: string,
 *     attempts: number,
 *     expireAt: Timestamp,          // GDPR/PII retention — see below.
 *   }
 *
 * **PII retention (C2 fix)**: `payload.title` / `payload.body` carry
 * user-visible strings — comment snippets, recipe titles, friend
 * display names — i.e. PII. We stamp every doc with
 * `expireAt = createdAt + 7 days` and rely on Firestore's TTL policy
 * to auto-delete past that. 7d covers worst-case retry headroom
 * (5 attempts × 5-min cadence = 25 min) plus generous slack.
 *
 * **TTL policy (BUT-1699, 2026-07-31)**: DECLARED in
 * `firestore.indexes.json` as a `fieldOverrides` entry with
 * `"ttl": true` on `expireAt`, and pinned by
 * `src/__tests__/firestore-ttl-policies.test.ts`. It is applied by
 * `firebase deploy --only firestore:indexes`.
 *
 * This comment previously said the policy needed a manual one-off
 * gcloud command. It was never run, so docs DID accumulate forever —
 * from the day this shipped until 2026-07-31. That matters more here
 * than for its sibling: `payload` carries notification title and body,
 * i.e. comment snippets, recipe titles and friends' display names.
 *
 * Declaring is not activating: Firestore offers no round-trip, so
 * nothing in this repo can prove the policy is live. After a deploy,
 * confirm with `gcloud firestore fields ttls list`. `on-user-deleted.ts`
 * still cascades on account deletion; this is the passive expiry for
 * the tombstone-after-delivery case and for still-active accounts.
 *
 * Idempotency: drainer flips `status` from `pending` → `delivered` via
 * a transaction. A retry that re-runs the drainer skips already-delivered
 * docs. The send itself isn't transactionally tied to the status flip
 * (FCM is an external service) — the at-most-once contract is "we won't
 * deliver twice for the same scheduled doc" which the status flip
 * guarantees as long as the drainer always flips BEFORE sending. We do
 * the opposite (flip AFTER successful send) so a transient FCM error
 * triggers retry; the at-least-once trade-off is acceptable for pushes
 * (the platform itself doesn't promise exactly-once).
 */

import { logger } from "firebase-functions/logger";
import * as admin from "firebase-admin";

const TTL_DAYS = 7;
const MS_PER_DAY = 24 * 60 * 60 * 1000;

export interface ScheduledNotificationPayload {
  title: string;
  body: string;
  data: Record<string, string>;
}

export interface EnqueueScheduledNotificationOpts {
  userId: string;
  notificationType: string;
  deliverAt: Date;
  payload: ScheduledNotificationPayload;
  /** Test seam. */
  db?: admin.firestore.Firestore;
}

/**
 * Writes a pending scheduled-notification doc. Returns the doc id so
 * callers can correlate logs.
 */
export async function enqueueScheduledNotification(
  opts: EnqueueScheduledNotificationOpts
): Promise<string> {
  const db = opts.db ?? admin.firestore();
  const ref = db.collection("scheduled_notifications").doc();
  // 7-day TTL anchored to `now` rather than `deliverAt`. Drainer parks
  // permanently-failing docs at status=failed; passive TTL ensures they
  // don't accumulate even if no operator ever reviews the failed list.
  const expireAt = new Date(Date.now() + TTL_DAYS * MS_PER_DAY);
  await ref.set({
    userId: opts.userId,
    notificationType: opts.notificationType,
    deliverAt: admin.firestore.Timestamp.fromDate(opts.deliverAt),
    payload: opts.payload,
    status: "pending",
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
    attempts: 0,
    expireAt: admin.firestore.Timestamp.fromDate(expireAt),
  });
  logger.info("scheduled_notification_enqueued", {
    userId: opts.userId,
    notificationType: opts.notificationType,
    deliverAtIso: opts.deliverAt.toISOString(),
    docId: ref.id,
  });
  return ref.id;
}
