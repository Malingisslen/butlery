/**
 * BUT-2419: the project gate for hand-run admin scripts.
 *
 * What this proves, with an injected environment and key-file reader so no
 * project, credential or network is involved:
 * 1. No `--project`, an empty one, or two that disagree are refused.
 * 2. Only allowlisted ids pass; `demo-` and unknown ids are refused, and a
 *    narrowed allowlist refuses production.
 * 3. GOOGLE_CLOUD_PROJECT / GCLOUD_PROJECT naming another project is refused.
 * 4. A service-account key for another project is refused, as is a key file
 *    that cannot be read; a user credential without `project_id` passes.
 * 5. `initializeAdminApp` refuses before `initializeApp`: no app exists after.
 *
 * Run: ts-node src/__tests__/require-project.test.ts
 */

import * as admin from "firebase-admin";
import { initializeAdminApp, resolveCredentialPath } from "../admin/admin-init";
import {
  ADMIN_PROJECTS,
  PRODUCTION_PROJECT,
  projectFlagValues,
  requireProject,
  RequireProjectOptions,
  RETIRING_PRODUCTION_PROJECT,
  STAGING_PROJECT,
} from "../admin/require-project";

let failed = 0;
function assert(cond: boolean, msg: string): void {
  if (cond) {
    console.log(`  PASS  ${msg}`);
  } else {
    failed++;
    console.log(`  FAIL  ${msg}`);
  }
}

function refusal(options: RequireProjectOptions): string | null {
  try {
    requireProject({ env: {}, ...options });
    return null;
  } catch (err: unknown) {
    return err instanceof Error ? err.message : String(err);
  }
}

function refuses(
  options: RequireProjectOptions,
  pattern: RegExp,
  msg: string,
): void {
  const message = refusal(options);
  assert(
    message !== null && /^REFUSED: /.test(message) && pattern.test(message),
    msg,
  );
}

function keyFiles(files: Record<string, string>): (p: string) => string {
  return (p: string) => {
    if (!(p in files)) throw new Error(`ENOENT: ${p}`);
    return files[p];
  };
}

const STAGING_KEY = JSON.stringify({
  type: "service_account",
  project_id: STAGING_PROJECT,
});
const PROD_KEY = JSON.stringify({
  type: "service_account",
  project_id: PRODUCTION_PROJECT,
});
const USER_CREDENTIAL = JSON.stringify({
  type: "authorized_user",
  client_id: "x",
  quota_project_id: "somewhere-else",
});

function testFlagParsing(): void {
  console.log("flag parsing");
  assert(
    JSON.stringify(projectFlagValues(["--dry-run", "--project", "a"])) ===
      '["a"]',
    "--project <id> is read",
  );
  assert(
    JSON.stringify(projectFlagValues(["--project=a"])) === '["a"]',
    "--project=<id> is read",
  );
  assert(
    JSON.stringify(projectFlagValues(["--project", "--live"])) === '[""]',
    "a following flag is not taken as the id",
  );
}

function testMissingAndEmpty(): void {
  console.log("missing and empty");
  refuses({ argv: [] }, /--project/, "no --project is refused");
  refuses(
    { argv: ["--dry-run"] },
    /--project/,
    "other flags without --project are refused",
  );
  refuses(
    { argv: ["--project"] },
    /without a project id/,
    "a bare --project is refused",
  );
  refuses(
    { argv: ["--project="] },
    /without a project id/,
    "--project= is refused",
  );
  refuses(
    { argv: ["--project", "  "] },
    /without a project id/,
    "a blank id is refused",
  );
  refuses(
    { argv: ["--project", STAGING_PROJECT, `--project=${PRODUCTION_PROJECT}`] },
    /more than once/,
    "two disagreeing --project flags are refused",
  );
}

function testAllowlist(): void {
  console.log("allowlist");
  assert(
    requireProject({ argv: ["--project", PRODUCTION_PROJECT], env: {} }) ===
      PRODUCTION_PROJECT,
    "production passes the default allowlist",
  );
  assert(
    requireProject({ argv: [`--project=${STAGING_PROJECT}`], env: {} }) ===
      STAGING_PROJECT,
    "staging passes the default allowlist",
  );
  assert(
    requireProject({
      argv: ["--project", RETIRING_PRODUCTION_PROJECT],
      env: {},
    }) === RETIRING_PRODUCTION_PROJECT,
    "the retiring production project passes the default allowlist",
  );
  assert(
    ADMIN_PROJECTS.length === 3,
    "the default allowlist holds exactly the three projects",
  );
  refuses(
    { argv: ["--project", "demo-x"] },
    /demo-x.*not a project/,
    "demo-x is refused",
  );
  refuses(
    { argv: ["--project", "butlery-app-2"] },
    /not a project/,
    "an unknown id is refused",
  );
  refuses(
    { argv: ["--project", PRODUCTION_PROJECT], allowed: [STAGING_PROJECT] },
    /not a project/,
    "a staging-only allowlist refuses production",
  );
}

function testEnvironment(): void {
  console.log("environment");
  for (const name of ["GOOGLE_CLOUD_PROJECT", "GCLOUD_PROJECT"]) {
    refuses(
      {
        argv: ["--project", STAGING_PROJECT],
        env: { [name]: PRODUCTION_PROJECT },
      },
      new RegExp(name),
      `${name} naming another project is refused`,
    );
    assert(
      requireProject({
        argv: ["--project", STAGING_PROJECT],
        env: { [name]: STAGING_PROJECT },
      }) === STAGING_PROJECT,
      `${name} naming the same project passes`,
    );
  }
}

function testKeyFile(): void {
  console.log("key file");
  const readFile = keyFiles({
    "staging.json": STAGING_KEY,
    "prod.json": PROD_KEY,
    "user.json": USER_CREDENTIAL,
    "broken.json": "{not json",
  });
  refuses(
    {
      argv: ["--project", PRODUCTION_PROJECT],
      env: { GOOGLE_APPLICATION_CREDENTIALS: "staging.json" },
      readFile,
    },
    /key for "butlery-app-staging"/,
    "production with a staging key is refused",
  );
  refuses(
    {
      argv: ["--project", STAGING_PROJECT],
      env: { GOOGLE_APPLICATION_CREDENTIALS: "prod.json" },
      readFile,
    },
    /key for "butlery-prod"/,
    "staging with a production key is refused",
  );
  refuses(
    {
      argv: ["--project", STAGING_PROJECT],
      env: { GOOGLE_APPLICATION_CREDENTIALS: "missing.json" },
      readFile,
    },
    /could not be read/,
    "an unreadable key file is refused",
  );
  refuses(
    {
      argv: ["--project", STAGING_PROJECT],
      env: { GOOGLE_APPLICATION_CREDENTIALS: "broken.json" },
      readFile,
    },
    /could not be read/,
    "a key file that is not JSON is refused",
  );
  assert(
    requireProject({
      argv: ["--project", STAGING_PROJECT],
      env: { GOOGLE_APPLICATION_CREDENTIALS: "staging.json" },
      readFile,
    }) === STAGING_PROJECT,
    "a matching key passes",
  );
  assert(
    requireProject({
      argv: ["--project", STAGING_PROJECT],
      env: { GOOGLE_APPLICATION_CREDENTIALS: "user.json" },
      readFile,
    }) === STAGING_PROJECT,
    "a user credential without project_id passes",
  );
}

function testInitializeAdminAppRefusesFirst(): void {
  console.log("initializeAdminApp");
  for (const argv of [[], ["--project", "demo-x"], ["--project", ""]]) {
    let threw = false;
    try {
      initializeAdminApp({ argv, env: {} });
    } catch {
      threw = true;
    }
    assert(
      threw && admin.apps.length === 0,
      `refuses [${argv.join(" ")}] with no app initialized`,
    );
  }
}

function testCredentialResolution(): void {
  console.log("resolveCredentialPath");
  let looked = false;
  const find = (): string => {
    looked = true;
    return "cli.json";
  };
  assert(
    resolveCredentialPath(
      { GOOGLE_APPLICATION_CREDENTIALS: "named.json" },
      find,
    ) === "named.json" && !looked,
    "a named key wins and the CLI credential is not looked up",
  );
  assert(
    resolveCredentialPath({}, find) === "cli.json",
    "the CLI credential is used only when no key is named",
  );
  assert(
    resolveCredentialPath({}, () => null) === undefined,
    "no credential at all resolves to undefined",
  );
}

function testInitializeAdminAppChecksTheCliCredential(): void {
  console.log("initializeAdminApp checks the credential it found");
  let threw = "";
  try {
    initializeAdminApp({
      argv: ["--project", STAGING_PROJECT],
      env: {},
      findCredentials: () => "prod.json",
      readFile: keyFiles({ "prod.json": PROD_KEY }),
    });
  } catch (e) {
    threw = String(e);
  }
  assert(
    threw.includes(PRODUCTION_PROJECT) && admin.apps.length === 0,
    "a CLI credential for production is refused for --project staging",
  );
}

function main(): void {
  console.log("require-project");
  testFlagParsing();
  testMissingAndEmpty();
  testAllowlist();
  testEnvironment();
  testKeyFile();
  testInitializeAdminAppRefusesFirst();
  testCredentialResolution();
  testInitializeAdminAppChecksTheCliCredential();
  console.log(failed === 0 ? "\nAll assertions passed" : `\n${failed} FAILED`);
  process.exit(failed === 0 ? 0 : 1);
}

main();
