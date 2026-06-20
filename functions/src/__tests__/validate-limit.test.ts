/**
 * Unit tests for clampLimit — the guard on client-supplied callable `limit`
 * values that prevents unbounded (costly) Firestore reads and rejects bad input.
 *
 * Run with: npx ts-node src/__tests__/validate-limit.test.ts
 */

import { clampLimit } from "../shared/validate-limit";

let failed = 0;

function expectEquals(name: string, actual: number, expected: number): void {
  if (actual === expected) {
    console.log(`  PASS  ${name}`);
  } else {
    failed++;
    console.log(`  FAIL  ${name} — expected ${expected}, got ${actual}`);
  }
}

function expectThrowsInvalidArgument(name: string, raw: unknown): void {
  try {
    clampLimit(raw);
    failed++;
    console.log(`  FAIL  ${name} — expected throw, returned normally`);
  } catch (e) {
    const code = (e as { code?: string }).code;
    if (code === "invalid-argument") {
      console.log(`  PASS  ${name}`);
    } else {
      failed++;
      console.log(`  FAIL  ${name} — wrong error: ${JSON.stringify(e)}`);
    }
  }
}

function runTests(): void {
  console.log("\nclampLimit\n--------------------------------\n");

  expectEquals("absent (undefined) -> fallback 50", clampLimit(undefined), 50);
  expectEquals("absent (null) -> fallback 50", clampLimit(null), 50);
  expectEquals("valid in-range -> unchanged", clampLimit(100), 100);
  expectEquals("at max -> unchanged", clampLimit(500), 500);
  expectEquals("above max -> capped to 500", clampLimit(100000), 500);
  expectEquals("custom fallback honoured", clampLimit(undefined, { fallback: 10 }), 10);
  expectEquals("custom max honoured", clampLimit(999, { max: 25 }), 25);

  expectThrowsInvalidArgument("zero is rejected", 0);
  expectThrowsInvalidArgument("negative is rejected", -5);
  expectThrowsInvalidArgument("non-integer is rejected", 50.5);
  expectThrowsInvalidArgument("string is rejected", "50");
  expectThrowsInvalidArgument("NaN is rejected", NaN);

  console.log(`\n${failed === 0 ? "all passed" : `${failed} failed`}`);
  if (failed > 0) process.exit(1);
}

runTests();
