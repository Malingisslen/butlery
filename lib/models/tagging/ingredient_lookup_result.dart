import 'package:butlery/models/tagging/ingredient_data.dart';
import 'package:butlery/models/tagging/tri_state.dart';

/// Result of looking up ingredients from the database.
///
/// Contains matched ingredients with their properties,
/// unmatched ingredient names, and coverage statistics.
class IngredientLookupResult {
  /// Ingredients successfully matched in the database.
  final List<IngredientData> matched;

  /// Ingredient names not found in the database.
  final List<String> unmatched;

  /// Percentage of ingredients found (0.0 - 1.0).
  final double coverage;

  const IngredientLookupResult({
    required this.matched,
    required this.unmatched,
    required this.coverage,
  });

  /// Creates an empty result for recipes with no ingredients.
  /// HIGH-1: Coverage is 0.0 because we have no ingredient data to analyze.
  /// This is consistent with TagResult.empty() semantics.
  factory IngredientLookupResult.empty() {
    return const IngredientLookupResult(
      matched: [],
      unmatched: [],
      coverage: 0.0, // No ingredients = no data to analyze
    );
  }

  /// Creates from lists, auto-calculating coverage.
  /// HIGH-1: Empty lists result in 0.0 coverage (no data to analyze).
  factory IngredientLookupResult.fromLists({
    required List<IngredientData> matched,
    required List<String> unmatched,
  }) {
    final total = matched.length + unmatched.length;
    final coverage = total == 0 ? 0.0 : matched.length / total;
    return IngredientLookupResult(
      matched: matched,
      unmatched: unmatched,
      coverage: coverage,
    );
  }

  /// Returns true if any ingredients are unknown.
  bool get hasUnknowns => unmatched.isNotEmpty;

  /// Returns true if all ingredients were found.
  bool get hasFullCoverage => coverage >= 1.0;

  /// Total number of ingredients (matched + unmatched).
  int get totalCount => matched.length + unmatched.length;

  /// Number of matched ingredients.
  int get matchedCount => matched.length;

  /// Number of unmatched ingredients.
  int get unmatchedCount => unmatched.length;

  // Property aggregation

  /// Gets all unique properties from matched ingredients.
  Set<String> get allProperties {
    return matched.expand((i) => i.properties).toSet();
  }

  /// Gets all unique groups from matched ingredients.
  Set<String> get allGroups {
    return matched.map((i) => i.group).toSet();
  }

  /// Gets all top-level groups from matched ingredients.
  Set<String> get allTopLevelGroups {
    return matched.map((i) => i.topLevelGroup).toSet();
  }

  /// Checks if any matched ingredient has the given property.
  bool hasProperty(String property) {
    return matched.any((i) => i.hasProperty(property));
  }

  /// Checks if any matched ingredient has any of the given properties.
  bool hasAnyProperty(Iterable<String> properties) {
    return matched.any((i) => i.hasAnyProperty(properties));
  }

  /// Checks if any matched ingredient is in the given group.
  bool hasGroup(String groupPath) {
    return matched.any((i) => i.isInGroup(groupPath));
  }

  /// Gets all ingredients with a specific property.
  List<IngredientData> getIngredientsWithProperty(String property) {
    return matched.where((i) => i.hasProperty(property)).toList();
  }

  /// Gets all ingredients in a specific group.
  List<IngredientData> getIngredientsInGroup(String groupPath) {
    return matched.where((i) => i.isInGroup(groupPath)).toList();
  }

  // TriState calculations for properties

  /// Calculates TriState for a property based on coverage and presence.
  ///
  /// - CONTAINS: At least one ingredient has the property
  /// - FREE: 100% coverage AND no ingredient has the property
  /// - UNKNOWN: Coverage < 100%
  TriState getPropertyStatus(String property) {
    if (coverage < 1.0) {
      return TriState.unknown;
    }
    if (hasProperty(property)) {
      return TriState.contains;
    }
    return TriState.free;
  }

  /// Calculates TriState for combined properties using OR logic.
  ///
  /// Used for allergens like 'nuts' = tree-nut OR peanut.
  TriState getCombinedPropertyStatus(List<String> properties) {
    if (coverage < 1.0) {
      return TriState.unknown;
    }
    if (hasAnyProperty(properties)) {
      return TriState.contains;
    }
    return TriState.free;
  }

  /// Calculates TriState for dietary exclusion.
  ///
  /// Dietary checks are CONTAINS (has excluded property) or FREE.
  /// Example: vegetarian = no 'meat' and no 'seafood'.
  TriState getDietaryStatus(List<String> excludedProperties) {
    if (coverage < 1.0) {
      return TriState.unknown;
    }
    if (hasAnyProperty(excludedProperties)) {
      return TriState.contains;
    }
    return TriState.free;
  }

  // Group-based queries

  /// Returns true if this has a meat protein.
  bool get hasMeat => hasGroup('protein/meat');

  /// Returns true if this has seafood.
  bool get hasSeafood => hasGroup('protein/seafood');

  /// Returns true if this has fish.
  bool get hasFish => hasGroup('protein/seafood/fish');

  /// Returns true if this has shellfish.
  bool get hasShellfish => hasGroup('protein/seafood/shellfish');

  /// Returns true if this has dairy.
  bool get hasDairy => hasGroup('protein/dairy');

  /// Returns true if this has eggs.
  bool get hasEggs => hasGroup('protein/egg');

  /// Returns true if this has plant-based protein.
  bool get hasPlantProtein => hasGroup('protein/plant-based');

  /// Returns true if this has vegetables.
  bool get hasVegetables => hasGroup('vegetable');

  /// Returns true if this has fruit.
  bool get hasFruit => hasGroup('fruit');

  /// Returns true if this has grains.
  bool get hasGrains => hasGroup('grain');

  /// Returns true if this has spices/herbs.
  bool get hasSpices => hasGroup('spice');

  @override
  String toString() =>
      'IngredientLookupResult(${matched.length} matched, ${unmatched.length} unmatched, ${(coverage * 100).toStringAsFixed(0)}% coverage)';

  /// Creates a copy with additional matched/unmatched ingredients.
  IngredientLookupResult copyWith({
    List<IngredientData>? matched,
    List<String>? unmatched,
  }) {
    final newMatched = matched ?? this.matched;
    final newUnmatched = unmatched ?? this.unmatched;
    return IngredientLookupResult.fromLists(
      matched: newMatched,
      unmatched: newUnmatched,
    );
  }

  /// Merges with another lookup result.
  IngredientLookupResult merge(IngredientLookupResult other) {
    return IngredientLookupResult.fromLists(
      matched: [...matched, ...other.matched],
      unmatched: [...unmatched, ...other.unmatched],
    );
  }
}
