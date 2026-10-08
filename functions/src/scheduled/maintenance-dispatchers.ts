/**
 * Maintenance dispatchers — one Cloud Scheduler job per CHAIN, not per job.
 *
 * Cloud Scheduler bills ~$0.10 per job per month (3 free per BILLING ACCOUNT,
 * shared across every project) regardless of how often it fires. Frequency is
 * therefore cost-neutral and only the JOB COUNT matters. Butlery had 26
 * `onSchedule` functions ≈ 24 kr/month; the analytics half of those is merged
 * here into three, and the run-seams they call are unchanged.
 *
 * STANDING RULE FOR THIS FILE — it is a composition root, exactly like
 * `index.ts` and the DI modules. A `MaintenanceTask` entry is
 * `{ name, run, timeoutMs }` and NOTHING ELSE. No inline queries, no shared db
 * handles beyond `deps`, no "while we're here" logic. The moment a task body
 * lives in this file it becomes a god-function. New maintenance work is added
 * as a task in an existing chain by default; a standalone `onSchedule` only
 * when frequency or failure-isolation genuinely requires it.
 *
 * SPLIT RULE: if this file passes 400 lines, split the registries from
 * `runTaskChain` into two files. Do not reach for ACCEPTED_LARGE_FILES.md.
 *
 * The cleanup/purge jobs are deliberately NOT here. They carry GDPR
 * retention guarantees, two currently-inert 8-minute self-budgets that a
 * shared chain would un-cap, and weekday moves that would perturb the `ops`
 * anomaly series — that merge is its own piece of work.
 */

import { onSchedule } from "firebase-functions/v2/scheduler";
import { logger } from "firebase-functions/logger";
import {
  runTaskChain,
  MaintenanceTask,
  CHAIN_TIMEOUT_SECONDS,
  TASK_TIMEOUT_MS,
} from "./task-chain";

import {
  runImportHealthSnapshot,
  runRecipeMethodSnapshot,
  runParsingCorrectionsSnapshot,
  runOpsSnapshot,
  runFeedbackSnapshot,
} from "../analytics/daily-snapshots";
import { runTrackRetention } from "../analytics/track-retention";
import { runComputeFeatureRetention } from "../analytics/compute-feature-retention";
import { runDetectLapsedUsers } from "../analytics/detect-lapsed-users";
import { runCorrelateNotificationEffectiveness } from "../analytics/correlate-notifications";
import { runDetectAnomalies } from "../analytics/detect-anomalies";
import { runWeeklyActivityDigest } from "../analytics/send-activity-digest";
import { runReconcileBlockMirrors } from "../social/sync-block-mirror";
import { runSweepErasureHolds } from "../moderation/erasure-hold";
import { runSweepRetainedReporterReports } from "../moderation/reporter-retention";
import { runNorthStarWeekly } from "../scheduled/north-star-weekly";
import { runImportTierWeekly } from "../analytics/import-tier-weekly";
import { drainRatingAggregationQueue } from "../ratings/rating-aggregation";
import { drainPoolAggregationQueue } from "../ratings/pool-aggregation";
import { updateRecipeRatingStats } from "../ratings/update-recipe-rating-stats";
import { updatePooledRatingStats } from "../ratings/update-pooled-rating-stats";

/**
 * Daily analytics chain, 06:00 UTC.
 *
 * Order is load-bearing and pinned by
 * `__tests__/maintenance-dispatchers.test.ts`:
 *   1. The four non-ops snapshots produce what `detectAnomalies` consumes, so
 *      it runs LAST (`cloud-functions-specialist.knowledge.md:826-828` — a
 *      consumer runs strictly after its producer's slowest run and SKIPS on a
 *      missing producer doc, which `runDetectAnomalies` already implements).
 *   2. `opsSnapshot` reads `system_events` for the current UTC day and the
 *      cleanup jobs that write there still hold their own schedules. The
 *      latest on any day is `purgeExpiredAuditLogs` at 05:00 Sunday (the rest
 *      are ≤ 04:00, including `cleanupDeletedIngredients` on Monday) — hence
 *      the 06:00 chain start rather than anything earlier.
 *
 * `correlateNotificationEffectiveness` reads `notification_history` and
 * `users.lastActiveAt` only — it produces nothing anyone here consumes. It is
 * LAST because it is the heaviest task in the chain (a full day of
 * `notification_history` at 500/page + chunked `getAll` + batch commits), and a
 * timeout in it aborts everything behind it. Nothing behind it is the point.
 *
 * `detectLapsedUsers` runs ahead of the reporting tasks: it is the one
 * USER-FACING task in this chain (it sends win-back push via
 * `sendPushToUserRespectingPreferences`). Suppressing a user's notification
 * because `recipeMethodSnapshot` was slow is the wrong trade. Its send time
 * moves 05:00 → ~06:00 UTC, which is 08:00 Swedish summer time — still outside
 * quiet hours, but the exact minute now varies with the tasks ahead of it.
 *
 * KNOWN, ACCEPTED, TICKETED SEPARATELY: `runDetectLapsedUsers` commits
 * notification batches per threshold but advances its resume cursor only at the
 * very end (BUT-1567, deliberate). A run raced out mid-threshold leaves
 * committed notification docs behind an un-advanced cursor, and the next run
 * re-sends. Moving it earlier shrinks the window; the real fix is a
 * deterministic per-user/threshold/day notification doc id, which is a
 * data-semantics change and does not belong in a mechanical trigger merge.
 */
export const DAILY_ANALYTICS_TASKS: MaintenanceTask[] = [
  // BUT-2046 follow-up. FIRST, not last: this is the only thing that ends a
  // legal hold, and a task in the tail is the first thing dropped when the
  // chain runs short of budget — the repo has already paid for putting a
  // silent safety control there.
  //
  // First position has its own cost, stated so a later reader weighs both: a
  // task that TIMES OUT aborts the chain, so a slow sweep takes every task
  // behind it down with it. What makes that acceptable is the sweep's own
  // wall-clock budget (`SWEEP_DEADLINE_MS`), which stops early and defers the
  // rest a day; the row cap beside it bounds what is READ, not how long the
  // run takes. An UNBOUNDED sweep in first position is the combination to
  // avoid.
  { name: "sweepErasureHolds", run: () => runSweepErasureHolds(), timeoutMs: TASK_TIMEOUT_MS },
  // Right behind it, and for its reason: it ends the retention of a report
  // whose reporter erased their account (2026-09-18).
  { name: "sweepRetainedReporterReports", run: () => runSweepRetainedReporterReports(), timeoutMs: TASK_TIMEOUT_MS },
  { name: "trackDayNRetention", run: () => runTrackRetention(), timeoutMs: TASK_TIMEOUT_MS },
  { name: "computeFeatureRetention", run: () => runComputeFeatureRetention(), timeoutMs: TASK_TIMEOUT_MS },
  { name: "detectLapsedUsers", run: () => runDetectLapsedUsers(), timeoutMs: TASK_TIMEOUT_MS },
  { name: "importHealthSnapshot", run: () => runImportHealthSnapshot(), timeoutMs: TASK_TIMEOUT_MS },
  { name: "recipeMethodSnapshot", run: () => runRecipeMethodSnapshot(), timeoutMs: TASK_TIMEOUT_MS },
  { name: "parsingCorrectionsSnapshot", run: () => runParsingCorrectionsSnapshot(), timeoutMs: TASK_TIMEOUT_MS },
  { name: "feedbackSnapshot", run: () => runFeedbackSnapshot(), timeoutMs: TASK_TIMEOUT_MS },
  { name: "opsSnapshot", run: () => runOpsSnapshot(), timeoutMs: TASK_TIMEOUT_MS },
  { name: "detectAnomalies", run: () => runDetectAnomalies(), timeoutMs: TASK_TIMEOUT_MS },
  { name: "correlateNotificationEffectiveness", run: () => runCorrelateNotificationEffectiveness(), timeoutMs: TASK_TIMEOUT_MS },
];

/** Snapshot tasks `detectAnomalies` consumes — asserted to precede it. */
export const SNAPSHOT_PRODUCER_TASKS = [
  "importHealthSnapshot",
  "recipeMethodSnapshot",
  "parsingCorrectionsSnapshot",
  "feedbackSnapshot",
  "opsSnapshot",
];

/**
 * Weekly reports chain, Monday 08:00 UTC.
 *
 * `weeklyActivityDigest` is FIRST and the chain fires at 08:00 rather than the
 * former 06:00 of `northStarWeekly`, because the digest is user-facing — its
 * send time is preserved to the minute. The report moves two hours later.
 *
 * ACCEPTED COUPLING: the digest pages 100 users at a time with a per-user push
 * and has no internal wall-clock cap. If it races out, the chain aborts by
 * design and `northStarWeekly` is skipped — and since `isoWeek` derives from
 * `now` and `retryCount` is 0, that week's snapshot doc is never written and no
 * later run revisits it. Before the merge a slow digest cost only the digest.
 * This is a real, deliberate trade for one Cloud Scheduler job (~1 kr/month);
 * the clean fix is a catch-up in `runNorthStarWeekly` (compute the previous ISO
 * week too when its doc is missing — it already takes `deps.now` and writes
 * idempotently by week), tracked separately.
 */
export const WEEKLY_REPORT_TASKS: MaintenanceTask[] = [
  { name: "weeklyActivityDigest", run: () => runWeeklyActivityDigest(), timeoutMs: TASK_TIMEOUT_MS },
  { name: "northStarWeekly", run: () => runNorthStarWeekly(), timeoutMs: TASK_TIMEOUT_MS },
  { name: "importTierWeekly", run: () => runImportTierWeekly(), timeoutMs: TASK_TIMEOUT_MS },
  // BUT-1917. The block mirror is a safety control whose failure is SILENT: a
  // missing entry lets a blocked person keep acting and nothing on any screen
  // says so, so `retry: true` on the trigger is not the whole story. A task
  // rather than its own `onSchedule` per this file's standing rule — it needs
  // neither its own frequency nor failure isolation, and Scheduler bills per
  // job.
  {
    name: "reconcileBlockMirrors",
    run: () => runReconcileBlockMirrors(),
    timeoutMs: TASK_TIMEOUT_MS,
  },
];

export const dailyAnalytics = onSchedule(
  {
    schedule: "0 6 * * *",
    timeZone: "UTC",
    timeoutSeconds: CHAIN_TIMEOUT_SECONDS,
    retryCount: 0,
    // 512MiB, not the 256MiB default these jobs each had alone. Peak RSS is no
    // longer one task's — `runRecipeMethodSnapshot` materialises up to
    // RECIPE_SCAN_CAP (5000) recipe documents into `snap.docs` in the SAME
    // process that `runDetectLapsedUsers` just paged `users` in. An OOM kill
    // produces NO error log, takes the whole day's chain with it, and leaves
    // nothing to diagnose. ~4,500 GB-s/month against a 400,000 GB-s free tier
    // — the insurance is free.
    memory: "512MiB",
  },
  async () => {
    await runTaskChain(DAILY_ANALYTICS_TASKS, "dailyAnalytics");
  },
);

export const weeklyReports = onSchedule(
  {
    schedule: "0 8 * * 1",
    timeZone: "UTC",
    timeoutSeconds: CHAIN_TIMEOUT_SECONDS,
    retryCount: 0,
  },
  async () => {
    await runTaskChain(WEEKLY_REPORT_TASKS, "weeklyReports");
  },
);

/**
 * Rating + pool aggregation drains, every minute.
 *
 * These two queues are INDEPENDENT and already able to overlap across
 * invocations, so they run CONCURRENTLY via `Promise.allSettled` — not through
 * `runTaskChain`. Serialising them would add pool latency on top of rating
 * latency for no benefit. `timeoutSeconds: 120` is what both carried before.
 */
export const drainAggregations = onSchedule(
  { schedule: "every 1 minutes", timeoutSeconds: 120, retryCount: 0 },
  async () => {
    const [rating, pool] = await Promise.allSettled([
      drainRatingAggregationQueue({ aggregate: updateRecipeRatingStats }),
      drainPoolAggregationQueue({ aggregate: updatePooledRatingStats }),
    ]);

    if (rating.status === "fulfilled") {
      logger.info("rating_aggregation.drain_complete", {
        event: "rating_aggregation.drain_complete",
        processed: rating.value.processed,
        failed: rating.value.failed,
        durationMs: rating.value.durationMs,
      });
    } else {
      logDrainRejection("rating_aggregation.drain_failed", rating.reason);
    }

    if (pool.status === "fulfilled") {
      logger.info("pool_aggregation.drain_complete", {
        event: "pool_aggregation.drain_complete",
        processed: pool.value.processed,
        failed: pool.value.failed,
        durationMs: pool.value.durationMs,
      });
    } else {
      logDrainRejection("pool_aggregation.drain_failed", pool.reason);
    }

    const dead = deadDrainQueues(rating.status, pool.status);
    if (dead.length > 0) {
      throw new Error(`drainAggregations: ${dead.join(", ")} queue(s) failed`);
    }
  },
);

/**
 * Which drain queues rejected — the seam that decides whether the run is
 * recorded as failed.
 *
 * EITHER queue rejecting is a failure, not only both. A rejection here means
 * the marker scan itself failed (`shared/debounce-queue.ts` catches per-item
 * failures and counts them into `failed`), and each queue is the SOLE producer
 * of its stats collection — a persistently failing rating drain returning HTTP
 * 200 every minute is exactly the silence this merge must not introduce.
 * `Promise.allSettled` has already run both legs, so failing the run costs no
 * work, and `retryCount: 0` means no re-drain: the next minute's tick is the
 * retry.
 *
 * Extracted rather than inlined so the decision is testable — the `onSchedule`
 * wrapper around it cannot be invoked from a unit test.
 */
export function deadDrainQueues(
  ratingStatus: "fulfilled" | "rejected",
  poolStatus: "fulfilled" | "rejected",
): string[] {
  return [
    ratingStatus === "rejected" ? "rating" : null,
    poolStatus === "rejected" ? "pool" : null,
  ].filter((q): q is string => q !== null);
}

/**
 * `{ errCode, errName }` — never `{ err }`.
 *
 * `firebase-functions`' logger only unwraps an Error passed POSITIONALLY; an
 * Error nested in the payload object serialises to `err: {}`, i.e. a logged
 * failure with no cause at all. Verified against the emulator and recorded in
 * the cloud-functions knowledge file.
 */
function logDrainRejection(event: string, reason: unknown): void {
  const err = reason instanceof Error ? reason : new Error(String(reason));
  logger.error(event, {
    errName: err.name,
    errCode: (reason as { code?: number | string })?.code,
  });
}
