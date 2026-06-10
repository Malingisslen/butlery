/**
 * BUT-1223: run-all-collect-exit test runner.
 *
 * The old composite `npm test` chained suites with `&&`, so the first red
 * suite aborted the chain and masked every suite after it. This runner:
 *
 *   1. Auto-discovers suites from package.json: every `test:*` script EXCEPT
 *      `test:rules*` (owned by firestore-rules-tester, needs the emulator)
 *      and `test:integration:*` (emulator-bound). New `test:foo` scripts are
 *      picked up automatically — no more "added the granular script, forgot
 *      to extend the composite chain".
 *   2. Runs every suite even when earlier ones fail.
 *   3. Prints a pass/fail summary and exits non-zero if ANY suite failed.
 *
 * Plain Node, no deps. Invoked via `npm test` (cwd = functions/).
 */

const { spawnSync } = require("child_process");
const path = require("path");

const pkg = require(path.join(__dirname, "..", "package.json"));

const EXCLUDE_PREFIXES = ["test:rules", "test:integration:"];

const suites = Object.keys(pkg.scripts)
  .filter((name) => name.startsWith("test:"))
  .filter((name) => !EXCLUDE_PREFIXES.some((p) => name.startsWith(p)));

if (suites.length === 0) {
  console.error("run-all-tests: no test:* suites discovered — refusing to pass vacuously.");
  process.exit(1);
}

const failed = [];
const startedAt = Date.now();

for (const suite of suites) {
  console.log(`\n=== ${suite} ===`);
  // shell: true so `npm` resolves on Windows (npm.cmd) and POSIX alike.
  // Suite names come from our own package.json — trusted input.
  const result = spawnSync(`npm run ${suite}`, {
    stdio: "inherit",
    shell: true,
    cwd: path.join(__dirname, ".."),
  });
  if (result.status !== 0) {
    failed.push(suite);
    console.error(`### ${suite} FAILED (exit ${result.status})`);
  }
}

const seconds = Math.round((Date.now() - startedAt) / 1000);
console.log(`\n========================================`);
console.log(`Suites: ${suites.length - failed.length}/${suites.length} passed (${seconds}s)`);
if (failed.length > 0) {
  console.error(`Failed suites:`);
  for (const f of failed) console.error(`  - ${f}`);
  process.exit(1);
}
console.log("All suites green.");
