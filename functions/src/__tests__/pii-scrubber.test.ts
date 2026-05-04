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

import { scrubPii, scrubUrlParams } from "../llm/pii-scrubber";

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

// BUT-692: scrubUrlParams parity cases. Mirrors the Dart group at
// test/unit/services/llm/pii_scrubber_test.dart "scrubUrlParams - path-
// embedded tokens". If these diverge, the two scrubbers are out of sync
// and the defence-in-depth contract is broken.
interface UrlCase {
  name: string;
  input: string;
  // Substrings that must be GONE from the output.
  expectStripped?: string[];
  // Substrings that must remain in the output.
  expectKept?: string[];
}

const URL_CASES: UrlCase[] = [
  {
    name: "BUT-534: strips query, preserves fragment (recipe section anchors)",
    input: "https://example.com/recipe?utm_source=x&token=secret#ingredienser",
    expectStripped: ["utm_source", "token"],
    expectKept: ["example.com/recipe", "#ingredienser"],
  },
  {
    name: "redacts mixed-case + digit Algolia-shaped path token",
    input: "https://example.com/r/7Br2c3DmEIeu61HVcgWa9/title",
    expectStripped: ["7Br2c3DmEIeu61HVcgWa9"],
    expectKept: [":redacted", "/title"],
  },
  {
    name: "redacts UUID path segment",
    input:
      "https://example.com/share/f47ac10b-58cc-4372-a567-0e02b2c3d479/view",
    expectStripped: ["f47ac10b-58cc-4372-a567-0e02b2c3d479"],
    expectKept: [":redacted"],
  },
  {
    name: "redacts JWT-shaped token in path",
    input:
      "https://example.com/auth/eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9_xx",
    expectStripped: ["eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9_xx"],
    expectKept: [":redacted"],
  },
  {
    name: "redacts 32-char hex hash path segment",
    input: "https://example.com/tracking/a8e4f2b9c1d3e5f7a1b3c5d7e9f1a3b5/x",
    expectStripped: ["a8e4f2b9c1d3e5f7a1b3c5d7e9f1a3b5"],
    expectKept: [":redacted"],
  },
  {
    name: "keeps Swedish recipe slug intact",
    input: "https://recept.se/recept/gulasch-med-svamp-och-russin",
    expectStripped: [":redacted"],
    expectKept: ["gulasch-med-svamp-och-russin"],
  },
  {
    name: "keeps long-but-slug-shaped path segments",
    input: "https://example.com/super-premium-italienska-tomater",
    expectStripped: [":redacted"],
    expectKept: ["super-premium-italienska-tomater"],
  },
  {
    name: "returns input unchanged when not parseable",
    input: "not a url at all",
    expectKept: ["not a url at all"],
  },
  // BUT-765: opaque-token redaction inside URL fragments.
  {
    name: "BUT-765: keeps short slug fragment intact (#method)",
    input: "https://example.com/recipe#method",
    expectStripped: [":redacted"],
    expectKept: ["#method"],
  },
  {
    name: "BUT-765: keeps slug-shaped fragment with hyphens intact",
    input: "https://example.com/recipe#super-premium-italienska",
    expectStripped: [":redacted"],
    expectKept: ["#super-premium-italienska"],
  },
  {
    name: "BUT-765: redacts UUID-shaped fragment wholesale",
    input:
      "https://example.com/share#f47ac10b-58cc-4372-a567-0e02b2c3d479",
    expectStripped: ["f47ac10b-58cc-4372-a567-0e02b2c3d479"],
    expectKept: ["#:redacted"],
  },
  {
    name: "BUT-765: redacts JWT-shaped value inside keyed fragment",
    input:
      "https://example.com/auth#token=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9",
    expectStripped: ["eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9"],
    expectKept: ["token=:redacted"],
  },
  {
    name: "BUT-765: redacts long alphanumeric run in unkeyed fragment",
    input: "https://example.com#abcdefghijklmnopqrstuvwxyz",
    expectStripped: ["abcdefghijklmnopqrstuvwxyz"],
    expectKept: [":redacted"],
  },
  {
    name: "BUT-765: redacts 32-char hex hash fragment",
    input: "https://example.com/r#a8e4f2b9c1d3e5f7a1b3c5d7e9f1a3b5",
    expectStripped: ["a8e4f2b9c1d3e5f7a1b3c5d7e9f1a3b5"],
    expectKept: [":redacted"],
  },
  {
    name:
      "BUT-765: mixed keyed fragment redacts opaque values, preserves slug",
    input:
      "https://example.com#section=ingredienser&token=eyJhbGciOiJIUzI1NiJ9",
    expectStripped: ["eyJhbGciOiJIUzI1NiJ9"],
    expectKept: ["section=ingredienser", "token=:redacted"],
  },
  {
    name:
      "BUT-765: parity-pin — percent-encoded fragment redacts after decode",
    input:
      "https://example.com#token%3DeyJhbGciOiJIUzI1NiJ9_extra",
    expectStripped: ["eyJhbGciOiJIUzI1NiJ9_extra"],
    expectKept: [":redacted"],
  },
];

function runTests(): void {
  console.log("BUT-423/692: PII Scrubber Tests\n");
  console.log("================================\n");

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

  console.log("\nBUT-692: scrubUrlParams\n");
  console.log("------------------------\n");

  for (const tc of URL_CASES) {
    const out = scrubUrlParams(tc.input);
    let ok = true;
    for (const s of tc.expectStripped ?? []) {
      if (out.includes(s)) {
        ok = false;
        break;
      }
    }
    if (ok) {
      for (const s of tc.expectKept ?? []) {
        if (!out.includes(s)) {
          ok = false;
          break;
        }
      }
    }

    if (ok) {
      console.log(`  PASS  ${tc.name}`);
    } else {
      failed++;
      console.log(`  FAIL  ${tc.name}`);
      console.log(`        input:  ${JSON.stringify(tc.input)}`);
      console.log(`        output: ${JSON.stringify(out)}`);
    }
  }

  const total = CASES.length + URL_CASES.length;
  console.log(
    `\n${total - failed}/${total} passed` + (failed ? `, ${failed} failed` : "")
  );
  if (failed > 0) process.exit(1);
}

runTests();
