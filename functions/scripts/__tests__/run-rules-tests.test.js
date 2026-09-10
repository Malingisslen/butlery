/**
 * BUT-2065: tests for the rules-suite runner.
 *
 * The defect it replaces is invisible by construction — an `&&` chain that
 * stops at the first red suite produces the same red verdict as a chain that
 * ran everything, so nothing on screen distinguishes "40 suites failed" from
 * "1 failed and 44 never ran". These tests are what make the difference
 * observable, and they drive the runner as a CHILD PROCESS against fixture
 * suites: no emulator, no ts-node, no Firestore.
 *
 * The fixtures are tiny node scripts rather than real suites, and the runner is
 * pointed at them through the `RULES_RUNNER_CMD` seam, because the property
 * under test is the runner's collect-and-exit behaviour, not what ts-node does.
 *
 * Plain Node + node:assert, run by `npm run test:script-rules-runner`, which
 * run-ci-unit-tests.js discovers and the CF unit-test job executes.
 */

const assert = require("assert");
const fs = require("fs");
const os = require("os");
const path = require("path");
const { spawnSync } = require("child_process");

const RUNNER = path.join(__dirname, "..", "run-rules-tests.js");

const results = [];
function test(name, fn) {
  try {
    fn();
    results.push({ name, ok: true });
  } catch (err) {
    results.push({ name, ok: false, err });
  }
}

/** A throwaway directory holding one passing and one failing fixture suite. */
function withFixtures(fn) {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), "rules-runner-"));
  try {
    fs.writeFileSync(
      path.join(dir, "green.js"),
      'console.log("GREEN RAN");\n',
    );
    fs.writeFileSync(
      path.join(dir, "red.js"),
      'console.log("RED RAN");\nprocess.exit(1);\n',
    );
    fs.writeFileSync(
      path.join(dir, "green2.js"),
      'console.log("GREEN2 RAN");\n',
    );
    fn(dir);
  } finally {
    fs.rmSync(dir, { recursive: true, force: true });
  }
}

function run(dir, suites) {
  return spawnSync(
    process.execPath,
    [RUNNER, ...suites.map((s) => path.join(dir, s))],
    { encoding: "utf8", env: { ...process.env, RULES_RUNNER_CMD: "node" } },
  );
}

test("a suite that fails FIRST does not stop the ones after it", () => {
  withFixtures((dir) => {
    const r = run(dir, ["red.js", "green.js", "green2.js"]);
    const out = r.stdout + r.stderr;
    assert.ok(out.includes("RED RAN"), "the failing suite ran");
    assert.ok(
      out.includes("GREEN RAN"),
      "the suite after the failure never ran — this is the whole defect",
    );
    assert.ok(out.includes("GREEN2 RAN"), "the third suite never ran");
  });
});

test("the run still fails when any suite fails", () => {
  withFixtures((dir) => {
    const r = run(dir, ["red.js", "green.js"]);
    assert.notStrictEqual(
      r.status,
      0,
      "a run containing a failure must not exit 0",
    );
  });
});

test("an all-green run exits 0", () => {
  withFixtures((dir) => {
    const r = run(dir, ["green.js", "green2.js"]);
    assert.strictEqual(r.status, 0, r.stdout + r.stderr);
  });
});

test("the output says how many suites RAN, not just whether it is green", () => {
  withFixtures((dir) => {
    const r = run(dir, ["red.js", "green.js", "green2.js"]);
    const out = r.stdout + r.stderr;
    assert.ok(
      /Rules suites: 2\/3 passed, 3 ran/.test(out),
      `no ran-count in output:\n${out}`,
    );
    assert.ok(out.includes("Failed suites:"), "the failures are not named");
    assert.ok(
      !/never ran/.test(out),
      "a complete run must not claim suites were skipped",
    );
  });
});

test("no suites is a refusal, not a vacuous pass", () => {
  const r = spawnSync(process.execPath, [RUNNER], { encoding: "utf8" });
  assert.notStrictEqual(r.status, 0);
  assert.ok(/refusing to pass vacuously/.test(r.stderr), r.stderr);
});

// The list is deliberately NOT discovered by the runner: thirty-six of the
// forty-five suites have their own `test:rules:*` script and nine do not, so
// discovery would silently run nine fewer. And `check-test-registration.js`
// reads the file list out of this very string. Both properties are asserted
// here so a later "tidy the long script" edit reddens rather than shipping.
test("test:rules:all still names every suite as a readable path", () => {
  const pkg = JSON.parse(
    fs.readFileSync(path.join(__dirname, "..", "..", "package.json"), "utf8"),
  );
  const command = pkg.scripts["test:rules:all"];
  assert.ok(
    command.startsWith("node scripts/run-rules-tests.js "),
    `test:rules:all no longer invokes the runner: ${command}`,
  );
  assert.ok(
    !command.includes("&&"),
    "an && is back in test:rules:all — that is the defect BUT-2065 removed",
  );
  const referenced = command.match(/src\/__tests__\/\S+\.test\.ts/g) ?? [];
  assert.ok(
    referenced.length >= 40,
    `only ${referenced.length} suites named; check-test-registration.js reads ` +
      "this list and would go blind",
  );
  assert.strictEqual(
    new Set(referenced).size,
    referenced.length,
    "a suite is named twice, so it would run twice",
  );
  for (const file of referenced) {
    assert.ok(
      fs.existsSync(path.join(__dirname, "..", "..", file)),
      `test:rules:all names a file that does not exist: ${file}`,
    );
  }
});

let failures = 0;
for (const r of results) {
  if (r.ok) {
    console.log(`  ok  ${r.name}`);
  } else {
    failures++;
    console.error(`  FAIL  ${r.name}`);
    console.error(`        ${r.err && r.err.message}`);
  }
}
console.log(`\n${results.length - failures}/${results.length} checks passed.`);
if (failures > 0) process.exit(1);
