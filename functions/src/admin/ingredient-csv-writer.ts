/**
 * Applies admin-vy cell changes to the ingredient CSV
 * (docs/tagging/data/Butlery_Ingredients_INGREDIENTS.csv) without disturbing
 * anything else in it: the file is the source of truth and every change
 * reaches production through a reviewed diff, so the diff must show exactly
 * the edited cells and nothing else.
 *
 * Values are read with the sync's own tokenizer (`parseCsvLine`) and
 * interpreted with `csvToFirestore`; this module only tracks the raw bytes of
 * each cell so untouched cells are written back verbatim.
 */

import {
  EDITABLE_COLUMNS,
  EditableColumn,
  columnSpec,
  columnValuesEqual,
  docValueForColumn,
  isEditableColumn,
} from "./ingredient-compare";
import { validateProposedChange } from "./ingredient-change-validation";
import { csvToFirestore, IngredientDoc, IngredientRow, parseCsvLine } from "./sync-ingredients-core";

// A constant, never a parameter: the CSV sits in a public repo, so no admin
// name or uid may ever reach it through this writer.
export const VERIFIED_BY_ADMIN_VY = "admin-vy";

export interface CellChange {
  id: string;
  column: string;
  newValue: unknown;
}

export interface CsvRow {
  lineIndex: number;
  rawCells: string[];
  values: string[];
  // "\r" when this line ended CRLF, kept so a rewritten line keeps its ending.
  lineEndCr: string;
}

export interface ParsedCsvFile {
  lines: string[];
  header: string[];
  rows: CsvRow[];
}

export class CsvWriteError extends Error {
  constructor(readonly code: string, message: string) {
    super(message);
    this.name = "CsvWriteError";
  }
}

const NEEDS_QUOTES = new RegExp("[\",\\r\\n]");
const LINE_BREAK = new RegExp("[\\r\\n]");
const DATE_ONLY = new RegExp("^\\d{4}-\\d{2}-\\d{2}$");
const DECIMAL_COMMA_FREE_COMMA = new RegExp(",(?!\\d)");

// Cuts a line at the same commas parseCsvLine cuts at, keeping each cell's
// raw text (quotes, escapes and surrounding blanks) intact.
function splitRawCells(line: string): string[] {
  const cells: string[] = [];
  let start = 0;
  let inQuotes = false;
  for (let i = 0; i < line.length; i++) {
    const char = line[i];
    if (char === '"') {
      if (inQuotes && i + 1 < line.length && line[i + 1] === '"') {
        i++;
      } else {
        inQuotes = !inQuotes;
      }
    } else if (char === "," && !inQuotes) {
      cells.push(line.slice(start, i));
      start = i + 1;
    }
  }
  cells.push(line.slice(start));
  return cells;
}

/** Splits like the sync's loadCsv: on "\n", blank lines skipped, first line = header. */
export function parseCsvFile(text: string): ParsedCsvFile {
  const lines = text.split("\n");
  let header: string[] | null = null;
  const rows: CsvRow[] = [];
  const seen = new Set<string>();
  lines.forEach((line, lineIndex) => {
    const lineEndCr = line.endsWith("\r") ? "\r" : "";
    const body = lineEndCr ? line.slice(0, -1) : line;
    if (!body.trim()) return;
    if (!header) {
      header = parseCsvLine(body);
      return;
    }
    const values = parseCsvLine(body);
    const rawCells = splitRawCells(body);
    if (values.length !== header.length || rawCells.length !== values.length) {
      throw new CsvWriteError(
        "malformed-row",
        `Line ${lineIndex + 1}: ${values.length} cells, header has ${header.length}`
      );
    }
    const id = values[header.indexOf("id")];
    if (seen.has(id)) {
      throw new CsvWriteError("duplicate-id", `Duplicate id ${id} on line ${lineIndex + 1}`);
    }
    seen.add(id);
    rows.push({ lineIndex, rawCells, values, lineEndCr });
  });
  if (!header) throw new CsvWriteError("no-header", "CSV has no header line");
  return { lines, header, rows };
}

export function serializeCsvFile(file: ParsedCsvFile): string {
  const lines = [...file.lines];
  for (const row of file.rows) {
    lines[row.lineIndex] = row.rawCells.join(",") + row.lineEndCr;
  }
  return lines.join("\n");
}

function encodeCell(plain: string): string {
  if (LINE_BREAK.test(plain)) {
    throw new CsvWriteError("line-break", "A cell value may not contain a line break");
  }
  return NEEDS_QUOTES.test(plain) ? `"${plain.split('"').join('""')}"` : plain;
}

function separatorFor(column: EditableColumn, currentPlain: string): string {
  const separators = columnSpec(column).separators ?? [";"];
  for (const s of separators) {
    if (s === ";" && currentPlain.includes(";")) return ";";
    if (s === "," && DECIMAL_COMMA_FREE_COMMA.test(currentPlain)) return ",";
  }
  return separators[0];
}

function plainValue(column: EditableColumn, newValue: unknown, currentPlain: string): string {
  const kind = columnSpec(column).kind;
  if (kind === "number") return newValue === null ? "" : String(newValue);
  if (kind === "list") {
    const items = (newValue as string[]).map((s) => s.trim());
    return items.join(separatorFor(column, currentPlain));
  }
  return (newValue as string).trim();
}

function rowObject(header: string[], values: string[]): IngredientRow {
  const row: Record<string, string> = {};
  header.forEach((h, j) => {
    row[h] = values[j];
  });
  return row as IngredientRow;
}

/** One parsed row as the sync would store it. */
export function csvRowToDoc(header: string[], values: string[]): IngredientDoc {
  return csvToFirestore(rowObject(header, values));
}

function sameOrderedList(a: unknown, b: string[]): boolean {
  const list = (a as string[] | undefined) ?? [];
  return list.length === b.length && list.every((x, i) => x === b[i]);
}

// The written cell must read back, through the sync's tokenizer and
// csvToFirestore, as exactly the intended value. A digit-leading alias after a
// "," separator is the known case that does not: ",70% choklad" is a decimal
// comma to the sync's split, so the two items would merge into one.
function assertRoundTrip(
  column: EditableColumn,
  newValue: unknown,
  plain: string,
  header: string[],
  row: CsvRow,
  col: number,
  after: IngredientDoc
): void {
  const reread = parseCsvLine(row.rawCells.join(","));
  if (reread.length !== header.length || reread[col] !== plain) {
    throw new CsvWriteError("cell-roundtrip", `Cell ${column} does not re-read as written`);
  }
  const kind = columnSpec(column).kind;
  if (kind === "list") {
    const intended = (newValue as string[]).map((s) => s.trim());
    if (!sameOrderedList(docValueForColumn(after, column), intended)) {
      throw new CsvWriteError("list-roundtrip", `List ${column} re-parses to different items`);
    }
  }
  if (kind === "number" && after.avgPriceSek !== (newValue === null ? undefined : newValue)) {
    throw new CsvWriteError("price-roundtrip", "Price re-parses to a different number");
  }
}

function stockholmDate(now: Date): string {
  return now.toLocaleDateString("sv-SE", { timeZone: "Europe/Stockholm" });
}

export interface ApplyResult {
  text: string;
  applied: CellChange[];
  unchanged: CellChange[];
}

/**
 * Applies the changes in order (a later change to the same cell wins). A
 * change whose value already equals the cell is reported as unchanged and
 * leaves the line untouched, and so is every change on a row that ends with
 * the values it started with. Throws on an unknown id or column, an invalid
 * value, or a value that would not read back as written.
 */
export function applyCellChangesDetailed(
  text: string,
  changes: readonly CellChange[],
  options: { now?: Date } = {}
): ApplyResult {
  const file = parseCsvFile(text);
  const { header } = file;
  const idCol = header.indexOf("id");
  const updatedCol = header.indexOf("updated_date");
  const verifiedCol = header.indexOf("verified_by");
  if (updatedCol < 0 || verifiedCol < 0) {
    throw new CsvWriteError("missing-column", "CSV lacks updated_date or verified_by");
  }
  const byId = new Map(file.rows.map((r) => [r.values[idCol], r]));
  // Each touched row as it was before the loop, so a later change that puts
  // a cell back is not mistaken for an edit.
  const initial = new Map<CsvRow, { rawCells: string[]; values: string[] }>();
  const changesOf = new Map<CsvRow, CellChange[]>();
  const unchanged: CellChange[] = [];

  for (const change of changes) {
    const { id, column, newValue } = change;
    if (!isEditableColumn(column)) {
      throw new CsvWriteError("unknown-column", `Not an editable column: ${column}`);
    }
    const row = byId.get(id);
    if (!row) throw new CsvWriteError("missing-id", `No CSV row with id ${id}`);
    const validation = validateProposedChange(column, newValue);
    if (!validation.ok) {
      throw new CsvWriteError(validation.reason, `Invalid value for ${column} on ${id}`);
    }
    const col = header.indexOf(column);
    if (col < 0) throw new CsvWriteError("missing-column", `CSV lacks column ${column}`);

    const before = csvToFirestore(rowObject(header, row.values));
    const plain = plainValue(column, newValue, row.values[col]);
    const oldRaw = row.rawCells[col];
    const oldPlain = row.values[col];
    row.rawCells[col] = encodeCell(plain);
    row.values[col] = plain;
    const after = csvToFirestore(rowObject(header, row.values));
    assertRoundTrip(column, newValue, plain, header, row, col, after);

    if (columnValuesEqual(column, docValueForColumn(before, column), docValueForColumn(after, column))) {
      row.rawCells[col] = oldRaw;
      row.values[col] = oldPlain;
      unchanged.push(change);
    } else {
      if (!initial.has(row)) {
        const rawCells = [...row.rawCells];
        rawCells[col] = oldRaw;
        const values = [...row.values];
        values[col] = oldPlain;
        initial.set(row, { rawCells, values });
      }
      changesOf.set(row, [...(changesOf.get(row) ?? []), change]);
    }
  }

  const applied: CellChange[] = [];
  const touched: CsvRow[] = [];
  for (const [row, start] of initial) {
    const before = csvRowToDoc(header, start.values);
    const after = csvRowToDoc(header, row.values);
    const differs = Object.keys(EDITABLE_COLUMNS).some((column) => {
      const c = column as EditableColumn;
      return header.includes(c) && !columnValuesEqual(c, docValueForColumn(before, c), docValueForColumn(after, c));
    });
    if (differs) {
      touched.push(row);
      applied.push(...(changesOf.get(row) ?? []));
    } else {
      row.rawCells = start.rawCells;
      row.values = start.values;
      unchanged.push(...(changesOf.get(row) ?? []));
    }
  }
  // Keep the caller's order in both lists.
  const order = new Map(changes.map((c, i) => [c, i]));
  applied.sort((a, b) => (order.get(a) ?? 0) - (order.get(b) ?? 0));
  unchanged.sort((a, b) => (order.get(a) ?? 0) - (order.get(b) ?? 0));

  const now = options.now ?? new Date();
  for (const row of touched) {
    const date = stockholmDate(now);
    const stamp = DATE_ONLY.test(row.values[updatedCol]) ? date : `${date} 00:00:00`;
    row.rawCells[updatedCol] = encodeCell(stamp);
    row.values[updatedCol] = stamp;
    row.rawCells[verifiedCol] = encodeCell(VERIFIED_BY_ADMIN_VY);
    row.values[verifiedCol] = VERIFIED_BY_ADMIN_VY;
  }

  return { text: serializeCsvFile(file), applied, unchanged };
}

export function applyCellChanges(
  text: string,
  changes: readonly CellChange[],
  options: { now?: Date } = {}
): string {
  return applyCellChangesDetailed(text, changes, options).text;
}
