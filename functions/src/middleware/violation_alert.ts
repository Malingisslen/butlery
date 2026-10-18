/**
 * BUT-2138: an ops-log alert when one account is stopped by the rate limiter
 * over and over on the same day.
 *
 * Every denial already writes a `rate_limit_violation` row, but nothing reads
 * those rows, so a pattern could only be found by someone who already suspected
 * the account. This counts denials per account per UTC day and writes ONE
 * `system_events` row when the count reaches the threshold. Malin chose the
 * threshold, the window and "admin tab only" on 2026-10-18.
 *
 * Where the data lives, and why:
 * - The counter is `system_rate_limits/{uid}_violationCounter`. Being keyed
 *   `${uid}_` under `system_rate_limits` puts it under the 90-day
 *   `cleanupOldRateLimits` prune (on `updatedAt`), the account-deletion
 *   cascade's prefix sweep, with no new retention or erasure code.
 * - The alert row carries NO identifier, so it needs no retention or erasure
 *   path. Who crossed the threshold is found from the counters:
 *   `system_rate_limits` where `alertedDayKey == <dayKey>`, a single equality
 *   the automatic index serves.
 */

import * as admin from "firebase-admin";
import { logger } from "firebase-functions/logger";
import { hashUid } from "../shared/hash-uid";

export const ABUSE_ALERT_THRESHOLD = 20;

export const ABUSE_ALERT_EVENT_TYPE = "rate_limit_abuse_threshold_reached";

interface StoredViolationCounter {
  dayKey?: string;
  count?: number;
}

/**
 * Accounts already at the threshold today on this instance. Without it an
 * account hammering a denied path would keep buying a read per call after the
 * alert has gone out. Holds the day it was reached, so a new day counts again.
 */
const saturated = new Map<string, string>();

export function __resetViolationAlertCacheForTest(): void {
  saturated.clear();
}

/**
 * Count one denial and write the alert on the denial that reaches the
 * threshold.
 *
 * Never throws: a failure is logged and must not change the denial the caller
 * returns. One attempt only — contention on the counter comes from the same
 * account's own burst, and a retry would add latency to every denial in it for
 * a count that only has to reach a threshold.
 */
export async function recordViolation(
  db: admin.firestore.Firestore,
  userId: string,
  operationType: string,
  dayKey: string,
  now: Date = new Date()
): Promise<void> {
  if (saturated.get(userId) === dayKey) return;

  const counterRef = db
    .collection("system_rate_limits")
    .doc(`${userId}_violationCounter`);

  try {
    const outcome = await db.runTransaction(
      async (tx) => {
        const snap = await tx.get(counterRef);
        const stored = snap.exists
          ? (snap.data() as StoredViolationCounter)
          : undefined;
        const prior = stored?.dayKey === dayKey ? (stored.count ?? 0) : 0;
        if (prior >= ABUSE_ALERT_THRESHOLD) return "past" as const;

        const count = prior + 1;
        const crossed = count === ABUSE_ALERT_THRESHOLD;
        tx.set(
          counterRef,
          {
            dayKey,
            count,
            updatedAt: admin.firestore.Timestamp.fromDate(now),
            ...(crossed ? { alertedDayKey: dayKey } : {}),
          },
          { merge: true }
        );

        if (crossed) {
          tx.create(db.collection("system_events").doc(), {
            type: ABUSE_ALERT_EVENT_TYPE,
            severity: "critical",
            threshold: ABUSE_ALERT_THRESHOLD,
            dayKey,
            operationType,
            // The admin ops-log tab orders by `executedAt`; a row carrying
            // only `timestamp` never shows there.
            executedAt: admin.firestore.FieldValue.serverTimestamp(),
            timestamp: admin.firestore.FieldValue.serverTimestamp(),
          });
        }
        return crossed ? ("crossed" as const) : ("counted" as const);
      },
      { maxAttempts: 1 }
    );

    if (outcome === "crossed") {
      logger.warn(ABUSE_ALERT_EVENT_TYPE, {
        userIdHash: hashUid(userId),
        operationType,
      });
    }
    if (outcome !== "counted") saturated.set(userId, dayKey);
  } catch (error) {
    logger.warn("Failed to count rate limit violation:", error);
  }
}
