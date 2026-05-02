/**
 * BUT-577: parseIngredientLinesResponse partial-array recovery tests.
 *
 * Verifies:
 *   1. Happy path — fully-formed wrapped {ingredients: [...]} response parses
 *      cleanly with truncated=false.
 *   2. Happy path — fully-formed bare [...] array parses cleanly.
 *   3. Salvage — truncated mid-object yields the fully-formed prefix +
 *      truncated=true.
 *   4. Salvage — truncated mid-array (after a complete object, before the next)
 *      yields the recovered prefix + truncated=true.
 *   5. Garbage — completely malformed input returns null (no salvage).
 *
 * Run with: npx ts-node src/__tests__/parse-ingredient-lines.test.ts
 */

import {
  parseIngredientLinesResponse,
  type ParsedIngredientLines,
} from "../llm/gemini-client";

interface UnitCase {
  name: string;
  fn: () => void;
}

function assertEqual<T>(actual: T, expected: T, msg: string): void {
  if (actual !== expected) {
    throw new Error(`${msg}: expected ${JSON.stringify(expected)}, got ${JSON.stringify(actual)}`);
  }
}

function assertNotNull<T>(value: T | null, msg: string): asserts value is T {
  if (value === null) {
    throw new Error(`${msg}: expected non-null result`);
  }
}

function assertNull(value: unknown, msg: string): void {
  if (value !== null) {
    throw new Error(`${msg}: expected null, got ${JSON.stringify(value)}`);
  }
}

const cases: UnitCase[] = [
  {
    name: "happy path: wrapped {ingredients: [...]} parses cleanly with truncated=false",
    fn: () => {
      const json = JSON.stringify({
        ingredients: [
          { amount: 2, unit: "dl", name: "mjölk", preparation: null },
          { amount: 1, unit: "msk", name: "smör", preparation: "smält" },
          { amount: null, unit: null, name: "salt", preparation: null },
        ],
      });
      const result: ParsedIngredientLines | null = parseIngredientLinesResponse(json);
      assertNotNull(result, "wrapped happy path");
      assertEqual(result.truncated, false, "truncated flag");
      assertEqual(result.ingredients.length, 3, "ingredient count");
      assertEqual(result.ingredients[0].name, "mjölk", "first name");
      assertEqual(result.ingredients[1].preparation, "smält", "second preparation");
      assertEqual(result.ingredients[2].amount, null, "third amount nullable");
    },
  },
  {
    name: "happy path: bare [...] array parses cleanly with truncated=false",
    fn: () => {
      const json = JSON.stringify([
        { amount: 100, unit: "g", name: "smör", preparation: null },
        { amount: 2, unit: "st", name: "ägg", preparation: null },
      ]);
      const result = parseIngredientLinesResponse(json);
      assertNotNull(result, "bare array happy path");
      assertEqual(result.truncated, false, "truncated flag");
      assertEqual(result.ingredients.length, 2, "ingredient count");
      assertEqual(result.ingredients[0].name, "smör", "first name");
      assertEqual(result.ingredients[1].name, "ägg", "second name");
    },
  },
  {
    name: "happy path: code-fenced wrapped response strips fences cleanly",
    fn: () => {
      const json =
        '```json\n' +
        JSON.stringify({
          ingredients: [{ amount: 1, unit: "dl", name: "vatten", preparation: null }],
        }) +
        "\n```";
      const result = parseIngredientLinesResponse(json);
      assertNotNull(result, "fenced response");
      assertEqual(result.truncated, false, "truncated flag");
      assertEqual(result.ingredients.length, 1, "ingredient count");
    },
  },
  {
    name: "salvage: truncated mid-object yields fully-formed prefix + truncated=true",
    fn: () => {
      // Mid-string truncation inside the second object's "amount" field —
      // simulates a Gemini token-cap cutoff.
      const truncated =
        '{"ingredients":[' +
        '{"name":"mjöl","amount":2,"unit":"dl","preparation":null},' +
        '{"name":"socker","amou';
      const result = parseIngredientLinesResponse(truncated);
      assertNotNull(result, "salvage mid-object");
      assertEqual(result.truncated, true, "truncated flag");
      assertEqual(result.ingredients.length, 1, "salvaged count");
      assertEqual(result.ingredients[0].name, "mjöl", "salvaged name");
      assertEqual(result.ingredients[0].amount, 2, "salvaged amount");
    },
  },
  {
    name: "salvage: bare array truncated mid-object yields prefix + truncated=true",
    fn: () => {
      const truncated =
        '[{"name":"flour","amount":2,"unit":"cups","preparation":null},' +
        '{"name":"sugar","amou';
      const result = parseIngredientLinesResponse(truncated);
      assertNotNull(result, "salvage bare array mid-object");
      assertEqual(result.truncated, true, "truncated flag");
      assertEqual(result.ingredients.length, 1, "salvaged count");
      assertEqual(result.ingredients[0].name, "flour", "salvaged name");
    },
  },
  {
    name: "salvage: truncated mid-array (between complete objects) yields prefix",
    fn: () => {
      const truncated = '[{"name":"flour","amount":1,"unit":"dl","preparation":null},';
      const result = parseIngredientLinesResponse(truncated);
      assertNotNull(result, "salvage mid-array");
      assertEqual(result.truncated, true, "truncated flag");
      assertEqual(result.ingredients.length, 1, "salvaged count");
      assertEqual(result.ingredients[0].name, "flour", "salvaged name");
    },
  },
  {
    name: "salvage: many complete objects + one truncated tail",
    fn: () => {
      const objs = [
        '{"name":"a","amount":1,"unit":"dl","preparation":null}',
        '{"name":"b","amount":2,"unit":"dl","preparation":null}',
        '{"name":"c","amount":3,"unit":"dl","preparation":null}',
        '{"name":"d","amount":4,"unit":"dl","preparation":null}',
        '{"name":"e","amount":5,"un', // truncated
      ];
      const truncated = '{"ingredients":[' + objs.join(",");
      const result = parseIngredientLinesResponse(truncated);
      assertNotNull(result, "salvage long prefix");
      assertEqual(result.truncated, true, "truncated flag");
      assertEqual(result.ingredients.length, 4, "salvaged count");
      assertEqual(result.ingredients[3].name, "d", "fourth name");
    },
  },
  {
    name: "salvage: brace inside string value does not perturb depth counter",
    fn: () => {
      // The `}` and `{` inside the preparation string must not break the
      // brace counter — this exercises the quote-aware scan.
      const truncated =
        '[{"name":"sås","amount":2,"unit":"dl","preparation":"med } i strängen"},' +
        '{"name":"trunc","amou';
      const result = parseIngredientLinesResponse(truncated);
      assertNotNull(result, "salvage with brace-in-string");
      assertEqual(result.truncated, true, "truncated flag");
      assertEqual(result.ingredients.length, 1, "salvaged count");
      assertEqual(result.ingredients[0].name, "sås", "salvaged name");
      assertEqual(
        result.ingredients[0].preparation,
        "med } i strängen",
        "preparation preserved"
      );
    },
  },
  {
    name: "salvage: escaped quote inside string does not break scan",
    fn: () => {
      const truncated =
        '[{"name":"q\\"u\\"otes","amount":1,"unit":"dl","preparation":null},' +
        '{"name":"trunc","amou';
      const result = parseIngredientLinesResponse(truncated);
      assertNotNull(result, "salvage with escaped quotes");
      assertEqual(result.truncated, true, "truncated flag");
      assertEqual(result.ingredients.length, 1, "salvaged count");
      assertEqual(result.ingredients[0].name, 'q"u"otes', "name with escaped quotes");
    },
  },
  {
    name: "garbage input returns null (no salvage)",
    fn: () => {
      const result = parseIngredientLinesResponse("this is not JSON at all, just prose");
      assertNull(result, "pure garbage");
    },
  },
  {
    name: "empty array returns null (no salvage)",
    fn: () => {
      assertNull(parseIngredientLinesResponse("[]"), "empty bare array");
      assertNull(
        parseIngredientLinesResponse('{"ingredients":[]}'),
        "empty wrapped array"
      );
    },
  },
  {
    name: "salvage: only objects without a valid `name` field yield null",
    fn: () => {
      // Object parses successfully but validateIngredient rejects (no name).
      // After the parse failure path runs, no ingredients survive validation.
      const truncated = '[{"amount":1,"unit":"dl","preparation":null},{"amount":2,"un';
      const result = parseIngredientLinesResponse(truncated);
      assertNull(result, "no salvageable ingredient with name");
    },
  },
];

function runTests(): void {
  console.log("BUT-577: parseIngredientLinesResponse partial-recovery tests\n");
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
