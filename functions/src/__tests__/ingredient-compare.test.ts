/**
 * The shared ingredient comparison: the proposal-vs-CSV check
 * (`columnValuesEqual`) and the sync's `hasChanges`, which now delegates to
 * the same normaliser and must keep its earlier results.
 *
 * Run with: npx ts-node src/__tests__/ingredient-compare.test.ts
 */

import * as fs from "fs";
import * as path from "path";
import {
  columnValuesEqual,
  comparableIngredient,
  docValueForColumn,
  EDITABLE_COLUMNS,
} from "../admin/ingredient-compare";
import { csvToFirestore, hasChanges, IngredientRow } from "../admin/sync-ingredients-core";
import { assertEqual, runTests, UnitCase } from "./_unit-runner";

function row(overrides: Partial<IngredientRow>): IngredientRow {
  return {
    id: "x", swedish: "mjölk", english: "milk", group: "protein/dairy",
    properties: "dairy,animal-product", aliases_sv: "mellanmjölk;standardmjölk",
    aliases_en: "", search_terms: "", status: "validated", season_availability: "",
    price_category: "", carbon_footprint_category: "", notes_sv: "", notes_en: "",
    typical_storage: "", typical_unit: "", avg_price_sek: "",
    ...overrides,
  } as IngredientRow;
}

function storedFrom(r: IngredientRow): Record<string, unknown> {
  const { updatedAt: _ignored, ...rest } = csvToFirestore(r);
  void _ignored;
  return rest;
}

function assert(cond: boolean, msg: string): void {
  if (!cond) throw new Error(msg);
}

const cases: UnitCase[] = [
  {
    name: "english fallback: a blank english cell compares equal to the swedish name",
    fn: () => {
      const doc = csvToFirestore(row({ english: "" }));
      assertEqual(comparableIngredient(doc).english, "mjölk", "comparable english");
      assert(columnValuesEqual("english", docValueForColumn(doc, "english"), "mjölk"), "equal to swedish");
      assert(!columnValuesEqual("english", docValueForColumn(doc, "english"), ""), "not blank");
    },
  },
  {
    name: "decimal comma: '12,50' in the CSV equals 12.5 from a proposal",
    fn: () => {
      const doc = csvToFirestore(row({ avg_price_sek: "12,50" }));
      assert(columnValuesEqual("avg_price_sek", doc.avgPriceSek, 12.5), "12,50 == 12.5");
      assert(columnValuesEqual("avg_price_sek", "12,50", 12.5), "string form");
      assert(!columnValuesEqual("avg_price_sek", doc.avgPriceSek, 12), "not truncated");
      assert(!columnValuesEqual("avg_price_sek", "ca 15", 15), "junk is no price");
    },
  },
  {
    name: "lists compare without regard to order",
    fn: () => {
      assert(columnValuesEqual("properties", ["dairy", "animal-product"], ["animal-product", "dairy"]), "order");
      assert(!columnValuesEqual("properties", ["dairy"], ["dairy", "egg"]), "extra item");
      assert(columnValuesEqual("season_availability", undefined, []), "absent list == []");
      assert(!columnValuesEqual("aliases_sv", "a;b", ["a", "b"]), "a raw string is not a list");
    },
  },
  {
    name: "blank and absent are the same value for text and price",
    fn: () => {
      assert(columnValuesEqual("notes_sv", undefined, ""), "text");
      assert(columnValuesEqual("avg_price_sek", undefined, null), "price null == absent");
      assert(columnValuesEqual("avg_price_sek", "", null), "price blank cell == null");
      assert(!columnValuesEqual("notes_sv", "a", ""), "text differs");
    },
  },
  {
    name: "every editable column maps to a field csvToFirestore produces",
    fn: () => {
      const doc = csvToFirestore(row({
        notes_sv: "n", notes_en: "n", season_availability: "summer", typical_storage: "dry",
        typical_unit: "g", price_category: "budget", avg_price_sek: "1", carbon_footprint_category: "low",
        aliases_en: "a", search_terms: "s",
      }));
      for (const column of Object.keys(EDITABLE_COLUMNS) as Array<keyof typeof EDITABLE_COLUMNS>) {
        assert(docValueForColumn(doc, column) !== undefined, `${column} has no value`);
      }
    },
  },
  {
    name: "unknown column throws",
    fn: () => {
      let threw = false;
      try {
        columnValuesEqual("verified_by", "a", "a");
      } catch {
        threw = true;
      }
      assert(threw, "verified_by is not editable");
    },
  },
  {
    name: "hasChanges keeps its results: list order, blank vs absent, english fallback",
    fn: () => {
      const r = row({ english: "" });
      const stored = storedFrom(r);
      assert(!hasChanges(stored, csvToFirestore(r)), "identical");
      stored.properties = ["animal-product", "dairy"];
      stored.notesSv = "";
      assert(!hasChanges(stored, csvToFirestore(r)), "reordered list + empty string");
      assert(hasChanges({ ...stored, english: "" }, csvToFirestore(r)), "stored blank english vs fallback");
      assert(hasChanges(storedFrom(r), csvToFirestore(row({ english: "", aliases_en: "x" }))), "aliasesEn compared");
      assert(hasChanges({ ...storedFrom(r), normalizedNames: [] }, csvToFirestore(r)), "normalizedNames compared");
    },
  },
  {
    name: "hasChanges compares the price exactly as stored (a stored null is still a change)",
    fn: () => {
      const r = row({});
      assert(hasChanges({ ...storedFrom(r), avgPriceSek: null }, csvToFirestore(r)), "null vs absent");
      assert(!hasChanges(storedFrom(row({ avg_price_sek: "12,5" })), csvToFirestore(row({ avg_price_sek: "12.5" }))), "12,5 == 12.5");
    },
  },
  {
    name: "hasChanges on a corrupt non-array list keeps the pre-extraction listEquals result",
    fn: () => {
      const r = row({ properties: "" });
      assert(hasChanges({ ...storedFrom(r), properties: "x" }, csvToFirestore(r)), "string vs []");
    },
  },
  {
    name: "drift pin: EDITABLE_COLUMNS equals the column/kind pairs of IngredientColumn in Dart",
    fn: () => {
      const dart = fs.readFileSync(
        path.resolve(__dirname, "../../../lib/models/tagging/ingredient_column.dart"),
        "utf-8"
      );
      const body = dart.slice(dart.indexOf("enum IngredientColumn {"), dart.indexOf("const IngredientColumn("));
      const pairs = [...body.matchAll(new RegExp("\\(\\s*'([a-z_]+)',\\s*IngredientColumnKind\\.(text|list|number),?\\s*\\)", "g"))]
        .map((m) => `${m[1]}:${m[2]}`);
      if (pairs.length === 0) throw new Error("no IngredientColumn entries found in the Dart file");
      const ours = Object.entries(EDITABLE_COLUMNS).map(([column, spec]) => `${column}:${spec.kind}`);
      assertEqual(pairs.join(","), ours.join(","), "columns and kinds, in order");
    },
  },
];

runTests("ingredient-compare (admin-vy C1)", cases);
