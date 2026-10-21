/**
 * The project gate every hand-run admin script passes before it touches
 * firebase-admin (BUT-2419).
 *
 * With a production and a staging project side by side, a script that infers
 * its target — from a hardcoded default, from `gcloud`'s active project, from
 * whichever key file happens to be in the environment — can hit the wrong one
 * without saying so. So the target is never inferred: the operator names it
 * with `--project <id>`, and every other source that could disagree is made
 * to agree or the script refuses. The checks run before `initializeApp`, so a
 * refusal has opened no connection to anything.
 */

import * as fs from "fs";

export const PRODUCTION_PROJECT = "butlery-prod";
export const STAGING_PROJECT = "butlery-app-staging";
/**
 * The production project being replaced (BUT-2427). It stays administrable
 * until it is deleted, because its test accounts go through the deletion
 * cascade first; the deletion commit removes it from the allowlist.
 */
export const RETIRING_PRODUCTION_PROJECT = "butlery-app-1";

/**
 * An allowlist rather than a pattern: a `demo-` project, a typo, or a third
 * project nobody has decided to administer from these scripts is refused.
 */
export const ADMIN_PROJECTS: readonly string[] = [
  PRODUCTION_PROJECT,
  STAGING_PROJECT,
  RETIRING_PRODUCTION_PROJECT,
];

/** Environment variables Google client libraries read a project id from. */
const PROJECT_ENV_VARS = ["GOOGLE_CLOUD_PROJECT", "GCLOUD_PROJECT"] as const;

export interface RequireProjectOptions {
  argv?: readonly string[];
  env?: NodeJS.ProcessEnv;
  allowed?: readonly string[];
  readFile?: (filePath: string) => string;
}

function refuse(reason: string): never {
  throw new Error(`REFUSED: ${reason} Nothing has been initialized.`);
}

/**
 * Every `--project` value on the command line, in both `--project id` and
 * `--project=id` spellings. A flag with no value yields "".
 */
export function projectFlagValues(argv: readonly string[]): string[] {
  const values: string[] = [];
  for (let i = 0; i < argv.length; i++) {
    const arg = argv[i];
    if (arg === "--project") {
      const next = argv[i + 1];
      values.push(next === undefined || next.startsWith("--") ? "" : next);
    } else if (arg.startsWith("--project=")) {
      values.push(arg.slice("--project=".length));
    }
  }
  return values;
}

/**
 * Returns the project id the operator named, or throws before anything is
 * initialized.
 */
export function requireProject(options: RequireProjectOptions = {}): string {
  const argv = options.argv ?? process.argv.slice(2);
  const env = options.env ?? process.env;
  const allowed = options.allowed ?? ADMIN_PROJECTS;
  const readFile =
    options.readFile ?? ((filePath: string) => fs.readFileSync(filePath, "utf8"));

  const values = projectFlagValues(argv);
  if (values.length === 0) {
    refuse(`pass the target explicitly: --project <${allowed.join("|")}>.`);
  }
  const projectId = values[0].trim();
  if (projectId.length === 0) {
    refuse("--project was given without a project id.");
  }
  // Two flags that disagree leave the target to whichever one the parser
  // happens to read; neither reading is the operator's intent.
  if (values.some((value) => value.trim() !== projectId)) {
    refuse(`--project was given more than once with different ids (${values.join(", ")}).`);
  }
  if (!allowed.includes(projectId)) {
    refuse(
      `"${projectId}" is not a project this script may target ` +
        `(allowed: ${allowed.join(", ")}).`,
    );
  }

  for (const name of PROJECT_ENV_VARS) {
    const value = env[name];
    if (value !== undefined && value.trim() !== "" && value.trim() !== projectId) {
      refuse(
        `${name} is "${value}" but --project is "${projectId}". ` +
          `Unset ${name} or make it match.`,
      );
    }
  }

  const keyPath = env.GOOGLE_APPLICATION_CREDENTIALS;
  if (keyPath !== undefined && keyPath.trim() !== "") {
    let parsed: unknown;
    try {
      parsed = JSON.parse(readFile(keyPath));
    } catch (err: unknown) {
      const message = err instanceof Error ? err.message : String(err);
      refuse(
        `GOOGLE_APPLICATION_CREDENTIALS points at ${keyPath}, which could not ` +
          `be read as JSON (${message}), so its project cannot be checked.`,
      );
    }
    // A service-account key names its project; a user credential
    // (`authorized_user`) does not, and is checked by the project's IAM
    // instead.
    const keyProject = (parsed as { project_id?: unknown } | null)?.project_id;
    if (typeof keyProject === "string" && keyProject !== projectId) {
      refuse(
        `GOOGLE_APPLICATION_CREDENTIALS is a key for "${keyProject}" but ` +
          `--project is "${projectId}".`,
      );
    }
  }

  return projectId;
}
