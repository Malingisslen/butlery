/**
 * Track Day-N Retention (BUT-605 extends BUT prior).
 *
 * Scheduled daily at 4 AM UTC. For each user, computes days since signup
 * and writes a retention event when the user hits day 1, 7, 14, 30, 90,
 * or 180. Each event is sliced by `lifecycleStage` so cohort dashboards
 * can filter `new_/activated/habitual/dormant/churned`.
 *
 * Firestore writes:
 *   /analytics/retention/events/{userId}_d{N}
 *     — { userId, day, timestamp, wasActive, lifecycleStage }
 *
 * Idempotency: deterministic doc id `<userId>_d<day>` + `set()` (latest
 * wins). A re-run on the same UTC day overwrites the same path rather
 * than producing duplicate auto-id rows. Mirrors the BUT-638 north-star
 * convention.
 *
 * Lifecycle stage is computed from the user doc's `joinedAt` +
 * `lastActiveAt` fields using the same rule order as
 * `lib/services/analytics/lifecycle_stage_classifier.dart`. Server side
 * we don't have an exact "cooks last 14 days" count without an N+1
 * query against `activity_events`, so the server-side rule degrades
 * `habitual` to `activated/new_` based on recency only — that's
 * acceptable because dashboards aggregate at cohort level and the
 * recency-dominated rules (`churned`/`dormant`) are the ones that
 * drive re-engagement filtering.
 */

import { onSchedule } from "firebase-functions/v2/scheduler";
import { logger } from "firebase-functions/logger";
import * as admin from "firebase-admin";

const RETENTION_DAYS = [1, 7, 14, 30, 90, 180] as const;
const MS_PER_DAY = 24 * 60 * 60 * 1000;
const BATCH_LIMIT = 500;
const PAGE_SIZE = 500;

export type RetentionDay = (typeof RETENTION_DAYS)[number];

/** Mirror of LifecycleStage.wireValue in the Dart classifier. */
export type LifecycleStage =
  | "new"
  | "activated"
  | "habitual"
  | "dormant"
  | "churned";

/**
 * Server-side lifecycle classifier. Recency-first, mirrors the Dart
 * classifier's priority order. Inputs are millisecond timestamps
 * (or null) so the function is pure / unit-testable.
 *
 * Differs from the Dart side: no `cooksLast14Days` input. We can't
 * cheaply count cook events per user inside a daily aggregator, so we
 * approximate `habitual` by "active within 7 days AND signed up >7
 * days ago" — captures the "returning, not just new" intent without
 * an N+1.
 */
export function classifyLifecycleStageServer(args: {
  joinedAtMs: number | null;
  lastActiveAtMs: number | null;
  nowMs: number;
}): LifecycleStage {
  const { joinedAtMs, lastActiveAtMs, nowMs } = args;
  if (joinedAtMs == null) return "new";

  const msSinceSignup = nowMs - joinedAtMs;
  // Floored days are kept ONLY for the 7-day habitual/activated proxy below
  // (server-specific, unchanged). The churned/dormant boundaries use full ms.
  const daysSinceSignup = Math.floor(msSinceSignup / MS_PER_DAY);

  if (lastActiveAtMs != null) {
    const msSinceActive = nowMs - lastActiveAtMs;
    // BUT-1586 (mirrors client BUT-1550): compare full milliseconds, not
    // floored days. `Math.floor` truncates toward zero, collapsing the
    // [30d,31d) window onto day-30 so a churned user (elapsed >30d, <31d) was
    // misclassified as dormant — and the app-emitted `lifecycle_stage` (fixed
    // in BUT-1550) then disagreed with this server event in that window.
    if (msSinceActive > 30 * MS_PER_DAY) return "churned";
    if (msSinceActive >= 14 * MS_PER_DAY) return "dormant";
    // Recent activity. 7-day habitual/activated proxy is server-specific (the
    // Dart classifier uses cooksLast14Days instead) and NOT part of the
    // BUT-1550 mirror, so its floored-day semantics are left exactly as-is.
    const daysSinceActive = Math.floor(msSinceActive / MS_PER_DAY);
    if (daysSinceSignup > 7 && daysSinceActive <= 7) return "habitual";
    if (daysSinceSignup <= 7) return "activated";
    return "activated";
  }

  // Never active — only signup date informs the stage. Same ms comparison.
  if (msSinceSignup > 30 * MS_PER_DAY) return "churned";
  if (msSinceSignup >= 14 * MS_PER_DAY) return "dormant";
  return "new";
}

export interface RunDeps {
  db?: admin.firestore.Firestore;
  now?: Date;
}

const getDb = () => admin.firestore();

/**
 * Test-seam entrypoint. Production schedule wrapper just calls
 * `runTrackRetention()` with no overrides; tests pass `{db, now}` to
 * pin time and inject a fake Firestore.
 */
export async function runTrackRetention(deps: RunDeps = {}): Promise<{
  processedUsers: number;
  eventsWritten: number;
}> {
  const db = deps.db ?? getDb();
  const now =
    deps.now != null
      ? admin.firestore.Timestamp.fromDate(deps.now)
      : admin.firestore.Timestamp.now();
  const nowMs = now.toMillis();

  logger.info("track_retention_start", { days: RETENTION_DAYS });

  let processedUsers = 0;
  let eventsWritten = 0;
  let batch = db.batch();
  let batchCount = 0;

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
      const lastActiveAt = data.lastActiveAt as
        | admin.firestore.Timestamp
        | undefined;

      if (!joinedAt || !lastActiveAt) {
        continue;
      }

      const daysSinceSignup = Math.floor(
        (nowMs - joinedAt.toMillis()) / MS_PER_DAY
      );

      const matchedDay = RETENTION_DAYS.find((d) => d === daysSinceSignup);
      if (matchedDay === undefined) {
        continue;
      }

      const wasActiveWithin24h =
        nowMs - lastActiveAt.toMillis() < MS_PER_DAY;

      const lifecycleStage = classifyLifecycleStageServer({
        joinedAtMs: joinedAt.toMillis(),
        lastActiveAtMs: lastActiveAt.toMillis(),
        nowMs,
      });

      // Deterministic id: re-run on same UTC day overwrites instead of
      // duplicating. The day bucket is part of the id so a single user
      // can have multiple events across the lifecycle (D1, D7, ... D180).
      const eventId = `${userDoc.id}_d${matchedDay}`;
      const eventRef = db
        .collection("analytics")
        .doc("retention")
        .collection("events")
        .doc(eventId);
      batch.set(eventRef, {
        userId: userDoc.id,
        day: matchedDay,
        timestamp: now,
        wasActive: wasActiveWithin24h,
        lifecycleStage,
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

  logger.info("track_retention_complete", {
    processedUsers,
    eventsWritten,
  });

  return { processedUsers, eventsWritten };
}

export const trackDayNRetention = onSchedule(
  { schedule: "0 4 * * *", timeZone: "UTC" },
  async () => {
    try {
      await runTrackRetention();
    } catch (error) {
      logger.error("track_retention_failed", { err: error });
      throw error;
    }
  }
);
