/**
 * Decides, for every queued admin proposal, whether it goes into the rolling
 * PR, is a conflict with the CSV, or is rejected, and produces the CSV text
 * the PR commits. Pure: no Firestore, no GitHub.
 *
 * Proposals are taken oldest first, and each one is compared with the CSV as
 * the proposals before it in the same run left it, so two proposals on one
 * cell cannot both claim the same old value.
 */

import {
  columnSpec,
  columnValuesEqual,
  docValueForColumn,
  EDITABLE_COLUMNS,
  EditableColumn,
  isEditableColumn,
} from "./ingredient-compare";
import { validateProposedChange } from "./ingredient-change-validation";
import { applyCellChangesDetailed, CellChange, csvRowToDoc, CsvWriteError, parseCsvFile } from "./ingredient-csv-writer";
import type { IngredientDoc } from "./sync-ingredients-core";

export interface QueuedProposal {
  id: string;
  ingredientId: string;
  changes: unknown;
  status: "pending" | "inReview";
  createdAtMs: number;
}

export interface ProposedColumnChange {
  column: EditableColumn;
  old: unknown;
  new: unknown;
}

export type ProposalOutcome =
  | { kind: "apply"; changes: ProposedColumnChange[]; swedishName: string }
  | {
      kind: "conflict";
      reason: "csv-mismatch" | "missing-row";
      changes: ProposedColumnChange[];
      // Per mismatching column, the value the CSV holds, in the proposal's shape.
      csvValue: Record<string, unknown> | null;
      swedishName: string | null;
    }
  | { kind: "rejected"; reason: string };

export interface ChangePlan {
  outcomes: Map<string, ProposalOutcome>;
  // Ids in the order they were decided.
  order: string[];
  text: string;
  appliedIds: string[];
}

export class SelfCheckError extends Error {
  constructor(readonly code: string, message: string) {
    super(message);
    this.name = "SelfCheckError";
  }
}

/** A stored value in the shape a proposal's `old`/`new` holds for [column]. */
export function proposalShape(column: EditableColumn, value: unknown): unknown {
  const kind = columnSpec(column).kind;
  if (kind === "list") return Array.isArray(value) ? [...value] : [];
  if (kind === "number") return typeof value === "number" ? value : null;
  return typeof value === "string" ? value : "";
}

function readChanges(raw: unknown): ProposedColumnChange[] | string {
  if (raw === null || typeof raw !== "object" || Array.isArray(raw)) return "wrong-type";
  const entries = Object.entries(raw as Record<string, unknown>);
  if (entries.length === 0) return "wrong-type";
  const out: ProposedColumnChange[] = [];
  for (const [column, change] of entries) {
    if (!isEditableColumn(column)) return "unknown-column";
    if (change === null || typeof change !== "object" || Array.isArray(change)) return "wrong-type";
    const c = change as Record<string, unknown>;
    if (!("old" in c) || !("new" in c)) return "wrong-type";
    out.push({ column, old: c.old, new: c.new });
  }
  // Column order is the CSV's, not the map's, so the PR text is stable.
  const columns = Object.keys(EDITABLE_COLUMNS);
  return out.sort((a, b) => columns.indexOf(a.column) - columns.indexOf(b.column));
}

interface RunningRow {
  line: string;
  doc: IngredientDoc;
}

function headerLine(lines: string[]): string {
  const line = lines.find((l) => l.replace(/\r$/, "").trim() !== "");
  if (line === undefined) throw new CsvWriteError("no-header", "CSV has no header line");
  return line;
}

export function planIngredientChanges(
  csvText: string,
  proposals: readonly QueuedProposal[],
  now: Date,
): ChangePlan {
  const file = parseCsvFile(csvText);
  const head = headerLine(file.lines);
  const idCol = file.header.indexOf("id");
  const running = new Map<string, RunningRow>();
  for (const row of file.rows) {
    running.set(row.values[idCol], { line: file.lines[row.lineIndex], doc: csvRowToDoc(file.header, row.values) });
  }

  const sorted = [...proposals].sort((a, b) => a.createdAtMs - b.createdAtMs || (a.id < b.id ? -1 : a.id > b.id ? 1 : 0));
  const outcomes = new Map<string, ProposalOutcome>();
  const order: string[] = [];
  const accepted: CellChange[] = [];
  const appliedIds: string[] = [];

  for (const p of sorted) {
    order.push(p.id);
    const changes = readChanges(p.changes);
    if (typeof changes === "string") {
      outcomes.set(p.id, { kind: "rejected", reason: changes });
      continue;
    }
    const invalid = changes.map((c) => validateProposedChange(c.column, c.new)).find((v) => !v.ok);
    if (invalid && !invalid.ok) {
      outcomes.set(p.id, { kind: "rejected", reason: invalid.reason });
      continue;
    }
    const row = running.get(p.ingredientId);
    if (!row) {
      outcomes.set(p.id, { kind: "conflict", reason: "missing-row", changes, csvValue: null, swedishName: null });
      continue;
    }
    const csvValue: Record<string, unknown> = {};
    for (const c of changes) {
      const current = docValueForColumn(row.doc, c.column);
      if (!columnValuesEqual(c.column, c.old, current)) csvValue[c.column] = proposalShape(c.column, current);
    }
    if (Object.keys(csvValue).length > 0) {
      outcomes.set(p.id, {
        kind: "conflict", reason: "csv-mismatch", changes, csvValue, swedishName: row.doc.swedish,
      });
      continue;
    }

    const cellChanges: CellChange[] = changes.map((c) => ({ id: p.ingredientId, column: c.column, newValue: c.new }));
    let trial;
    try {
      trial = applyCellChangesDetailed(`${head}\n${row.line}\n`, cellChanges, { now });
    } catch (err) {
      outcomes.set(p.id, { kind: "rejected", reason: err instanceof CsvWriteError ? err.code : "write-failed" });
      continue;
    }
    if (trial.applied.length === 0) {
      outcomes.set(p.id, { kind: "rejected", reason: "no-change" });
      continue;
    }
    const mini = parseCsvFile(trial.text);
    running.set(p.ingredientId, {
      line: mini.lines[mini.rows[0].lineIndex],
      doc: csvRowToDoc(mini.header, mini.rows[0].values),
    });
    accepted.push(...cellChanges);
    appliedIds.push(p.id);
    outcomes.set(p.id, { kind: "apply", changes, swedishName: row.doc.swedish });
  }

  const text = accepted.length ? applyCellChangesDetailed(csvText, accepted, { now }).text : csvText;
  selfCheck(csvText, text, accepted);
  return { outcomes, order, text, appliedIds };
}

// Text is checked on the cell itself: csvToFirestore fills a blank `english`
// from `swedish`, which is the sync's reading, not the value written.
function readsBackAs(header: string[], values: string[], column: EditableColumn, intended: unknown): boolean {
  const kind = columnSpec(column).kind;
  if (kind === "text") return values[header.indexOf(column)].trim() === String(intended).trim();
  const doc = csvRowToDoc(header, values);
  if (kind === "list") {
    const items = Array.isArray(intended) ? intended.map((s) => String(s).trim()) : [];
    return columnValuesEqual(column, items, docValueForColumn(doc, column));
  }
  return columnValuesEqual(column, intended, docValueForColumn(doc, column));
}

/**
 * The output must parse like the input, keep every row in place, differ only
 * on rows a change named, and read back every change as intended. Stands in
 * for a CI round trip, which a CSV-only PR does not run.
 */
export function selfCheck(before: string, after: string, changes: readonly CellChange[]): void {
  const a = parseCsvFile(before);
  let b;
  try {
    b = parseCsvFile(after);
  } catch (err) {
    throw new SelfCheckError("reparse", `Output does not parse: ${err instanceof Error ? err.message : err}`);
  }
  if (a.header.join(",") !== b.header.join(",")) throw new SelfCheckError("header", "Header changed");
  if (a.lines.length !== b.lines.length || a.rows.length !== b.rows.length) {
    throw new SelfCheckError("row-count", "Line or row count changed");
  }
  const idCol = a.header.indexOf("id");
  const touched = new Set(changes.map((c) => c.id));
  const rowAt = new Map(a.rows.map((r) => [r.lineIndex, r]));
  for (let i = 0; i < a.rows.length; i++) {
    if (a.rows[i].values[idCol] !== b.rows[i].values[idCol] || a.rows[i].lineIndex !== b.rows[i].lineIndex) {
      throw new SelfCheckError("id-order", `Row ${i + 1} moved`);
    }
  }
  for (let i = 0; i < a.lines.length; i++) {
    if (a.lines[i] === b.lines[i]) continue;
    const row = rowAt.get(i);
    if (!row || !touched.has(row.values[idCol])) throw new SelfCheckError("untouched-line", `Line ${i + 1} changed`);
  }
  const byId = new Map(b.rows.map((r) => [r.values[idCol], r]));
  const finalValue = new Map<string, unknown>();
  for (const c of changes) finalValue.set(`${c.id}\u0000${c.column}`, c.newValue);
  for (const [key, intended] of finalValue) {
    const [id, column] = key.split("\u0000") as [string, EditableColumn];
    const row = byId.get(id);
    if (!row) throw new SelfCheckError("missing-row", `Row ${id} vanished`);
    if (!readsBackAs(b.header, row.values, column, intended)) {
      throw new SelfCheckError("value", `${column} on ${id} does not read back as intended`);
    }
  }
}
