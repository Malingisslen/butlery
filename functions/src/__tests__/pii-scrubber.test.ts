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

import * as fs from "fs";
import * as path from "path";
import {
  scrubPii,
  scrubUrlParams,
  scrubPayload,
  looksLikeBase64Blob,
} from "../llm/pii-scrubber";

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
    name: "BUT-765: parity-pin — percent-encoded fragment redacts after decode",
    input: "https://example.com#token%3DeyJhbGciOiJIUzI1NiJ9_extra",
    expectStripped: ["eyJhbGciOiJIUzI1NiJ9_extra"],
    expectKept: [":redacted"],
  },
  // BUT-1413 gap 2: slug-embedded PII in URL path segments.
  {
    name: "BUT-1413 gap 2: street+number slug is redacted",
    // Would FAIL if slugContainsPii is removed — the opaque-segment heuristic
    // never fires on a 12-char lower-case slug.
    input: "https://example.com/profile/storgatan-14",
    expectStripped: ["storgatan-14"],
    expectKept: [":redacted"],
  },
  {
    name: "BUT-1413 gap 2: person-name slug (mormor-Anna) is redacted",
    // Would FAIL if slugContainsPii is removed.
    input: "https://example.com/users/mormor-Anna/recipes",
    expectStripped: ["mormor-Anna"],
    expectKept: [":redacted", "/recipes"],
  },
  {
    name: "BUT-1413 gap 2 negative: ordinary food slug is NOT over-redacted",
    // Would FAIL if slugContainsPii accidentally fired on normal slugs.
    input: "https://recept.se/recept/gulasch-med-svamp-russin",
    expectStripped: [":redacted"],
    expectKept: ["gulasch-med-svamp-russin"],
  },
  {
    // FIX 1 parity: percent-encoded person name in path segment must be caught
    // on the TS side after decodeURIComponent, matching Dart's auto-decode via
    // Uri.pathSegments. WOULD FAIL before FIX 1 (segment was passed encoded to
    // slugContainsPii, which could not detect the space-separated name).
    name: "FIX 1 parity: percent-encoded person-name path segment is redacted",
    input: "https://example.com/users/mormor%20Anna/recipes",
    expectStripped: ["mormor%20Anna"],
    expectKept: [":redacted", "/recipes"],
  },
];

// BUT-694: street-address + person-name heuristic vectors. Loaded from the
// shared fixture (NOT inlined) — the Dart port copies the same file, so the
// JSON is the single cross-port contract. Exact full-string equality, which
// also pins that the heuristics don't disturb surrounding text.
interface HeuristicVector {
  name: string;
  input: string;
  expected: string;
}

function loadHeuristicVectors(): HeuristicVector[] {
  const raw = fs.readFileSync(
    path.join(__dirname, "fixtures", "pii-heuristic-vectors.json"),
    "utf8"
  );
  const parsed = JSON.parse(raw) as { vectors: HeuristicVector[] };
  if (!Array.isArray(parsed.vectors) || parsed.vectors.length === 0) {
    throw new Error("pii-heuristic-vectors.json: vectors array missing/empty");
  }
  return parsed.vectors;
}

// BUT-1413: scrubPayload parity tests (gaps 1 and 3).
interface PayloadCase {
  name: string;
  run: () => boolean; // returns true when the assertion passes
  failNote: string; // what to print on failure
}

const PAYLOAD_CASES: PayloadCase[] = [
  {
    name: "BUT-1413 gap 1: strips URL query params on every element of a list-valued URL field",
    // Would FAIL if the list branch only called scrubPii instead of
    // scrubStringLeaf — scrubPii alone does not strip query params.
    run: () => {
      const out = scrubPayload({
        sourceUrls: [
          "https://example.com/recipe?token=secret&utm_source=x",
          "https://other.com/img?id=abc123",
        ] as unknown as string,
      });
      const urls = out["sourceUrls"] as string[];
      return (
        !urls[0].includes("token") &&
        !urls[0].includes("utm_source") &&
        urls[0].includes("example.com/recipe") &&
        !urls[1].includes("id=abc123") &&
        urls[1].includes("other.com/img")
      );
    },
    failNote: "list URL elements still contain query params after scrubPayload",
  },
  {
    name: "BUT-1413 gap 1: strips query params from URL-shaped strings in a generic-keyed list",
    // Would FAIL if the list branch used scrubPii(v) instead of
    // scrubStringLeaf(key, v) — the key 'items' doesn't contain 'url' but the
    // value starts with https:// so it should still get URL treatment.
    run: () => {
      const out = scrubPayload({
        items: [
          "https://cdn.example.com/photo?sig=opaque_token",
          "plain text stays plain",
        ] as unknown as string,
      });
      const items = out["items"] as string[];
      return (
        !items[0].includes("sig=opaque_token") &&
        items[0].includes("cdn.example.com/photo") &&
        items[1] === "plain text stays plain"
      );
    },
    failNote:
      "URL-shaped string in generic-keyed list still contains query params",
  },
  {
    name: "BUT-1413 gap 3: base64 blob under unknown key passes through verbatim",
    // Would FAIL if only the explicit OPAQUE_KEYS allowlist is checked and
    // the value-based heuristic (looksLikeBase64Blob) is removed.
    // 160 chars of pure base64-alphabet characters.
    run: () => {
      const blob =
        "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk" +
        "YPhfDwAChwGA60e6kgAAAABJRU5ErkJggg==AAAAAAAAAAAAAAAAAAAAAAAAA" +
        "AAAAAAAAAAAAA==";
      const out = scrubPayload({ unknownImageField: blob });
      return out["unknownImageField"] === blob;
    },
    failNote: "base64 blob under unknown key was modified by scrubPayload",
  },
  {
    name: "BUT-1413 gap 3: looksLikeBase64Blob returns false for short strings",
    run: () => !looksLikeBase64Blob("aGVsbG8="),
    failNote: "short base64 string incorrectly flagged as blob",
  },
  {
    name: "BUT-1413 gap 3: looksLikeBase64Blob returns false for normal text",
    run: () =>
      !looksLikeBase64Blob(
        "Detta är en vanlig mening som inte ska klassas som en blob."
      ),
    failNote: "normal Swedish text incorrectly flagged as base64 blob",
  },
  {
    // FIX 2 guard — direct unit test on looksLikeBase64Blob: a ≥128-char
    // mostly-lowercase slug whose every character is in the base64 alphabet
    // must NOT be classified as a blob. WOULD FAIL before FIX 2 because the
    // entropy-fraction guard did not exist — the slug would be passed through
    // verbatim, hiding any PII it contained.
    name: "FIX 2 guard: long mostly-lowercase slug is NOT classified as a base64 blob",
    run: () => {
      // 129-char all-base64-alphabet string that is almost entirely lowercase.
      // ~1.7% upper/digit (only the '1' and '4' in 'storgatan-14') — well
      // below the 25% entropy threshold.
      const slug =
        "storgatan-14-mormor-anna-extra-padding-to-reach-the-minimum-length-threshold-for-blob-detection-aaaaaaaaaaaaaaa-bbb-cccc-ddddd-ee";
      return !looksLikeBase64Blob(slug);
    },
    failNote:
      "long mostly-lowercase slug was incorrectly classified as a base64 blob — entropy-fraction guard missing",
  },
  {
    // FIX 2 guard — integration: the long slug embedded as a URL path segment
    // must be scrubbed (via slugContainsPii) rather than silently bypassed.
    // This mirrors a realistic sourceUrl pointing to a user profile page.
    name: "FIX 2 guard: long lowercase slug with PII in URL path is scrubbed",
    run: () => {
      const slug =
        "storgatan-14-mormor-anna-extra-padding-to-reach-the-minimum-length-threshold-for-blob-detection-aaaaaaaaaaaaaaa-bbb-cccc-ddddd-ee";
      const url = `https://example.com/profile/${slug}`;
      const out = scrubPayload({ sourceUrl: url });
      const result = out["sourceUrl"] as string;
      return result !== url && result.includes(":redacted");
    },
    failNote:
      "long lowercase slug with PII in URL path was not redacted — slug-PII detection missing",
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

  console.log("\nBUT-694: address + name heuristic vectors (shared fixture)\n");
  console.log("------------------------------------------------------------\n");

  const heuristicVectors = loadHeuristicVectors();
  for (const tc of heuristicVectors) {
    const out = scrubPii(tc.input);
    const ok = out === tc.expected;
    if (ok) {
      console.log(`  PASS  ${tc.name}`);
    } else {
      failed++;
      console.log(`  FAIL  ${tc.name}`);
      console.log(`        input:    ${JSON.stringify(tc.input)}`);
      console.log(`        expected: ${JSON.stringify(tc.expected)}`);
      console.log(`        output:   ${JSON.stringify(out)}`);
    }
  }

  console.log("\nBUT-1413: scrubPayload parity tests (gaps 1 and 3)\n");
  console.log("-----------------------------------------------------\n");

  for (const tc of PAYLOAD_CASES) {
    let ok = false;
    try {
      ok = tc.run();
    } catch (e) {
      ok = false;
    }
    if (ok) {
      console.log(`  PASS  ${tc.name}`);
    } else {
      failed++;
      console.log(`  FAIL  ${tc.name}`);
      console.log(`        note: ${tc.failNote}`);
    }
  }

  const total =
    CASES.length + URL_CASES.length + heuristicVectors.length + PAYLOAD_CASES.length;
  console.log(
    `\n${total - failed}/${total} passed` + (failed ? `, ${failed} failed` : "")
  );
  if (failed > 0) process.exit(1);
}

runTests();
