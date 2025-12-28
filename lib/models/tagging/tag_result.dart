import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:butlery/core/utils/serialization_utils.dart';
import 'package:butlery/models/tagging/tri_state.dart';
import 'package:butlery/services/tagging/tag_generator.dart'
    show kTagGeneratorVersion;

/// The output of the TagGenerator - stored on recipe documents.
///
/// Contains all computed tags, allergen status, dietary status,
/// coverage information, and any unknown ingredients.
class TagResult {
  /// Identity and category tags (e.g., 'kyckling', 'pasta-dish', 'italian').
  final Set<String> tags;

  /// Allergen status with tri-valued logic (CONTAINS/FREE/UNKNOWN).
  /// Keys are allergen identifiers from AllergenConfig.
  final Map<String, TriState> allergenStatus;

  /// Dietary status with tri-valued logic.
  /// Keys: 'vegetarian', 'vegan', 'pescetarian', etc.
  final Map<String, TriState> dietaryStatus;

  /// Percentage of ingredients found in database (0.0 - 1.0).
  final double coverage;

  /// Ingredients not found in the database.
  final List<String> unknownIngredients;

  /// When these tags were generated.
  final DateTime generatedAt;

  /// Version of the tag generator used.
  final String? generatorVersion;

  const TagResult({
    required this.tags,
    required this.allergenStatus,
    required this.dietaryStatus,
    required this.coverage,
    this.unknownIngredients = const [],
    required this.generatedAt,
    this.generatorVersion,
  });

  /// Creates an empty result for recipes with no ingredients.
  /// Coverage is 0.0 because we have no ingredient data to analyze.
  /// Empty status maps mean allergens/diets are unknown (safe default).
  /// Marked with generatorVersion 'empty' to distinguish from failed tagging.
  factory TagResult.empty() {
    return TagResult(
      tags: {},
      allergenStatus: {},
      dietaryStatus: {},
      coverage: 0.0, // No ingredients = no data to analyze
      unknownIngredients: [],
      generatedAt: DateTime.now(),
      generatorVersion: 'empty', // Mark as empty recipe, not failed
    );
  }

  /// Creates a pending result for recipes saved offline awaiting tagging.
  /// Used when a recipe is saved while offline - tags will be generated
  /// when connectivity is restored.
  factory TagResult.pending() {
    return TagResult(
      tags: {},
      allergenStatus: {},
      dietaryStatus: {},
      coverage: 0.0,
      unknownIngredients: [],
      generatedAt: DateTime.now(),
      generatorVersion: 'pending', // Mark as awaiting tagging
    );
  }

  /// Returns true if tagging is pending (saved offline).
  bool get isPending => generatorVersion == 'pending';

  /// Creates from Firestore map data.
  factory TagResult.fromFirestore(Map<String, dynamic>? data) {
    if (data == null) return TagResult.empty();

    return TagResult(
      tags: _parseStringSet(data['tags']),
      allergenStatus: _parseTriStateMap(data['allergenStatus']),
      dietaryStatus: _parseTriStateMap(data['dietaryStatus']),
      coverage:
          SerializationUtils.safeDouble(data, 'coverage', defaultValue: 0.0),
      unknownIngredients: _parseStringList(data['unknownIngredients']),
      generatedAt: SerializationUtils.safeRequiredDateTime(
        data,
        'generatedAt',
        defaultValue: DateTime.now(),
      ),
      generatorVersion:
          SerializationUtils.safeNullableString(data, 'generatorVersion'),
    );
  }

  /// Converts to Firestore map.
  Map<String, dynamic> toFirestore() {
    return {
      'tags': tags.toList(),
      'allergenStatus':
          allergenStatus.map((k, v) => MapEntry(k, v.toFirestore())),
      'dietaryStatus':
          dietaryStatus.map((k, v) => MapEntry(k, v.toFirestore())),
      'coverage': coverage,
      'unknownIngredients': unknownIngredients,
      'generatedAt': Timestamp.fromDate(generatedAt),
      if (generatorVersion != null) 'generatorVersion': generatorVersion,
    };
  }

  // Parsing helpers

  static Set<String> _parseStringSet(dynamic value) {
    if (value == null) return {};
    if (value is List) {
      return value.map((e) => e.toString()).toSet();
    }
    return {};
  }

  static List<String> _parseStringList(dynamic value) {
    if (value == null) return [];
    if (value is List) {
      return value.map((e) => e.toString()).toList();
    }
    return [];
  }

  static Map<String, TriState> _parseTriStateMap(dynamic value) {
    if (value == null) return {};
    if (value is Map) {
      return value.map(
        (k, v) => MapEntry(
            k.toString(), TriStateExtension.fromFirestore(v?.toString())),
      );
    }
    return {};
  }

  // Query helpers

  /// Checks if recipe is free from a specific allergen.
  /// Returns true ONLY if proven free (TriState.free).
  bool isAllergenFree(String allergen) =>
      allergenStatus[allergen] == TriState.free;

  /// Checks if recipe contains a specific allergen.
  bool containsAllergen(String allergen) =>
      allergenStatus[allergen] == TriState.contains;

  /// Checks if allergen status is unknown.
  bool isAllergenUnknown(String allergen) =>
      allergenStatus[allergen] == TriState.unknown ||
      !allergenStatus.containsKey(allergen);

  /// Gets allergen status for a specific allergen.
  TriState getAllergenStatus(String allergen) =>
      allergenStatus[allergen] ?? TriState.unknown;

  /// Checks if recipe is safe for a specific diet.
  /// Returns true ONLY if proven safe (TriState.free).
  bool isDietarySafe(String diet) => dietaryStatus[diet] == TriState.free;

  /// Gets dietary status for a specific diet.
  TriState getDietaryStatus(String diet) =>
      dietaryStatus[diet] ?? TriState.unknown;

  /// Returns true if all ingredients were found in database.
  bool get hasFullCoverage => coverage >= 1.0;

  /// Returns true if some ingredients are unknown.
  bool get hasUnknowns => unknownIngredients.isNotEmpty;

  /// Returns true if recipe has the specified tag.
  bool hasTag(String tag) => tags.contains(tag);

  /// Returns true if recipe has any of the specified tags.
  bool hasAnyTag(Iterable<String> queryTags) =>
      queryTags.any((t) => tags.contains(t));

  /// Returns true if recipe has all of the specified tags.
  bool hasAllTags(Iterable<String> queryTags) =>
      queryTags.every((t) => tags.contains(t));

  // Common allergen checks (convenience methods)

  bool get isGlutenFree => isAllergenFree('gluten');
  bool get isLactoseFree => isAllergenFree('laktos');
  bool get isDairyFree => isAllergenFree('mjölk');
  bool get isNutFree => isAllergenFree('nötter');
  bool get isPeanutFree => isAllergenFree('jordnötter');
  bool get isEggFree => isAllergenFree('ägg');
  bool get isFishFree => isAllergenFree('fisk');
  bool get isShellfishFree => isAllergenFree('skaldjur');
  bool get isSoyFree => isAllergenFree('soja');
  bool get isSesameFree => isAllergenFree('sesam');

  // Common dietary checks

  bool get isVegetarian => isDietarySafe('vegetarisk');
  bool get isVegan => isDietarySafe('vegansk');
  bool get isPescetarian => isDietarySafe('pescetarian');
  bool get isHalalFriendly => isDietarySafe('halalanpassad');
  bool get isKosherFriendly => isDietarySafe('kosheranpassad');
  bool get isPregnancySafe => isDietarySafe('graviditetssäker');
  bool get isKidFriendly => isDietarySafe('barnvänlig');

  // Version and retagging

  /// Returns true if tagging explicitly failed (error during generation).
  /// This is different from needsRetagging which includes version mismatches.
  bool get hasFailed => generatorVersion == 'failed';

  /// Checks if this result needs retagging due to version mismatch, failure, or pending status.
  ///
  /// Returns true if:
  /// - Generator version is 'failed' (tagging error)
  /// - Generator version is 'pending' (saved offline, awaiting tagging)
  /// - Generator version differs from current version
  /// - Generator version is null (legacy data)
  bool get needsRetagging {
    if (generatorVersion == null) return true;
    if (hasFailed) return true;
    if (isPending) return true;
    return generatorVersion != kTagGeneratorVersion;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TagResult &&
          runtimeType == other.runtimeType &&
          _setEquals(tags, other.tags) &&
          _mapEquals(allergenStatus, other.allergenStatus) &&
          _mapEquals(dietaryStatus, other.dietaryStatus) &&
          coverage == other.coverage &&
          _listEquals(unknownIngredients, other.unknownIngredients);

  static bool _setEquals<T>(Set<T> a, Set<T> b) =>
      a.length == b.length && a.containsAll(b);

  static bool _mapEquals<K, V>(Map<K, V> a, Map<K, V> b) =>
      a.length == b.length && a.entries.every((e) => b[e.key] == e.value);

  static bool _listEquals<T>(List<T> a, List<T> b) =>
      a.length == b.length &&
      a.asMap().entries.every((e) => b[e.key] == e.value);

  @override
  int get hashCode => Object.hash(
        tags,
        allergenStatus,
        dietaryStatus,
        coverage,
        Object.hashAll(unknownIngredients),
      );

  @override
  String toString() =>
      'TagResult(${tags.length} tags, coverage: ${(coverage * 100).toStringAsFixed(0)}%)';

  /// Creates a copy with optional field overrides.
  TagResult copyWith({
    Set<String>? tags,
    Map<String, TriState>? allergenStatus,
    Map<String, TriState>? dietaryStatus,
    double? coverage,
    List<String>? unknownIngredients,
    DateTime? generatedAt,
    String? generatorVersion,
  }) {
    return TagResult(
      tags: tags ?? this.tags,
      allergenStatus: allergenStatus ?? this.allergenStatus,
      dietaryStatus: dietaryStatus ?? this.dietaryStatus,
      coverage: coverage ?? this.coverage,
      unknownIngredients: unknownIngredients ?? this.unknownIngredients,
      generatedAt: generatedAt ?? this.generatedAt,
      generatorVersion: generatorVersion ?? this.generatorVersion,
    );
  }

  /// Merges tags from another TagResult (used for combining phases).
  TagResult mergeTags(Set<String> additionalTags) {
    return copyWith(tags: {...tags, ...additionalTags});
  }
}
