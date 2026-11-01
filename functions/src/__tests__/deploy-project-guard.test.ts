/**
 * BUT-451: guard that CI can only ever name a Firebase project through the
 * GitHub Environment it runs in.
 *
 * A second project (staging) beside production makes "which project does this
 * line write to" a question every workflow has to answer, and a literal
 * production id typed into one of them answers it wrongly the first time that
 * workflow runs for staging. The environment's `FIREBASE_PROJECT_ID` variable
 * is the single answer.
 *
 * Reads files as text, the way `_dart-guard-triggers.ts` and
 * `scripts/check-test-registration.js` read workflow YAML: no YAML dependency,
 * and each check asserts it found something to check, so a parse miss reddens
 * instead of passing over nothing.
 *
 * Run with: npx ts-node src/__tests__/deploy-project-guard.test.ts
 */

import * as fs from "fs";
import * as path from "path";

const REPO_ROOT = path.resolve(__dirname, "..", "..", "..");
const WORKFLOWS_DIR = path.join(REPO_ROOT, ".github", "workflows");

const PRODUCTION_ID = "butlery-prod";
/** The production project being replaced (BUT-2427); no workflow may name it either. */
const RETIRING_PRODUCTION_ID = "butlery-app-1";
const PRODUCTION_IDS = [PRODUCTION_ID, RETIRING_PRODUCTION_ID];
const STAGING_ID = "butlery-app-staging";

/**
 * Workflows that may contain the production id. Empty: every workflow reads
 * it from `vars.FIREBASE_PROJECT_ID`, and the deploy guards compare it with
 * `.firebaserc` instead of with a typed id. An entry needs a reason a reader
 * can check.
 */
const PRODUCTION_LITERAL_ALLOWED = new Map<string, string>([]);

/** Workflows that run against emulators only and must never learn the staging id. */
const EMULATOR_WORKFLOWS = [
  "emulator-lane.yml",
  "e2e_tests.yml",
  "firestore-rules.yml",
];

/** Where a script that copies data between projects could live. */
const SCRIPT_DIRS = [".github/workflows", "scripts", "functions/scripts"];

/**
 * The inputs above, which the CF unit-test workflow must trigger on — otherwise
 * an edit that breaks this guard never runs it.
 */
const REQUIRED_TRIGGER_PATHS = [
  ".github/workflows/**",
  ".firebaserc",
  "scripts/**",
  "functions/scripts/**",
];

let totalRun = 0;
let totalFailed = 0;

function record(name: string, ok: boolean, detail?: string): void {
  totalRun++;
  if (ok) {
    console.log(`  PASS  ${name}`);
  } else {
    totalFailed++;
    console.log(`  FAIL  ${name}${detail ? ` — ${detail}` : ""}`);
  }
}

function workflowFiles(): Array<{ name: string; text: string }> {
  return fs
    .readdirSync(WORKFLOWS_DIR)
    .filter((f) => f.endsWith(".yml") || f.endsWith(".yaml"))
    .sort()
    .map((name) => ({
      name,
      text: fs.readFileSync(path.join(WORKFLOWS_DIR, name), "utf8"),
    }));
}

function filesUnder(relativeDir: string): string[] {
  const out: string[] = [];
  const walk = (dir: string): void => {
    if (!fs.existsSync(dir)) return;
    for (const entry of fs.readdirSync(dir, { withFileTypes: true })) {
      if (entry.name === "node_modules" || entry.name.startsWith(".")) continue;
      const full = path.join(dir, entry.name);
      if (entry.isDirectory()) walk(full);
      else if (entry.isFile()) out.push(full);
    }
  };
  walk(path.join(REPO_ROOT, relativeDir));
  return out;
}

function testWorkflowsAreFound(): void {
  const files = workflowFiles();
  record(
    "the guard finds the workflows it checks",
    files.length > 0 && files.some((f) => f.name === "deploy-firebase.yml"),
    `found ${files.length} files in ${WORKFLOWS_DIR}`,
  );
}

function testNoWorkflowNamesProductionLiterally(): void {
  const offenders: string[] = [];
  for (const { name, text } of workflowFiles()) {
    if (PRODUCTION_LITERAL_ALLOWED.has(name)) continue;
    text.split(/\r?\n/).forEach((line, i) => {
      if (PRODUCTION_IDS.some((id) => line.includes(id))) {
        offenders.push(`${name}:${i + 1}`);
      }
    });
  }
  record(
    `no workflow contains the literal ${PRODUCTION_IDS.join(" or ")}`,
    offenders.length === 0,
    `use \${{ vars.FIREBASE_PROJECT_ID }} instead: ${offenders.join(", ")}`,
  );
}

/**
 * A `--project` value is accepted when it is the environment's variable, a
 * shell variable set from it, or an emulator `demo-` project (the Firebase CLI
 * never contacts a real backend for a `demo-` id).
 */
const ENV_DERIVED_VALUES = [
  /^"?\$\{\{\s*vars\.FIREBASE_PROJECT_ID\s*\}\}"?$/,
  /^"?\$\{?FIREBASE_PROJECT_ID\}?"?$/,
  /^"?\$\{?PROJECT\}?"?$/,
  /^demo-[a-z0-9-]+$/,
];

function testEveryProjectArgumentIsEnvDerived(): void {
  const offenders: string[] = [];
  const projectVarOffenders: string[] = [];
  let seen = 0;
  for (const { name, text } of workflowFiles()) {
    text.split(/\r?\n/).forEach((line, i) => {
      // `xcode-project --project ios/Runner.xcodeproj` names an Xcode project,
      // not a cloud one.
      if (line.includes("xcode-project")) return;
      // A `${{ … }}` expression holds spaces, so it is matched whole first.
      // The Firebase CLI also takes `-P`, and `firebase use <id>` switches the
      // project for every later command; an action names it in `projectId:` or
      // `project_id:`. `-P` is read only on a firebase line: `grep -P` is not one.
      const flag = line.includes("firebase") ? "(?:--project|-P)" : "--project";
      const re = new RegExp(
        String.raw`(?:${flag}(?:=|\s+)|firebase\s+use\s+|\bproject_?[iI]d:\s*)` +
          String.raw`("?\$\{\{[^}]*\}\}"?|\S+)`,
        "g",
      );
      let m: RegExpExecArray | null;
      while ((m = re.exec(line)) !== null) {
        seen++;
        // Trailing shell or Markdown punctuation (a comment quotes the flag in
        // backticks) is not part of the value.
        const value = m[1].replace(/[;)`]+$/, "");
        if (!ENV_DERIVED_VALUES.some((ok) => ok.test(value))) {
          offenders.push(`${name}:${i + 1} (${value})`);
        }
      }
      // `$PROJECT` is only accepted above because every assignment of it is
      // this one.
      const assign = /^\s*PROJECT=(\S+)/.exec(line);
      if (assign && assign[1] !== '"$FIREBASE_PROJECT_ID"') {
        projectVarOffenders.push(`${name}:${i + 1} (${assign[1]})`);
      }
    });
  }
  record(
    "the workflows pass --project at all (the check below is not vacuous)",
    seen > 0,
  );
  record(
    "every --project argument comes from the environment",
    offenders.length === 0,
    offenders.join(", "),
  );
  record(
    "every PROJECT= assignment in a workflow is the environment variable",
    projectVarOffenders.length === 0,
    projectVarOffenders.join(", "),
  );
}

function testFirebasercHasExactlyTheTwoAliases(): void {
  const rcPath = path.join(REPO_ROOT, ".firebaserc");
  let rc: { projects?: Record<string, unknown> } = {};
  try {
    rc = JSON.parse(fs.readFileSync(rcPath, "utf8"));
  } catch (e) {
    record(".firebaserc parses", false, String(e));
    return;
  }
  const projects = rc.projects ?? {};
  const keys = Object.keys(projects).sort();
  record(
    ".firebaserc has exactly the production and staging aliases",
    JSON.stringify(keys) === JSON.stringify(["production", "staging"]) &&
      projects.production === PRODUCTION_ID &&
      projects.staging === STAGING_ID,
    JSON.stringify(projects),
  );
  // A `default` alias is what `firebase deploy` without `--project` would use.
  // Without one, a forgotten flag fails instead of picking a project.
  record(
    ".firebaserc has no default alias",
    !("default" in projects),
    JSON.stringify(projects),
  );
}

function testEmulatorWorkflowsNeverNameStaging(): void {
  for (const file of EMULATOR_WORKFLOWS) {
    const full = path.join(WORKFLOWS_DIR, file);
    if (!fs.existsSync(full)) {
      record(`${file} exists`, false, "rename it in EMULATOR_WORKFLOWS");
      continue;
    }
    record(
      `${file} does not mention ${STAGING_ID}`,
      !fs.readFileSync(full, "utf8").includes(STAGING_ID),
    );
  }
}

/**
 * Production data never moves into staging, so nothing may export from one
 * project and import or restore into the other. A file that names both ids and
 * also runs a copy command is refused whichever way it copies.
 */
const COPY_COMMAND = new RegExp(
  [
    String.raw`firestore\s+(export|import)`,
    String.raw`firestore:(export|import)`,
    String.raw`databases\s+restore`,
    String.raw`backups?\s+restore`,
  ].join("|"),
);

function testNoCrossProjectCopy(): void {
  const offenders: string[] = [];
  let scanned = 0;
  for (const dir of SCRIPT_DIRS) {
    for (const file of filesUnder(dir)) {
      scanned++;
      const text = fs.readFileSync(file, "utf8");
      if (
        PRODUCTION_IDS.some((id) => text.includes(id)) &&
        text.includes(STAGING_ID) &&
        COPY_COMMAND.test(text)
      ) {
        offenders.push(
          path.relative(REPO_ROOT, file).split(path.sep).join("/"),
        );
      }
    }
  }
  record("the copy scan read some files", scanned > 0, SCRIPT_DIRS.join(", "));
  record(
    "no workflow or script exports, imports or restores between the two projects",
    offenders.length === 0,
    offenders.join(", "),
  );
}

/** The quoted entries under one trigger's `paths:` block, comments skipped. */
function pathsUnder(workflow: string, trigger: string): string[] {
  const at = workflow.indexOf(`\n  ${trigger}:`);
  if (at < 0) return [];
  // Stop at the next trigger, so a trigger without its own `paths:` block is
  // not credited with the following trigger's list.
  const next = workflow.slice(at + 1).search(/\n  [a-z_]+:/);
  const end = next < 0 ? workflow.length : at + 1 + next;
  const pathsAt = workflow.indexOf("paths:", at);
  if (pathsAt < 0 || pathsAt > end) return [];
  const entries: string[] = [];
  for (const line of workflow.slice(pathsAt).split(/\r?\n/).slice(1)) {
    const t = line.trim();
    if (t === "" || t.startsWith("#")) continue;
    if (!t.startsWith("- ")) break;
    entries.push(
      t
        .slice(2)
        .trim()
        .replace(/^["']|["']$/g, ""),
    );
  }
  return entries;
}

/**
 * Every workflow that runs in the `production` environment.
 */
const PRODUCTION_CLOUD_WORKFLOWS = [
  "backfill-age-claim.yml",
  "deploy-admin-web.yml",
  "deploy-app-link-files.yml",
  "deploy-firebase.yml",
  "deploy-hosting.yml",
  "measure-production.yml",
  "migrate-meal-type.yml",
  "repair-feature-retention.yml",
];

/** A job whose environment is, or can be, `production`. */
const PRODUCTION_ENVIRONMENT =
  /^\s*environment:\s*(?:production\s*$|\$\{\{[^}]*'production'[^}]*\}\})/m;

const STAGING_ONLY_KEY_READ =
  /\$\{\{\s*inputs\.environment == 'staging' && secrets\.FIREBASE_SERVICE_ACCOUNT \|\| ''\s*\}\}/;

/**
 * BUT-2421: production signs in with Workload Identity Federation and never
 * with the stored key, and every production workflow compares the WIF
 * token's project with the environment's variable before it acts.
 */
function testProductionWorkflowsSignInWithWif(): void {
  const files = workflowFiles();
  const inProduction = files
    .filter(({ text }) => PRODUCTION_ENVIRONMENT.test(text))
    .map(({ name }) => name);
  const classified = [...PRODUCTION_CLOUD_WORKFLOWS].sort();
  record(
    "every production workflow is a listed cloud workflow",
    JSON.stringify(inProduction) === JSON.stringify(classified),
    `in production: ${inProduction.join(", ")}`,
  );

  for (const name of PRODUCTION_CLOUD_WORKFLOWS) {
    const text = files.find((f) => f.name === name)?.text ?? "";
    const problems: string[] = [];
    if (!text.includes("google-github-actions/auth@")) problems.push("no WIF sign-in");
    if (!text.includes("vars.GCP_WORKLOAD_IDENTITY_PROVIDER")) problems.push("no WIF provider");
    if (!/id-token:\s*write/.test(text)) problems.push("no id-token permission");
    if (!/"\$WIF_PROJECT_ID" = "\$FIREBASE_PROJECT_ID"/.test(text)) {
      problems.push("no WIF project guard");
    }
    if (/--key-file|sa\.json/.test(text)) problems.push("writes or reads a key file");
    record(
      `${name} signs in with WIF and guards the project`,
      text.length > 0 && problems.length === 0,
      text.length === 0 ? "file not found" : problems.join(", "),
    );
  }

  const keyReads: string[] = [];
  for (const { name, text } of files) {
    if (!PRODUCTION_ENVIRONMENT.test(text)) continue;
    text.split(/\r?\n/).forEach((line, i) => {
      if (
        line.includes("secrets.FIREBASE_SERVICE_ACCOUNT") &&
        !STAGING_ONLY_KEY_READ.test(line)
      ) {
        keyReads.push(`${name}:${i + 1}`);
      }
    });
  }
  record(
    "no production job reads FIREBASE_SERVICE_ACCOUNT",
    keyReads.length === 0,
    keyReads.join(", "),
  );
}

function testCiRunsThisGuardWhenItsInputsChange(): void {
  const lane = fs.readFileSync(
    path.join(WORKFLOWS_DIR, "cloud-functions-unit.yml"),
    "utf8",
  );
  for (const trigger of ["push", "pull_request"]) {
    const paths = pathsUnder(lane, trigger);
    const missing = REQUIRED_TRIGGER_PATHS.filter((p) => !paths.includes(p));
    record(
      `cloud-functions-unit.yml ${trigger} trigger covers this guard's inputs`,
      paths.length > 0 && missing.length === 0,
      paths.length === 0
        ? "no paths: block found"
        : `missing ${missing.join(", ")}`,
    );
  }
}

function main(): void {
  console.log("deploy-project-guard tests\n");
  testWorkflowsAreFound();
  testNoWorkflowNamesProductionLiterally();
  testEveryProjectArgumentIsEnvDerived();
  testFirebasercHasExactlyTheTwoAliases();
  testEmulatorWorkflowsNeverNameStaging();
  testNoCrossProjectCopy();
  testProductionWorkflowsSignInWithWif();
  testCiRunsThisGuardWhenItsInputsChange();

  console.log(`\n${totalRun - totalFailed}/${totalRun} checks passed`);
  if (totalFailed > 0) process.exit(1);
}

main();
