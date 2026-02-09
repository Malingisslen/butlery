import 'package:butlery/core/utils/logger.dart';

/// Tri-valued logic for allergen and dietary safety.
///
/// CRITICAL: Never use boolean for allergens - use TriState.
/// This prevents allergic users from seeing recipes where safety is unknown.
enum TriState {
  /// Recipe contains the allergen/property.
  contains,

  /// Recipe is proven free (100% coverage, no ingredients have property).
  free,

  /// Coverage < 100% OR unknown ingredient - we don't know.
  unknown,
}

/// Extension methods for tri-valued logic operations.
extension TriStateExtension on TriState {
  /// OR-logic for combination allergens (e.g., nuts = tree-nut OR peanut).
  ///
  /// Priority: CONTAINS > UNKNOWN > FREE
  ///
  /// Examples:
  /// - Almond (tree-nut: CONTAINS) + unknown (peanut: UNKNOWN) → CONTAINS
  /// - No tree nuts (FREE) + unknown (peanut: UNKNOWN) → UNKNOWN
  /// - No tree nuts (FREE) + no peanuts (FREE) → FREE
  TriState orCombine(TriState other) {
    if (this == TriState.contains || other == TriState.contains) {
      return TriState.contains;
    }
    if (this == TriState.unknown || other == TriState.unknown) {
      return TriState.unknown;
    }
    return TriState.free;
  }

  /// AND-logic for dietary status (e.g., vegan = no animal products).
  ///
  /// Priority: CONTAINS > UNKNOWN > FREE
  TriState andCombine(TriState other) {
    if (this == TriState.contains || other == TriState.contains) {
      return TriState.contains;
    }
    if (this == TriState.unknown || other == TriState.unknown) {
      return TriState.unknown;
    }
    return TriState.free;
  }

  /// Returns true only if this is FREE (proven safe).
  bool get isFree => this == TriState.free;

  /// Returns true if this contains the allergen/property.
  bool get containsAllergen => this == TriState.contains;

  /// Returns true if status is unknown.
  bool get isUnknown => this == TriState.unknown;

  /// Converts to Firestore string representation.
  /// Uses lowercase format (Dart enum .name convention).
  /// The fromFirestore parser handles both lowercase and legacy uppercase.
  String toFirestore() => name;

  /// Creates from Firestore string representation.
  ///
  /// Logs a warning if an invalid value is encountered before defaulting to UNKNOWN.
  /// This is important for detecting data corruption in allergen-critical data.
  static TriState fromFirestore(String? value) {
    final upper = value?.toUpperCase();
    switch (upper) {
      case 'CONTAINS':
        return TriState.contains;
      case 'FREE':
        return TriState.free;
      case 'UNKNOWN':
      case null:
        return TriState.unknown;
      default:
        // Log unexpected values - could indicate data corruption
        AppLogger.warning(
          'Invalid TriState value "$value" encountered, defaulting to UNKNOWN',
        );
        return TriState.unknown;
    }
  }
}

/// Extension for parsing TriState from various string formats.
extension TriStateParsing on TriState {
  /// Parses from enum name (lowercase) or Firestore format (uppercase).
  /// Returns null if value is not a valid TriState.
  static TriState? fromString(String? value) {
    if (value == null) return null;
    final lower = value.toLowerCase();
    switch (lower) {
      case 'contains':
        return TriState.contains;
      case 'free':
        return TriState.free;
      case 'unknown':
        return TriState.unknown;
      default:
        return null;
    }
  }
}

/// Helper for combining multiple TriState values.
class TriStateCalculator {
  /// Combines multiple values using OR logic.
  static TriState orAll(Iterable<TriState> values) {
    if (values.isEmpty) return TriState.unknown;
    return values.reduce((a, b) => a.orCombine(b));
  }

  /// Combines multiple values using AND logic.
  static TriState andAll(Iterable<TriState> values) {
    if (values.isEmpty) return TriState.unknown;
    return values.reduce((a, b) => a.andCombine(b));
  }
}
