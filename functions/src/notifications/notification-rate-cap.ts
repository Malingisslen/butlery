/**
 * Global per-user push notification rate cap.
 *
 * Tracks send-counts in `users/{uid}/notificationCounters/{YYYY-MM-DD}`
 * and rejects further sends once the cap is hit. Caps are read from
 * Remote Config / process env so they can be tuned without a redeploy:
 *
 *   - PUSH_CAP_TOTAL_PER_24H        (default 10)
 *   - PUSH_CAP_NONCRITICAL_PER_24H  (default 5)
 *
 * Critical notifications (admin moderation, account-security alerts) bypass
 * the non-critical cap but still count against the total cap. The total
 * cap is the hard fatigue ceiling — friends comments + menu reminders +
 * win-back combined cannot exceed it.
 *
 * The increment + cap-check is a single Firestore transaction so concurrent
 * notification triggers don't race past the cap.
 */

import { logger } from "firebase-functions/logger";
import * as admin from "firebase-admin";

export const DEFAULT_TOTAL_CAP = 10;
export const DEFAULT_NONCRITICAL_CAP = 5;

export type Priority = "critical" | "noncritical";

export interface RateCapResult {
  allowed: boolean;
  count: number;
  cap: number;
  reason: "ok" | "total_cap" | "noncritical_cap";
}

interface CountersDoc {
  count?: number;
  criticalCount?: number;
}

/** Resolves caps from process env with defensive defaults. */
export function readCaps(env: NodeJS.ProcessEnv = process.env): {
  total: number;
  noncritical: number;
} {
  const total = Number(env.PUSH_CAP_TOTAL_PER_24H ?? DEFAULT_TOTAL_CAP);
  const noncritical = Number(
    env.PUSH_CAP_NONCRITICAL_PER_24H ?? DEFAULT_NONCRITICAL_CAP,
  );
  return {
    total: Number.isFinite(total) && total > 0 ? total : DEFAULT_TOTAL_CAP,
    noncritical:
      Number.isFinite(noncritical) && noncritical > 0
        ? noncritical
        : DEFAULT_NONCRITICAL_CAP,
  };
}

/** Pure decision helper, exported for unit tests. */
export function evaluateCap(args: {
  totalCount: number;
  noncriticalCount: number;
  priority: Priority;
  caps: { total: number; noncritical: number };
}): RateCapResult {
  const { totalCount, noncriticalCount, priority, caps } = args;
  if (totalCount >= caps.total) {
    return {
      allowed: false,
      count: totalCount,
      cap: caps.total,
      reason: "total_cap",
    };
  }
  if (priority === "noncritical" && noncriticalCount >= caps.noncritical) {
    return {
      allowed: false,
      count: noncriticalCount,
      cap: caps.noncritical,
      reason: "noncritical_cap",
    };
  }
  return {
    allowed: true,
    count: totalCount,
    cap: caps.total,
    reason: "ok",
  };
}

function dayKey(now: Date): string {
  const yyyy = now.getUTCFullYear();
  const mm = String(now.getUTCMonth() + 1).padStart(2, "0");
  const dd = String(now.getUTCDate()).padStart(2, "0");
  return `${yyyy}-${mm}-${dd}`;
}

/** Lazy admin SDK accessor — keeps the module import-safe in unit tests. */
function db(): admin.firestore.Firestore {
  return admin.firestore();
}

/**
 * Atomically check + increment the per-user counter. If the cap is hit,
 * the counter is NOT incremented and `allowed: false` is returned.
 *
 * `priority` defaults to "noncritical" because the vast majority of
 * notifications (friend comments, win-back, digests) are non-critical;
 * callers must explicitly opt into critical for moderation / security.
 */
export async function checkAndIncrement(args: {
  userId: string;
  priority?: Priority;
  now?: Date;
  caps?: { total: number; noncritical: number };
}): Promise<RateCapResult> {
  const userId = args.userId;
  const priority: Priority = args.priority ?? "noncritical";
  const now = args.now ?? new Date();
  const caps = args.caps ?? readCaps();

  const counterRef = db()
    .collection("users")
    .doc(userId)
    .collection("notificationCounters")
    .doc(dayKey(now));

  return await db().runTransaction(async (tx) => {
    const snap = await tx.get(counterRef);
    const data: CountersDoc = (snap.exists ? snap.data() : {}) ?? {};
    const totalCount = data.count ?? 0;
    const criticalCount = data.criticalCount ?? 0;
    const noncriticalCount = totalCount - criticalCount;

    const decision = evaluateCap({
      totalCount,
      noncriticalCount,
      priority,
      caps,
    });

    if (!decision.allowed) {
      logger.warn(
        `[notification-rate-cap] Capped ${priority} push to ${userId}: ` +
          `count=${totalCount}/${caps.total}, ` +
          `noncritical=${noncriticalCount}/${caps.noncritical}, ` +
          `reason=${decision.reason}`,
      );
      return decision;
    }

    tx.set(
      counterRef,
      {
        count: admin.firestore.FieldValue.increment(1),
        criticalCount: admin.firestore.FieldValue.increment(
          priority === "critical" ? 1 : 0,
        ),
        lastUpdated: admin.firestore.FieldValue.serverTimestamp(),
      },
      { merge: true },
    );

    return decision;
  });
}
