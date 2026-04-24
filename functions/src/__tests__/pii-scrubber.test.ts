/**
 * BUT-423: Unit tests for PII scrubber.
 *
 * Asserts the regex tightening for personnummer and Swedish phones:
 * - Barcodes (EAN-13) MUST NOT be scrubbed as personnummer.
 * - Cooking ranges like "04-05 min" MUST NOT be scrubbed as phone numbers.
 * - Real personnummer and Swedish phone shapes MUST be scrubbed.
 *
 * Run with: npx ts-node src/__tests__/pii-scrubber.test.ts
 */

import { scrubPii } from "../llm/pii-scrubber";

interface Case {
  name: string;
  input: string;
  expectScrubbed: boolean;
  // Optional: require a specific replacement token to appear in the output.
  expectToken?: string;
  // Optional: require a specific substring to remain in the output.
  expectContains?: string;
}

const CASES: Case[] = [
  {
    name: "personnummer YYMMDD-XXXX is scrubbed",
    input: "Personnummer: 901015-1234",
    expectScrubbed: true,
    expectToken: "[PERSONNUMMER]",
  },
  {
    name: "personnummer YYYYMMDD-XXXX is scrubbed",
    input: "PN 19901015-1234 på kortet",
    expectScrubbed: true,
    expectToken: "[PERSONNUMMER]",
  },
  {
    name: "EAN-13 barcode is NOT scrubbed",
    input: "EAN 7310865111294 on package",
    expectScrubbed: false,
    expectContains: "7310865111294",
  },
  {
    name: "cooking range 04-05 min is NOT scrubbed",
    input: "Koka i 04-05 min",
    expectScrubbed: false,
    expectContains: "04-05 min",
  },
  {
    name: "cooking range 10-15 minuter is NOT scrubbed",
    input: "Koka i 10-15 minuter",
    expectScrubbed: false,
    expectContains: "10-15 minuter",
  },
  {
    name: "Swedish mobile 070-123 45 67 is scrubbed",
    input: "Ring 070-123 45 67",
    expectScrubbed: true,
    expectToken: "[PHONE]",
  },
  {
    name: "International +46 70 123 45 67 is scrubbed",
    input: "Ring +46 70 123 45 67",
    expectScrubbed: true,
    expectToken: "[PHONE]",
  },
  {
    name: "temperature 200°C and time 30 min are NOT scrubbed",
    input: "Temp 200°C i 30 min",
    expectScrubbed: false,
    expectContains: "200°C",
  },
  {
    name: "email is scrubbed",
    input: "Kontakta chef@exempel.se",
    expectScrubbed: true,
    expectToken: "[EMAIL]",
  },
  {
    name: "personnummer without hyphen is NOT scrubbed (prevents barcode FP)",
    input: "Ref 9010151234 ingen bindestreck",
    expectScrubbed: false,
    expectContains: "9010151234",
  },
];

function runTests(): void {
  console.log("BUT-423: PII Scrubber Tests\n");
  console.log("===========================\n");

  let failed = 0;
  for (const tc of CASES) {
    const out = scrubPii(tc.input);
    const changed = out !== tc.input;

    let ok = changed === tc.expectScrubbed;
    if (ok && tc.expectToken) ok = out.includes(tc.expectToken);
    if (ok && tc.expectContains) ok = out.includes(tc.expectContains);

    if (ok) {
      console.log(`  PASS  ${tc.name}`);
    } else {
      failed++;
      console.log(`  FAIL  ${tc.name}`);
      console.log(`        input:  ${JSON.stringify(tc.input)}`);
      console.log(`        output: ${JSON.stringify(out)}`);
    }
  }

  const total = CASES.length;
  console.log(
    `\n${total - failed}/${total} passed` + (failed ? `, ${failed} failed` : "")
  );
  if (failed > 0) process.exit(1);
}

runTests();
