/**
 * Condition C4: TS ↔ Dart parity for the pooled-ratings CanonicalPoolKey.
 *
 * Reads the SAME fixture as the Dart test
 * (test/unit/services/rating/canonical_pool_key_parity_test.dart). If TS and
 * Dart disagree on any key, pool routing between the client hint and the server
 * authority diverges — a correctness break on a public reputation signal.
 *
 * Run with: npx ts-node src/__tests__/pool-key-parity.test.ts
 */

import * as fs from "fs";
import * as path from "path";
import { computePoolKey } from "../ratings/canonical-pool-key";

interface Case {
  name: string;
  title: string;
  ingredients: string[];
  expected: string | null;
}

interface Fixture {
  version: string;
  contract: string;
  cases: Case[];
}

function run(): void {
  console.log("Pool-key TS↔Dart parity (condition C4)\n");

  const fixturePath = path.join(
    __dirname,
    "..",
    "..",
    "..",
    "test",
    "fixtures",
    "pool_key_parity.json"
  );

  if (!fs.existsSync(fixturePath)) {
    console.error(`ERROR: fixture not found at ${fixturePath}`);
    process.exit(1);
  }

  const fixture: Fixture = JSON.parse(fs.readFileSync(fixturePath, "utf-8"));
  const failures: string[] = [];
  let passed = 0;

  for (const c of fixture.cases) {
    const actual = computePoolKey(c.title, c.ingredients);
    if (actual === c.expected) {
      passed++;
    } else {
      failures.push(
        `  ${c.name}: expected ${JSON.stringify(c.expected)}, got ${JSON.stringify(actual)}`
      );
    }
  }

  console.log(`Results: ${passed}/${fixture.cases.length} passed\n`);

  if (failures.length > 0) {
    console.error("FAILURES (TS key does not match the Dart fixture):");
    failures.forEach((f) => console.error(f));
    console.error(
      "\nCRITICAL: TS authority and Dart hint diverge. Fix the TS twin " +
        "(functions/src/ratings/canonical-pool-key.ts) to match Dart.\n"
    );
    process.exit(1);
  }

  console.log("All pool-key parity cases passed — TS matches Dart.\n");
}

run();
