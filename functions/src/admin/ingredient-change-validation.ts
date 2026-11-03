/**
 * Server-side check of one proposed ingredient cell value, run on freshly
 * read proposals before the CSV writer sees them. Independent of
 * firestore.rules: the rules bound sizes and types, this also owns the
 * vocabularies and the CSV-injection surface, because the value lands in a
 * file that people open in a spreadsheet.
 */

import { EDITABLE_COLUMNS, EditableColumnSpec, isEditableColumn } from "./ingredient-compare";
import { VALID_GROUP_PREFIXES, VALID_PROPERTIES } from "./sync-ingredients-core";

// No TypeScript list existed for these; they mirror kProposableStatuses,
// kProposablePriceCategories and kProposableCarbonCategories in
// lib/services/tagging/ingredient_change_validator.dart (pinned by
// ingredient-change-validation.test.ts).
export const PROPOSABLE_STATUSES: readonly string[] = ["draft", "validated", "verified", "needs-review"];
export const PRICE_CATEGORIES: readonly string[] = ["budget", "standard", "medium", "premium"];
export const CARBON_CATEGORIES: readonly string[] = ["low", "medium", "high"];

export const MAX_TEXT_LENGTH = 300;
export const MAX_LIST_ITEMS = 30;

export type ChangeRejectReason =
  | "unknown-column"
  | "wrong-type"
  | "too-long"
  | "too-many-items"
  | "empty-item"
  | "empty-required"
  | "control-character"
  | "format-character"
  | "formula-prefix"
  | "separator-in-item"
  | "unknown-property"
  | "invalid-group"
  | "invalid-status"
  | "invalid-price-category"
  | "invalid-carbon-category"
  | "invalid-price";

export type ChangeValidation =
  | { ok: true }
  | { ok: false; reason: ChangeRejectReason };

// C0, DEL, C1, plus the Unicode line and paragraph separators: any of them
// can break a CSV line or hide content from the reviewer.
const CONTROL_CHARACTERS = new RegExp("[\\u0000-\\u001F\\u007F-\\u009F\\u2028\\u2029]");
// Bidi overrides and other invisible format characters (U+202E et al.).
const FORMAT_CHARACTERS = new RegExp("\\p{Cf}", "u");
// Spreadsheets also evaluate a formula behind leading blanks or quotes.
const LEADING_BLANKS_AND_QUOTES = new RegExp("^[\\s\"']+");
const FORMULA_PREFIX = new RegExp("^[=+\\-@]");
// Same as the Dart validator: a comma before a digit is a Swedish decimal
// comma ("0,5%") that the sync's alias split leaves alone.
const LIST_SEPARATORS = new RegExp("[;|]|,(?!\\d)");
// What the sync's avg_price_sek check accepts, in the form the writer emits.
const PRICE_TEXT = new RegExp("^\\d+(\\.\\d+)?$");

const fail = (reason: ChangeRejectReason): ChangeValidation => ({ ok: false, reason });
const OK: ChangeValidation = { ok: true };

function checkString(value: string): ChangeRejectReason | null {
  if (value.length > MAX_TEXT_LENGTH) return "too-long";
  if (CONTROL_CHARACTERS.test(value)) return "control-character";
  if (FORMAT_CHARACTERS.test(value)) return "format-character";
  if (FORMULA_PREFIX.test(value.replace(LEADING_BLANKS_AND_QUOTES, ""))) return "formula-prefix";
  return null;
}

function validateText(column: string, value: unknown): ChangeValidation {
  if (typeof value !== "string") return fail("wrong-type");
  const problem = checkString(value);
  if (problem) return fail(problem);
  const trimmed = value.trim();
  switch (column) {
    case "swedish":
      return trimmed ? OK : fail("empty-required");
    case "group":
      return VALID_GROUP_PREFIXES.some((p) => trimmed === p || trimmed.startsWith(p + "/"))
        ? OK
        : fail("invalid-group");
    case "status":
      return PROPOSABLE_STATUSES.includes(trimmed) ? OK : fail("invalid-status");
    case "price_category":
      return !trimmed || PRICE_CATEGORIES.includes(trimmed) ? OK : fail("invalid-price-category");
    case "carbon_footprint_category":
      return !trimmed || CARBON_CATEGORIES.includes(trimmed) ? OK : fail("invalid-carbon-category");
    default:
      return OK;
  }
}

function validateList(column: string, value: unknown): ChangeValidation {
  if (!Array.isArray(value)) return fail("wrong-type");
  if (value.length > MAX_LIST_ITEMS) return fail("too-many-items");
  for (const item of value) {
    if (typeof item !== "string") return fail("wrong-type");
    if (!item.trim()) return fail("empty-item");
    const problem = checkString(item);
    if (problem) return fail(problem);
    if (LIST_SEPARATORS.test(item)) return fail("separator-in-item");
    if (column === "properties" && !VALID_PROPERTIES.has(item.trim())) {
      return fail("unknown-property");
    }
  }
  return OK;
}

function validatePrice(value: unknown): ChangeValidation {
  if (value === null) return OK;
  if (typeof value !== "number") return fail("wrong-type");
  if (!Number.isFinite(value) || value < 0 || !PRICE_TEXT.test(String(value))) {
    return fail("invalid-price");
  }
  return OK;
}

/**
 * `newValue` is in the shape the proposal stores: a string for text columns
 * ("" = blank), a string[] for list columns, a number or null for the price.
 */
export function validateProposedChange(column: string, newValue: unknown): ChangeValidation {
  if (!isEditableColumn(column)) return fail("unknown-column");
  const spec: EditableColumnSpec = EDITABLE_COLUMNS[column];
  if (spec.kind === "list") return validateList(column, newValue);
  if (spec.kind === "number") return validatePrice(newValue);
  return validateText(column, newValue);
}
