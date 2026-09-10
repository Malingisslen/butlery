/**
 * BUT-2065: run-all-collect-exit runner for the Firestore Rules suites.
 *
 * `test:rules:all` chained ~45 `ts-node` calls with `&&`, so the first red suite
 * aborted the run and every suite after it was never executed. The outcome reads
 * as "the rules are red" — which is true — while hiding how many suites got no
 * answer at all. A suite added at the end of the chain could be written, green
 * locally, and never once have run there.
 *
 * Same class the repo already paid for with `npm test` (BUT-1223), and the same
 * shape of fix as `run-all-tests.js` beside this file: run every suite, collect
 * the failures, exit non-zero if any failed, and report how many RAN.
 *
 * The suite list stays in `functions/package.json`, passed as arguments, and is
 * NOT discovered here. Two reasons, both measured:
 *
 *   1. Discovering `test:rules:*` scripts would drop nine suites. Thirty-six of
 *      the forty-five have their own script; the other nine (eight
 *      `*.integration.test.ts` plus `analyze-corrections-alias.test.ts`) are
 *      named ONLY by the chain. Silently running nine fewer suites is the exact
 *      defect this file exists to remove.
 *   2. `check-test-registration.js` reads the file list straight out of the
 *      `test:rules:all` string (`referencedTestFiles`), and its RULES_TRIGGERS
 *      assertion checks each of those files against every `paths:` block of
 *      .github/workflows/firestore-rules.yml. Moving the list into this script
 *      would blind that guard.
 *
 * SEQUENTIAL, deliberately. The suites share one Firestore emulator and do not
 * clear between each other — this repo has already shipped a vacuous test case
 * from that (a seed left behind by an earlier suite). Parallelism here is a
 * correctness question that has to be measured first, not a speed knob.
 *
 * Plain Node, no deps. Invoked via `npm run test:rules:all` (cwd = functions/).
 */

const { spawnSync } = require("child_process");
const path = require("path");

const suites = process.argv.slice(2);

if (suites.length === 0) {
  console.error(
    "run-rules-tests: no suites passed — refusing to pass vacuously. " +
      "The list lives in package.json's `test:rules:all`.",
  );
  process.exit(1);
}

const failed = [];
// Counted by INCREMENT, not derived as `suites.length - failed.length`. The
// derived form reports "2/3 passed" when one suite failed and the other two
// never started — which is the exact thing this runner exists to make
// visible, restated as an honest-looking number. Measured: with a `break`
// reintroduced into the loop, the derived form stayed green.
let ran = 0;
const startedAt = Date.now();

// Test seam. The property under test is this file's collect-and-exit
// behaviour, and proving it needs suites that fail on purpose — which real
// rules suites cannot be, and which ts-node cannot run without an emulator.
// Production never sets it.
const interpreter = process.env.RULES_RUNNER_CMD || "ts-node";

for (const suite of suites) {
  console.log(`\n=== ${suite} ===`);
  // shell: true so `ts-node` resolves from node_modules/.bin on Windows and
  // POSIX alike. Paths come from our own package.json — trusted input.
  const result = spawnSync(`${interpreter} ${suite}`, {
    stdio: "inherit",
    shell: true,
    cwd: path.join(__dirname, ".."),
  });
  ran++;
  if (result.status !== 0) {
    failed.push(suite);
    console.error(`### ${suite} FAILED (exit ${result.status})`);
  }
}

const seconds = Math.round((Date.now() - startedAt) / 1000);
console.log(`\n========================================`);
console.log(
  `Rules suites: ${ran - failed.length}/${suites.length} passed, ${ran} ran (${seconds}s)`,
);
if (ran !== suites.length) {
  console.error(
    `### ${suites.length - ran} suite(s) never ran — the runner stopped early.`,
  );
}
if (failed.length > 0) {
  console.error(`Failed suites:`);
  for (const f of failed) console.error(`  - ${f}`);
  process.exit(1);
}
console.log("All rules suites green.");
