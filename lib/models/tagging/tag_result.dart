import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/core/utils/serialization_utils.dart';
import 'package:butlery/models/tagging/tag_decision.dart';
import 'package:butlery/models/tagging/tri_state.dart';
import 'package:butlery/services/tagging/config/allergen_config.dart';
import 'package:butlery/services/tagging/config/dietary_config.dart';
import 'package:butlery/services/tagging/tag_generator.dart'
    show kTagGeneratorVersion;

/// L12: Schema version for TagResult data structure.
/// Increment this when making breaking changes to the serialization format.
/// Used for migrations when reading older data formats.
const int kTagResultSchemaVersion = 1;

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

  /// C2: Coverage ratio (0.0-1.0) indicating what fraction of recipe ingredients
  /// were found in the ingredient database. 1.0 = all matched, 0.5 = half matched.
  /// Use [coveragePercent] for display and [hasReliableCoverage] for dietary claims.
  final double coverage;

  /// Ingredients not found in the database.
  final List<String> unknownIngredients;

  /// When these tags were generated.
  final DateTime generatedAt;

  /// Version of the tag generator used.
  final String? generatorVersion;

  /// C3: Whether this result is partial due to timeout or interruption.
  /// Partial results have Phase 1 complete (allergens safe) but may be
  /// missing Phase 3-4 tags (difficulty, mood, practical).
  final bool isPartial;

  /// H3: Decision logs explaining why each allergen/dietary status was set.
  /// NOT stored in Firestore to avoid storage bloat. Available in-memory
  /// and via JSON serialization for debugging purposes.
  final List<TagDecision>? decisions;

  const TagResult({
    required this.tags,
    required this.allergenStatus,
    required this.dietaryStatus,
    required this.coverage,
    this.unknownIngredients = const [],
    required this.generatedAt,
    this.generatorVersion,
    this.isPartial = false,
    this.decisions,
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

  /// Creates a failed result when tag generation encounters an error.
  /// The reason parameter provides context for debugging.
  factory TagResult.failed({String? reason}) {
    return TagResult(
      tags: {},
      allergenStatus: {},
      dietaryStatus: {},
      coverage: 0.0,
      unknownIngredients: reason != null ? [reason] : [],
      generatedAt: DateTime.now(),
      generatorVersion: 'failed', // Mark as failed tagging
    );
  }

  /// Returns true if tagging is pending (saved offline).
  bool get isPending => generatorVersion == 'pending';

  /// Creates from Firestore map data.
  factory TagResult.fromFirestore(Map<String, dynamic>? data) {
    if (data == null) return TagResult.empty();

    // L12: Check schema version and migrate if needed
    final schemaVersion =
        SerializationUtils.safeInt(data, 'schemaVersion', defaultValue: 0);
    final migratedData = _migrateSchema(data, schemaVersion);

    // H7: Clamp coverage to valid [0.0, 1.0] range
    final rawCoverage = SerializationUtils.safeDouble(migratedData, 'coverage',
        defaultValue: 0.0);
    final coverage = rawCoverage.clamp(0.0, 1.0);

    // H11: Log warning when DateTime is missing (could indicate data corruption)
    DateTime generatedAt;
    final rawGeneratedAt = migratedData['generatedAt'];
    if (rawGeneratedAt == null) {
      AppLogger.warning(
        'TagResult.fromFirestore: generatedAt is null, defaulting to now(). '
            'This may indicate corrupted data.',
        'TagResult',
      );
      generatedAt = DateTime.now();
    } else {
      generatedAt = SerializationUtils.safeRequiredDateTime(
        migratedData,
        'generatedAt',
        defaultValue: DateTime.now(),
      );
    }

    return TagResult(
      tags: _parseStringSet(migratedData['tags']),
      // M11: Use validated parsing for allergen/dietary status
      allergenStatus: _parseAllergenStatus(migratedData['allergenStatus']),
      dietaryStatus: _parseDietaryStatus(migratedData['dietaryStatus']),
      coverage: coverage,
      unknownIngredients: _parseStringList(migratedData['unknownIngredients']),
      generatedAt: generatedAt,
      generatorVersion: SerializationUtils.safeNullableString(
          migratedData, 'generatorVersion'),
      isPartial: SerializationUtils.safeBool(migratedData, 'isPartial',
          defaultValue: false),
    );
  }

  /// Converts to Firestore map (uses Timestamp for dates).
  Map<String, dynamic> toFirestore() {
    // M15: Sort tags for consistent ordering across all storage
    final sortedTags = tags.toList()..sort();
    return {
      'tags': sortedTags,
      'allergenStatus':
          allergenStatus.map((k, v) => MapEntry(k, v.toFirestore())),
      'dietaryStatus':
          dietaryStatus.map((k, v) => MapEntry(k, v.toFirestore())),
      'coverage': coverage,
      'unknownIngredients': unknownIngredients,
      'generatedAt': Timestamp.fromDate(generatedAt),
      // M14: Always write generatorVersion for consistency (null means unversioned)
      'generatorVersion': generatorVersion,
      // C3: Include partial flag
      'isPartial': isPartial,
      // L12: Include schema version for future migrations
      'schemaVersion': kTagResultSchemaVersion,
    };
  }

  /// Converts to JSON map (uses ISO string for dates).
  /// Use this for Drift/SQLite storage and JSON serialization.
  Map<String, dynamic> toJson() {
    // M15: Sort tags for consistent ordering across all storage
    final sortedTags = tags.toList()..sort();
    return {
      'tags': sortedTags,
      'allergenStatus':
          allergenStatus.map((k, v) => MapEntry(k, v.toFirestore())),
      'dietaryStatus':
          dietaryStatus.map((k, v) => MapEntry(k, v.toFirestore())),
      'coverage': coverage,
      'unknownIngredients': unknownIngredients,
      'generatedAt': generatedAt.toIso8601String(),
      // M14: Always write generatorVersion for consistency (null means unversioned)
      'generatorVersion': generatorVersion,
      // C3: Include partial flag
      'isPartial': isPartial,
      // L12: Include schema version for future migrations
      'schemaVersion': kTagResultSchemaVersion,
      // H3: Include decisions if present (for debugging)
      if (decisions != null && decisions!.isNotEmpty)
        'decisions': decisions!.map((d) => d.toJson()).toList(),
    };
  }

  /// Creates from JSON map (expects ISO string for dates).
  /// Use this for Drift/SQLite storage and JSON deserialization.
  factory TagResult.fromJson(Map<String, dynamic>? data) {
    if (data == null) return TagResult.empty();

    // L12: Check schema version and migrate if needed
    final schemaVersion =
        SerializationUtils.safeInt(data, 'schemaVersion', defaultValue: 0);
    final migratedData = _migrateSchema(data, schemaVersion);

    // H11: Log warning when DateTime is missing (could indicate data corruption)
    DateTime parseDateTime(dynamic value) {
      if (value == null) {
        AppLogger.warning(
          'TagResult.fromJson: generatedAt is null, defaulting to now(). '
              'This may indicate corrupted data.',
          'TagResult',
        );
        return DateTime.now();
      }
      if (value is DateTime) return value;
      if (value is String) return DateTime.parse(value);
      if (value is Timestamp) return value.toDate();
      AppLogger.warning(
        'TagResult.fromJson: unexpected generatedAt type ${value.runtimeType}, defaulting to now().',
        'TagResult',
      );
      return DateTime.now();
    }

    // H7: Clamp coverage to valid [0.0, 1.0] range
    final rawCoverage = SerializationUtils.safeDouble(migratedData, 'coverage',
        defaultValue: 0.0);
    final coverage = rawCoverage.clamp(0.0, 1.0);

    return TagResult(
      tags: _parseStringSet(migratedData['tags']),
      // M11: Use validated parsing for allergen/dietary status
      allergenStatus: _parseAllergenStatus(migratedData['allergenStatus']),
      dietaryStatus: _parseDietaryStatus(migratedData['dietaryStatus']),
      coverage: coverage,
      unknownIngredients: _parseStringList(migratedData['unknownIngredients']),
      generatedAt: parseDateTime(migratedData['generatedAt']),
      generatorVersion: SerializationUtils.safeNullableString(
          migratedData, 'generatorVersion'),
      isPartial: SerializationUtils.safeBool(migratedData, 'isPartial',
          defaultValue: false),
      // H3: Parse decisions if present
      decisions: _parseDecisions(migratedData['decisions']),
    );
  }

  // Schema migration helpers

  /// L12: Migrates data from older schema versions to current version.
  ///
  /// Currently supports:
  /// - V0 → V1: Add schemaVersion field (no data transformation needed)
  ///
  /// Future migrations can be added here when the schema evolves.
  static Map<String, dynamic> _migrateSchema(
    Map<String, dynamic> data,
    int fromVersion,
  ) {
    if (fromVersion >= kTagResultSchemaVersion) {
      return data; // Already at current version
    }

    final migrated = Map<String, dynamic>.from(data);

    // V0 → V1: Initial schema version (no data transformation needed)
    if (fromVersion < 1) {
      migrated['schemaVersion'] = 1;
      // No data transformation needed for V1, just version tracking
      AppLogger.debug(
        'TagResult: Migrated from schema v$fromVersion to v1',
        'TagResult',
      );
    }

    // Future migrations would be added here:
    // if (fromVersion < 2) {
    //   // V1 → V2 migration logic
    //   migrated['newField'] = migrated['oldField'];
    //   migrated.remove('oldField');
    //   migrated['schemaVersion'] = 2;
    // }

    return migrated;
  }

  // Parsing helpers

  static Set<String> _parseStringSet(dynamic value) {
    if (value == null) return {};
    if (value is List) {
      final result = value.map((e) => e.toString()).toSet();
      // M12: Log warning if duplicates were found
      if (value.length != result.length) {
        final duplicateCount = value.length - result.length;
        AppLogger.warning(
          'TagResult: Found $duplicateCount duplicate tag(s) in stored data, deduplicated.',
          'TagResult',
        );
      }
      return result;
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

  static Map<String, TriState> _parseTriStateMap(
    dynamic value, {
    Set<String>? validKeys,
    String? contextName,
  }) {
    if (value == null) return {};
    if (value is Map) {
      final result = <String, TriState>{};
      for (final entry in value.entries) {
        final key = entry.key.toString();
        final triState =
            TriStateExtension.fromFirestore(entry.value?.toString());

        // M11: Validate key if validKeys provided
        if (validKeys != null && !validKeys.contains(key)) {
          AppLogger.warning(
            'TagResult: Unknown ${contextName ?? "status"} key "$key", skipping.',
            'TagResult',
          );
          continue;
        }

        result[key] = triState;
      }
      return result;
    }
    return {};
  }

  /// M11: Parses allergenStatus with validation against AllergenConfig.
  static Map<String, TriState> _parseAllergenStatus(dynamic value) {
    return _parseTriStateMap(
      value,
      validKeys: AllergenConfig.allKeys.toSet(),
      contextName: 'allergen',
    );
  }

  /// M11: Parses dietaryStatus with validation against DietaryConfig.
  static Map<String, TriState> _parseDietaryStatus(dynamic value) {
    return _parseTriStateMap(
      value,
      validKeys: DietaryConfig.allKeys.toSet(),
      contextName: 'dietary',
    );
  }

  /// H3: Parses decisions list from JSON.
  static List<TagDecision>? _parseDecisions(dynamic value) {
    if (value == null) return null;
    if (value is List) {
      return value
          .whereType<Map<String, dynamic>>()
          .map((d) => TagDecision.fromJson(d))
          .toList();
    }
    return null;
  }

  // H3: Decision query helpers

  /// H3: Gets the decision that explains a specific allergen status.
  TagDecision? getAllergenDecision(String allergen) => decisions
      ?.where((d) => d.type == 'allergen' && d.key == allergen)
      .firstOrNull;

  /// H3: Gets the decision that explains a specific dietary status.
  TagDecision? getDietaryDecision(String diet) =>
      decisions?.where((d) => d.type == 'dietary' && d.key == diet).firstOrNull;

  /// H3: Returns true if decisions are available for inspection.
  bool get hasDecisions => decisions != null && decisions!.isNotEmpty;

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

  /// C2: Coverage as percentage (0-100) for display purposes.
  int get coveragePercent => (coverage * 100).round();

  /// C2: Whether coverage is sufficient for reliable dietary/allergen claims.
  /// Below 80% coverage, claims should be treated with caution.
  bool get hasReliableCoverage => coverage >= 0.8;

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
          _listEquals(unknownIngredients, other.unknownIngredients) &&
          generatorVersion == other.generatorVersion &&
          isPartial == other.isPartial;

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
        generatorVersion,
        isPartial,
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
    bool? isPartial,
    List<TagDecision>? decisions,
  }) {
    return TagResult(
      tags: tags ?? this.tags,
      allergenStatus: allergenStatus ?? this.allergenStatus,
      dietaryStatus: dietaryStatus ?? this.dietaryStatus,
      coverage: coverage ?? this.coverage,
      unknownIngredients: unknownIngredients ?? this.unknownIngredients,
      generatedAt: generatedAt ?? this.generatedAt,
      generatorVersion: generatorVersion ?? this.generatorVersion,
      isPartial: isPartial ?? this.isPartial,
      decisions: decisions ?? this.decisions,
    );
  }

  /// Merges tags from another TagResult (used for combining phases).
  TagResult mergeTags(Set<String> additionalTags) {
    return copyWith(tags: {...tags, ...additionalTags});
  }
}
