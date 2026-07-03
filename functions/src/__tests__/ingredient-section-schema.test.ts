/**
 * Ingredient sections (PR #211, prompt v3.0.0): section-field contract tests.
 *
 * Proves the server-side half of the section pipeline:
 *   (a) `parseRecipeResponse` carries a `section` string through to
 *       `ExtractedIngredient.section`
 *   (b) blank/whitespace sections coerce to null (no phantom groups)
 *   (c) sections are trimmed and hard-capped at 60 chars — responseSchema
 *       cannot enforce string length, so validateIngredient must
 *       (acceptance criterion 9)
 *   (d) a missing section key (old cached responses, pre-3.0.0 replays)
 *       parses as null — backward compatible
 *   (e) the extraction prompt teaches the section field (rule + EXEMPEL 4)
 *       and no longer teaches the old flatten-into-preparation workaround
 *
 * Run with: npx ts-node src/__tests__/ingredient-section-schema.test.ts
 */

import {
  parseRecipeResponse,
  PROMPT_VERSION,
  RECIPE_EXTRACTION_SYSTEM_PROMPT,
  IMAGE_OCR_SYSTEM_PROMPT,
  IMAGE_OCR_HANDWRITTEN_SYSTEM_PROMPT,
  SPOKEN_CONTENT_SYSTEM_PROMPT,
} from "../llm/gemini-client";

interface UnitCase {
  name: string;
  fn: () => void;
}

function assertEqual<T>(actual: T, expected: T, msg: string): void {
  if (actual !== expected) {
    throw new Error(
      `${msg}: expected ${JSON.stringify(expected)}, got ${JSON.stringify(actual)}`
    );
  }
}

function assert(cond: boolean, msg: string): void {
  if (!cond) throw new Error(msg);
}

function buildRecipeJson(ingredients: unknown[]): string {
  return JSON.stringify({
    title: "Kanelbullar",
    ingredients,
    instructions: ["Baka."],
    tags: ["fika"],
  });
}

const cases: UnitCase[] = [
  {
    name: "section string is carried through to ExtractedIngredient",
    fn: () => {
      const recipe = parseRecipeResponse(
        buildRecipeJson([
          { name: "vetemjöl", amount: 5, unit: "dl", section: "Deg" },
          { name: "smör", amount: 75, unit: "g", preparation: "rumsvarmt", section: "Fyllning" },
        ])
      );
      assert(recipe !== null, "recipe parses");
      assertEqual(recipe!.ingredients[0].section, "Deg", "first section");
      assertEqual(recipe!.ingredients[1].section, "Fyllning", "second section");
      assertEqual(
        recipe!.ingredients[1].preparation,
        "rumsvarmt",
        "preparation stays clean, no group-name suffix"
      );
    },
  },
  {
    name: "blank / whitespace-only section coerces to null",
    fn: () => {
      const recipe = parseRecipeResponse(
        buildRecipeJson([
          { name: "salt", section: "" },
          { name: "peppar", section: "   " },
        ])
      );
      assert(recipe !== null, "recipe parses");
      assertEqual(recipe!.ingredients[0].section, null, "empty string");
      assertEqual(recipe!.ingredients[1].section, null, "whitespace");
    },
  },
  {
    name: "section is trimmed and truncated to 60 chars",
    fn: () => {
      const long = "X".repeat(80);
      const recipe = parseRecipeResponse(
        buildRecipeJson([
          { name: "socker", section: `  Glasyr  ` },
          { name: "mjöl", section: long },
        ])
      );
      assert(recipe !== null, "recipe parses");
      assertEqual(recipe!.ingredients[0].section, "Glasyr", "trimmed");
      assertEqual(recipe!.ingredients[1].section!.length, 60, "capped at 60");
      assertEqual(recipe!.ingredients[1].section, long.slice(0, 60), "prefix kept");
    },
  },
  {
    name: "60-cap slices by code point, never splitting an emoji surrogate",
    fn: () => {
      // 58 ASCII + an astral emoji (2 UTF-16 units) straddling index 59-60.
      // A naive .slice(0,60) would keep a lone high surrogate; code-point
      // slicing keeps the whole emoji (or drops it whole).
      const heading = "X".repeat(58) + "🍰" + "more";
      const recipe = parseRecipeResponse(
        buildRecipeJson([{ name: "glasyr", section: heading }])
      );
      assert(recipe !== null, "recipe parses");
      const out = recipe!.ingredients[0].section!;
      // No lone surrogate: the string round-trips through UTF-8 unchanged.
      assertEqual(
        Buffer.from(out, "utf8").toString("utf8"),
        out,
        "valid UTF-8 (no unpaired surrogate)"
      );
      assert(
        Array.from(out).length <= 60,
        "at most 60 code points"
      );
      assert(!/[\uD800-\uDFFF]/.test(out.slice(-1)), "no trailing lone surrogate");
    },
  },
  {
    name: "non-string / missing section parses as null (pre-3.0.0 replays)",
    fn: () => {
      const recipe = parseRecipeResponse(
        buildRecipeJson([
          { name: "mjölk", amount: 2, unit: "dl" },
          { name: "jäst", section: 42 },
        ])
      );
      assert(recipe !== null, "recipe parses");
      assertEqual(recipe!.ingredients[0].section, null, "missing key");
      assertEqual(recipe!.ingredients[1].section, null, "non-string");
    },
  },
  {
    name: "prompt v3.1.0 teaches section and drops the preparation flatten",
    fn: () => {
      assertEqual(PROMPT_VERSION, "3.1.0", "prompt version");
      assert(
        RECIPE_EXTRACTION_SYSTEM_PROMPT.includes('sätt section="Deg"'),
        "group rule instructs the section field"
      );
      assert(
        RECIPE_EXTRACTION_SYSTEM_PROMPT.includes('"section":"Fyllning"'),
        "EXEMPEL 4 demonstrates the section field"
      );
      assert(
        !RECIPE_EXTRACTION_SYSTEM_PROMPT.includes('preparation="deg"'),
        "old flatten-into-preparation rule is gone"
      );
      assert(
        !RECIPE_EXTRACTION_SYSTEM_PROMPT.includes('"smält, deg"'),
        "EXEMPEL 4 no longer flattens the group into preparation"
      );
    },
  },
  {
    // Finding D: OCR/handwritten/spoken prompts share RECIPE_SCHEMA (where a
    // bare name:"Deg" is valid), so they must ALSO carry the group rule or a
    // photographed/transcribed grouped recipe can emit a phantom heading row.
    name: "v3.1.0: the group rule reaches the OCR, handwritten, and spoken prompts",
    fn: () => {
      const rule = 'sätt section="Deg"';
      assert(
        IMAGE_OCR_SYSTEM_PROMPT.includes(rule),
        "photo OCR prompt carries the group rule"
      );
      assert(
        IMAGE_OCR_HANDWRITTEN_SYSTEM_PROMPT.includes(rule),
        "handwritten OCR prompt carries the group rule"
      );
      assert(
        SPOKEN_CONTENT_SYSTEM_PROMPT.includes(rule),
        "spoken prompt carries the group rule"
      );
      assert(
        IMAGE_OCR_SYSTEM_PROMPT.includes("ALDRIG en egen ingrediens"),
        "the phantom-heading prohibition is present, not just the field name"
      );
    },
  },
];

function runTests(): void {
  console.log("Ingredient sections: section-field contract tests\n");
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
