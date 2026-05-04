/**
 * BUT-522: regression gate for the description-length cap (300 chars).
 *
 * Run with: npx ts-node src/__tests__/parse-recipe-response-description-length.test.ts
 */

import { parseRecipeResponse } from "../llm/gemini-client";
import { assertEqual, runTests, UnitCase } from "./_unit-runner";

function buildRecipeJson(description: unknown): string {
  return JSON.stringify({
    title: "Pannkakor",
    description,
    ingredients: [{ amount: 3, unit: "dl", name: "mjölk" }],
    instructions: ["Vispa ihop allt."],
    tags: [],
  });
}

const cases: UnitCase[] = [
  {
    name: "preserves descriptions under the 300-char cap",
    fn: () => {
      const desc = "Klassiska svenska pannkakor.";
      const recipe = parseRecipeResponse(buildRecipeJson(desc));
      assertEqual(recipe?.description, desc, "short description preserved");
    },
  },
  {
    name: "preserves descriptions exactly 300 chars",
    fn: () => {
      const desc = "x".repeat(300);
      const recipe = parseRecipeResponse(buildRecipeJson(desc));
      assertEqual(recipe?.description?.length, 300, "300-char preserved");
      assertEqual(recipe?.description, desc, "300-char identity");
    },
  },
  {
    name: "truncates descriptions over 300 chars to exactly 300",
    fn: () => {
      const desc = "y".repeat(500);
      const recipe = parseRecipeResponse(buildRecipeJson(desc));
      assertEqual(recipe?.description?.length, 300, "truncated length");
      assertEqual(recipe?.description, "y".repeat(300), "truncated content");
    },
  },
  {
    name: "returns null description for non-string values",
    fn: () => {
      const recipe = parseRecipeResponse(buildRecipeJson(42));
      assertEqual(recipe?.description, null, "non-string → null");
    },
  },
];

runTests("BUT-522: description length cap tests", cases);
