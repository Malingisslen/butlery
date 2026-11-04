/**
 * The one comparison between an ingredient as the CSV produces it
 * (`csvToFirestore`) and as Firestore or an admin proposal holds it.
 *
 * The sync's change detection (`hasChanges`) and the admin-vy CSV writer both
 * go through here, so "this row changed" and "this proposal's old value still
 * matches the CSV" are decided by the same normalisation.
 */

import type * as admin from "firebase-admin";
import type { IngredientDoc } from "./sync-ingredients-core";

export type ColumnKind = "text" | "list" | "number";

export interface EditableColumnSpec {
  field: keyof IngredientDoc;
  kind: ColumnKind;
  // Separators csvToFirestore splits this column on, the one to use for an
  // empty cell first. A list written with any other character re-parses as
  // one blob item.
  separators?: readonly string[];
}

// The columns an admin may propose changes to. Mirrors IngredientColumn in
// lib/models/tagging/ingredient_column.dart and `changesOk` in firestore.rules.
export const EDITABLE_COLUMNS = {
  swedish: { field: "swedish", kind: "text" },
  english: { field: "english", kind: "text" },
  group: { field: "group", kind: "text" },
  properties: { field: "properties", kind: "list", separators: [","] },
  aliases_sv: { field: "aliasesSv", kind: "list", separators: [";", ","] },
  aliases_en: { field: "aliasesEn", kind: "list", separators: [";", ","] },
  search_terms: { field: "searchTerms", kind: "list", separators: [";", ","] },
  notes_sv: { field: "notesSv", kind: "text" },
  notes_en: { field: "notesEn", kind: "text" },
  season_availability: { field: "seasonAvailability", kind: "list", separators: [";"] },
  typical_storage: { field: "typicalStorage", kind: "text" },
  typical_unit: { field: "typicalUnit", kind: "text" },
  price_category: { field: "priceCategory", kind: "text" },
  avg_price_sek: { field: "avgPriceSek", kind: "number" },
  carbon_footprint_category: { field: "carbonFootprintCategory", kind: "text" },
  status: { field: "status", kind: "text" },
} as const satisfies Record<string, EditableColumnSpec>;

export type EditableColumn = keyof typeof EDITABLE_COLUMNS;

export function isEditableColumn(column: string): column is EditableColumn {
  return Object.prototype.hasOwnProperty.call(EDITABLE_COLUMNS, column);
}

export function columnSpec(column: EditableColumn): EditableColumnSpec {
  return EDITABLE_COLUMNS[column];
}

const TEXT_FIELDS = [
  "swedish", "english", "group", "status",
  "priceCategory", "carbonFootprintCategory", "notesSv", "notesEn",
  "typicalStorage", "typicalUnit",
] as const;

// normalizedNames is not editable, but the sync must still see it change.
const LIST_FIELDS = [
  "properties", "aliasesSv", "aliasesEn", "searchTerms",
  "normalizedNames", "seasonAvailability",
] as const;

type TextField = (typeof TEXT_FIELDS)[number];
type ListField = (typeof LIST_FIELDS)[number];
export type ComparedField = TextField | ListField | "avgPriceSek";

export type ComparableIngredient =
  { [K in TextField]: string | undefined } &
  { [K in ListField]: string[] } &
  { avgPriceSek: unknown };

export const COMPARED_FIELDS: readonly ComparedField[] = [
  ...TEXT_FIELDS, ...LIST_FIELDS, "avgPriceSek",
];

export function listEquals(a: string[], b: string[]): boolean {
  if (a.length !== b.length) return false;
  const setA = new Set(a);
  const setB = new Set(b);
  return [...setA].every((x) => setB.has(x)) && [...setB].every((x) => setA.has(x));
}

// A blank cell and an absent field are the same value: csvToFirestore omits
// a blanked optional, while a hand-edited doc may hold "".
function comparableText(value: unknown): string | undefined {
  const s = String(value || "");
  return s === "" ? undefined : s;
}

// A non-array stored value is passed through rather than coerced to [], so a
// corrupt doc keeps comparing as it did before this module existed.
function comparableList(value: unknown): string[] {
  const v = (value as string[]) || [];
  return Array.isArray(v) ? [...v].sort() : v;
}

/**
 * Normalises a csvToFirestore doc, or a stored Firestore doc, into the form
 * both sides compare in. The price is kept exactly as stored: the sync treats
 * a stored `null` as a change to repair, and only `columnValuesEqual` folds
 * null into blank for the proposal check.
 */
export function comparableIngredient(
  doc: IngredientDoc | admin.firestore.DocumentData
): ComparableIngredient {
  const source = doc as Record<string, unknown>;
  const out: Record<string, unknown> = {};
  for (const f of TEXT_FIELDS) out[f] = comparableText(source[f]);
  for (const f of LIST_FIELDS) out[f] = comparableList(source[f]);
  out.avgPriceSek = source.avgPriceSek;
  return out as ComparableIngredient;
}

export function comparedFieldEquals(
  field: ComparedField,
  a: ComparableIngredient,
  b: ComparableIngredient
): boolean {
  if ((LIST_FIELDS as readonly string[]).includes(field)) {
    return listEquals(a[field as ListField], b[field as ListField]);
  }
  return a[field] === b[field];
}

// Same parse as csvToFirestore's avg_price_sek, so a value given as "12,50"
// compares equal to the 12.5 the sync stores. `null` = not a price at all.
function comparablePrice(value: unknown): number | undefined | null {
  if (value === null || value === undefined) return undefined;
  if (typeof value === "number") return Number.isFinite(value) ? value : null;
  if (typeof value === "string") {
    const s = value.trim().replace(",", ".");
    if (s === "") return undefined;
    const n = parseFloat(s);
    return isNaN(n) ? null : n;
  }
  return null;
}

/**
 * Compares two values of one editable CSV column for the proposal-vs-CSV
 * check: lists order-independent, the price numerically with blank and null
 * alike, text with blank and absent alike.
 */
export function columnValuesEqual(column: string, a: unknown, b: unknown): boolean {
  if (!isEditableColumn(column)) {
    throw new Error(`Not an editable ingredient column: ${column}`);
  }
  const spec = columnSpec(column);
  if (spec.kind === "number") {
    const x = comparablePrice(a);
    const y = comparablePrice(b);
    return x !== null && y !== null && x === y;
  }
  if (spec.kind === "list") {
    const isList = (v: unknown): boolean => v == null || Array.isArray(v);
    if (!isList(a) || !isList(b)) return false;
    return listEquals(comparableList(a), comparableList(b));
  }
  return comparableText(a) === comparableText(b);
}

/** The value csvToFirestore produced for one editable column. */
export function docValueForColumn(doc: IngredientDoc, column: EditableColumn): unknown {
  return doc[columnSpec(column).field];
}
