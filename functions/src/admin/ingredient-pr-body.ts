/**
 * The text of the admin-vy's rolling ingredient PR. The repository is public,
 * so the body carries ingredient ids, names, columns and values only: never a
 * uid, an admin's name or a proposal's `note`. Every value is rendered as
 * inline code after `neutralize`, so a value can form no mention, link, image,
 * HTML tag or table cell break.
 */

import { ALLERGEN_RELEVANT_PROPERTIES } from "../shared/allergen-properties";

export const PR_TITLE = "Ingrediensändringar från admin-vyn";

// A GitHub PR body is capped at 65536 characters; the rest is in the diff.
export const MAX_BODY_CHARS = 60000;

// Columns whose change can move an allergen or diet verdict, listed first.
export const ALLERGEN_COLUMNS: readonly string[] = ["properties", "group", "aliases_sv", "aliases_en", "status"];

// Mirrors _veganClaims and _animalProperties in
// lib/models/tagging/ingredient_allergen_impact.dart (pinned by
// ingredient-pr-body.test.ts).
export const VEGAN_CLAIMS: readonly string[] = ["vegan-friendly", "plant-based"];
export const ANIMAL_PROPERTIES: readonly string[] = ["animal-product", "meat", "dairy", "egg", "seafood"];

export interface BodyChange {
  column: string;
  old: unknown;
  new: unknown;
}

export interface BodyProposal {
  ingredientId: string;
  swedishName: string;
  changes: BodyChange[];
}

export interface BodyConflict {
  ingredientId: string;
  swedishName: string | null;
  column: string | null;
  csvValue: unknown;
  old: unknown;
  new: unknown;
}

export interface BodyRejection {
  ingredientId: string;
  reason: string;
}

export interface PrBodyInput {
  applied: BodyProposal[];
  conflicts: BodyConflict[];
  rejected: BodyRejection[];
}

/** Same decision as `propertyChangeAffectsAllergens` in the Dart model. */
export function propertyChangeAffectsAllergens(oldProps: readonly string[], newProps: readonly string[]): boolean {
  const before = new Set(oldProps);
  const after = new Set(newProps);
  if ([...before].some((p) => !after.has(p) && ALLERGEN_RELEVANT_PROPERTIES.has(p))) return true;
  const addedClaim = [...after].some((p) => !before.has(p) && VEGAN_CLAIMS.includes(p));
  return addedClaim && [...after].some((p) => ANIMAL_PROPERTIES.includes(p) || ALLERGEN_RELEVANT_PROPERTIES.has(p));
}

const asStrings = (v: unknown): string[] => (Array.isArray(v) ? v.map((x) => String(x)) : []);

export function proposalTouchesAllergenColumns(p: BodyProposal): boolean {
  return p.changes.some((c) => ALLERGEN_COLUMNS.includes(c.column));
}

export function proposalAffectsAllergens(p: BodyProposal): boolean {
  const props = p.changes.find((c) => c.column === "properties");
  return props !== undefined && propertyChangeAffectsAllergens(asStrings(props.old), asStrings(props.new));
}

const REPLACEMENTS: ReadonlyArray<[RegExp, string]> = [
  [new RegExp("`", "g"), "ˋ"],
  [new RegExp("@", "g"), "＠"],
  [new RegExp("\\[", "g"), "［"],
  [new RegExp("\\]", "g"), "］"],
  [new RegExp("!", "g"), "ǃ"],
  [new RegExp("<", "g"), "‹"],
  [new RegExp(">", "g"), "›"],
  [new RegExp("\\|", "g"), "¦"],
  [new RegExp("[\\u0000-\\u001F\\u007F-\\u009F\\u2028\\u2029]", "g"), " "],
];

export function neutralize(text: string): string {
  let out = text;
  for (const [pattern, replacement] of REPLACEMENTS) out = out.replace(pattern, replacement);
  return out;
}

function code(text: string): string {
  return "`" + neutralize(text) + "`";
}

export function renderValue(value: unknown): string {
  if (value === null || value === undefined || value === "") return "*(tomt)*";
  if (Array.isArray(value)) {
    return value.length === 0 ? "*(tomt)*" : code(value.map((v) => String(v)).join(", "));
  }
  return code(String(value));
}

function ingredientLabel(id: string, name: string | null): string {
  return name ? `${code(name)} (${code(id)})` : code(id);
}

function proposalLines(p: BodyProposal): string[] {
  const warn = proposalAffectsAllergens(p) ? " **Varning: kan ändra allergen- eller kostbedömning.**" : "";
  const lines = [`- ${ingredientLabel(p.ingredientId, p.swedishName)}${warn}`];
  for (const c of p.changes) {
    lines.push(`  - ${code(c.column)}: ${renderValue(c.old)} → ${renderValue(c.new)}`);
  }
  return lines;
}

function conflictRow(c: BodyConflict): string {
  const column = c.column ? code(c.column) : "*(hela raden)*";
  const csv = c.column ? renderValue(c.csvValue) : "*saknas i CSV:n*";
  return `| ${ingredientLabel(c.ingredientId, c.swedishName)} | ${column} | ${csv} | ${renderValue(c.old)} | ${renderValue(c.new)} |`;
}

/** Adds lines until the cap, then says how many were left out. */
function appendCapped(out: string[], items: string[][], budget: { left: number }, noun: string): void {
  let shown = 0;
  for (const lines of items) {
    const size = lines.reduce((n, l) => n + l.length + 1, 0);
    if (size > budget.left) break;
    out.push(...lines);
    budget.left -= size;
    shown++;
  }
  if (shown < items.length) out.push(`- … och ${items.length - shown} ${noun} till, se diffen.`);
}

export function buildPrBody(input: PrBodyInput): string {
  const first = input.applied.filter(proposalTouchesAllergenColumns);
  const rest = input.applied.filter((p) => !proposalTouchesAllergenColumns(p));
  const out: string[] = [
    `Förslag från admin-vyn som ändrar \`docs/tagging/data/Butlery_Ingredients_INGREDIENTS.csv\`: ` +
      `${input.applied.length} förslag med, ${input.conflicts.length} konflikter, ${input.rejected.length} nekade.`,
    "",
    "Ändrade egenskaper (`properties`) taggar om de recept som använder ingrediensen efter synken " +
      "(`on-ingredient-properties-changed` markerar dem). Ändringar av grupp, alias och övriga fält " +
      "taggar inte om befintliga recept.",
    "",
  ];
  const budget = { left: MAX_BODY_CHARS - out.join("\n").length - 2000 };

  if (first.length) {
    out.push("## Påverkar allergener", "");
    appendCapped(out, first.map(proposalLines), budget, "förslag");
    out.push("");
  }
  if (rest.length) {
    out.push("## Övriga ändringar", "");
    appendCapped(out, rest.map(proposalLines), budget, "förslag");
    out.push("");
  }
  if (input.conflicts.length) {
    out.push(
      "## Konflikter (inte med i ändringen)",
      "",
      "| Ingrediens | Fält | Värde i CSV:n | Förslagets gamla värde | Nytt värde |",
      "|---|---|---|---|---|",
    );
    appendCapped(out, input.conflicts.map((c) => [conflictRow(c)]), budget, "konflikter");
    out.push("");
  }
  if (input.rejected.length) {
    out.push("## Nekade av servern (inte med i ändringen)", "");
    appendCapped(out, input.rejected.map((r) => [`- ${code(r.ingredientId)}: ${code(r.reason)}`]), budget, "nekade");
    out.push("");
  }
  return out.join("\n");
}
