/**
 * BUT-1675: guard that every Cloud Functions test file is actually wired into CI.
 *
 * The repo decides what to run from HAND-TYPED lists — npm `test:*` script names
 * and a workflow `paths:` filter. Both are silent-drift holes: add a test file and
 * forget the script and it never runs; add a rules suite and forget the workflow
 * trigger and the whole rules gate stays dark for that change. Nothing goes red,
 * so nobody notices. This guard turns each hand-typed list into a checked one.
 *
 * Five assertions, all fatal:
 *   1. REGISTERED        — every functions/src/__tests__/**\/*.test.ts is named by
 *                          at least one `test*` script in functions/package.json.
 *   2. NO_STALE_SCRIPT   — every test file a `test*` script names actually exists.
 *   3. CI_REACHABLE      — every test file is executed by a real CI lane: either
 *                          run-ci-unit-tests.js discovery (a `test:*` script that
 *                          is neither `test:rules*` nor `test:integration:*`) or
 *                          the `test:rules:all` chain the Firestore Rules job runs.
 *                          A registered-but-unreachable file is the worst case —
 *                          it LOOKS covered.
 *   4. RULES_TRIGGERS    — every file in `test:rules:all` appears in EVERY `paths:`
 *                          trigger block of .github/workflows/firestore-rules.yml,
 *                          so editing that suite actually fires the rules job.
 *   5. NO_STALE_TRIGGER  — every test path listed in those blocks matches a file.
 *
 * BUT-1709: the guard is itself the thing nothing else checks, so its criteria are
 * expressed as `runCheck(options)` over an injectable tree and exercised against
 * synthetic fixtures in scripts/__tests__/check-test-registration.test.js. Keep new
 * criteria inside runCheck — anything that reads the real repo at module load is,
 * by construction, untestable.
 *
 * Plain Node, no deps. Runs pre-commit (lefthook) and in the CF unit-test job.
 */

const fs = require("fs");
const path = require("path");

const FUNCTIONS_DIR = path.resolve(__dirname, "..");
const REPO_ROOT = path.resolve(FUNCTIONS_DIR, "..");

// Mirrors run-all-tests.js / run-ci-unit-tests.js discovery: these prefixes are
// emulator-bound and therefore skipped by the non-emulator unit runners.
const NON_UNIT_PREFIXES = ["test:rules", "test:integration:"];

/**
 * Every allowlist entry must name a Linear ticket. Prose alone is how an
 * allowlist quietly becomes the default landing spot for anything inconvenient;
 * a ticket reference gives the exemption an owner and an end date, and the
 * TICKET_RE check below reddens an entry that lacks one.
 */
const TICKET_RE = /\bBUT-\d+\b/;

/**
 * Test files knowingly not referenced by any script. Empty by default — mirrors
 * the CI_EXCLUDE contract in run-ci-unit-tests.js, but ticket-backed.
 */
const UNREGISTERED_OK = new Map([
  // (empty — a test file with no script runs nowhere; write the script instead)
]);

/**
 * Pre-existing debt, NOT an escape hatch for new files.
 *
 * These four suites have a `test:integration:*` script — so they look wired —
 * but no CI lane runs them: the unit runners skip `test:integration:*`, and the
 * `test:rules:all` chain the Firestore Rules job executes never names them. They
 * are emulator-backed and unverified in CI, so wiring them up is a behaviour
 * change with its own risk; it is tracked separately rather than smuggled into
 * the ticket that added this guard. Every run prints them as a warning so the
 * debt cannot go quiet. Do not extend this list to silence a NEW orphan — wire
 * the file into a lane instead.
 */
const KNOWN_UNREACHABLE = new Map([
  [
    "family-rating-aggregation.integration.test.ts",
    "BUT-1702 — emulator suite, unverified in CI",
  ],
  [
    "cleanup-rate-limits.integration.test.ts",
    "BUT-1702 — emulator suite, unverified in CI",
  ],
  [
    "cleanup-shared-content-metadata.integration.test.ts",
    "BUT-1702 — emulator suite, unverified in CI",
  ],
  [
    "on-user-deleted.integration.test.ts",
    "BUT-1702 — emulator suite, unverified in CI",
  ],
]);

const TEST_PATH_RE = /src\/__tests__\/([A-Za-z0-9_.@\-*]+\.test\.ts)/g;

/** Every basename a script command line points at, deduped. */
function referencedTestFiles(command) {
  const found = new Set();
  const re = new RegExp(TEST_PATH_RE.source, "g");
  let match;
  while ((match = re.exec(command)) !== null) found.add(match[1]);
  return found;
}

/** `firestore-rules*.test.ts` → /^firestore-rules.*\.test\.ts$/ */
function globToRegExp(pattern) {
  const escaped = pattern.replace(/[.+^${}()|[\]\\]/g, "\\$&").replace(/\*/g, ".*");
  return new RegExp(`^${escaped}$`);
}

function matchesAny(name, patterns) {
  for (const pattern of patterns) {
    if (pattern === name) return true;
    if (pattern.includes("*") && globToRegExp(pattern).test(name)) return true;
  }
  return false;
}

/**
 * Collect every `functions/src/__tests__/...` entry under each `paths:` key of
 * the workflow. Hand-rolled rather than pulling in a YAML dep: the shape is a
 * flat list of quoted scalars, and a parse miss shows up as an empty block,
 * which the caller treats as fatal rather than as "nothing to check".
 */
function workflowPathBlocks(yaml) {
  const lines = yaml.split(/\r?\n/);
  const blocks = [];
  for (let i = 0; i < lines.length; i++) {
    const header = /^(\s*)paths:\s*$/.exec(lines[i]);
    if (!header) continue;
    const indent = header[1].length;
    // Nearest less-indented key above is the trigger this block belongs to, so
    // a failure can say "push" rather than only a line number.
    let trigger = "unknown trigger";
    for (let k = i - 1; k >= 0; k--) {
      const key = /^(\s*)([A-Za-z_][A-Za-z0-9_-]*):/.exec(lines[k]);
      if (key && key[1].length < indent) {
        trigger = key[2];
        break;
      }
    }
    const entries = [];
    for (let j = i + 1; j < lines.length; j++) {
      const line = lines[j];
      if (line.trim() === "" || line.trim().startsWith("#")) continue;
      const item = /^(\s*)-\s+(.*)$/.exec(line);
      if (!item || item[1].length <= indent) break;
      entries.push(item[2].trim().replace(/^["']|["']$/g, ""));
    }
    blocks.push({ trigger, line: i + 1, entries });
  }
  return blocks;
}

/**
 * Run every criterion against a tree. Pure apart from the reads it is told to
 * do, so a fixture directory exercises exactly the code CI runs.
 *
 * Returns `{ failures, warnings, summary }`; the caller decides how to exit.
 * `fatalNoTests` distinguishes "this tree has no test files" (fatal for the
 * real repo, since a vacuous pass is the failure mode) from the fixture case.
 */
function runCheck({
  functionsDir = FUNCTIONS_DIR,
  repoRoot = REPO_ROOT,
  rulesWorkflow = null,
  unregisteredOk = UNREGISTERED_OK,
  knownUnreachable = KNOWN_UNREACHABLE,
} = {}) {
  const testsDir = path.join(functionsDir, "src", "__tests__");
  const workflowPath =
    rulesWorkflow ??
    path.join(repoRoot, ".github", "workflows", "firestore-rules.yml");

  const failures = [];
  const warnings = [];
  const fail = (check, message) => failures.push(`[${check}] ${message}`);

  const pkg = JSON.parse(
    fs.readFileSync(path.join(functionsDir, "package.json"), "utf8"),
  );
  const testFiles = fs.existsSync(testsDir)
    ? fs
        .readdirSync(testsDir)
        .filter((name) => name.endsWith(".test.ts"))
        .sort()
    : [];

  if (testFiles.length === 0) {
    fail(
      "NO_TESTS",
      "no *.test.ts found under src/__tests__ — refusing to pass vacuously.",
    );
    return { failures, warnings, summary: null, testFiles };
  }

  const scripts = Object.entries(pkg.scripts ?? {}).filter(([name]) =>
    name.startsWith("test"),
  );

  const registered = new Set();
  const unitLaneReachable = new Set();
  for (const [name, command] of scripts) {
    const files = referencedTestFiles(command);
    const isUnitLane =
      name.startsWith("test:") &&
      !NON_UNIT_PREFIXES.some((prefix) => name.startsWith(prefix));
    for (const file of files) {
      registered.add(file);
      if (isUnitLane) unitLaneReachable.add(file);
    }
  }

  const rulesAllCommand = pkg.scripts?.["test:rules:all"];
  if (!rulesAllCommand) {
    fail(
      "RULES_TRIGGERS",
      "functions/package.json has no `test:rules:all` script — the Firestore Rules job runs that chain; nothing to verify against.",
    );
  }
  const rulesChain = rulesAllCommand
    ? referencedTestFiles(rulesAllCommand)
    : new Set();

  // 0. The allowlists themselves.
  for (const [listName, list] of [
    ["UNREGISTERED_OK", unregisteredOk],
    ["KNOWN_UNREACHABLE", knownUnreachable],
  ]) {
    for (const [file, reason] of list) {
      if (!TICKET_RE.test(reason ?? "")) {
        fail(
          "ALLOWLIST",
          `${listName} entry "${file}" has no Linear ticket reference (expected e.g. BUT-1234) — an exemption without an owner never expires.`,
        );
      }
    }
  }

  // 1. REGISTERED
  for (const file of testFiles) {
    if (registered.has(file)) continue;
    const known = unregisteredOk.get(file);
    if (known) {
      warnings.push(`${file} is referenced by no script (accepted, ${known}).`);
      continue;
    }
    fail(
      "REGISTERED",
      `${file} is named by no test* script in functions/package.json — it never runs. Add e.g. "test:${file.replace(/\.test\.ts$/, "")}": "ts-node src/__tests__/${file}".`,
    );
  }

  // 2. NO_STALE_SCRIPT
  const existing = new Set(testFiles);
  for (const file of registered) {
    if (!existing.has(file)) {
      fail(
        "NO_STALE_SCRIPT",
        `a test* script points at functions/src/__tests__/${file}, which does not exist — delete the script entry.`,
      );
    }
  }

  // 3. CI_REACHABLE
  for (const file of testFiles) {
    if (!registered.has(file)) continue; // already reported by REGISTERED
    if (unitLaneReachable.has(file) || rulesChain.has(file)) continue;
    const known = knownUnreachable.get(file);
    if (known) {
      warnings.push(
        `${file} is registered but NO CI lane runs it (accepted debt, ${known}).`,
      );
      continue;
    }
    fail(
      "CI_REACHABLE",
      `${file} has a script but no CI lane runs it: the unit runners skip test:rules*/test:integration:* and \`test:rules:all\` does not name it. Rename the script to a unit-lane name, or append the file to test:rules:all so the emulator job runs it.`,
    );
  }

  // 4 + 5. Workflow trigger blocks
  const yaml = fs.readFileSync(workflowPath, "utf8");
  const blocks = workflowPathBlocks(yaml);
  if (blocks.length < 2) {
    fail(
      "RULES_TRIGGERS",
      `expected at least 2 \`paths:\` trigger blocks in .github/workflows/firestore-rules.yml (pull_request + push), parsed ${blocks.length}. Either a trigger was dropped or this guard's parser needs updating.`,
    );
  }

  for (const block of blocks) {
    const testEntries = block.entries
      .filter((entry) => entry.startsWith("functions/src/__tests__/"))
      .map((entry) => entry.slice("functions/src/__tests__/".length));

    if (testEntries.length === 0) {
      fail(
        "RULES_TRIGGERS",
        `the \`${block.trigger}\` trigger's \`paths:\` block (firestore-rules.yml line ${block.line}) lists no test files — a change to any rules suite would not fire the job.`,
      );
      continue;
    }

    for (const file of rulesChain) {
      if (!matchesAny(file, testEntries)) {
        fail(
          "RULES_TRIGGERS",
          `${file} runs in test:rules:all but is missing from the \`${block.trigger}\` trigger's \`paths:\` block (firestore-rules.yml line ${block.line}) — editing it would not fire the rules job. Add "functions/src/__tests__/${file}".`,
        );
      }
    }

    for (const entry of testEntries) {
      const matches = entry.includes("*")
        ? testFiles.some((file) => globToRegExp(entry).test(file))
        : existing.has(entry);
      if (!matches) {
        fail(
          "NO_STALE_TRIGGER",
          `the \`${block.trigger}\` trigger's \`paths:\` block (firestore-rules.yml line ${block.line}) lists functions/src/__tests__/${entry}, which matches no file — delete the stale entry.`,
        );
      }
    }
  }

  return {
    failures,
    warnings,
    testFiles,
    summary: `${testFiles.length} test files registered, ${rulesChain.size} rules suites triggered by ${blocks.length} paths blocks`,
  };
}

module.exports = {
  runCheck,
  referencedTestFiles,
  workflowPathBlocks,
  globToRegExp,
  matchesAny,
};

if (require.main === module) {
  const { failures, warnings, summary } = runCheck();

  for (const warning of warnings) console.warn(`WARN  ${warning}`);

  if (failures.length > 0) {
    console.error(
      `\ncheck-test-registration: ${failures.length} problem(s) — a test file or rules trigger is not wired into CI.\n`,
    );
    for (const failure of failures) console.error(`  - ${failure}`);
    console.error("");
    process.exit(1);
  }

  console.log(
    `check-test-registration: OK — ${summary}${warnings.length ? `, ${warnings.length} accepted-debt warning(s)` : ""}.`,
  );
}
