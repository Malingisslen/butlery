/**
 * BUT-595: Unit tests for the `logParseCorrection` validate-and-prepare
 * pipeline.
 *
 * The handler is a thin wrapper around `validateAndPreparePayload` plus an
 * admin-SDK Firestore add. We test the pure pipeline directly so the suite
 * doesn't need the Firebase emulator.
 *
 * Each case names the contract it proves. Failure means either the rule
 * regressed or the contract changed.
 *
 * Run with: npx ts-node src/__tests__/log-parse-correction.test.ts
 */

import {
  validateAndPreparePayload,
  ParseCorrectionData,
  MAX_VALUE_CHARS,
} from "../events/log-parse-correction";

interface Case {
  name: string;
  input: ParseCorrectionData;
  expect: (
    result: ReturnType<typeof validateAndPreparePayload>
  ) => string | null;
}

const VALID_HASH = "a".repeat(64);
const VALID_HASH_2 = "b".repeat(64);

function expectInvalid(reason: string) {
  return (r: ReturnType<typeof validateAndPreparePayload>) =>
    r.kind === "invalid" && r.reason === reason
      ? null
      : `expected invalid:${reason}, got ${JSON.stringify(r)}`;
}

function expectSkip(reason: string) {
  return (r: ReturnType<typeof validateAndPreparePayload>) =>
    r.kind === "skip" && r.reason === reason
      ? null
      : `expected skip:${reason}, got ${JSON.stringify(r)}`;
}

function expectWrite(check: (doc: Record<string, unknown>) => string | null) {
  return (r: ReturnType<typeof validateAndPreparePayload>) =>
    r.kind === "write"
      ? check(r.doc)
      : `expected write, got ${JSON.stringify(r)}`;
}

const CASES: Case[] = [
  {
    name: "rejects unknown correctedField",
    input: {
      correctedField: "color",
      fromValue: "a",
      toValue: "b",
      sourceTier: "llm",
      userIdHash: VALID_HASH,
      recipeIdHash: VALID_HASH_2,
    },
    expect: expectInvalid("correctedField"),
  },
  {
    name: "rejects unknown sourceTier",
    input: {
      correctedField: "title",
      fromValue: "a",
      toValue: "b",
      sourceTier: "carrier_pigeon",
      userIdHash: VALID_HASH,
      recipeIdHash: VALID_HASH_2,
    },
    expect: expectInvalid("sourceTier"),
  },
  {
    name: "rejects raw uid in userIdHash",
    input: {
      correctedField: "title",
      fromValue: "a",
      toValue: "b",
      sourceTier: "llm",
      userIdHash: "raw-firebase-uid",
      recipeIdHash: VALID_HASH_2,
    },
    expect: expectInvalid("hashes"),
  },
  {
    name: "skips whitespace-only diff",
    input: {
      correctedField: "title",
      fromValue: "Köttbullar",
      toValue: "  Köttbullar  ",
      sourceTier: "site_config",
      userIdHash: VALID_HASH,
      recipeIdHash: VALID_HASH_2,
    },
    expect: expectSkip("whitespace_or_case_only"),
  },
  {
    name: "skips case-only diff",
    input: {
      correctedField: "title",
      fromValue: "Köttbullar",
      toValue: "KÖTTBULLAR",
      sourceTier: "regex",
      userIdHash: VALID_HASH,
      recipeIdHash: VALID_HASH_2,
    },
    expect: expectSkip("whitespace_or_case_only"),
  },
  {
    name: "scrubs personnummer in fromValue server-side",
    input: {
      correctedField: "instructions",
      fromValue:
        "Vid frågor kontakta Anna 901015-1234 för dagens recept-tid 30 min",
      toValue: "Koka i 30 minuter, servera direkt",
      sourceTier: "llm",
      userIdHash: VALID_HASH,
      recipeIdHash: VALID_HASH_2,
    },
    expect: expectWrite((doc) => {
      const fv = doc.fromValue as string;
      if (fv.includes("901015-1234")) return "personnummer leaked into fromValue";
      if (!fv.includes("[PERSONNUMMER]")) return "missing PII token";
      return null;
    }),
  },
  {
    name: "skips correction when >50% of input is PII (poison guard)",
    input: {
      correctedField: "title",
      fromValue: "901015-1234",
      toValue: "Köttbullar",
      sourceTier: "llm",
      userIdHash: VALID_HASH,
      recipeIdHash: VALID_HASH_2,
    },
    expect: expectSkip("pii_heavy"),
  },
  {
    name: "writes valid correction with all fields populated",
    input: {
      correctedField: "title",
      fromValue: "Kötbullar",
      toValue: "Köttbullar med gräddsås",
      sourceTier: "llm",
      promptVersion: "v3.1",
      domain: "ica.se",
      userIdHash: VALID_HASH,
      recipeIdHash: VALID_HASH_2,
    },
    expect: expectWrite((doc) => {
      if (doc.correctedField !== "title") return "correctedField mismatch";
      if (doc.sourceTier !== "llm") return "sourceTier mismatch";
      if (doc.promptVersion !== "v3.1") return "promptVersion not preserved";
      if (doc.domain !== "ica.se") return "domain not preserved";
      if (doc.userIdHash !== VALID_HASH) return "userIdHash not preserved";
      if (doc.schemaVersion !== "v2-perfield")
        return "schemaVersion not stamped";
      return null;
    }),
  },
  {
    name: "drops promptVersion when sourceTier is not llm",
    input: {
      correctedField: "title",
      fromValue: "old",
      toValue: "new",
      sourceTier: "regex",
      promptVersion: "v3.1",
      userIdHash: VALID_HASH,
      recipeIdHash: VALID_HASH_2,
    },
    expect: expectWrite((doc) => {
      if ("promptVersion" in doc)
        return "promptVersion should not be written for non-llm tier";
      return null;
    }),
  },
  {
    name: "normalizes www-prefixed domain to bare host",
    input: {
      correctedField: "title",
      fromValue: "old",
      toValue: "new",
      sourceTier: "site_config",
      domain: "www.ICA.se",
      userIdHash: VALID_HASH,
      recipeIdHash: VALID_HASH_2,
    },
    expect: expectWrite((doc) => {
      if (doc.domain !== "ica.se")
        return `expected ica.se, got ${doc.domain}`;
      return null;
    }),
  },
  {
    name: "truncates fromValue/toValue to MAX_VALUE_CHARS",
    input: {
      correctedField: "instructions",
      fromValue: "x".repeat(MAX_VALUE_CHARS + 50),
      toValue: "y".repeat(MAX_VALUE_CHARS + 50),
      sourceTier: "regex",
      userIdHash: VALID_HASH,
      recipeIdHash: VALID_HASH_2,
    },
    expect: expectWrite((doc) => {
      const fv = doc.fromValue as string;
      const tv = doc.toValue as string;
      if (fv.length !== MAX_VALUE_CHARS)
        return `fromValue not truncated: ${fv.length}`;
      if (tv.length !== MAX_VALUE_CHARS)
        return `toValue not truncated: ${tv.length}`;
      return null;
    }),
  },
];

function run(): void {
  console.log("BUT-595: logParseCorrection pipeline tests\n");
  console.log("==========================================\n");
  let failed = 0;
  for (const tc of CASES) {
    const result = validateAndPreparePayload(tc.input);
    const err = tc.expect(result);
    if (err === null) {
      console.log(`  PASS  ${tc.name}`);
    } else {
      failed++;
      console.log(`  FAIL  ${tc.name}`);
      console.log(`        ${err}`);
    }
  }
  const total = CASES.length;
  console.log(
    `\n${total - failed}/${total} passed` + (failed ? `, ${failed} failed` : "")
  );
  if (failed > 0) process.exit(1);
}

run();
