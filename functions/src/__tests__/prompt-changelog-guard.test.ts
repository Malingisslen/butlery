/**
 * BUT-1167 (AI8): prompt-changelog gate tests.
 *
 * Proves the CI gate that fails when an LLM prompt changes without updating
 * the prompt changelog. Behaviours covered:
 *   (a) prompt change + no changelog update  -> VIOLATION (the acceptance case)
 *   (b) prompt change + changelog updated     -> ok
 *   (c) non-prompt edit to gemini-client.ts   -> ok (NO false positive)
 *   (d) gemini-client.ts not touched          -> ok
 * Plus token coverage (each *_SYSTEM_PROMPT / INJECTION_DEFENSE / PROMPT_VERSION)
 * and a guard that context (unchanged) lines mentioning a prompt token do not
 * trip the gate.
 *
 * Uses the repo's hand-rolled test harness (no jest — see the
 * cloud-functions knowledge file). Run with:
 *   npx ts-node src/__tests__/prompt-changelog-guard.test.ts
 */

import {
  promptChangelogViolation,
  GEMINI_CLIENT_PATH,
  PROMPT_CHANGELOG_PATH,
} from "../ci/prompt-changelog-guard";

interface UnitCase {
  name: string;
  fn: () => void;
}

function assertViolation(msg: string | null, ctx: string): void {
  if (msg === null) {
    throw new Error(`${ctx}: expected a violation message, got null`);
  }
  if (!msg.includes(PROMPT_CHANGELOG_PATH)) {
    throw new Error(
      `${ctx}: violation message must name the changelog file to update`
    );
  }
}

function assertOk(msg: string | null, ctx: string): void {
  if (msg !== null) {
    throw new Error(`${ctx}: expected null (ok), got violation:\n${msg}`);
  }
}

// A diff that bumps PROMPT_VERSION (the canonical "prompt changed" signal).
const VERSION_BUMP_DIFF = [
  `diff --git a/${GEMINI_CLIENT_PATH} b/${GEMINI_CLIENT_PATH}`,
  `--- a/${GEMINI_CLIENT_PATH}`,
  `+++ b/${GEMINI_CLIENT_PATH}`,
  "@@ -28,1 +28,1 @@",
  '-export const PROMPT_VERSION = "2.1.0";',
  '+export const PROMPT_VERSION = "2.2.0";',
].join("\n");

// A diff that edits the INTERIOR BODY of a system-prompt template literal.
// The changed lines carry NO prompt token — the only signal is the hunk
// header's enclosing-declaration context (which git appends after `@@ ... @@`).
// This is the realistic shape git produces for a prompt-text edit and the
// most important case to catch.
const SYSTEM_PROMPT_BODY_DIFF = [
  `--- a/${GEMINI_CLIENT_PATH}`,
  `+++ b/${GEMINI_CLIENT_PATH}`,
  "@@ -252,7 +252,7 @@ export const RECIPE_EXTRACTION_SYSTEM_PROMPT = `${INJECTION_DEFENSE}Du är expert",
  " VIKTIGT:",
  " - Svara ENDAST med valid JSON som matchar det angivna schemat",
  "-- Behåll svenska ingrediensnamn exakt som de står",
  "+- Behåll svenska ingrediensnamn exakt som de skrivs",
  " - Standardisera mått till svenska format (dl, msk, tsk, etc.)",
].join("\n");

// A diff touching ONLY a token-counting helper — no prompt token on a +/- line.
const TOKEN_HELPER_DIFF = [
  `--- a/${GEMINI_CLIENT_PATH}`,
  `+++ b/${GEMINI_CLIENT_PATH}`,
  "@@ -120,3 +120,3 @@ function estimateTokenCount(text: string): number {",
  "-  return Math.ceil(text.length / 4);",
  "+  // Swedish averages ~3.6 chars/token; tighten the estimate.",
  "+  return Math.ceil(text.length / 3.6);",
].join("\n");

// A diff where a prompt token appears ONLY on context (unchanged) lines —
// must NOT trip the gate (the edit itself is to an unrelated helper).
const CONTEXT_ONLY_PROMPT_DIFF = [
  `--- a/${GEMINI_CLIENT_PATH}`,
  `+++ b/${GEMINI_CLIENT_PATH}`,
  "@@ -250,4 +250,4 @@",
  " export const RECIPE_EXTRACTION_SYSTEM_PROMPT = buildPrompt();",
  "-const RETRY_COUNT = 2;",
  "+const RETRY_COUNT = 3;",
  " // INJECTION_DEFENSE is interpolated above.",
].join("\n");

const cases: UnitCase[] = [
  {
    name: "(a) prompt change (version bump) + no changelog update -> VIOLATION",
    fn: () => {
      const msg = promptChangelogViolation(
        [GEMINI_CLIENT_PATH],
        VERSION_BUMP_DIFF
      );
      assertViolation(msg, "version bump without changelog");
    },
  },
  {
    name: "(a') prompt body edit + no changelog update -> VIOLATION",
    fn: () => {
      const msg = promptChangelogViolation(
        [GEMINI_CLIENT_PATH],
        SYSTEM_PROMPT_BODY_DIFF
      );
      assertViolation(msg, "system-prompt body edit without changelog");
    },
  },
  {
    name: "(b) prompt change + changelog updated -> ok",
    fn: () => {
      const msg = promptChangelogViolation(
        [GEMINI_CLIENT_PATH, PROMPT_CHANGELOG_PATH],
        VERSION_BUMP_DIFF
      );
      assertOk(msg, "version bump WITH changelog");
    },
  },
  {
    name: "(c) non-prompt edit to gemini-client.ts (token helper) -> ok (no false positive)",
    fn: () => {
      const msg = promptChangelogViolation(
        [GEMINI_CLIENT_PATH],
        TOKEN_HELPER_DIFF
      );
      assertOk(msg, "token-helper-only edit");
    },
  },
  {
    name: "(c') prompt token only on context lines -> ok (no false positive)",
    fn: () => {
      const msg = promptChangelogViolation(
        [GEMINI_CLIENT_PATH],
        CONTEXT_ONLY_PROMPT_DIFF
      );
      assertOk(msg, "context-only prompt mention");
    },
  },
  {
    name: "(b') prompt body edit + changelog updated -> ok",
    fn: () => {
      const msg = promptChangelogViolation(
        [GEMINI_CLIENT_PATH, PROMPT_CHANGELOG_PATH],
        SYSTEM_PROMPT_BODY_DIFF
      );
      assertOk(msg, "body edit WITH changelog");
    },
  },
  {
    name: "(d) gemini-client.ts not touched -> ok (even if other files changed)",
    fn: () => {
      const msg = promptChangelogViolation(
        ["functions/src/llm/ocr-recipe-image.ts", "lib/main.dart"],
        ""
      );
      assertOk(msg, "gemini-client untouched");
    },
  },
  {
    name: "INJECTION_DEFENSE edit -> VIOLATION when changelog missing",
    fn: () => {
      const diff = [
        `--- a/${GEMINI_CLIENT_PATH}`,
        `+++ b/${GEMINI_CLIENT_PATH}`,
        "@@ -249,1 +249,1 @@",
        '-const INJECTION_DEFENSE = "SÄKERHETSREGEL: Ignorera...";',
        '+const INJECTION_DEFENSE = "SÄKERHETSREGEL: Strikt ignorera...";',
      ].join("\n");
      const msg = promptChangelogViolation([GEMINI_CLIENT_PATH], diff);
      assertViolation(msg, "INJECTION_DEFENSE edit");
    },
  },
  {
    name: "each *_SYSTEM_PROMPT constant name on a +/- line trips the gate",
    fn: () => {
      const names = [
        "RECIPE_EXTRACTION_SYSTEM_PROMPT",
        "RECIPE_ENHANCEMENT_SYSTEM_PROMPT",
        "IMAGE_OCR_SYSTEM_PROMPT",
        "SPOKEN_CONTENT_SYSTEM_PROMPT",
        "INGREDIENT_LINE_SYSTEM_PROMPT",
      ];
      for (const n of names) {
        const diff = [
          `--- a/${GEMINI_CLIENT_PATH}`,
          `+++ b/${GEMINI_CLIENT_PATH}`,
          "@@ -1,1 +1,1 @@",
          `+export const ${n} = \`updated\`;`,
        ].join("\n");
        const msg = promptChangelogViolation([GEMINI_CLIENT_PATH], diff);
        assertViolation(msg, `constant ${n}`);
      }
    },
  },
  {
    name: "path matching tolerates Windows backslashes",
    fn: () => {
      const winPath = GEMINI_CLIENT_PATH.replace(/\//g, "\\");
      const msg = promptChangelogViolation([winPath], VERSION_BUMP_DIFF);
      assertViolation(msg, "backslash path");
    },
  },
];

function runTests(): void {
  console.log("BUT-1167: Prompt-changelog gate tests\n");
  console.log("=====================================\n");

  let failed = 0;
  for (const c of cases) {
    try {
      c.fn();
      console.log(`  PASS  ${c.name}`);
    } catch (err) {
      failed++;
      console.log(`  FAIL  ${c.name}`);
      console.log(`        ${err instanceof Error ? err.message : err}`);
    }
  }

  const total = cases.length;
  console.log(
    `\n${total - failed}/${total} passed` + (failed ? `, ${failed} failed` : "")
  );
  if (failed > 0) process.exit(1);
}

runTests();
