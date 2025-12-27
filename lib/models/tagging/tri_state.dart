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
  String toFirestore() {
    switch (this) {
      case TriState.contains:
        return 'CONTAINS';
      case TriState.free:
        return 'FREE';
      case TriState.unknown:
        return 'UNKNOWN';
    }
  }

  /// Creates from Firestore string representation.
  static TriState fromFirestore(String? value) {
    switch (value?.toUpperCase()) {
      case 'CONTAINS':
        return TriState.contains;
      case 'FREE':
        return TriState.free;
      case 'UNKNOWN':
      default:
        return TriState.unknown;
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
