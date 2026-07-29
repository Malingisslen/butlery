/**
 * BUT-1709: tests for the CI-wiring guard.
 *
 * check-test-registration.js is the thing that notices when a test file stops
 * running. Nothing noticed if IT stopped noticing: the guard passed green on
 * the real repo, which proves only the happy path — a criterion that had
 * quietly become a no-op (a regex that stopped matching, an early `continue`)
 * would look exactly the same. Each criterion is therefore fired here over a
 * synthetic tree built for that one failure, plus a clean tree that must stay
 * silent so the negatives aren't just "everything fails".
 *
 * Plain Node + node:assert, run by `npm run test:script-test-registration`,
 * which run-ci-unit-tests.js discovers and the CF unit-test job executes —
 * i.e. the very lane whose reachability this guard checks.
 */

const assert = require("assert");
const fs = require("fs");
const os = require("os");
const path = require("path");

const { runCheck, workflowPathBlocks } = require("../check-test-registration.js");

const results = [];
function test(name, fn) {
  try {
    fn();
    results.push({ name, ok: true });
  } catch (err) {
    results.push({ name, ok: false, err });
  }
}

const codesOf = (failures) =>
  failures.map((f) => /^\[([A-Z_]+)\]/.exec(f)?.[1]).sort();

/** A workflow with the two `paths:` trigger blocks the guard expects. */
function workflowYaml(entriesByTrigger) {
  const block = (trigger, extra, entries) =>
    [
      `  ${trigger}:`,
      ...extra,
      "    paths:",
      ...entries.map((entry) => `      - "${entry}"`),
    ].join("\n");
  return [
    "name: Firestore Rules",
    "on:",
    block("pull_request", [], entriesByTrigger.pull_request),
    block("push", ["    branches: [main]"], entriesByTrigger.push),
    "jobs:",
    "  rules-tests:",
    "    runs-on: ubuntu-latest",
    "",
  ].join("\n");
}

/**
 * Build a throwaway functions tree.
 *
 * `tests` are basenames created under src/__tests__; `scripts` is the
 * package.json test-script map; `triggers` overrides the workflow entries
 * (defaults to exactly the test:rules:all chain, i.e. a correct workflow).
 */
function makeTree({ tests, scripts, triggers }) {
  const root = fs.mkdtempSync(path.join(os.tmpdir(), "cf-guard-fixture-"));
  const testsDir = path.join(root, "functions", "src", "__tests__");
  fs.mkdirSync(testsDir, { recursive: true });
  for (const name of tests) {
    fs.writeFileSync(path.join(testsDir, name), "// fixture\n");
  }
  fs.writeFileSync(
    path.join(root, "functions", "package.json"),
    JSON.stringify({ name: "fixture", scripts }, null, 2),
  );

  const chain = scripts["test:rules:all"] ?? "";
  const chainFiles = [...chain.matchAll(/src\/__tests__\/([\w.@-]+\.test\.ts)/g)].map(
    (m) => `functions/src/__tests__/${m[1]}`,
  );
  const entries = triggers ?? { pull_request: chainFiles, push: chainFiles };
  const workflowPath = path.join(root, "firestore-rules.yml");
  fs.writeFileSync(workflowPath, workflowYaml(entries));

  return {
    functionsDir: path.join(root, "functions"),
    repoRoot: root,
    rulesWorkflow: workflowPath,
  };
}

const check = (tree, extra = {}) =>
  runCheck({
    ...tree,
    unregisteredOk: new Map(),
    knownUnreachable: new Map(),
    ...extra,
  });

// ── the clean tree must stay silent ───────────────────────────────────────

const cleanTree = () =>
  makeTree({
    tests: ["alpha.test.ts", "beta-rules.test.ts"],
    scripts: {
      "test:alpha": "ts-node src/__tests__/alpha.test.ts",
      "test:rules:beta": "ts-node src/__tests__/beta-rules.test.ts",
      "test:rules:all": "ts-node src/__tests__/beta-rules.test.ts",
    },
  });

test("a correctly wired tree produces no failures and no warnings", () => {
  const result = check(cleanTree());
  assert.deepStrictEqual(result.failures, []);
  assert.deepStrictEqual(result.warnings, []);
  assert.match(result.summary, /2 test files registered/);
});

// ── negative paths, one criterion at a time ───────────────────────────────

test("REGISTERED fires for a test file no script names", () => {
  const tree = makeTree({
    tests: ["alpha.test.ts", "orphan.test.ts", "beta-rules.test.ts"],
    scripts: {
      "test:alpha": "ts-node src/__tests__/alpha.test.ts",
      "test:rules:all": "ts-node src/__tests__/beta-rules.test.ts",
    },
  });
  const result = check(tree);
  assert.deepStrictEqual(codesOf(result.failures), ["REGISTERED"]);
  assert.match(result.failures[0], /orphan\.test\.ts/);
});

test("NO_STALE_SCRIPT fires for a script pointing at a deleted file", () => {
  const tree = makeTree({
    tests: ["alpha.test.ts", "beta-rules.test.ts"],
    scripts: {
      "test:alpha": "ts-node src/__tests__/alpha.test.ts",
      "test:ghost": "ts-node src/__tests__/ghost.test.ts",
      "test:rules:all": "ts-node src/__tests__/beta-rules.test.ts",
    },
  });
  const result = check(tree);
  assert.deepStrictEqual(codesOf(result.failures), ["NO_STALE_SCRIPT"]);
  assert.match(result.failures[0], /ghost\.test\.ts/);
});

test("CI_REACHABLE fires for a file only an integration script names — the LOOKS-covered case", () => {
  const tree = makeTree({
    tests: ["alpha.test.ts", "orphaned.integration.test.ts", "beta-rules.test.ts"],
    scripts: {
      "test:alpha": "ts-node src/__tests__/alpha.test.ts",
      "test:integration:orphaned":
        "ts-node src/__tests__/orphaned.integration.test.ts",
      "test:rules:all": "ts-node src/__tests__/beta-rules.test.ts",
    },
  });
  const result = check(tree);
  assert.deepStrictEqual(codesOf(result.failures), ["CI_REACHABLE"]);
  assert.match(result.failures[0], /orphaned\.integration\.test\.ts/);
});

test("CI_REACHABLE also fires for a rules-prefixed script the test:rules:all chain forgot", () => {
  const tree = makeTree({
    tests: ["alpha.test.ts", "beta-rules.test.ts", "gamma-rules.test.ts"],
    scripts: {
      "test:alpha": "ts-node src/__tests__/alpha.test.ts",
      "test:rules:gamma": "ts-node src/__tests__/gamma-rules.test.ts",
      "test:rules:all": "ts-node src/__tests__/beta-rules.test.ts",
    },
  });
  const result = check(tree);
  assert.ok(codesOf(result.failures).includes("CI_REACHABLE"));
  assert.ok(result.failures.some((f) => /gamma-rules\.test\.ts/.test(f)));
});

// The `push` block MUST carry a real test entry that simply is not the chained
// one. `RULES_TRIGGERS` is raised from two branches — "this block lists no test
// files at all" and "this chained suite is missing from the block" — and both
// messages name the trigger, so a fixture with an EMPTY push block (e.g.
// `["firestore.rules"]`) trips the wrong branch and the per-file `matchesAny`
// check goes unpinned: neutering it to `if (false)` left this suite green.
// Assert on branch-unique text, never on the shared code alone.
test("RULES_TRIGGERS fires when a chained suite is missing from ONE trigger block", () => {
  const tree = makeTree({
    tests: ["alpha.test.ts", "beta-rules.test.ts"],
    scripts: {
      "test:alpha": "ts-node src/__tests__/alpha.test.ts",
      "test:rules:all": "ts-node src/__tests__/beta-rules.test.ts",
    },
    triggers: {
      pull_request: ["functions/src/__tests__/beta-rules.test.ts"],
      push: ["functions/src/__tests__/alpha.test.ts"],
    },
  });
  const result = check(tree);
  assert.deepStrictEqual(codesOf(result.failures), ["RULES_TRIGGERS"]);
  assert.match(
    result.failures[0],
    /beta-rules\.test\.ts runs in test:rules:all but is missing from the `push` trigger/,
  );
});

test("NO_STALE_TRIGGER fires for a trigger entry matching no file", () => {
  const tree = makeTree({
    tests: ["alpha.test.ts", "beta-rules.test.ts"],
    scripts: {
      "test:alpha": "ts-node src/__tests__/alpha.test.ts",
      "test:rules:all": "ts-node src/__tests__/beta-rules.test.ts",
    },
    triggers: {
      pull_request: [
        "functions/src/__tests__/beta-rules.test.ts",
        "functions/src/__tests__/deleted-rules.test.ts",
      ],
      push: [
        "functions/src/__tests__/beta-rules.test.ts",
        "functions/src/__tests__/deleted-rules.test.ts",
      ],
    },
  });
  const result = check(tree);
  assert.deepStrictEqual(codesOf(result.failures), [
    "NO_STALE_TRIGGER",
    "NO_STALE_TRIGGER",
  ]);
});

test("a glob trigger entry counts as covering the files it matches", () => {
  const tree = makeTree({
    tests: ["alpha.test.ts", "beta-rules.test.ts"],
    scripts: {
      "test:alpha": "ts-node src/__tests__/alpha.test.ts",
      "test:rules:all": "ts-node src/__tests__/beta-rules.test.ts",
    },
    triggers: {
      pull_request: ["functions/src/__tests__/beta-*.test.ts"],
      push: ["functions/src/__tests__/beta-*.test.ts"],
    },
  });
  assert.deepStrictEqual(check(tree).failures, []);
});

test("RULES_TRIGGERS fires when a trigger block lost its test entries entirely", () => {
  const tree = makeTree({
    tests: ["alpha.test.ts", "beta-rules.test.ts"],
    scripts: {
      "test:alpha": "ts-node src/__tests__/alpha.test.ts",
      "test:rules:all": "ts-node src/__tests__/beta-rules.test.ts",
    },
    triggers: {
      pull_request: ["firestore.rules"],
      push: ["firestore.rules"],
    },
  });
  const result = check(tree);
  assert.deepStrictEqual(codesOf(result.failures), [
    "RULES_TRIGGERS",
    "RULES_TRIGGERS",
  ]);
});

test("a missing test:rules:all script is fatal, not a silent zero-length chain", () => {
  const tree = makeTree({
    tests: ["alpha.test.ts"],
    scripts: { "test:alpha": "ts-node src/__tests__/alpha.test.ts" },
    triggers: {
      pull_request: ["functions/src/__tests__/alpha.test.ts"],
      push: ["functions/src/__tests__/alpha.test.ts"],
    },
  });
  assert.ok(codesOf(check(tree).failures).includes("RULES_TRIGGERS"));
});

test("an empty tests directory fails rather than passing vacuously", () => {
  const tree = makeTree({
    tests: [],
    scripts: { "test:rules:all": "echo none" },
    triggers: { pull_request: ["firestore.rules"], push: ["firestore.rules"] },
  });
  assert.deepStrictEqual(codesOf(check(tree).failures), ["NO_TESTS"]);
});

// ── allowlists ────────────────────────────────────────────────────────────

test("an allowlist entry downgrades a failure to a warning — but only with a ticket", () => {
  const tree = makeTree({
    tests: ["alpha.test.ts", "orphan.test.ts", "beta-rules.test.ts"],
    scripts: {
      "test:alpha": "ts-node src/__tests__/alpha.test.ts",
      "test:rules:all": "ts-node src/__tests__/beta-rules.test.ts",
    },
  });
  const ticketed = check(tree, {
    unregisteredOk: new Map([["orphan.test.ts", "BUT-9999 — fixture"]]),
  });
  assert.deepStrictEqual(ticketed.failures, []);
  assert.strictEqual(ticketed.warnings.length, 1);

  const untickted = check(tree, {
    unregisteredOk: new Map([["orphan.test.ts", "because reasons"]]),
  });
  assert.deepStrictEqual(codesOf(untickted.failures), ["ALLOWLIST"]);
});

// ── the workflow parser the criteria stand on ─────────────────────────────

test("workflowPathBlocks names each block's trigger and stops at the block end", () => {
  const yaml = workflowYaml({
    pull_request: ["firestore.rules", "functions/src/__tests__/a.test.ts"],
    push: ["functions/src/__tests__/b.test.ts"],
  });
  const blocks = workflowPathBlocks(yaml);
  assert.deepStrictEqual(
    blocks.map((b) => b.trigger),
    ["pull_request", "push"],
  );
  assert.deepStrictEqual(blocks[0].entries, [
    "firestore.rules",
    "functions/src/__tests__/a.test.ts",
  ]);
  assert.deepStrictEqual(blocks[1].entries, ["functions/src/__tests__/b.test.ts"]);
});

// ── the real repo, as the guard actually runs it ──────────────────────────

test("the real repository passes its own guard", () => {
  const result = runCheck();
  assert.deepStrictEqual(result.failures, []);
});

// ── report ────────────────────────────────────────────────────────────────

const failed = results.filter((r) => !r.ok);
for (const result of results) {
  console.log(`${result.ok ? "PASS" : "FAIL"}  ${result.name}`);
  if (!result.ok) console.error(`      ${result.err.message}`);
}
console.log(
  `\ncheck-test-registration.test: ${results.length - failed.length}/${results.length} passed.`,
);
if (failed.length > 0) process.exit(1);
