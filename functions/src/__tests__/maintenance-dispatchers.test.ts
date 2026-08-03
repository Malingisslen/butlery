/**
 * maintenance-dispatchers tests — pure unit level, no emulator.
 *
 * Two things are being guarded here, and only one of them is obvious.
 *
 * 1. `runTaskChain`'s failure semantics. A THROWING task must not stop the
 *    chain; a TIMED-OUT task must stop it (`withTimeout` is a `Promise.race`,
 *    so the raced-out task keeps running and keeps writing Firestore —
 *    continuing would put two tasks writing concurrently in one process). A
 *    task with too little remaining budget is skipped, not started and cut off.
 *    The aggregate error must name every failed task.
 *
 * 2. The ONE real producer→consumer ordering in the daily chain: the snapshot
 *    tasks produce what `detectAnomalies` consumes, so it must run last
 *    (`cloud-functions-specialist.knowledge.md:826-828`).
 *
 * A NOTE ON WHAT IS *NOT* TESTED HERE, deliberately. An earlier draft of this
 * suite asserted "opsSnapshot runs after every `system_events` writer in the
 * daily chain". That test was VACUOUS: every scheduled `system_events` writer
 * in this repo is a WEEKLY cleanup job, so no daily task writes there and the
 * assertion held under any ordering. The real constraint is CROSS-CHAIN —
 * `dailyAnalytics` fires at 06:00 UTC, after the last weekly cleanup job at
 * 05:00 Sunday — and it lives in two cron strings, which a unit test cannot
 * see. It is documented at the schedule definitions instead. Do not "restore"
 * the vacuous test; it guards nothing.
 *
 * Both ordering assertions below were mutation-tested: moving `detectAnomalies`
 * ahead of the snapshots reddens (2), and dropping a task from the registry
 * reddens the membership check.
 *
 * Run with: npx ts-node src/__tests__/maintenance-dispatchers.test.ts
 */

import * as admin from "firebase-admin";

if (admin.apps.length === 0) {
  admin.initializeApp({ projectId: "butlery-test-maintenance-dispatchers" });
}

import {
  runTaskChain,
  MaintenanceTask,
  DAILY_ANALYTICS_TASKS,
  WEEKLY_REPORT_TASKS,
  SNAPSHOT_PRODUCER_TASKS,
  CHAIN_DEADLINE_MS,
  CHAIN_TIMEOUT_SECONDS,
  TASK_TIMEOUT_MS,
  deadDrainQueues,
} from "../scheduled/maintenance-dispatchers";

let totalRun = 0;
let totalFailed = 0;

function record(name: string, ok: boolean, detail?: string): void {
  totalRun++;
  if (ok) {
    console.log(`  PASS  ${name}`);
  } else {
    totalFailed++;
    console.error(`  FAIL  ${name}${detail ? ` — ${detail}` : ""}`);
  }
}

function task(
  name: string,
  run: () => Promise<unknown>,
  timeoutMs = 1000,
): MaintenanceTask {
  return { name, run, timeoutMs };
}

const ok = (name: string, sink: string[]) =>
  task(name, async () => {
    sink.push(name);
  });

async function testRegistryMembership(): Promise<void> {
  const expectedDaily = [
    "trackDayNRetention",
    "computeFeatureRetention",
    // User-facing (win-back push) — ahead of the reporting tasks on purpose.
    "detectLapsedUsers",
    "importHealthSnapshot",
    "recipeMethodSnapshot",
    "parsingCorrectionsSnapshot",
    "feedbackSnapshot",
    "opsSnapshot",
    "detectAnomalies",
    // Heaviest and consumed by nobody — last, so a timeout in it takes
    // nothing else down with it.
    "correlateNotificationEffectiveness",
  ];
  const actualDaily = DAILY_ANALYTICS_TASKS.map((t) => t.name);
  record(
    "DAILY_ANALYTICS_TASKS holds exactly the ten merged daily jobs",
    JSON.stringify(actualDaily) === JSON.stringify(expectedDaily),
    `got ${JSON.stringify(actualDaily)}`,
  );

  const expectedWeekly = ["weeklyActivityDigest", "northStarWeekly"];
  const actualWeekly = WEEKLY_REPORT_TASKS.map((t) => t.name);
  record(
    "WEEKLY_REPORT_TASKS holds the digest first, then the report",
    JSON.stringify(actualWeekly) === JSON.stringify(expectedWeekly),
    `got ${JSON.stringify(actualWeekly)}`,
  );

  record(
    "every task declares a positive timeout budget",
    [...DAILY_ANALYTICS_TASKS, ...WEEKLY_REPORT_TASKS].every(
      (t) => typeof t.timeoutMs === "number" && t.timeoutMs > 0,
    ),
  );
}

async function testProducerBeforeConsumer(): Promise<void> {
  const names = DAILY_ANALYTICS_TASKS.map((t) => t.name);
  const consumerIndex = names.indexOf("detectAnomalies");
  record(
    "detectAnomalies is present in the daily chain",
    consumerIndex >= 0,
  );

  // Pin the producer set to a LITERAL. Asserting only "every declared producer
  // runs first" would stay green if someone deleted an entry from
  // SNAPSHOT_PRODUCER_TASKS — fewer producers to check is not fewer producers.
  record(
    "SNAPSHOT_PRODUCER_TASKS names all five snapshot tasks",
    JSON.stringify(SNAPSHOT_PRODUCER_TASKS) ===
      JSON.stringify([
        "importHealthSnapshot",
        "recipeMethodSnapshot",
        "parsingCorrectionsSnapshot",
        "feedbackSnapshot",
        "opsSnapshot",
      ]),
    JSON.stringify(SNAPSHOT_PRODUCER_TASKS),
  );

  const producersPresent = SNAPSHOT_PRODUCER_TASKS.every((p) =>
    names.includes(p),
  );
  record(
    "every declared snapshot producer is in the daily chain",
    producersPresent,
    `missing: ${SNAPSHOT_PRODUCER_TASKS.filter((p) => !names.includes(p)).join(", ")}`,
  );

  const allProducersBefore = SNAPSHOT_PRODUCER_TASKS.every(
    (p) => names.indexOf(p) >= 0 && names.indexOf(p) < consumerIndex,
  );
  record(
    "every snapshot producer runs BEFORE detectAnomalies",
    allProducersBefore,
    `order: ${names.join(" -> ")}`,
  );
}

async function testTimeoutBudgetsFitTheChain(): Promise<void> {
  record(
    "in-code chain deadline stays below the declared platform timeout",
    CHAIN_DEADLINE_MS < CHAIN_TIMEOUT_SECONDS * 1000,
    `${CHAIN_DEADLINE_MS}ms vs ${CHAIN_TIMEOUT_SECONDS * 1000}ms`,
  );

  record(
    "per-task budget matches the 60s platform default these jobs ran under",
    TASK_TIMEOUT_MS === 60_000,
    `got ${TASK_TIMEOUT_MS}`,
  );
}

async function testFailureContinuesChain(): Promise<void> {
  const sink: string[] = [];
  const tasks: MaintenanceTask[] = [
    ok("a", sink),
    ok("b", sink),
    task("boom", async () => {
      throw new Error("synthetic failure");
    }),
    ok("d", sink),
    ok("e", sink),
  ];

  let thrown: Error | null = null;
  try {
    await runTaskChain(tasks, "testChain");
  } catch (err) {
    thrown = err as Error;
  }

  record(
    "a throwing task does not stop the tasks after it",
    JSON.stringify(sink) === JSON.stringify(["a", "b", "d", "e"]),
    `ran ${JSON.stringify(sink)}`,
  );
  record(
    "the chain still throws afterwards so the run records as failed",
    thrown != null,
  );
  record(
    "the aggregate error names the failed task",
    thrown != null && thrown.message.includes("boom"),
    thrown?.message,
  );
}

async function testTimeoutAbortsChain(): Promise<void> {
  const sink: string[] = [];
  const tasks: MaintenanceTask[] = [
    ok("a", sink),
    task(
      "hangs",
      () =>
        new Promise((resolve) => {
          // unref: `withTimeout` races rather than cancels, so this timer
          // outlives the assertion. Without unref every green run holds the
          // Node process open for 5s on top of the suite.
          setTimeout(resolve, 5_000).unref();
        }),
      50,
    ),
    ok("never-runs", sink),
  ];

  let thrown: Error | null = null;
  try {
    await runTaskChain(tasks, "testChain");
  } catch (err) {
    thrown = err as Error;
  }

  record(
    "a timed-out task ABORTS the chain (the raced-out task is still writing)",
    JSON.stringify(sink) === JSON.stringify(["a"]),
    `ran ${JSON.stringify(sink)}`,
  );
  record(
    "the aggregate error reports where the chain aborted",
    thrown != null && thrown.message.includes("aborted at hangs"),
    thrown?.message,
  );
}

async function testBudgetExhaustionSkips(): Promise<void> {
  const sink: string[] = [];
  // A fake clock that jumps past the deadline after the first task.
  let clock = 0;
  const nowFn = () => clock;
  const tasks: MaintenanceTask[] = [
    task("first", async () => {
      sink.push("first");
      clock = CHAIN_DEADLINE_MS; // budget consumed
    }),
    ok("second", sink),
    ok("third", sink),
  ];

  let thrown: Error | null = null;
  try {
    await runTaskChain(tasks, "testChain", CHAIN_DEADLINE_MS, nowFn);
  } catch (err) {
    thrown = err as Error;
  }

  record(
    "tasks with no remaining budget are SKIPPED, not started and cut off",
    JSON.stringify(sink) === JSON.stringify(["first"]),
    `ran ${JSON.stringify(sink)}`,
  );
  record(
    "a skipped task is not reported as a failure",
    thrown == null,
    thrown?.message,
  );
}

async function testBudgetBoundarySkipsRatherThanStarts(): Promise<void> {
  // The boundary the first draft got wrong: at `remaining` just above the skip
  // floor the COMPUTED budget is near zero. Starting the task there would race
  // it out instantly, record a TIMEOUT and abort the whole chain — the exact
  // opposite of "skip, never start-and-cut".
  const sink: string[] = [];
  let clock = 0;
  const nowFn = () => clock;
  const tasks: MaintenanceTask[] = [
    task("first", async () => {
      sink.push("first");
      clock = CHAIN_DEADLINE_MS - 5_001; // leaves 5001ms → budget 1ms
    }),
    ok("boundary", sink),
    ok("after", sink),
  ];

  let thrown: Error | null = null;
  try {
    await runTaskChain(tasks, "testChain", CHAIN_DEADLINE_MS, nowFn);
  } catch (err) {
    thrown = err as Error;
  }

  record(
    "a task whose computed budget is below the floor is skipped, not started",
    JSON.stringify(sink) === JSON.stringify(["first"]),
    `ran ${JSON.stringify(sink)}`,
  );
  record(
    "that boundary skip does not abort the chain as a timeout",
    thrown == null,
    thrown?.message,
  );
}

async function testCleanChainReportsCompleted(): Promise<void> {
  const sink: string[] = [];
  const result = await runTaskChain(
    [ok("a", sink), ok("b", sink)],
    "testChain",
  );
  record(
    "a clean chain reports every task completed and nothing failed",
    result.completed.length === 2 &&
      result.failed.length === 0 &&
      result.skipped.length === 0 &&
      result.abortedAt === null,
    JSON.stringify(result),
  );
}

async function testDrainFailureIsNeverSilent(): Promise<void> {
  // The defect this pins: merging the two per-minute rating drains into one
  // job made it possible to swallow a whole-queue failure. Each queue is the
  // SOLE producer of its stats collection, so ONE rejecting must fail the run
  // — an earlier draft only threw when BOTH rejected, i.e. a persistently
  // broken rating drain would have returned success every minute forever.
  record(
    "both queues fine → run is not failed",
    deadDrainQueues("fulfilled", "fulfilled").length === 0,
  );
  record(
    "rating queue alone rejecting fails the run",
    JSON.stringify(deadDrainQueues("rejected", "fulfilled")) ===
      JSON.stringify(["rating"]),
    JSON.stringify(deadDrainQueues("rejected", "fulfilled")),
  );
  record(
    "pool queue alone rejecting fails the run",
    JSON.stringify(deadDrainQueues("fulfilled", "rejected")) ===
      JSON.stringify(["pool"]),
    JSON.stringify(deadDrainQueues("fulfilled", "rejected")),
  );
  record(
    "both rejecting names both queues",
    JSON.stringify(deadDrainQueues("rejected", "rejected")) ===
      JSON.stringify(["rating", "pool"]),
    JSON.stringify(deadDrainQueues("rejected", "rejected")),
  );
}

async function main(): Promise<void> {
  console.log("maintenance-dispatchers tests\n");
  await testRegistryMembership();
  await testProducerBeforeConsumer();
  await testTimeoutBudgetsFitTheChain();
  await testFailureContinuesChain();
  await testTimeoutAbortsChain();
  await testBudgetExhaustionSkips();
  await testBudgetBoundarySkipsRatherThanStarts();
  await testDrainFailureIsNeverSilent();
  await testCleanChainReportsCompleted();

  console.log(`\n${totalRun - totalFailed}/${totalRun} checks passed`);
  if (totalFailed > 0) {
    process.exit(1);
  }
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
