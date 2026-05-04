/**
 * Tiny test runner used by the ts-node-driven unit suites in this directory.
 *
 * The project intentionally avoids a full test framework (Jest, Mocha) for
 * the hand-written Cloud Function unit cases — keeping them ts-node-runnable
 * means a developer can `npx ts-node src/__tests__/foo.test.ts` from any
 * checkout without installing anything beyond the existing dev deps.
 *
 * Pre-extraction the same `assertEqual + UnitCase + runTests` shape was
 * copy-pasted across multiple test files. Centralising it removes drift
 * (one suite quietly diverged on its `process.exit` code earlier this year).
 *
 * NOT for use with rules-unit-testing or anything that needs Jest globals;
 * those suites already use the Firebase rules SDK's own runner.
 */

export interface UnitCase {
  name: string;
  fn: () => void | Promise<void>;
}

export function assertEqual<T>(actual: T, expected: T, msg: string): void {
  if (actual !== expected) {
    throw new Error(
      `${msg}: expected ${JSON.stringify(expected)}, got ${JSON.stringify(actual)}`
    );
  }
}

/**
 * Run a list of test cases sequentially and exit non-zero if any fail.
 *
 * Async cases are awaited. A thrown error becomes a FAIL with the error
 * message; everything else is PASS. The "X/Y passed" footer is the line
 * the parent CI scrapes for the success summary.
 */
export async function runTests(
  label: string,
  cases: UnitCase[]
): Promise<void> {
  console.log(`${label}\n`);
  console.log(
    "============================================================\n"
  );

  let failed = 0;
  for (const c of cases) {
    try {
      await c.fn();
      console.log(`  PASS  ${c.name}`);
    } catch (err) {
      failed++;
      console.log(`  FAIL  ${c.name}`);
      console.log(`        ${err instanceof Error ? err.message : err}`);
    }
  }

  const total = cases.length;
  console.log(
    `\n${total - failed}/${total} passed` +
      (failed ? `, ${failed} failed` : "")
  );
  if (failed > 0) process.exit(1);
}
