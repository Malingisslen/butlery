/**
 * Shared Swedish/European diacritics stripping for ingredient normalization.
 *
 * Used by admin scripts, analytics, and ingredient triggers to ensure
 * consistent text comparison across the codebase.
 */

/** Strip Swedish and common European diacritics to ASCII equivalents. */
export function stripDiacritics(s: string): string {
  return s
    .replace(/å/g, "a")
    .replace(/ä/g, "a")
    .replace(/ö/g, "o")
    .replace(/é/g, "e")
    .replace(/è/g, "e")
    .replace(/ê/g, "e")
    .replace(/ü/g, "u")
    .replace(/ñ/g, "n");
}

/**
 * Every spelling an ingredient name can appear under in a recipe's
 * `core.ingredientsNormalized`, deduped and safe to pass straight to
 * `array-contains-any`.
 *
 * BUT-1794 — this MUST stay a union, and must not be "simplified" back to a
 * single normalized string. The Dart producer (`IngredientNormalizer`, via
 * `ingredient_processor.dart`) lowercases but does NOT fold å/ä/ö, so live
 * recipes store "mjölk"; the retired admin backfill wrote the stripped
 * "mjolk". The corpus therefore holds both, and querying either form alone
 * silently matches only half of it — invisibly, because an empty result from a
 * cascade looks exactly like "nothing needed updating". 8 of the 14 EU
 * allergens have å/ä/ö in their Swedish names, so the half that goes missing
 * is the half that matters.
 *
 * It lives here rather than beside each trigger so the two cascades cannot
 * drift apart.
 */
export function ingredientMatchVariants(text: string): string[] {
  // Trimmed: the Sheet-sourced `ingredients/{id}.swedish` can carry a stray
  // space, and variants that match nothing are indistinguishable from
  // "nothing to update" — the exact invisibility this helper exists to end.
  const lower = text.trim().toLowerCase();
  return [...new Set([lower, stripDiacritics(lower)])];
}
