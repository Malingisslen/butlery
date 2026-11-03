/**
 * The admin-vy PR text: values can form no mention, link, image or HTML,
 * allergen-relevant proposals come first, conflicts sit side by side, and
 * the Dart allergen-impact sets are mirrored.
 *
 * Run with: npx ts-node src/__tests__/ingredient-pr-body.test.ts
 */

import * as fs from "fs";
import * as path from "path";
import {
  ANIMAL_PROPERTIES,
  buildPrBody,
  BodyProposal,
  MAX_BODY_CHARS,
  neutralize,
  propertyChangeAffectsAllergens,
  renderValue,
  VEGAN_CLAIMS,
} from "../admin/ingredient-pr-body";
import { assertEqual, runTests, UnitCase } from "./_unit-runner";

function assert(cond: boolean, msg: string): void {
  if (!cond) throw new Error(msg);
}

const HOSTILE = ["@user", "![x](http://x)", "<script>alert(1)</script>", "a`b``c", "[link](http://y)", "x|y", "rad\nbryt"];

const proposal = (id: string, column: string, old: unknown, next: unknown): BodyProposal => ({
  ingredientId: id, swedishName: `Namn ${id}`, changes: [{ column, old, new: next }],
});

const cases: UnitCase[] = [
  {
    name: "neutralize leaves no backtick, @, brackets, !, angle brackets, pipe or line break",
    fn: () => {
      for (const v of HOSTILE) {
        const out = neutralize(v);
        assert(!/[`@[\]!<>|\r\n]/.test(out), `${JSON.stringify(v)} -> ${out}`);
      }
    },
  },
  {
    name: "hostile values in names, ids, old and new values and conflicts form no markup",
    fn: () => {
      const body = buildPrBody({
        applied: HOSTILE.map((v, i) => ({
          ingredientId: `id${i}${v}`, swedishName: v,
          changes: [{ column: "notes_sv", old: v, new: v }, { column: "aliases_sv", old: [v], new: [v, "ok"] }],
        })),
        conflicts: HOSTILE.map((v) => ({ ingredientId: v, swedishName: v, column: "swedish", csvValue: v, old: v, new: v })),
        rejected: HOSTILE.map((v) => ({ ingredientId: v, reason: "too-long" })),
      });
      for (const needle of ["@user", "](", "![", "<script", "</", "``"]) {
        assert(!body.includes(needle), `body contains ${needle}`);
      }
      for (const line of body.split("\n")) {
        const ticks = (line.match(/`/g) ?? []).length;
        assertEqual(ticks % 2, 0, `balanced code spans on: ${line}`);
        if (line.startsWith("| ") && !line.startsWith("| Ingrediens")) {
          assertEqual(line.split("|").length, 7, `a conflict row keeps its five cells: ${line}`);
        }
      }
    },
  },
  {
    name: "allergen-column proposals come first; a dropped allergen property carries the warning",
    fn: () => {
      const body = buildPrBody({
        applied: [
          proposal("notes", "notes_sv", "a", "b"),
          proposal("milk", "properties", ["dairy", "contains-lactose"], ["dairy"]),
          proposal("grp", "group", "veg", "veg/leaf"),
        ],
        conflicts: [], rejected: [],
      });
      const allergen = body.indexOf("## Påverkar allergener");
      const other = body.indexOf("## Övriga ändringar");
      assert(allergen >= 0 && other > allergen, "sections in order");
      assert(body.indexOf("`milk`") < other && body.indexOf("`grp`") < other, "allergen columns first");
      assert(body.indexOf("`notes`") > other, "notes in the other section");
      const milkLine = body.split("\n").find((l) => l.includes("`milk`"))!;
      assert(milkLine.includes("Varning"), "warning on milk");
      const grpLine = body.split("\n").find((l) => l.includes("`grp`"))!;
      assert(!grpLine.includes("Varning"), "a group change alone has no warning");
    },
  },
  {
    name: "the body says properties retag recipes and other fields do not",
    fn: () => {
      const body = buildPrBody({ applied: [proposal("a", "swedish", "A", "B")], conflicts: [], rejected: [] });
      assert(body.includes("on-ingredient-properties-changed"), "names the trigger");
      assert(body.includes("taggar inte om befintliga recept"), "other fields do not retag");
    },
  },
  {
    name: "a conflict shows the CSV value, the old and the new side by side; a missing row says so",
    fn: () => {
      const body = buildPrBody({
        applied: [],
        conflicts: [
          { ingredientId: "x", swedishName: "X", column: "status", csvValue: "verified", old: "draft", new: "validated" },
          { ingredientId: "gone", swedishName: null, column: null, csvValue: null, old: null, new: null },
        ],
        rejected: [],
      });
      assert(body.includes("| `X` (`x`) | `status` | `verified` | `draft` | `validated` |"), body);
      assert(body.includes("*saknas i CSV:n*"), "missing row");
    },
  },
  {
    name: "empty values render as (tomt), lists joined",
    fn: () => {
      assertEqual(renderValue(""), "*(tomt)*", "blank");
      assertEqual(renderValue(null), "*(tomt)*", "null");
      assertEqual(renderValue([]), "*(tomt)*", "empty list");
      assertEqual(renderValue(["a", "b"]), "`a, b`", "list");
      assertEqual(renderValue(12.5), "`12.5`", "number");
    },
  },
  {
    name: "the body stays under GitHub's cap and says how many were left out",
    fn: () => {
      const many = Array.from({ length: 3000 }, (_, i) => proposal(`ingredient-${i}`, "notes_sv", "x".repeat(40), "y".repeat(40)));
      const body = buildPrBody({ applied: many, conflicts: [], rejected: [] });
      assert(body.length <= MAX_BODY_CHARS, `length ${body.length}`);
      assert(/… och \d+ förslag till, se diffen\./.test(body), "left-out note");
    },
  },
  {
    name: "allergen impact: same decisions as the Dart predicate",
    fn: () => {
      assertEqual(propertyChangeAffectsAllergens(["contains-gluten"], []), true, "allergen removed");
      assertEqual(propertyChangeAffectsAllergens([], ["contains-gluten"]), false, "allergen added");
      assertEqual(propertyChangeAffectsAllergens(["dairy"], ["dairy", "vegan-friendly"]), true, "vegan claim beside animal");
      assertEqual(propertyChangeAffectsAllergens([], ["vegan-friendly"]), false, "clean vegan claim");
      assertEqual(propertyChangeAffectsAllergens(["animal-product"], ["animal-product", "plant-based"]), true, "plant-based beside animal-product");
    },
  },
  {
    name: "drift pin: vegan claims and animal properties equal the Dart sets",
    fn: () => {
      const dart = fs.readFileSync(
        path.resolve(__dirname, "../../../lib/models/tagging/ingredient_allergen_impact.dart"), "utf-8"
      );
      const set = (name: string): string[] => {
        const m = dart.match(new RegExp("const Set<String> " + name + " = \\{([^}]*)\\}"));
        if (!m) throw new Error(`${name} not found in the Dart file`);
        return [...m[1].matchAll(new RegExp("'([^']+)'", "g"))].map((x) => x[1]);
      };
      assertEqual(set("_veganClaims").join(","), VEGAN_CLAIMS.join(","), "vegan claims");
      assertEqual(set("_animalProperties").join(","), ANIMAL_PROPERTIES.join(","), "animal properties");
    },
  },
];

runTests("ingredient-pr-body (admin-vy C2)", cases);
