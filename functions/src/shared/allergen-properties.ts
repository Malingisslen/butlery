/**
 * Single source of truth for which ingredient properties are allergen-relevant.
 *
 * Used by:
 * - sync-ingredients (diff report: highlight allergen-property removals)
 * - analyze-corrections (hold-for-review gate on alias auto-learning, BUT-1468)
 *
 * Keep in lockstep with ALLERGEN_BLOCK_PROPERTIES (exported next to
 * VALID_PROPERTIES in sync-ingredients-core.ts — pinned by a drift test in
 * sync-ingredients-diff.test.ts) and with the client-side allergen triggers
 * in lib/services/tagging/config/allergen_config.dart. A property listed here
 * means "a mistake on this ingredient can produce a wrong allergen or
 * dietary-restriction verdict", so automated writes touching such ingredients
 * must be held for human review.
 */
export const ALLERGEN_RELEVANT_PROPERTIES: ReadonlySet<string> = new Set([
  // Allergen block of VALID_PROPERTIES (EU-14 + lactose)
  "contains-gluten",
  "contains-lactose",
  "peanut",
  "sesame",
  "soy",
  "tree-nut",
  "crustacean",
  "mollusc",
  "celery",
  "mustard",
  "lupin",
  "sulfites",
  // Diet/meat-detail properties that feed allergen verdicts client-side
  // (fisk, skaldjur combined trigger, mjölk/ägg detection)
  "fish",
  "shellfish",
  "seafood",
  "dairy",
  "egg",
  // Dietary-restriction triggers (fläskfri/alkoholfri/köttfri badges in
  // allergen_config.dart) — a wrong verdict here hits religious-dietary
  // users through the same machinery, so holds apply to these too.
  "meat",
  "pork",
  "beef",
  "contains-alcohol",
]);
