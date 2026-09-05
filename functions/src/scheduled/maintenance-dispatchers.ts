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
 * The nine cleanup/purge jobs are deliberately NOT here. They carry GDPR
 * retention guarantees, two currently-inert 8-minute self-budgets that a
 * shared chain would un-cap, and weekday moves that would perturb the `ops`
 * anomaly series — that merge is its own piece of work.
 */

import { onSchedule } from "firebase-functions/v2/scheduler";
import { logger } from "firebase-functions/logger";
import { withTimeout } from "../shared/with-timeout";

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
import { runNorthStarWeekly } from "../scheduled/north-star-weekly";
import { drainRatingAggregationQueue } from "../ratings/rating-aggregation";
import { drainPoolAggregationQueue } from "../ratings/pool-aggregation";
import { updateRecipeRatingStats } from "../ratings/update-recipe-rating-stats";
import { updatePooledRatingStats } from "../ratings/update-pooled-rating-stats";

/**
 * `timeoutSeconds` declared on the chain dispatchers.
 *
 * 540 is chosen because this repo already deploys that value successfully
 * (`account/request-account-deletion.ts`, `migrations/backfill-shared-list-
 * contributors.ts`). The platform ceiling for v2 SCHEDULED functions is not
 * verified here — if a larger value were needed the deploy would reject it
 * loudly, which is the control.
 *
 * Paired with `CHAIN_DEADLINE_MS` below: raise them together. The in-code
 * deadline must stay BELOW the platform timeout or it is dead code — the same
 * trap `shared/with-timeout.ts` documents about itself.
 */
export const CHAIN_TIMEOUT_SECONDS = 540;

/** Wall clock a chain gives itself, ~40s under the platform timeout. */
export const CHAIN_DEADLINE_MS = 500_000;

/**
 * Per-task budget.
 *
 * 60s is exactly what these tasks run under TODAY: none of them declared
 * `timeoutSeconds`, so every one of them has always lived on the v2 60-second
 * default. No task gets more budget than it had — only less, when the chain is
 * running out.
 *
 * Be precise about what "less" means, because the earlier wording here claimed
 * a task is always SKIPPED rather than started and cut off, and that is not
 * what the code does. `budgetMs = Math.min(task.timeoutMs, available)`
 * TRUNCATES, and the skip only fires below `CHAIN_RESERVE_MS`. So for
 * `CHAIN_RESERVE_MS <= available < TASK_TIMEOUT_MS` a task runs on a cut
 * budget, and if it uses all of it the chain records a TIMEOUT and abandons
 * everything behind it.
 *
 * That window is reachable by construction on the daily chain: ten tasks at 60s
 * is 600_000ms of budget inside a 500_000ms deadline, so the chain is
 * over-subscribed by design and relies on tasks finishing early. Tracked as
 * BUT-1814 — either size the budgets to fit or make truncation a hard skip.
 */
export const TASK_TIMEOUT_MS = 60_000;

/**
 * Smallest slice worth STARTING a task with. Below this the task is skipped
 * with a log rather than started and raced out — a visible gap beats a silent
 * truncation, and a raced-out task aborts the whole chain.
 *
 * This is a floor on the AVAILABLE slice, never on a task's own declared
 * `timeoutMs`: a task is free to declare a budget smaller than this.
 */
const MIN_TASK_BUDGET_MS = 5_000;

/**
 * Wall clock held back from the last task so the chain can log its summary and
 * throw its aggregate error inside the platform timeout rather than being
 * killed mid-write.
 */
const CHAIN_RESERVE_MS = 5_000;

export interface MaintenanceTask {
  /** Stable identifier — appears in logs and is asserted by the test suite. */
  name: string;
  run: () => Promise<unknown>;
  timeoutMs: number;
}

export interface ChainResult {
  completed: string[];
  failed: string[];
  skipped: string[];
  abortedAt: string | null;
}

/**
 * Run tasks sequentially under one shared deadline.
 *
 * Failure semantics, deliberately chosen:
 *   - A task that THROWS is logged as `maintenance.task_failed` and the chain
 *     CONTINUES. Nine of the ten daily tasks write an idempotent, date-keyed
 *     doc, so a neighbour's failure cannot corrupt them. The exception is
 *     `correlateNotificationEffectiveness`, which writes auto-id rows and
 *     WOULD duplicate a day if the chain were re-fired by hand — do not treat
 *     "one task failed, just run it again" as safe for that one until its doc
 *     id is made deterministic (tracked separately; it is a data-semantics
 *     change, not part of a trigger merge).
 *   - A task that TIMES OUT ABORTS the chain. `withTimeout` is a
 *     `Promise.race` — it does not cancel the underlying work, which keeps
 *     running and keeps writing Firestore. Continuing would put two tasks in
 *     the same process writing concurrently and would break the guarantee that
 *     `runOpsSnapshot` reads a settled `system_events`.
 *   - A task with too little remaining budget is SKIPPED and logged. A visible
 *     gap beats a silent truncation.
 *   - After the chain, a single error naming EVERY failed task is thrown, so
 *     Error Reporting groups on something readable instead of one opaque title.
 *     With `retryCount: 0` the throw records the run as failed; it never
 *     re-runs the tasks that succeeded.
 */
export async function runTaskChain(
  tasks: MaintenanceTask[],
  chainName: string,
  deadlineMs: number = CHAIN_DEADLINE_MS,
  nowFn: () => number = Date.now,
): Promise<ChainResult> {
  const startedAt = nowFn();
  const result: ChainResult = {
    completed: [],
    failed: [],
    skipped: [],
    abortedAt: null,
  };

  logger.info("maintenance.chain_start", { chain: chainName, tasks: tasks.length });

  for (let index = 0; index < tasks.length; index++) {
    const task = tasks[index];
    const elapsed = nowFn() - startedAt;
    const remaining = deadlineMs - elapsed;
    // Gate on the AVAILABLE slice, never on raw remaining wall clock: at
    // `remaining === CHAIN_RESERVE_MS` the slice is 0 ms, and the task would be
    // started, raced out instantly, recorded as a TIMEOUT and would abort the
    // whole chain — the opposite of "skip, never start-and-cut".
    const available = remaining - CHAIN_RESERVE_MS;

    if (available < MIN_TASK_BUDGET_MS) {
      result.skipped.push(task.name);
      logger.error("maintenance.task_skipped", {
        chain: chainName,
        task: task.name,
        index,
        remainingMs: remaining,
        availableMs: available,
        reason: "chain_budget_exhausted",
      });
      continue;
    }

    const budgetMs = Math.min(task.timeoutMs, available);
    const taskStartedAt = nowFn();
    try {
      await withTimeout(task.run(), budgetMs, `${chainName}.${task.name}`);
      result.completed.push(task.name);
      logger.info("maintenance.task_complete", {
        chain: chainName,
        task: task.name,
        index,
        durationMs: nowFn() - taskStartedAt,
      });
    } catch (err) {
      const error = err instanceof Error ? err : new Error(String(err));
      // Exact match on the label THIS chain passed to `withTimeout`, not a
      // loose substring: a task that adopts `withTimeout` internally would
      // otherwise have its own inner timeout misread as a chain timeout and
      // abort every task behind it.
      const timedOut = error.message.startsWith(
        `${chainName}.${task.name} timed out after`,
      );
      result.failed.push(task.name);
      // `{ errCode, errName }`, never `message`/`stack`: a Firestore error
      // carries `users/<raw uid>/…` paths, and these tasks iterate user data.
      // `compute-feature-retention.ts` explicitly forbids re-adding `message`
      // after four separate reports. The aggregate throw below names the failed
      // tasks, so nothing diagnostic is lost.
      logger.error("maintenance.task_failed", {
        chain: chainName,
        task: task.name,
        index,
        durationMs: nowFn() - taskStartedAt,
        timedOut,
        errName: error.name,
        errCode: (err as { code?: number | string })?.code,
      });

      if (timedOut) {
        // The raced-out task is STILL RUNNING and still writing. Stop here.
        result.abortedAt = task.name;
        for (let rest = index + 1; rest < tasks.length; rest++) {
          result.skipped.push(tasks[rest].name);
        }
        break;
      }
    }
  }

  logger.info("maintenance.chain_complete", {
    chain: chainName,
    completed: result.completed.length,
    failed: result.failed,
    skipped: result.skipped,
    abortedAt: result.abortedAt,
    durationMs: nowFn() - startedAt,
  });

  if (result.failed.length > 0) {
    throw new Error(
      `${chainName}: ${result.failed.length} task(s) failed: ${result.failed.join(", ")}` +
        (result.abortedAt != null ? ` (chain aborted at ${result.abortedAt})` : ""),
    );
  }

  return result;
}

/**
 * Daily analytics chain, 06:00 UTC.
 *
 * Order is load-bearing in two places and pinned by
 * `__tests__/maintenance-dispatchers.test.ts`:
 *   1. The four non-ops snapshots produce what `detectAnomalies` consumes, so
 *      it runs LAST (`cloud-functions-specialist.knowledge.md:826-828` — a
 *      consumer runs strictly after its producer's slowest run and SKIPS on a
 *      missing producer doc, which `runDetectAnomalies` already implements).
 *   2. `opsSnapshot` reads `system_events` for the current UTC day and the five
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
 * `detectLapsedUsers` is THIRD, not seventh: it is the one USER-FACING task in
 * this chain (it sends win-back push via
 * `sendPushToUserRespectingPreferences`). Suppressing a user's notification
 * because `recipeMethodSnapshot` was slow is the wrong trade. Its send time
 * moves 05:00 → ~06:00 UTC, which is 08:00 Swedish summer time — still outside
 * quiet hours, but the exact minute now varies with the two tasks ahead of it.
 *
 * KNOWN, ACCEPTED, TICKETED SEPARATELY: `runDetectLapsedUsers` commits
 * notification batches per threshold but advances its resume cursor only at the
 * very end (BUT-1567, deliberate). A run raced out mid-threshold leaves
 * committed notification docs behind an un-advanced cursor, and the next run
 * re-sends. Moving it to position 3 shrinks the window; the real fix is a
 * deterministic per-user/threshold/day notification doc id, which is a
 * data-semantics change and does not belong in a mechanical trigger merge.
 */
export const DAILY_ANALYTICS_TASKS: MaintenanceTask[] = [
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
