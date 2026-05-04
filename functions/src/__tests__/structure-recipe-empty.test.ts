/**
 * BUT-679: regression gate for the "Gemini said this isn't a recipe" path.
 *
 * Run with: npx ts-node src/__tests__/structure-recipe-empty.test.ts
 */

import { __test__ } from "../llm/structure-recipe";
import { assertEqual, runTests, UnitCase } from "./_unit-runner";

const { isNotRecipeResponse } = __test__;

const cases: UnitCase[] = [
  {
    name: "empty ingredients → not a recipe",
    fn: () => {
      const content = JSON.stringify({
        title: "Inget recept hittades",
        ingredients: [],
        instructions: ["throwaway"],
      });
      assertEqual(isNotRecipeResponse(content), true, "ingredients empty");
    },
  },
  {
    name: "empty instructions → not a recipe",
    fn: () => {
      const content = JSON.stringify({
        title: "Whatever",
        ingredients: [{ amount: 1, unit: "dl", name: "mjölk" }],
        instructions: [],
      });
      assertEqual(isNotRecipeResponse(content), true, "instructions empty");
    },
  },
  {
    name: "valid recipe → false",
    fn: () => {
      const content = JSON.stringify({
        title: "Pannkakor",
        ingredients: [{ amount: 3, unit: "dl", name: "mjölk" }],
        instructions: ["Vispa ihop allt."],
      });
      assertEqual(isNotRecipeResponse(content), false, "valid recipe");
    },
  },
  {
    name: "malformed JSON → false (falls through to parser)",
    fn: () => {
      assertEqual(
        isNotRecipeResponse("not valid json"),
        false,
        "malformed JSON"
      );
    },
  },
  {
    name: "empty object → false",
    fn: () => {
      assertEqual(isNotRecipeResponse("{}"), false, "fields missing");
    },
  },
  {
    name: "code-fenced JSON → handled via stripCodeFences",
    fn: () => {
      const content =
        "```json\n" +
        JSON.stringify({
          title: "Inget recept",
          ingredients: [],
          instructions: [],
        }) +
        "\n```";
      assertEqual(isNotRecipeResponse(content), true, "code-fenced");
    },
  },
];

runTests("BUT-679: isNotRecipeResponse tests", cases);
