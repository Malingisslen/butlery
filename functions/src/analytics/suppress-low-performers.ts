/**
 * Auto-suppress low-CTR notification types (BUT-645 phase 2).
 *
 * Runs weekly, Sunday 03:00 UTC. Per notification type computes:
 *   ctr = opened / sent
 * over the past 30 days. If `sent >= MIN_SENDS` and `ctr < CTR_THRESHOLD`,
 * flips the RC flag `notifications.enabled.<type>` to `false` so live
 * sends start short-circuiting on the per-type gate.
 *
 * Idempotency: re-checks the live RC state before flipping. An
 * already-disabled type is a no-op. A type that recovers (operator flips
 * the flag back true) is re-evaluated next run.
 *
 * Sources:
 *   - `notification_send_events` — written by every server-side push.
 *   - `notification_opened_events` — written by the client when the user
 *     taps a notification. (Server only reads; client wiring is out of
 *     scope for this task per the spec.)
 *
 * Both have 30-day TTLs so the aggregation window matches the data
 * retention window.
 */

import { onSchedule } from "firebase-functions/v2/scheduler";
import { logger } from "firebase-functions/logger";
import * as admin from "firebase-admin";
import { logAnalyticsEvent } from "../shared/analytics-server";
import {
  isNotificationTypeEnabled,
  setNotificationTypeEnabled,
} from "../shared/notification-rc-flags";

export const MIN_SENDS = 50;
export const CTR_THRESHOLD = 0.05;
const WINDOW_DAYS = 30;
const MS_PER_DAY = 24 * 60 * 60 * 1000;
// Page size for streaming the 30-day event collections. Each page is folded
// into per-type counters and discarded, so memory stays bounded no matter how
// many events the window holds.
const EVENTS_PAGE_SIZE = 1000;

interface TypeAgg {
  sent: number;
  opened: number;
}

/**
 * Streams a timestamped event collection and folds each doc's notificationType
 * into `agg` via `bump`. Pages with a cursor on the timestamp field (the range
 * field, so no composite index is needed); the timestamp stays in the
 * projection because the cursor reads it from each page's last document.
 */
async function aggregateByType(
  db: admin.firestore.Firestore,
  collection: string,
  timestampField: string,
  cutoff: admin.firestore.Timestamp,
  agg: Record<string, TypeAgg>,
  bump: (entry: TypeAgg) => void
): Promise<void> {
  const base = db
    .collection(collection)
    .where(timestampField, ">=", cutoff)
    .select("notificationType", timestampField)
    .orderBy(timestampField);

  let lastDoc: admin.firestore.QueryDocumentSnapshot | undefined;

  for (;;) {
    let page = base.limit(EVENTS_PAGE_SIZE);
    if (lastDoc) {
      page = page.startAfter(lastDoc);
    }
    const snap = await page.get();
    if (snap.empty) break;

    for (const doc of snap.docs) {
      const type = doc.data().notificationType as string | undefined;
      if (!type) continue;
      if (!agg[type]) agg[type] = { sent: 0, opened: 0 };
      bump(agg[type]);
    }

    lastDoc = snap.docs[snap.docs.length - 1];
    if (snap.size < EVENTS_PAGE_SIZE) break;
  }
}

export interface RunDeps {
  db?: admin.firestore.Firestore;
  now?: Date;
  /** Test seam — return a fake "is enabled?" decision per type. */
  isEnabled?: (type: string) => Promise<boolean>;
  /** Test seam — record the flag flip without hitting Admin SDK. */
  flipFlag?: (type: string, enabled: boolean) => Promise<void>;
}

export async function runSuppressLowPerformers(deps: RunDeps = {}): Promise<{
  evaluated: number;
  flipped: number;
}> {
  const db = deps.db ?? admin.firestore();
  const now = deps.now ?? new Date();
  const isEnabled =
    deps.isEnabled ?? ((type: string) => isNotificationTypeEnabled(type));
  const flipFlag =
    deps.flipFlag ??
    ((type: string, enabled: boolean) =>
      setNotificationTypeEnabled(type, enabled));

  const cutoff = admin.firestore.Timestamp.fromDate(
    new Date(now.getTime() - WINDOW_DAYS * MS_PER_DAY)
  );

  const agg: Record<string, TypeAgg> = {};

  // Aggregate sends.
  await aggregateByType(
    db,
    "notification_send_events",
    "sentAt",
    cutoff,
    agg,
    (entry) => entry.sent++
  );

  // Aggregate opens. Client writes `{userId, notificationType, openedAt}`.
  await aggregateByType(
    db,
    "notification_opened_events",
    "openedAt",
    cutoff,
    agg,
    (entry) => entry.opened++
  );

  let flipped = 0;
  let evaluated = 0;

  for (const [type, stats] of Object.entries(agg)) {
    if (stats.sent < MIN_SENDS) continue;
    evaluated++;
    const ctr = stats.opened / stats.sent;
    if (ctr >= CTR_THRESHOLD) continue;

    // Idempotency: if already disabled, skip. Logged at info so the run
    // is auditable.
    const stillEnabled = await isEnabled(type);
    if (!stillEnabled) {
      logger.info("auto_suppress_skip_already_disabled", {
        notificationType: type,
        sent: stats.sent,
        opened: stats.opened,
        ctr,
      });
      continue;
    }

    logger.warn("auto_suppress_flag_flip", {
      notificationType: type,
      sent: stats.sent,
      opened: stats.opened,
      ctr,
      action: "disabled",
    });
    await flipFlag(type, false);
    logAnalyticsEvent("notification_type_auto_suppressed", {
      notificationType: type,
      sent: stats.sent,
      opened: stats.opened,
      ctr,
    });
    flipped++;
  }

  logger.info("suppress_low_performers_complete", {
    typesEvaluated: evaluated,
    typesFlipped: flipped,
    windowDays: WINDOW_DAYS,
  });

  return { evaluated, flipped };
}

export const suppressLowPerformers = onSchedule(
  { schedule: "0 3 * * 0", timeZone: "UTC" },
  async () => {
    await runSuppressLowPerformers();
  }
);
