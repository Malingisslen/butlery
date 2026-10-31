/// M1: Centralized threshold configuration for the tagging system.
///
/// Collects all hardcoded thresholds in one place for easy adjustment
/// and documentation. All values are based on Swedish cooking conventions
/// and allergen safety requirements.
library;

/// Threshold configuration for tagging system.
class TaggingThresholds {
  TaggingThresholds._();

  // M3 fix: Removed unused reliableDietaryCoverage and reliableAllergenCoverage.
  // These suggested 80%/90% thresholds but the actual Phase 1 code correctly
  // requires 100% coverage for allergen/dietary claims (safety-critical).
  // Keeping unused constants creates confusion for developers.

  /// Timeout for tag generation operations.
  static const Duration generationTimeout = Duration(seconds: 30);

  /// Weighed protein per portion for "proteinrik" (Malin 2026-10-30).
  static const int proteinGramsPerPortion = 200;

  /// Weighed cheese in the whole recipe for "ostig" (Malin 2026-10-30).
  static const double cheeseGrams = 100;

  /// Fresh herbs for "örtig" (Malin 2026-10-30).
  static const int herbRichCount = 2;

  /// Preparation time "lite-jobb" stays under (Malin 2026-10-30).
  static const int littleWorkMaxMinutes = 15;

  /// Lines that are not staples for "få-ingredienser".
  static const int fewIngredientsMax = 6;

  /// Minimum vegetable count for "grönsaksrik" tag.
  static const int veggieRichCount = 3;

  /// Minimum spice group count for "kryddrik" tag.
  static const int spiceRichCount = 3;

  /// Maximum ingredients for "enkel" (easy) difficulty.
  static const int easyMaxIngredients = 6;

  /// Maximum time (minutes) for "enkel" (easy) difficulty.
  static const int easyMaxMinutes = 30;

  /// Minimum ingredients for "avancerad" (advanced) difficulty.
  static const int advancedMinIngredients = 12;

  /// Minimum time (minutes) for "avancerad" (advanced) difficulty.
  static const int advancedMinMinutes = 60;

  /// Minimum portions for "storkok" (batch cooking) tag.
  static const int batchCookingMinPortions = 6;

  /// Minimum portions for "meal-prep" friendly.
  static const int mealPrepMinPortions = 4;

  /// Minimum characters for substring matching in fuzzy lookup.
  static const int fuzzyMatchMinChars = 3;

  /// Coverage threshold for "mild" tag.
  /// At 80%+ coverage with no spicy ingredients, we can reasonably claim mild.
  /// Lower than 100% to avoid making the tag effectively unreachable,
  /// while still requiring strong evidence that no spicy ingredients exist.
  static const double mildCoverageThreshold = 0.80;
}
