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
