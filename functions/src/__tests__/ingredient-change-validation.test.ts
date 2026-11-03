/**
 * Server-side validation of proposed ingredient values: every rule both
 * ways, OWASP CSV-injection payloads, and a drift pin against the Dart
 * validator the admin form uses.
 *
 * Run with: npx ts-node src/__tests__/ingredient-change-validation.test.ts
 */

import * as fs from "fs";
import * as path from "path";
import {
  CARBON_CATEGORIES,
  ChangeRejectReason,
  PRICE_CATEGORIES,
  PROPOSABLE_STATUSES,
  validateProposedChange,
} from "../admin/ingredient-change-validation";
import { EDITABLE_COLUMNS } from "../admin/ingredient-compare";
import { assertEqual, runTests, UnitCase } from "./_unit-runner";

function expectOk(column: string, value: unknown): void {
  const r = validateProposedChange(column, value);
  if (!r.ok) throw new Error(`${column}=${JSON.stringify(value)} rejected: ${r.reason}`);
}

function expectReject(column: string, value: unknown, reason: ChangeRejectReason): void {
  const r = validateProposedChange(column, value);
  if (r.ok) throw new Error(`${column}=${JSON.stringify(value)} accepted`);
  assertEqual(r.reason, reason, `${column}=${JSON.stringify(value)}`);
}

const ch = (code: number): string => String.fromCharCode(code);

const OWASP_PAYLOADS = [
  "=cmd|' /C calc'!A0",
  "+1",
  "-1+1",
  "@SUM(1)",
  " =1",
  "\" =1",
  "'=1",
  "  @SUM(A1)",
];

const cases: UnitCase[] = [
  {
    name: "column allowlist: the 16 editable columns pass, everything else is refused",
    fn: () => {
      assertEqual(Object.keys(EDITABLE_COLUMNS).length, 16, "editable column count");
      for (const c of ["verified_by", "updated_date", "id", "created_by", "ai_generated", "__proto__", "constructor"]) {
        expectReject(c, "x", "unknown-column");
      }
    },
  },
  {
    name: "types: text needs string, list needs string[], price needs number or null",
    fn: () => {
      expectReject("notes_sv", 5, "wrong-type");
      expectReject("notes_sv", null, "wrong-type");
      expectReject("aliases_sv", "a;b", "wrong-type");
      expectReject("aliases_sv", ["a", 5], "wrong-type");
      expectReject("avg_price_sek", "12", "wrong-type");
      expectOk("notes_sv", "");
      expectOk("aliases_sv", []);
      expectOk("avg_price_sek", null);
      expectOk("avg_price_sek", 12.5);
    },
  },
  {
    name: "lengths: text 300, list 30 items, item 300",
    fn: () => {
      expectOk("notes_sv", "a".repeat(300));
      expectReject("notes_sv", "a".repeat(301), "too-long");
      expectOk("aliases_sv", Array.from({ length: 30 }, (_, i) => `a${i}`));
      expectReject("aliases_sv", Array.from({ length: 31 }, (_, i) => `a${i}`), "too-many-items");
      expectOk("aliases_sv", ["a".repeat(300)]);
      expectReject("aliases_sv", ["a".repeat(301)], "too-long");
      expectReject("aliases_sv", ["a", "  "], "empty-item");
    },
  },
  {
    name: "vocabularies: properties, group prefix, status, price and carbon categories",
    fn: () => {
      expectOk("properties", ["dairy", "contains-gluten"]);
      expectReject("properties", ["dairy", "raw-safe"], "unknown-property");
      expectOk("group", "protein/dairy");
      expectOk("group", "spice");
      expectReject("group", "proteinx/dairy", "invalid-group");
      expectReject("group", "", "invalid-group");
      for (const s of PROPOSABLE_STATUSES) expectOk("status", s);
      expectReject("status", "deleted", "invalid-status");
      expectReject("status", "", "invalid-status");
      for (const p of PRICE_CATEGORIES) expectOk("price_category", p);
      expectOk("price_category", "");
      expectReject("price_category", "cheap", "invalid-price-category");
      for (const c of CARBON_CATEGORIES) expectOk("carbon_footprint_category", c);
      expectOk("carbon_footprint_category", "");
      expectReject("carbon_footprint_category", "huge", "invalid-carbon-category");
      expectOk("swedish", "mjölk");
      expectReject("swedish", "  ", "empty-required");
      expectOk("english", "");
    },
  },
  {
    name: "price: finite, non-negative, in a form the sync's price check accepts",
    fn: () => {
      expectOk("avg_price_sek", 0);
      expectReject("avg_price_sek", -1, "invalid-price");
      expectReject("avg_price_sek", Number.NaN, "invalid-price");
      expectReject("avg_price_sek", Number.POSITIVE_INFINITY, "invalid-price");
      expectReject("avg_price_sek", 1e21, "invalid-price");
    },
  },
  {
    name: "control characters (C0, C1, CR, LF, tab, U+2028) are refused in text and items",
    fn: () => {
      for (const code of [0x00, 0x09, 0x0a, 0x0d, 0x1b, 0x7f, 0x85, 0x9f, 0x2028, 0x2029]) {
        expectReject("notes_sv", `a${ch(code)}b`, "control-character");
        expectReject("aliases_sv", [`a${ch(code)}b`], "control-character");
      }
      expectOk("notes_sv", "åäö ÅÄÖ é ü – ok");
    },
  },
  {
    name: "format characters (\\p{Cf}: bidi U+202E, U+200B, U+FEFF) are refused",
    fn: () => {
      for (const code of [0x202e, 0x202d, 0x2066, 0x200b, 0x200d, 0xfeff, 0x00ad]) {
        expectReject("notes_en", `abc${ch(code)}def`, "format-character");
        expectReject("search_terms", [`abc${ch(code)}`], "format-character");
      }
    },
  },
  {
    name: "OWASP CSV-injection payloads are refused in text and list items",
    fn: () => {
      for (const p of OWASP_PAYLOADS) {
        expectReject("notes_sv", p, "formula-prefix");
        expectReject("aliases_en", [p.replace("|", "")], "formula-prefix");
      }
      expectReject("notes_sv", "\t=1", "control-character");
      expectOk("notes_sv", "a = b");
      expectOk("notes_sv", "Kan ersättas med t.ex. smör");
      expectOk("aliases_sv", ["a-b", "e@mail"]);
    },
  },
  {
    name: "separators inside one item are refused; a decimal comma is allowed as in Dart",
    fn: () => {
      expectReject("aliases_sv", ["a;b"], "separator-in-item");
      expectReject("aliases_sv", ["a|b"], "separator-in-item");
      expectReject("aliases_sv", ["a,b"], "separator-in-item");
      expectReject("search_terms", ["a, 5"], "separator-in-item");
      expectOk("aliases_sv", ["lättmjölk 0,5%"]);
      expectOk("notes_sv", "Text; with, separators | ok");
    },
  },
  {
    name: "drift pin: status, price and carbon lists equal the Dart validator's",
    fn: () => {
      const dart = fs.readFileSync(
        path.resolve(__dirname, "../../../lib/services/tagging/ingredient_change_validator.dart"),
        "utf-8"
      );
      const quoted = (name: string): string[] => {
        const m = dart.match(new RegExp("const List<String> " + name + " = \\[([^\\]]*)\\]"));
        if (!m) throw new Error(`${name} not found in the Dart validator`);
        return [...m[1].matchAll(new RegExp("'([^']+)'", "g"))].map((x) => x[1]);
      };
      assertEqual(quoted("kProposableStatuses").join(","), PROPOSABLE_STATUSES.join(","), "statuses");
      assertEqual(quoted("kProposablePriceCategories").join(","), PRICE_CATEGORIES.join(","), "price");
      assertEqual(quoted("kProposableCarbonCategories").join(","), CARBON_CATEGORIES.join(","), "carbon");
    },
  },
];

runTests("ingredient-change-validation (admin-vy C1)", cases);
