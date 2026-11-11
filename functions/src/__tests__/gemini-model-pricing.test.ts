/**
 * Per-model pricing in `calculateGeminiCost`: the photo call is priced at the
 * vision model's rate, thought tokens bill as output, an unlisted model is
 * never priced below the dearest listed one, and the default stays the text
 * model's rate.
 *
 * Run: npx ts-node src/__tests__/gemini-model-pricing.test.ts
 */

import { runTests, UnitCase, assertEqual } from "./_unit-runner";
import {
  calculateGeminiCost,
  pricingForModel,
  TEXT_MODEL,
  TEXT_PRICING,
  VISION_MODEL,
  VISION_PRICING,
} from "../llm/gemini-client";

function assertApprox(actual: number, expected: number, msg: string): void {
  if (Math.abs(actual - expected) > 1e-12) {
    throw new Error(`${msg}: expected ${expected}, got ${actual}`);
  }
}

const cases: UnitCase[] = [
  {
    name: "vision usage 2155 in / 633 out / 0 cached is priced at the 3.1 rate",
    fn: () => {
      const cost = calculateGeminiCost(
        {
          promptTokenCount: 2155,
          candidatesTokenCount: 633,
          cachedContentTokenCount: 0,
        },
        0,
        VISION_PRICING,
      );
      // 2155 * 0.275 / 1e6 + 633 * 1.65 / 1e6 = 0.000592625 + 0.00104445
      assertApprox(cost, 0.001637075, "vision cost");
    },
  },
  {
    name: "cached vision tokens use the cached rate",
    fn: () => {
      const cost = calculateGeminiCost(
        { promptTokenCount: 1000, candidatesTokenCount: 0, cachedContentTokenCount: 1000 },
        0,
        VISION_PRICING,
      );
      // 1000 * 0.0275 / 1e6
      assertApprox(cost, 0.0000275, "cached vision cost");
    },
  },
  {
    name: "thoughtsTokenCount is billed at the output rate",
    fn: () => {
      const withThoughts = calculateGeminiCost(
        { promptTokenCount: 0, candidatesTokenCount: 100, thoughtsTokenCount: 400 },
        0,
        VISION_PRICING,
      );
      // (100 + 400) * 1.65 / 1e6
      assertApprox(withThoughts, 0.000825, "thoughts as output");
    },
  },
  {
    name: "an unknown model id gets the highest listed price, not the 2.5 price",
    fn: () => {
      const p = pricingForModel("gemini-9-unlisted");
      assertEqual(p.inputPerM, 0.275, "input");
      assertEqual(p.outputPerM, 1.65, "output");
      assertEqual(p.cachedInputPerM, 0.0275, "cached");
      assertEqual(pricingForModel(TEXT_MODEL), TEXT_PRICING, "text id");
      assertEqual(pricingForModel(VISION_MODEL), VISION_PRICING, "vision id");
    },
  },
  {
    name: "without a pricing argument the 2.5 text rate applies",
    fn: () => {
      const cost = calculateGeminiCost(
        { promptTokenCount: 5000, candidatesTokenCount: 1000 },
        0,
      );
      // 5000 * 0.10 / 1e6 + 1000 * 0.40 / 1e6
      assertApprox(cost, 0.0009, "default text cost");
    },
  },
];

runTests("gemini-model-pricing", cases);
