/**
 * Pausing Cloud Scheduler for the duration of a reset (BUT-2036).
 *
 * `admin/reset-user-data.ts` wipes Firestore in Phase 2. The scheduled jobs
 * write into the same collections and know nothing about a reset, so one that
 * fires mid-wipe puts rows back behind the walk. The kill switch
 * (`shared/reset-kill-switch.ts`) closes the other half of this — the Auth
 * trigger — and cannot reach these: a scheduled job is not that trigger, and
 * nothing makes every job read a flag before it runs.
 *
 * The jobs are ENUMERATED at run time rather than listed here. A hand-written
 * list is the failure this repo has paid for twice (BUT-2040, BUT-2043): a job
 * added later is not in it, nothing reddens, and the gap is visible only to
 * someone reading a run's output closely.
 *
 * Only jobs found ENABLED are paused, and only those are resumed — a job a
 * person had already paused before the run must stay paused, the same
 * ownership question the kill switch answers with its run id.
 *
 * Pausing does not stop an execution already in flight. That is a named
 * residual rather than something this module handles; the runbook carries it.
 *
 * Operating instructions, including the IAM the operator needs and what to do
 * when a job is left paused: `docs/ops/reset-user-data-runbook.md`.
 */

import { GoogleAuth } from "google-auth-library";

const SCHEDULER_HOST = "https://cloudscheduler.googleapis.com/v1";

/**
 * A job's full resource name, `projects/{p}/locations/{loc}/jobs/{id}`.
 *
 * Carried whole rather than split, because it is what every later call takes:
 * the pause and resume endpoints address a job by it, and the operator's
 * recovery command is built from it. Splitting and rejoining it is a second
 * place for the parts to be assembled wrongly.
 */
export type JobName = string;

/**
 * The calls this module makes, behind an interface so a test can drive the
 * decisions — which jobs are paused, which are resumed, what a failure does —
 * without a network or a project.
 */
export interface SchedulerApi {
  listLocationIds(projectId: string): Promise<string[]>;
  listJobs(
    projectId: string,
    locationId: string,
  ): Promise<{ name: JobName; state: string }[]>;
  pause(name: JobName): Promise<void>;
  resume(name: JobName): Promise<void>;
}

export interface JobActionResult {
  /** The jobs the call succeeded on. */
  done: JobName[];
  /** The jobs it did not, each with the reason to print. */
  failed: { name: JobName; message: string }[];
}

/** The command that undoes a pause by hand, for a job left standing. */
export function gcloudResumeCommand(name: JobName): string {
  const match = /^projects\/([^/]+)\/locations\/([^/]+)\/jobs\/(.+)$/.exec(
    name,
  );
  if (match === null) {
    // A name this module cannot parse still has to reach the operator. A
    // command built from a guess would look runnable and address the wrong
    // job, or none.
    return `(unrecognised job name — resume "${name}" from the console)`;
  }
  const [, project, location, jobId] = match;
  return (
    `gcloud scheduler jobs resume ${jobId} --location=${location} ` +
    `--project=${project}`
  );
}

/**
 * Every ENABLED job in the project, across every region Cloud Scheduler
 * reports for it.
 *
 * The regions are asked for rather than assumed: a job created outside the
 * region this repo pins its functions to — by a later change, or by hand —
 * would be invisible to a region constant and would keep firing through the
 * wipe.
 *
 * Throws rather than returning a partial list. A caller cannot tell a project
 * with nothing enabled from a project whose listing failed, and those are
 * opposite instructions.
 */
export async function listEnabledSchedulerJobs(
  api: SchedulerApi,
  projectId: string,
): Promise<JobName[]> {
  const locationIds = await api.listLocationIds(projectId);
  const enabled: JobName[] = [];
  for (const locationId of locationIds) {
    const jobs = await api.listJobs(projectId, locationId);
    for (const job of jobs) {
      if (job.state === "ENABLED") enabled.push(job.name);
    }
  }
  return enabled;
}

/**
 * Pauses each job, and reports rather than throwing.
 *
 * The caller has to know WHICH jobs it managed to pause even when one of them
 * fails: those are off now, and leaving them off is the outcome this module
 * exists to prevent.
 *
 * `onPaused` fires per job as it goes, so a caller can hold a live record of
 * what is off. The returned list arrives only once every job has been tried,
 * and an interrupt in the middle would otherwise find the caller believing it
 * had paused nothing.
 */
export async function pauseJobs(
  api: SchedulerApi,
  names: JobName[],
  onPaused?: (name: JobName) => void,
): Promise<JobActionResult> {
  return actOnEach(names, async (name) => {
    await api.pause(name);
    onPaused?.(name);
  });
}

/** Resumes each job, reporting per job for the same reason as `pauseJobs`. */
export async function resumeJobs(
  api: SchedulerApi,
  names: JobName[],
): Promise<JobActionResult> {
  return actOnEach(names, (name) => api.resume(name));
}

/**
 * Which of `names` Cloud Scheduler still reports as PAUSED.
 *
 * The verification phase asks this instead of trusting what `resumeJobs`
 * returned: a resume call that answered without error is a claim about the
 * request, and what the operator needs is a claim about the jobs.
 */
export async function findStillPausedJobs(
  api: SchedulerApi,
  projectId: string,
  names: JobName[],
): Promise<JobName[]> {
  if (names.length === 0) return [];
  const wanted = new Set(names);
  const stillPaused: JobName[] = [];
  const locationIds = await api.listLocationIds(projectId);
  for (const locationId of locationIds) {
    const jobs = await api.listJobs(projectId, locationId);
    for (const job of jobs) {
      if (wanted.has(job.name) && job.state === "PAUSED") {
        stillPaused.push(job.name);
      }
    }
  }
  return stillPaused;
}

async function actOnEach(
  names: JobName[],
  act: (name: JobName) => Promise<void>,
): Promise<JobActionResult> {
  const result: JobActionResult = { done: [], failed: [] };
  for (const name of names) {
    try {
      await act(name);
      result.done.push(name);
    } catch (err: unknown) {
      result.failed.push({
        name,
        message: err instanceof Error ? err.message : String(err),
      });
    }
  }
  return result;
}

/**
 * The real API, over REST.
 *
 * `google-auth-library` rather than `@google-cloud/scheduler`: the credentials
 * are the ones `initializeAdminApp()` already resolved, and four endpoints do
 * not earn a client library's dependency tree in a script that runs by hand.
 */
export function createSchedulerApi(): SchedulerApi {
  const auth = new GoogleAuth({
    scopes: ["https://www.googleapis.com/auth/cloud-platform"],
  });

  async function call<T>(url: string, method: "GET" | "POST"): Promise<T> {
    try {
      const client = await auth.getClient();
      // Bounded, because an unbounded hang here stops a live run at a prompt
      // that never returns. Failing is the safe direction — nothing has been
      // deleted at the point these calls are made — but only if it fails.
      const res = await client.request<T>({ url, method, timeout: 30_000 });
      return res.data;
    } catch (err: unknown) {
      // The transport's own message is `Request failed with status code 403`,
      // which cannot tell missing IAM from a disabled API, and every
      // operator-facing line this run prints is built from it. The reason the
      // service actually gave lives one level down.
      const detail = (
        err as {
          response?: { data?: { error?: { message?: string; status?: string } } };
        }
      ).response?.data?.error;
      if (detail?.message !== undefined) {
        throw new Error(`${detail.status ?? "error"}: ${detail.message}`);
      }
      throw err;
    }
  }

  return {
    async listLocationIds(projectId: string): Promise<string[]> {
      const ids: string[] = [];
      let pageToken: string | undefined;
      do {
        const query = isBlank(pageToken)
          ? ""
          : `?pageToken=${encodeURIComponent(pageToken as string)}`;
        const data = await call<{
          locations?: { locationId?: string }[];
          nextPageToken?: string;
        }>(`${SCHEDULER_HOST}/projects/${projectId}/locations${query}`, "GET");
        for (const location of data.locations ?? []) {
          if (location.locationId !== undefined) ids.push(location.locationId);
        }
        pageToken = data.nextPageToken;
      } while (!isBlank(pageToken));
      return ids;
    },

    async listJobs(
      projectId: string,
      locationId: string,
    ): Promise<{ name: JobName; state: string }[]> {
      const jobs: { name: JobName; state: string }[] = [];
      let pageToken: string | undefined;
      // Paged rather than read in one call: a truncated listing leaves the
      // jobs past the first page running through the wipe, which is the same
      // hole as a hand-written list one step further in.
      do {
        const query = isBlank(pageToken)
          ? ""
          : `&pageToken=${encodeURIComponent(pageToken as string)}`;
        const data = await call<{
          jobs?: { name?: string; state?: string }[];
          nextPageToken?: string;
        }>(
          `${SCHEDULER_HOST}/projects/${projectId}/locations/${locationId}` +
            `/jobs?pageSize=500${query}`,
          "GET",
        );
        for (const job of data.jobs ?? []) {
          // A job whose state the API did not report is left out of the
          // ENABLED set by `listEnabledSchedulerJobs` — this run will not
          // pause what it cannot classify, and will not resume it either.
          if (job.name !== undefined) {
            jobs.push({ name: job.name, state: job.state ?? "UNKNOWN" });
          }
        }
        pageToken = data.nextPageToken;
      } while (!isBlank(pageToken));
      return jobs;
    },

    async pause(name: JobName): Promise<void> {
      await call(`${SCHEDULER_HOST}/${name}:pause`, "POST");
    },

    async resume(name: JobName): Promise<void> {
      await call(`${SCHEDULER_HOST}/${name}:resume`, "POST");
    },
  };
}

function isBlank(token: string | undefined): boolean {
  return token === undefined || token === "";
}
