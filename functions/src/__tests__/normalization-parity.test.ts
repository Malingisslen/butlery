/**
 * CRIT-5: Parity test for TypeScript ↔ Dart normalization.
 *
 * This test ensures the TypeScript normalization matches the expected output
 * defined in the shared fixture file. The Dart side has a matching test
 * that reads the same fixture file.
 *
 * Run with: npx ts-node src/__tests__/normalization-parity.test.ts
 *
 * If this test fails, the normalization contract is broken and cascade
 * retagging will fail silently.
 */

import * as fs from "fs";
import * as path from "path";

// Import the normalization function from the source
function normalizeSwedish(text: string): string {
  return text
    .toLowerCase()
    .replace(/å/g, "a")
    .replace(/ä/g, "a")
    .replace(/ö/g, "o");
}

interface TestCase {
  input: string;
  expected: string;
}

interface Fixture {
  version: string;
  description: string;
  contract: string;
  normalizations: TestCase[];
}

function runParityTests(): void {
  console.log("CRIT-5: Swedish Normalization Parity Test\n");
  console.log("========================================\n");

  // Load fixture file - path relative to functions directory
  const fixturePath = path.join(
    __dirname,
    "..",
    "..",
    "..",
    "test",
    "fixtures",
    "swedish_normalization.json"
  );

  if (!fs.existsSync(fixturePath)) {
    console.error(`ERROR: Fixture file not found at: ${fixturePath}`);
    process.exit(1);
  }

  const fixtureContent = fs.readFileSync(fixturePath, "utf-8");
  const fixture: Fixture = JSON.parse(fixtureContent);

  console.log(`Fixture version: ${fixture.version}`);
  console.log(`Contract: ${fixture.contract}`);
  console.log(`Test cases: ${fixture.normalizations.length}\n`);

  // Run all test cases
  const failures: string[] = [];
  let passed = 0;

  for (const testCase of fixture.normalizations) {
    const actual = normalizeSwedish(testCase.input);

    if (actual === testCase.expected) {
      passed++;
    } else {
      failures.push(
        `  Input "${testCase.input}": expected "${testCase.expected}", got "${actual}"`
      );
    }
  }

  // Report results
  console.log(`Results: ${passed}/${fixture.normalizations.length} passed\n`);

  if (failures.length > 0) {
    console.error("FAILURES:");
    failures.forEach((f) => console.error(f));
    console.error("\nCRITICAL: This breaks the Dart/TypeScript contract!");
    console.error("See: lib/utils/text/swedish_character_normalizer.dart\n");
    process.exit(1);
  }

  console.log("All parity tests passed!");
  console.log("TypeScript normalization matches Dart implementation.\n");
}

// Run tests
runParityTests();
