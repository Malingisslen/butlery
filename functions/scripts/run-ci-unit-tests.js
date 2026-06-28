/**
 * BUT-1392: CI unit-test runner for Cloud Functions DI-seam (non-emulator) tests.
 *
 * Mirrors run-all-tests.js auto-discovery logic (all test:* scripts except
 * test:rules* and test:integration:*). CI_EXCLUDE below is the escape hatch for
 * a suite with a pre-existing failure on main — keep it empty when the suite is
 * green; add an entry (with the fix needed) only to avoid a red CI gate, and
 * remove it once fixed. (Two such suites — app-check-enforcement and
 * request-account-deletion — were fixed in this ticket, so the set is empty.)
 *
 * Invoked by the cloud-functions-unit CI job:
 *   node scripts/run-ci-unit-tests.js
 */

const { spawnSync } = require("child_process");
const path = require("path");

const pkg = require(path.join(__dirname, "..", "package.json"));

const EXCLUDE_PREFIXES = ["test:rules", "test:integration:"];

/**
 * Suites excluded from CI because they have pre-existing failures on main.
 * Document the fix needed next to each entry. Remove the entry once fixed.
 */
const CI_EXCLUDE = new Set([
  // (empty — no suite is currently excluded; see header for the contract)
]);

const suites = Object.keys(pkg.scripts)
  .filter((name) => name.startsWith("test:"))
  .filter((name) => !EXCLUDE_PREFIXES.some((p) => name.startsWith(p)))
  .filter((name) => !CI_EXCLUDE.has(name));

if (suites.length === 0) {
  console.error("run-ci-unit-tests: no test:* suites discovered — refusing to pass vacuously.");
  process.exit(1);
}

console.log(`Running ${suites.length} DI-seam unit suites (${CI_EXCLUDE.size} excluded — see header).`);

const failed = [];
const startedAt = Date.now();

for (const suite of suites) {
  console.log(`\n=== ${suite} ===`);
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
console.log("All CI suites green.");
