/**
 * BUT-1032 phase 1: implicit-cache observability + cache-aware cost telemetry.
 *
 * Two things under test:
 *   1. `calculateGeminiCost` prices cached prompt tokens
 *      (`usageMetadata.cachedContentTokenCount`) at 10% of the input rate,
 *      with defensive clamping to [0, promptTokenCount] and unchanged
 *      behavior when the field is absent.
 *   2. The `structure_recipe.complete` success log carries the three raw
 *      token-count fields when Vertex reports them.
 *
 * Telemetry-only — no request-behavior change is asserted or implied.
 *
 * Run with: npx ts-node src/__tests__/gemini-cache-telemetry.test.ts
 */

import { logger } from "firebase-functions/logger";
import type { GenerativeModel, VertexAI } from "@google-cloud/vertexai";
import * as geminiClient from "../llm/gemini-client";
import { calculateGeminiCost } from "../llm/gemini-client";
import { runStructureRecipe } from "../llm/structure-recipe";
import { assertEqual, runTests, UnitCase } from "./_unit-runner";

// Pricing constants mirrored from gemini-client.ts (private there). If these
// drift, the exact-cost assertions below go red — intentional: a silent price
// change should force this telemetry suite to be re-reviewed.
const INPUT_COST_PER_M = 0.10;
const OUTPUT_COST_PER_M = 0.40;
const CACHED_INPUT_DISCOUNT = 0.10;

function assertApprox(actual: number, expected: number, msg: string): void {
  if (Math.abs(actual - expected) > 1e-12) {
    throw new Error(`${msg}: expected ~${expected}, got ${actual}`);
  }
}

// =============================================================================
// calculateGeminiCost — cache-aware pricing
// =============================================================================

const costCases: UnitCase[] = [
  {
    name: "cached tokens discounted at 10% of input rate",
    fn: () => {
      // 5000 prompt tokens of which 4000 cached, 1000 output tokens.
      // fresh 1000 @ full input rate + 4000 @ 10% input rate + 1000 output.
      const cost = calculateGeminiCost(
        {
          promptTokenCount: 5000,
          candidatesTokenCount: 1000,
          cachedContentTokenCount: 4000,
        },
        0,
      );
      const expected =
        ((1000 + 4000 * CACHED_INPUT_DISCOUNT) / 1_000_000) * INPUT_COST_PER_M +
        (1000 / 1_000_000) * OUTPUT_COST_PER_M;
      assertApprox(cost, expected, "cache-discounted cost");
      // Pin the literal value too so the formula can't drift unnoticed:
      // (1400/1e6)*0.10 + (1000/1e6)*0.40 = 0.00014 + 0.0004 = 0.00054.
      assertApprox(cost, 0.00054, "cache-discounted cost (literal)");
    },
  },
  {
    name: "cachedContentTokenCount undefined → old behavior (full input rate)",
    fn: () => {
      const cost = calculateGeminiCost(
        { promptTokenCount: 5000, candidatesTokenCount: 1000 },
        0,
      );
      const expected =
        (5000 / 1_000_000) * INPUT_COST_PER_M +
        (1000 / 1_000_000) * OUTPUT_COST_PER_M;
      assertApprox(cost, expected, "uncached cost");
      assertApprox(cost, 0.0009, "uncached cost (literal)");
    },
  },
  {
    name: "cached > prompt clamps to promptTokenCount",
    fn: () => {
      // Malformed: 5000 cached vs 1000 prompt. Clamped to 1000 → the whole
      // prompt is priced at the discount, never a negative fresh-token slice.
      const cost = calculateGeminiCost(
        {
          promptTokenCount: 1000,
          candidatesTokenCount: 0,
          cachedContentTokenCount: 5000,
        },
        0,
      );
      const expected =
        ((1000 * CACHED_INPUT_DISCOUNT) / 1_000_000) * INPUT_COST_PER_M;
      assertApprox(cost, expected, "clamped-to-prompt cost");
      if (cost < 0) throw new Error(`cost went negative: ${cost}`);
    },
  },
  {
    name: "negative cached clamps to 0 (same as undefined)",
    fn: () => {
      const withNegative = calculateGeminiCost(
        {
          promptTokenCount: 5000,
          candidatesTokenCount: 1000,
          cachedContentTokenCount: -400,
        },
        0,
      );
      const withoutField = calculateGeminiCost(
        { promptTokenCount: 5000, candidatesTokenCount: 1000 },
        0,
      );
      assertApprox(withNegative, withoutField, "negative cached ignored");
    },
  },
  {
    name: "minCost floor still applies to cache-discounted totals",
    fn: () => {
      // Same usage as case 1 (true cost 0.00054) with the default minCost:
      // the floor wins.
      const cost = calculateGeminiCost({
        promptTokenCount: 5000,
        candidatesTokenCount: 1000,
        cachedContentTokenCount: 4000,
      });
      assertEqual(cost, 0.001, "floored at default minCost");
    },
  },
  {
    name: "undefined usage → minCost (unchanged)",
    fn: () => {
      assertEqual(calculateGeminiCost(undefined), 0.001, "undefined usage");
      assertEqual(calculateGeminiCost(undefined, 0.05), 0.05, "custom minCost");
    },
  },
];

// =============================================================================
// structure_recipe.complete success log carries token counts
// =============================================================================

interface CapturedLog {
  message: string;
  meta?: Record<string, unknown>;
}

const logCase: UnitCase = {
  name: "structure_recipe.complete (success) includes the three token counts",
  fn: async () => {
    const captured: CapturedLog[] = [];
    const originalInfo = logger.info;
    const originalGetClient = geminiClient.getGeminiClient;
    const originalGetTextModel = geminiClient.getTextModel;

    // The CJS emit makes these exports plain writable properties, and
    // structure-recipe resolves them via the module object at call time —
    // same hijack pattern as the logger capture in ocr-validation.test.ts.
    const mutable = geminiClient as {
      getGeminiClient: () => VertexAI;
      getTextModel: (client: VertexAI) => GenerativeModel;
    };

    const recipeJson = JSON.stringify({
      title: "Pannkakor",
      description: null,
      portions: 4,
      prepTimeMinutes: 5,
      cookTimeMinutes: 15,
      ingredients: [
        { amount: 3, unit: "dl", name: "mjölk", preparation: null },
      ],
      instructions: ["Vispa ihop allt.", "Stek i smör."],
      tags: ["frukost"],
      difficulty: "easy",
      source: null,
    });

    const fakeModel = {
      generateContent: async () => ({
        response: {
          candidates: [
            { content: { role: "model", parts: [{ text: recipeJson }] } },
          ],
          usageMetadata: {
            promptTokenCount: 5000,
            candidatesTokenCount: 1000,
            cachedContentTokenCount: 4000,
          },
        },
      }),
    } as unknown as GenerativeModel;

    try {
      (logger as unknown as { info: (...args: unknown[]) => void }).info = (
        ...args: unknown[]
      ) => {
        captured.push({
          message: String(args[0] ?? ""),
          meta: args[1] as Record<string, unknown> | undefined,
        });
      };
      mutable.getGeminiClient = () => ({} as unknown as VertexAI);
      mutable.getTextModel = () => fakeModel;

      const result = await runStructureRecipe(
        {
          text:
            "Pannkakor: 3 dl mjölk, 1.5 dl vetemjöl, 2 ägg. " +
            "Vispa ihop allt. Stek i smör.",
          mode: "extract",
        },
        "uid-hash",
        {
          loadKillSwitch: async () => ({
            aiEnabled: true,
            llmParserEnabled: true,
          }),
        },
      );

      assertEqual(result.success, true, "extraction succeeds");

      const complete = captured.find(
        (l) => l.message === "structure_recipe.complete",
      );
      if (!complete || !complete.meta) {
        throw new Error("structure_recipe.complete log not captured");
      }
      assertEqual(complete.meta.success, true, "log success flag");
      assertEqual(complete.meta.promptTokenCount, 5000, "promptTokenCount");
      assertEqual(
        complete.meta.candidatesTokenCount,
        1000,
        "candidatesTokenCount",
      );
      assertEqual(
        complete.meta.cachedContentTokenCount,
        4000,
        "cachedContentTokenCount",
      );
    } finally {
      (logger as unknown as { info: typeof originalInfo }).info = originalInfo;
      mutable.getGeminiClient = originalGetClient;
      mutable.getTextModel = originalGetTextModel;
    }
  },
};

runTests("BUT-1032: implicit-cache cost + telemetry tests", [
  ...costCases,
  logCase,
]);
