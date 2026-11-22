/**
 * Photo reading logs no recipe text, including on the structureRecipe retry
 * (real `runStructureRecipe`, model faked), and writes one scrubbed, expiring
 * sample per call. All recipes here are invented.
 * Run: npx ts-node src/__tests__/ocr-photo-logs.test.ts
 */

import type { GeminiClient, GeminiModel } from "../llm/gemini-sdk";
import type { Firestore } from "firebase-admin/firestore";
import { logger } from "firebase-functions/logger";
import { runTests, UnitCase, assertEqual } from "./_unit-runner";
import { runOcrRecipeImage, type OcrPerformResult } from "../llm/ocr-recipe-image";
import { runStructureRecipe } from "../llm/structure-recipe";
import * as geminiClient from "../llm/gemini-client";
import { captureLlmSample, resetSampleCaptureCacheForTest } from "../llm/llm-sample-capture";

const logged: string[] = [];
for (const level of ["debug", "info", "warn", "error", "log"] as const) {
  (logger as unknown as Record<string, (...a: unknown[]) => void>)[level] = (...args: unknown[]) => {
    logged.push(args.map((a) => (a instanceof Error ? `${a.name} ${a.message}` : JSON.stringify(a))).join(" "));
  };
}
// The runner reports through console.log, so console lines are captured AND
// still printed.
const printLine = console.log.bind(console);
for (const level of ["log", "info", "warn", "error"] as const) {
  (console as unknown as Record<string, (...a: unknown[]) => void>)[level] = (...args: unknown[]) => {
    logged.push(args.map((a) => (a instanceof Error ? `${a.name} ${a.message}` : String(a))).join(" "));
    printLine(...args);
  };
}

const TITLE_A = "Qwertykaka";
const TITLE_B = "Zxcvbsoppa";
const INGREDIENT_A = "plommonfluff";
const INGREDIENT_B = "krusbärsgrus";
const SECRETS = [TITLE_A, TITLE_B, INGREDIENT_A, INGREDIENT_B];

function recipe(title: string, ingredient: string) {
  return {
    title,
    description: null,
    portions: 4,
    prepTimeMinutes: 10,
    cookTimeMinutes: 20,
    ingredients: [{ amount: 2, unit: "dl", name: ingredient, preparation: null }],
    instructions: ["Blanda allt."],
    tags: [],
    difficulty: "easy",
    source: null,
  };
}

// The photo answer is prose, so the photo parse fails and the retry runs.
const PROSE = `${TITLE_A}: 2 dl ${INGREDIENT_A}. Blanda allt väl och servera.`;

function opts(performOcr: () => Promise<OcrPerformResult>) {
  return {
    data: { imageBase64: "/9j/" + "A".repeat(40) },
    authUidHash: "test-hash",
    userId: "test-uid",
    performOcr,
    isAiDisabled: async () => false,
    checkGlobalLimit: async () => true,
    checkIngredientRetryUserLimit: async () => true,
    checkUserLimit: async () => true,
    now: () => 1000,
    structureRecipe: (req: Parameters<typeof runStructureRecipe>[0], hash: string) =>
      runStructureRecipe(req, hash, {
        loadKillSwitch: async () => ({ aiEnabled: true, llmParserEnabled: true }),
      }),
  };
}

/** Runs `fn` with the text model answering `text`; returns how often it was called. */
async function withTextModel(text: string, fn: () => Promise<void>): Promise<number> {
  const mutable = geminiClient as {
    getGeminiClient: () => GeminiClient;
    getTextModel: (client: GeminiClient) => GeminiModel;
  };
  const originals = { client: mutable.getGeminiClient, model: mutable.getTextModel };
  let calls = 0;
  mutable.getGeminiClient = () => ({}) as GeminiClient;
  mutable.getTextModel = () =>
    ({
      generateContent: async () => {
        calls++;
        return {
          candidates: [{ content: { role: "model", parts: [{ text }] } }],
          usageMetadata: { promptTokenCount: 1, candidatesTokenCount: 1 },
        };
      },
    }) as unknown as GeminiModel;
  try {
    await fn();
  } finally {
    mutable.getGeminiClient = originals.client;
    mutable.getTextModel = originals.model;
  }
  return calls;
}

function assertNoSecrets(where: string): void {
  const text = logged.join("\n");
  for (const secret of SECRETS) {
    assertEqual(text.includes(secret), false, `${where}: logs contain ${secret}`);
  }
}

const cases: UnitCase[] = [
  {
    name: "a successful structureRecipe retry logs no title or ingredient",
    fn: async () => {
      logged.length = 0;
      let result: Awaited<ReturnType<typeof runOcrRecipeImage>> | undefined;
      const calls = await withTextModel(JSON.stringify(recipe(TITLE_B, INGREDIENT_B)), async () => {
        result = await runOcrRecipeImage(opts(async () => ({ content: PROSE, cost: 0.01 })));
      });
      assertEqual(calls, 1, "the real retry reached the model");
      assertEqual(result?.recipe?.title, TITLE_B, "retry recipe returned");
      assertEqual(logged.some((l) => l.includes("Successfully extracted recipe")), true, "success line logged");
      assertNoSecrets("retry success");
    },
  },
  {
    name: "a failed structureRecipe parse logs neither the answer nor the parse error's quote of it",
    fn: async () => {
      logged.length = 0;
      const calls = await withTextModel(`${TITLE_B} med ${INGREDIENT_B}, inte JSON`, async () => {
        await runOcrRecipeImage(opts(async () => ({ content: PROSE, cost: 0.01 })));
      });
      assertEqual(calls, 1, "the real retry reached the model");
      assertEqual(logged.some((l) => l.includes("Failed to parse response")), true, "parse failure logged");
      assertEqual(logged.some((l) => l.includes("Failed to parse recipe response: SyntaxError")), true, "error name only");
      assertNoSecrets("retry parse failure");
    },
  },
  {
    name: "one runOcrRecipeImage call attempts exactly one photo sample capture",
    fn: async () => {
      logged.length = 0;
      const content = JSON.stringify({ recipes: [recipe(TITLE_A, INGREDIENT_A), recipe(TITLE_B, INGREDIENT_B)] });
      await runOcrRecipeImage(opts(async () => ({ content, cost: 0.01 })));
      // No Firebase app in this process: each capture attempt logs one failure.
      const attempts = logged.filter((l) => l.includes("[llm-sample-capture]"));
      assertEqual(attempts.length, 1, "captures");
    },
  },
  {
    name: "a multi-recipe answer is stored as one sample, capped at 50 000 chars, with expireAt",
    fn: async () => {
      resetSampleCaptureCacheForTest();
      const rows: Record<string, unknown>[] = [];
      const db = {
        doc: () => ({ get: async () => ({ exists: false, data: () => undefined }) }),
        collection: () => ({ add: async (row: Record<string, unknown>) => { rows.push(row); } }),
      } as unknown as Firestore;
      const big = JSON.stringify({
        recipes: Array.from({ length: 6 }, (_, i) => recipe(`Rätt ${i}`, "x".repeat(12_000))),
      });
      await captureLlmSample({ mode: "ocr", inputKind: "image", rawLlmResponse: big, modelId: "m" }, db);
      resetSampleCaptureCacheForTest();
      assertEqual(rows.length, 1, "rows");
      assertEqual((rows[0].scrubbedOutput as string).length, 50_000, "capped");
      assertEqual(rows[0].outputLength, big.length, "full length recorded");
      assertEqual(rows[0].expireAt !== undefined && rows[0].expireAt !== null, true, "expireAt");
    },
  },
];

runTests("ocr-photo-logs", cases);
