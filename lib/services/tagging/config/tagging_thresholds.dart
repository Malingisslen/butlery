/// M1: Centralized threshold configuration for the tagging system.
///
/// Collects all hardcoded thresholds in one place for easy adjustment
/// and documentation. All values are based on Swedish cooking conventions
/// and allergen safety requirements.
library;

/// Threshold configuration for tagging system.
class TaggingThresholds {
  TaggingThresholds._();

  /// Minimum coverage for reliable dietary claims.
  /// Below this threshold, dietary status is marked UNKNOWN.
  static const double reliableDietaryCoverage = 0.8;

  /// Minimum coverage for reliable allergen claims.
  /// Below this threshold, allergen status is marked UNKNOWN.
  static const double reliableAllergenCoverage = 0.9;

  /// Timeout for tag generation operations.
  static const Duration generationTimeout = Duration(seconds: 30);

  /// Minimum protein ratio (of matched ingredients) for "proteinrik" tag.
  static const double highProteinRatio = 0.25;

  /// Minimum vegetable count for "grönsaksrik" tag.
  static const int veggieRichCount = 3;

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
}
