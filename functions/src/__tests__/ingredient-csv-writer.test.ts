/**
 * Admin-vy CSV writer: the reviewed PR diff must show exactly the edited
 * cells, and every written cell must read back through the sync's own parser
 * as the intended value.
 *
 * Run with: npx ts-node src/__tests__/ingredient-csv-writer.test.ts
 */

import * as fs from "fs";
import * as path from "path";
import {
  applyCellChanges,
  applyCellChangesDetailed,
  CellChange,
  CsvWriteError,
  parseCsvFile,
  serializeCsvFile,
  VERIFIED_BY_ADMIN_VY,
} from "../admin/ingredient-csv-writer";
import { EDITABLE_COLUMNS, EditableColumn, columnValuesEqual } from "../admin/ingredient-compare";
import { csvToFirestore, IngredientDoc, IngredientRow, parseCsvLine } from "../admin/sync-ingredients-core";
import { assertEqual, runTests, UnitCase } from "./_unit-runner";

const CSV_PATH = path.resolve(
  __dirname, "../../../docs/tagging/data/Butlery_Ingredients_INGREDIENTS.csv"
);
const REAL = fs.readFileSync(CSV_PATH, "utf-8");
const NOW = new Date("2026-11-03T12:00:00Z");

function assert(cond: boolean, msg: string): void {
  if (!cond) throw new Error(msg);
}

function assertThrowsCode(fn: () => unknown, code: string, msg: string): void {
  try {
    fn();
  } catch (err) {
    assert(err instanceof CsvWriteError, `${msg}: threw a non-CsvWriteError: ${err}`);
    assertEqual((err as CsvWriteError).code, code, msg);
    return;
  }
  throw new Error(`${msg}: did not throw`);
}

function changedLineIndexes(a: string, b: string): number[] {
  const x = a.split("\n");
  const y = b.split("\n");
  assertEqual(y.length, x.length, "line count");
  return x.map((l, i) => (l === y[i] ? -1 : i)).filter((i) => i >= 0);
}

function docFor(text: string, id: string): IngredientDoc {
  const lines = text.split("\n");
  const header = parseCsvLine(lines[0]);
  const line = lines.find((l) => parseCsvLine(l)[0] === id);
  if (!line) throw new Error(`no line for ${id}`);
  const values = parseCsvLine(line);
  const row: Record<string, string> = {};
  header.forEach((h, j) => (row[h] = values[j]));
  return csvToFirestore(row as IngredientRow);
}

function cellOf(text: string, id: string, column: string): string {
  const file = parseCsvFile(text);
  const row = file.rows.find((r) => r.values[0] === id)!;
  return row.values[file.header.indexOf(column)];
}

function firstRowWhere(pred: (cell: (c: string) => string) => boolean): string {
  const file = parseCsvFile(REAL);
  const row = file.rows.find((r) => pred((c) => r.values[file.header.indexOf(c)]));
  if (!row) throw new Error("fixture row not found in the real CSV");
  return row.values[0];
}

const cases: UnitCase[] = [
  {
    name: "real CSV: parse + serialize is byte-identical",
    fn: () => {
      assertEqual(serializeCsvFile(parseCsvFile(REAL)), REAL, "round trip");
      assertEqual(applyCellChanges(REAL, [], { now: NOW }), REAL, "empty change set");
    },
  },
  {
    name: "real CSV: every row parses to the header width (writer sees what the sync sees)",
    fn: () => {
      const file = parseCsvFile(REAL);
      const dataLines = REAL.split("\n").filter((l) => l.trim()).length - 1;
      assertEqual(file.rows.length, dataLines, "row count");
    },
  },
  {
    name: "one-cell edit changes exactly one line, stamps updated_date and verified_by",
    fn: () => {
      const out = applyCellChanges(REAL, [{ id: "abalone", column: "notes_sv", newValue: "Skaldjur." }], { now: NOW });
      const changed = changedLineIndexes(REAL, out);
      assertEqual(changed.length, 1, "changed lines");
      assertEqual(parseCsvLine(out.split("\n")[changed[0]])[0], "abalone", "the edited row");
      assertEqual(cellOf(out, "abalone", "notes_sv"), "Skaldjur.", "new cell");
      assertEqual(cellOf(out, "abalone", "updated_date"), "2026-11-03 00:00:00", "updated_date format");
      assertEqual(cellOf(out, "abalone", "verified_by"), VERIFIED_BY_ADMIN_VY, "verified_by");
    },
  },
  {
    name: "csvToFirestore(written row) equals the intended value for every editable column",
    fn: () => {
      const values: Record<EditableColumn, unknown> = {
        swedish: "öronsnäcka ny",
        english: "abalone new",
        group: "protein/seafood",
        properties: ["animal-product", "mollusc", "seafood"],
        aliases_sv: ["havsöra", "lättmjölk 0,5%"],
        aliases_en: ["paua", "sea ear"],
        search_terms: ["oronsnacka", "abalone"],
        notes_sv: "Säg \"hej\", tack",
        notes_en: "Shellfish, frozen.",
        season_availability: ["summer", "autumn"],
        typical_storage: "refrigerated",
        typical_unit: "kg",
        price_category: "medium",
        avg_price_sek: 12.5,
        carbon_footprint_category: "low",
        status: "verified",
      };
      for (const column of Object.keys(EDITABLE_COLUMNS) as EditableColumn[]) {
        const out = applyCellChanges(REAL, [{ id: "abalone", column, newValue: values[column] }], { now: NOW });
        const doc = docFor(out, "abalone");
        const field = EDITABLE_COLUMNS[column].field;
        assert(columnValuesEqual(column, doc[field], values[column]), `${column}: got ${JSON.stringify(doc[field])}`);
        assertEqual(changedLineIndexes(REAL, out).length, 1, `${column}: one line`);
      }
    },
  },
  {
    name: "blanked optional cells read back as absent; blank english falls back to swedish",
    fn: () => {
      const out = applyCellChanges(REAL, [
        { id: "abalone", column: "notes_en", newValue: "" },
        { id: "abalone", column: "avg_price_sek", newValue: null },
        { id: "abalone", column: "season_availability", newValue: [] },
        { id: "abalone", column: "english", newValue: "" },
      ], { now: NOW });
      const doc = docFor(out, "abalone");
      assertEqual(doc.notesEn, undefined, "notesEn");
      assertEqual(doc.avgPriceSek, undefined, "avgPriceSek");
      assertEqual(doc.seasonAvailability, undefined, "seasonAvailability");
      assertEqual(doc.english, doc.swedish, "english fallback");
    },
  },
  {
    name: "a list cell keeps its separator: ';' stays ';', ',' stays ','",
    fn: () => {
      let out = applyCellChanges(REAL, [{ id: "abalone", column: "aliases_sv", newValue: ["x", "y"] }], { now: NOW });
      assertEqual(cellOf(out, "abalone", "aliases_sv"), "x;y", "semicolon cell");
      const commaId = firstRowWhere((c) => c("aliases_sv").includes(",") && !c("aliases_sv").includes(";"));
      out = applyCellChanges(REAL, [{ id: commaId, column: "aliases_sv", newValue: ["x", "y"] }], { now: NOW });
      assertEqual(cellOf(out, commaId, "aliases_sv"), "x,y", "comma cell");
      assert(out.split("\n").some((l) => l.includes("\"x,y\"")), "comma list is quoted");
    },
  },
  {
    name: "an empty list cell gets the separator csvToFirestore expects for that column",
    fn: () => {
      const emptyAlias = firstRowWhere((c) => c("aliases_sv") === "");
      const out = applyCellChanges(REAL, [{ id: emptyAlias, column: "aliases_sv", newValue: ["a", "b"] }], { now: NOW });
      assertEqual(cellOf(out, emptyAlias, "aliases_sv"), "a;b", "aliases default ';'");
      const csv = "id,swedish,properties,updated_date,verified_by\nx,ett,,2026-01-01 00:00:00,\n";
      const written = applyCellChanges(csv, [{ id: "x", column: "properties", newValue: ["egg", "dairy"] }], { now: NOW });
      assertEqual(written, "id,swedish,properties,updated_date,verified_by\nx,ett,\"egg,dairy\",2026-11-03 00:00:00,admin-vy\n", "properties default ','");
    },
  },
  {
    name: "a digit-leading item after a ',' separator is refused (would merge into one alias)",
    fn: () => {
      const commaId = firstRowWhere((c) => c("aliases_sv").includes(",") && !c("aliases_sv").includes(";"));
      assertThrowsCode(
        () => applyCellChanges(REAL, [{ id: commaId, column: "aliases_sv", newValue: ["mörk choklad", "70% choklad"] }]),
        "list-roundtrip",
        "digit-leading alias"
      );
      const out = applyCellChanges(REAL, [{ id: "abalone", column: "aliases_sv", newValue: ["mörk choklad", "70% choklad"] }], { now: NOW });
      assertEqual(docFor(out, "abalone").aliasesSv.join("|"), "mörk choklad|70% choklad", "fine with ';'");
    },
  },
  {
    name: "quoting only when needed, quotes escaped, untouched quoted cells verbatim",
    fn: () => {
      const out = applyCellChanges(REAL, [{ id: "abalone", column: "notes_sv", newValue: "a \"b\", c" }], { now: NOW });
      const line = out.split("\n").find((l) => l.startsWith("abalone,"))!;
      assert(line.includes(",\"a \"\"b\"\", c\","), `escaped cell in ${line}`);
      assert(line.includes("\"animal-product,mollusc,needs-cooking,seafood\""), "untouched quoted cell");
      const plain = applyCellChanges(REAL, [{ id: "abalone", column: "notes_sv", newValue: "enkel" }], { now: NOW });
      assert(plain.split("\n").find((l) => l.startsWith("abalone,"))!.includes(",enkel,"), "no quotes");
    },
  },
  {
    name: "missing id, non-editable column and invalid value all throw",
    fn: () => {
      assertThrowsCode(() => applyCellChanges(REAL, [{ id: "no-such-id", column: "notes_sv", newValue: "x" }]), "missing-id", "missing id");
      for (const column of ["verified_by", "updated_date", "id", "created_by"]) {
        assertThrowsCode(() => applyCellChanges(REAL, [{ id: "abalone", column, newValue: "Malin" }]), "unknown-column", column);
      }
      assertThrowsCode(() => applyCellChanges(REAL, [{ id: "abalone", column: "notes_sv", newValue: "=1+1" }]), "formula-prefix", "formula");
      assertThrowsCode(() => applyCellChanges(REAL, [{ id: "abalone", column: "notes_sv", newValue: "a\nb" }]), "control-character", "newline");
    },
  },
  {
    name: "no identity can reach verified_by: extra fields on a change are ignored",
    fn: () => {
      const malinId = firstRowWhere((c) => c("verified_by") === "Malin");
      const change = { id: malinId, column: "notes_en", newValue: "Changed.", verified_by: "Malin", verifiedBy: "uid123" };
      const out = applyCellChanges(REAL, [change as CellChange], { now: NOW });
      assertEqual(cellOf(out, malinId, "verified_by"), VERIFIED_BY_ADMIN_VY, "constant wins");
      assert(!out.includes("uid123"), "no uid in output");
    },
  },
  {
    name: "row count and id order never change across many edits",
    fn: () => {
      const before = parseCsvFile(REAL).rows.map((r) => r.values[0]);
      const changes = before.slice(0, 40).map((id) => ({ id, column: "typical_unit", newValue: "kg" }));
      const after = parseCsvFile(applyCellChanges(REAL, changes, { now: NOW })).rows.map((r) => r.values[0]);
      assertEqual(after.join("\n"), before.join("\n"), "ids in order");
    },
  },
  {
    name: "a no-op change leaves the file byte-identical and is reported unchanged",
    fn: () => {
      const current = cellOf(REAL, "abalone", "aliases_sv").split(";").reverse();
      const result = applyCellChangesDetailed(REAL, [{ id: "abalone", column: "aliases_sv", newValue: current }], { now: NOW });
      assertEqual(result.text, REAL, "identical");
      assertEqual(result.unchanged.length, 1, "unchanged");
      assertEqual(result.applied.length, 0, "applied");
    },
  },
  {
    name: "no CRLF introduced; an existing CRLF line and the trailing-newline state are kept",
    fn: () => {
      const out = applyCellChanges(REAL, [{ id: "abalone", column: "notes_sv", newValue: "x" }], { now: NOW });
      assert(!out.includes("\r"), "no CR");
      assertEqual(out.endsWith("\n"), REAL.endsWith("\n"), "trailing newline state");
      const crlf = "id,swedish,notes_sv,updated_date,verified_by\r\na,ett,,2026-01-01,\r\nb,två,,2026-01-01,\r\n";
      const written = applyCellChanges(crlf, [{ id: "a", column: "notes_sv", newValue: "n" }], { now: NOW });
      assertEqual(written, "id,swedish,notes_sv,updated_date,verified_by\r\na,ett,n,2026-11-03,admin-vy\r\nb,två,,2026-01-01,\r\n", "CRLF + date-only format kept");
    },
  },
  {
    name: "a later change that puts a cell back leaves the row untouched and unstamped",
    fn: () => {
      const original = cellOf(REAL, "abalone", "notes_sv");
      const result = applyCellChangesDetailed(REAL, [
        { id: "abalone", column: "notes_sv", newValue: "Tillfälligt." },
        { id: "abalone", column: "notes_sv", newValue: original },
      ], { now: NOW });
      assertEqual(result.text, REAL, "byte-identical");
      assertEqual(result.applied.length, 0, "nothing applied");
      assertEqual(result.unchanged.length, 2, "both reported unchanged");
    },
  },
  {
    name: "a row that differs at the end is stamped and every change on it reported applied, in order",
    fn: () => {
      const result = applyCellChangesDetailed(REAL, [
        { id: "abalone", column: "notes_sv", newValue: "Ett." },
        { id: "abalone", column: "notes_en", newValue: "Two." },
      ], { now: NOW });
      assertEqual(result.applied.map((c) => c.newValue).join("|"), "Ett.|Two.", "applied order");
      assertEqual(cellOf(result.text, "abalone", "verified_by"), VERIFIED_BY_ADMIN_VY, "stamped");
    },
  },
];

runTests("ingredient-csv-writer (admin-vy C1)", cases);
