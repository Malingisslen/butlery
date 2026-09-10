/**
 * BUT-2036: the reset run's Cloud Scheduler pause.
 *
 * What this proves, against a fake Scheduler so no project or network is
 * involved — these are the decisions, not the transport:
 * 1. Only ENABLED jobs are selected, across every region.
 * 2. A job a person had already paused is neither paused nor resumed by the
 *    run.
 * 3. A failing pause is reported per job rather than thrown, so the caller
 *    can resume what it managed to pause before refusing.
 * 4. A failing listing throws, because "nothing is enabled" and "I could not
 *    ask" are opposite instructions.
 * 5. The still-paused probe answers from the jobs' STATE, not from what the
 *    resume step reported.
 * 6. The recovery command names the job, its region and its project.
 *
 * Run: ts-node src/__tests__/reset-scheduler-pause.test.ts
 */

import {
  findStillPausedJobs,
  gcloudResumeCommand,
  JobName,
  listEnabledSchedulerJobs,
  pauseJobs,
  resumeJobs,
  SchedulerApi,
} from "../admin/reset-scheduler-pause";

let failed = 0;
function assert(cond: boolean, msg: string): void {
  if (cond) {
    console.log(`  PASS  ${msg}`);
  } else {
    failed++;
    console.log(`  FAIL  ${msg}`);
  }
}

const PROJECT = "butlery-test";

function jobName(location: string, id: string): JobName {
  return `projects/${PROJECT}/locations/${location}/jobs/${id}`;
}

interface FakeOptions {
  jobsByLocation: Record<string, { name: JobName; state: string }[]>;
  failListLocations?: string;
  failListJobs?: string;
  failPauseFor?: JobName[];
  failResumeFor?: JobName[];
}

/**
 * The fake holds STATE rather than a call log: the still-paused probe has to
 * be answerable from what the jobs are, or it would be testing the same
 * report it exists to distrust.
 */
function makeFake(options: FakeOptions): {
  api: SchedulerApi;
  paused: JobName[];
  resumed: JobName[];
  setState: (name: JobName, state: string) => void;
} {
  const paused: JobName[] = [];
  const resumed: JobName[] = [];
  const state = new Map<JobName, string>();
  for (const jobs of Object.values(options.jobsByLocation)) {
    for (const job of jobs) state.set(job.name, job.state);
  }

  const api: SchedulerApi = {
    async listLocationIds(): Promise<string[]> {
      if (options.failListLocations !== undefined) {
        throw new Error(options.failListLocations);
      }
      return Object.keys(options.jobsByLocation);
    },
    async listJobs(
      _projectId: string,
      locationId: string,
    ): Promise<{ name: JobName; state: string }[]> {
      if (options.failListJobs !== undefined) {
        throw new Error(options.failListJobs);
      }
      return (options.jobsByLocation[locationId] ?? []).map((job) => ({
        name: job.name,
        state: state.get(job.name) ?? job.state,
      }));
    },
    async pause(name: JobName): Promise<void> {
      if (options.failPauseFor?.includes(name) === true) {
        throw new Error(`pause denied for ${name}`);
      }
      paused.push(name);
      state.set(name, "PAUSED");
    },
    async resume(name: JobName): Promise<void> {
      if (options.failResumeFor?.includes(name) === true) {
        throw new Error(`resume denied for ${name}`);
      }
      resumed.push(name);
      state.set(name, "ENABLED");
    },
  };

  return { api, paused, resumed, setState: (n, s) => state.set(n, s) };
}

const EU = jobName("europe-west1", "cleanup-old-notifications");
const EU_SECOND = jobName("europe-west1", "reconcile-block-mirrors");
const US = jobName("us-central1", "ping-sweeper");
const HAND_PAUSED = jobName("europe-west1", "suppress-low-performers");

async function testOnlyEnabledJobsAcrossEveryRegion(): Promise<void> {
  const fake = makeFake({
    jobsByLocation: {
      "europe-west1": [
        { name: EU, state: "ENABLED" },
        { name: HAND_PAUSED, state: "PAUSED" },
        { name: EU_SECOND, state: "ENABLED" },
      ],
      "us-central1": [{ name: US, state: "ENABLED" }],
    },
  });

  const enabled = await listEnabledSchedulerJobs(fake.api, PROJECT);

  assert(
    JSON.stringify(enabled) === JSON.stringify([EU, EU_SECOND, US]),
    "every ENABLED job is selected, in every region",
  );
  assert(
    !enabled.includes(HAND_PAUSED),
    "a job somebody had already paused is not selected",
  );

  await pauseJobs(fake.api, enabled);
  assert(
    !fake.paused.includes(HAND_PAUSED),
    "and it is never paused, so the run does not own it",
  );

  const resumeResult = await resumeJobs(fake.api, enabled);
  assert(
    !fake.resumed.includes(HAND_PAUSED),
    "and it is never resumed — a person's pause outlives the run",
  );
  assert(
    resumeResult.done.length === 3 && resumeResult.failed.length === 0,
    "the three the run paused are the three it resumes",
  );
}

async function testAFailingPauseIsReportedPerJob(): Promise<void> {
  const fake = makeFake({
    jobsByLocation: {
      "europe-west1": [
        { name: EU, state: "ENABLED" },
        { name: EU_SECOND, state: "ENABLED" },
      ],
    },
    failPauseFor: [EU_SECOND],
  });

  const result = await pauseJobs(fake.api, [EU, EU_SECOND]);

  assert(
    JSON.stringify(result.done) === JSON.stringify([EU]),
    "the jobs that were paused are named, so the caller can put them back",
  );
  assert(
    result.failed.length === 1 && result.failed[0].name === EU_SECOND,
    "the job that was not paused is reported rather than thrown",
  );
  assert(
    result.failed[0].message.includes("pause denied"),
    "with the reason the operator has to act on",
  );

  // The caller keeps a live record so an interrupt mid-pause finds the jobs
  // that are already off. Without it the record is written only after every
  // job has been tried, and a Ctrl-C in between resumes nothing.
  const seen: JobName[] = [];
  const second = makeFake({
    jobsByLocation: {
      "europe-west1": [
        { name: EU, state: "ENABLED" },
        { name: EU_SECOND, state: "ENABLED" },
      ],
    },
    failPauseFor: [EU_SECOND],
  });
  await pauseJobs(second.api, [EU, EU_SECOND], (name) => seen.push(name));
  assert(
    JSON.stringify(seen) === JSON.stringify([EU]),
    "each pause is reported as it lands, not only once the batch is done",
  );
}

async function testAFailingListingThrows(): Promise<void> {
  const fake = makeFake({
    jobsByLocation: { "europe-west1": [{ name: EU, state: "ENABLED" }] },
    failListJobs: "PERMISSION_DENIED",
  });

  let threw = false;
  try {
    await listEnabledSchedulerJobs(fake.api, PROJECT);
  } catch (err: unknown) {
    threw = err instanceof Error && err.message === "PERMISSION_DENIED";
  }

  assert(
    threw,
    "a listing that failed throws — it must not read as an empty project",
  );
}

async function testStillPausedAnswersFromState(): Promise<void> {
  const fake = makeFake({
    jobsByLocation: {
      "europe-west1": [
        { name: EU, state: "ENABLED" },
        { name: EU_SECOND, state: "ENABLED" },
      ],
    },
    failResumeFor: [EU_SECOND],
  });

  const enabled = await listEnabledSchedulerJobs(fake.api, PROJECT);
  await pauseJobs(fake.api, enabled);
  const resumeResult = await resumeJobs(fake.api, enabled);
  const stillPaused = await findStillPausedJobs(fake.api, PROJECT, enabled);

  assert(
    resumeResult.done.length === 1,
    "the resume step reports one job put back",
  );
  assert(
    JSON.stringify(stillPaused) === JSON.stringify([EU_SECOND]),
    "and the probe finds the other still PAUSED by re-reading its state",
  );

  // The probe must not answer about a job this run never paused, or a
  // deliberate pause would fail somebody else's run.
  fake.setState(HAND_PAUSED, "PAUSED");
  const scoped = await findStillPausedJobs(fake.api, PROJECT, [EU]);
  assert(
    scoped.length === 0,
    "a job outside the run's own paused set is not reported",
  );
}

function testRecoveryCommand(): void {
  assert(
    gcloudResumeCommand(EU) ===
      "gcloud scheduler jobs resume cleanup-old-notifications " +
        `--location=europe-west1 --project=${PROJECT}`,
    "the recovery command names the job, its region and its project",
  );
  assert(
    gcloudResumeCommand("nonsense").includes("nonsense"),
    "an unparseable name still reaches the operator, without a fake command",
  );
}

async function main(): Promise<void> {
  console.log("reset-scheduler-pause");
  await testOnlyEnabledJobsAcrossEveryRegion();
  await testAFailingPauseIsReportedPerJob();
  await testAFailingListingThrows();
  await testStillPausedAnswersFromState();
  testRecoveryCommand();
  console.log(failed === 0 ? "\nAll assertions passed" : `\n${failed} FAILED`);
  process.exit(failed === 0 ? 0 : 1);
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
