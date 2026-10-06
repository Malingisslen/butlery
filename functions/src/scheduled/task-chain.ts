/**
 * The sequential task-chain runner behind the maintenance dispatchers, split
 * out of `maintenance-dispatchers.ts` under that file's SPLIT RULE. The
 * registries and the `onSchedule` exports stay there.
 */

import { logger } from "firebase-functions/logger";
import { withTimeout } from "../shared/with-timeout";

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
 * That window is reachable by construction on the daily chain: the per-task
 * budgets sum past the chain deadline, so the chain is over-subscribed by
 * design and relies on tasks finishing early. Tracked as
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
 *     CONTINUES. A daily task that writes an idempotent, date-keyed doc cannot
 *     be corrupted by a neighbour's failure. The exception is
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
