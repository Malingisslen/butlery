/**
 * BUT-546: validateDifficulty drift-logging tests.
 *
 * Verifies that `parseRecipeResponse` emits a `logger.warn` (with the raw
 * value + promptVersion) when Gemini returns a difficulty value outside the
 * `easy | medium | hard` enum, and stays silent for valid + absent values.
 *
 * The warn signal is the regression-prevention surface: a future refactor
 * that drops the warn line breaks tests 3-4. Without coverage, silent LLM
 * drift becomes invisible.
 *
 * Run with: npx ts-node src/__tests__/parse-recipe-response-difficulty.test.ts
 */

import { logger } from "firebase-functions/logger";

// Capture logger.warn calls before importing gemini-client. The Cloud Functions
// logger writes to stdout via Bunyan; replacing the method intercepts cleanly.
interface WarnCall {
  msg: string;
  payload: Record<string, unknown> | undefined;
}
const warnCalls: WarnCall[] = [];
(logger as unknown as { warn: (msg: string, payload?: unknown) => void }).warn = (
  msg: string,
  payload?: unknown
): void => {
  warnCalls.push({
    msg,
    payload: typeof payload === "object" && payload !== null
      ? (payload as Record<string, unknown>)
      : undefined,
  });
};

import { parseRecipeResponse } from "../llm/gemini-client";

interface UnitCase {
  name: string;
  fn: () => void;
}

function assertEqual<T>(actual: T, expected: T, msg: string): void {
  if (actual !== expected) {
    throw new Error(`${msg}: expected ${JSON.stringify(expected)}, got ${JSON.stringify(actual)}`);
  }
}

function buildRecipeJson(difficulty: unknown): string {
  return JSON.stringify({
    title: "Pannkakor",
    ingredients: [{ name: "mjöl", amount: 3, unit: "dl" }],
    instructions: ["Vispa.", "Stek."],
    difficulty,
  });
}

function lastWarn(): WarnCall {
  if (warnCalls.length === 0) {
    throw new Error("Expected at least one warn call but none captured");
  }
  return warnCalls[warnCalls.length - 1];
}

const cases: UnitCase[] = [
  {
    name: "valid lowercase difficulty 'easy' returns enum, no warn",
    fn: () => {
      warnCalls.length = 0;
      const recipe = parseRecipeResponse(buildRecipeJson("easy"), "v3.1");
      assertEqual(recipe?.difficulty, "easy", "difficulty enum");
      assertEqual(warnCalls.length, 0, "no warn on valid value");
    },
  },
  {
    name: "valid mixed-case difficulty 'MEDIUM' returns lowercase enum, no warn",
    fn: () => {
      warnCalls.length = 0;
      const recipe = parseRecipeResponse(buildRecipeJson("MEDIUM"), "v3.1");
      assertEqual(recipe?.difficulty, "medium", "difficulty enum");
      assertEqual(warnCalls.length, 0, "no warn on case-variant valid value");
    },
  },
  {
    name: "absent difficulty (undefined) returns null, no warn",
    fn: () => {
      warnCalls.length = 0;
      const recipe = parseRecipeResponse(
        JSON.stringify({
          title: "Test",
          ingredients: [{ name: "x", amount: 1, unit: "g" }],
        }),
        "v3.1"
      );
      assertEqual(recipe?.difficulty, null, "difficulty null when absent");
      assertEqual(warnCalls.length, 0, "no warn for absent field");
    },
  },
  {
    name: "explicit null difficulty returns null, no warn",
    fn: () => {
      warnCalls.length = 0;
      const recipe = parseRecipeResponse(buildRecipeJson(null), "v3.1");
      assertEqual(recipe?.difficulty, null, "difficulty null");
      assertEqual(warnCalls.length, 0, "no warn for explicit null");
    },
  },
  {
    name: "invalid string drift ('advanced') returns null AND emits warn with raw + promptVersion",
    fn: () => {
      warnCalls.length = 0;
      const recipe = parseRecipeResponse(buildRecipeJson("advanced"), "v3.1");
      assertEqual(recipe?.difficulty, null, "difficulty null on enum miss");
      assertEqual(warnCalls.length, 1, "exactly one warn emitted");
      const w = lastWarn();
      assertEqual(w.payload?.rawValue, "advanced", "raw value captured");
      assertEqual(w.payload?.rawType, "string", "raw type captured");
      assertEqual(w.payload?.promptVersion, "v3.1", "promptVersion captured");
    },
  },
  {
    name: "non-string drift (number 5) returns null AND emits warn",
    fn: () => {
      warnCalls.length = 0;
      const recipe = parseRecipeResponse(buildRecipeJson(5), "v3.1");
      assertEqual(recipe?.difficulty, null, "difficulty null on type drift");
      assertEqual(warnCalls.length, 1, "exactly one warn emitted");
      const w = lastWarn();
      assertEqual(w.payload?.rawType, "number", "raw type captured for non-string");
    },
  },
  {
    name: "promptVersion absent: warn payload has 'unknown' fallback",
    fn: () => {
      warnCalls.length = 0;
      // Caller doesn't thread promptVersion (legacy or test-only paths).
      const recipe = parseRecipeResponse(buildRecipeJson("expert"));
      assertEqual(recipe?.difficulty, null, "difficulty null");
      assertEqual(warnCalls.length, 1, "warn emitted");
      assertEqual(lastWarn().payload?.promptVersion, "unknown", "fallback promptVersion");
    },
  },
];

function runTests(): void {
  console.log("BUT-546: validateDifficulty drift-logging tests\n");
  console.log("============================================================\n");

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
