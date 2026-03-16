import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/core/utils/serialization_utils.dart';
import 'package:butlery/models/tagging/tag_decision.dart';
import 'package:butlery/models/tagging/tri_state.dart';
import 'package:butlery/services/tagging/config/allergen_config.dart';
import 'package:butlery/services/tagging/config/dietary_config.dart';
import 'package:butlery/services/tagging/tag_generator.dart'
    show kTagGeneratorVersion;
import 'package:butlery/services/tagging/tagging_events_tracker.dart';

/// L12: Schema version for TagResult data structure.
/// Increment this when making breaking changes to the serialization format.
/// Used for migrations when reading older data formats.
///
/// Version history:
/// - V1: Initial schema with basic tag result fields
/// - V2: Added errorReason field for explicit error tracking (MED-2)
const int kTagResultSchemaVersion = 2;

/// MED-2: Maximum length for errorReason field to prevent Firestore issues.
/// Longer reasons are truncated with ellipsis.
const int kMaxErrorReasonLength = 500;

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

  /// CRIT-2: Tracks if coverage value was out of range and had to be clamped.
  /// When true, this result should not be trusted for allergen/dietary claims
  /// and needsRetagging will return true.
  final bool hasCoverageAnomaly;

  /// H3: Decision logs explaining why each allergen/dietary status was set.
  /// NOT stored in Firestore to avoid storage bloat. Available in-memory
  /// and via JSON serialization for debugging purposes.
  final List<TagDecision>? decisions;

  /// MED-2/V2: Explicit error reason when tagging fails.
  /// Replaces the misuse of unknownIngredients for error messages.
  /// Null for successful tagging, contains error description on failure.
  final String? errorReason;

  /// Whether any matched ingredients have 'draft' status (AI-generated, unvalidated).
  /// When true, allergen/dietary classifications may be less reliable.
  final bool hasDraftIngredients;

  /// Creates a TagResult with the given properties.
  ///
  /// CRIT-2: Coverage is validated to be in [0.0, 1.0] range.
  /// Out-of-range values are logged, reported to analytics, clamped for safety,
  /// and hasCoverageAnomaly is set to true to trigger retagging.
  TagResult({
    required this.tags,
    required this.allergenStatus,
    required this.dietaryStatus,
    required double coverage,
    this.unknownIngredients = const [],
    required this.generatedAt,
    this.generatorVersion,
    this.isPartial = false,
    this.decisions,
    this.errorReason,
    this.hasDraftIngredients = false,
    bool? hasCoverageAnomaly,
  })  : coverage = _validateAndClampCoverage(coverage),
        hasCoverageAnomaly =
            hasCoverageAnomaly ?? _checkCoverageAnomaly(coverage);

  /// CRIT-2: Checks if coverage value is out of range (used to set hasCoverageAnomaly).
  static bool _checkCoverageAnomaly(double value) {
    return value < 0.0 || value > 1.0;
  }

  /// CRIT-2/CRIT-3: Validates coverage and fails fast on invalid values.
  ///
  /// In debug: Assertion failure to catch generator bugs during development.
  /// In release: Logs error, reports to analytics, and clamps to [0.0, 1.0] for safety.
  /// The hasCoverageAnomaly field is set separately to mark the result as needing retagging.
  ///
  /// Invalid coverage values indicate bugs in the tag generator that need
  /// immediate attention - they can lead to incorrect allergen/dietary claims.
  static double _validateAndClampCoverage(double value) {
    if (value < 0.0 || value > 1.0) {
      // CRIT-2: Fail fast in debug mode to catch generator bugs immediately
      assert(
        false,
        'CRIT-2: Coverage out of range: $value (expected 0.0-1.0). '
        'This indicates a bug in the tag generator that must be fixed.',
      );

      // In release: log error (not warning) and clamp for safety
      AppLogger.error(
        'CRIT-2: Coverage out of range: $value (expected 0.0-1.0), clamping. '
            'This indicates a bug in the tag generator. '
            'Result will be marked for retagging via hasCoverageAnomaly. '
            'Stack trace: ${StackTrace.current}',
        'TagResult',
      );

      // CRIT-3: Report to analytics for monitoring in production
      _reportCoverageAnomaly(value);

      return value.clamp(0.0, 1.0);
    }
    return value;
  }

  /// CRIT-3: Reports coverage anomaly to analytics.
  /// Fire-and-forget - analytics failures don't affect coverage validation.
  static void _reportCoverageAnomaly(double invalidValue) {
    try {
      final tracker = ServiceLocator.get<TaggingEventsTracker>();
      tracker.logCoverageAnomaly(invalidValue);
    } catch (_) {
      // Analytics not available - that's fine, we already logged the error
    }
  }

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
      hasCoverageAnomaly: false, // CRIT-2: Explicit normal state
    );
  }

  /// HIGH-12: Creates a TagResult for recipes where ALL ingredients are unknown.
  ///
  /// This is distinct from [empty()] which is for recipes with no ingredients.
  /// UI can check [generatorVersion] to distinguish:
  /// - 'empty' → Recipe has no ingredients (prompt to add)
  /// - 'all_unknown' → Recipe has ingredients but none are recognized
  ///
  /// Example:
  /// ```dart
  /// if (tagResult.generatorVersion == 'all_unknown') {
  ///   showDialog("Help identify: ${tagResult.unknownIngredients}");
  /// }
  /// ```
  factory TagResult.allUnknown(List<String> unknownIngredients) {
    // MED-2: Build error message and truncate if needed
    final errorMsg = unknownIngredients.isEmpty
        ? null
        : 'All ${unknownIngredients.length} ingredients are unknown';
    final truncatedError =
        errorMsg != null && errorMsg.length > kMaxErrorReasonLength
            ? '${errorMsg.substring(0, kMaxErrorReasonLength - 3)}...'
            : errorMsg;
    return TagResult(
      tags: {},
      allergenStatus: {},
      dietaryStatus: {},
      coverage: 0.0, // No known ingredients = 0% coverage
      unknownIngredients: unknownIngredients,
      generatedAt: DateTime.now(),
      generatorVersion: 'all_unknown', // Distinguishes from 'empty'
      hasCoverageAnomaly: false,
      errorReason: truncatedError,
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
      hasCoverageAnomaly: false, // CRIT-2: Explicit normal state
    );
  }

  /// Creates a failed result when tag generation encounters an error.
  /// The reason parameter provides context for debugging.
  ///
  /// MED-2/V2: Now uses dedicated [errorReason] field instead of misusing
  /// [unknownIngredients]. The error is still added to unknownIngredients
  /// for backward compatibility with older UI that reads that field.
  /// Reason is truncated to [kMaxErrorReasonLength] chars to prevent Firestore issues.
  factory TagResult.failed({String? reason}) {
    // MED-2: Truncate reason to prevent Firestore write failures
    final truncatedReason =
        reason != null && reason.length > kMaxErrorReasonLength
            ? '${reason.substring(0, kMaxErrorReasonLength - 3)}...'
            : reason;
    return TagResult(
      tags: {},
      allergenStatus: {},
      dietaryStatus: {},
      coverage: 0.0,
      unknownIngredients:
          truncatedReason != null ? [truncatedReason] : [], // Backward compat
      generatedAt: DateTime.now(),
      generatorVersion: 'failed', // Mark as failed tagging
      errorReason: truncatedReason, // V2: Proper error field (truncated)
      hasCoverageAnomaly: false, // CRIT-2: Explicit normal state
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

    // H7/CRIT-2: Clamp coverage to valid [0.0, 1.0] range and track anomaly
    final rawCoverage = SerializationUtils.safeDouble(migratedData, 'coverage',
        defaultValue: 0.0);
    final hasCoverageAnomaly = rawCoverage < 0.0 || rawCoverage > 1.0;
    final coverage = rawCoverage.clamp(0.0, 1.0);
    if (hasCoverageAnomaly) {
      AppLogger.warning(
        'CRIT-2: Coverage anomaly detected in Firestore data: $rawCoverage',
        'TagResult',
      );
    }

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
      // V2: Read errorReason field
      errorReason:
          SerializationUtils.safeNullableString(migratedData, 'errorReason'),
      // Persist draft ingredient warning across reloads
      hasDraftIngredients: SerializationUtils.safeBool(
          migratedData, 'hasDraftIngredients',
          defaultValue: false),
      // CRIT-2: Track coverage anomaly from stored data
      hasCoverageAnomaly: hasCoverageAnomaly,
    );
  }

  /// Converts to Firestore map (uses Timestamp for dates).
  ///
  /// MED-1: [includeDecisions] optionally includes decision logs in Firestore.
  /// Defaults to false to avoid storage bloat. Set to true for debugging or
  /// auditing failed recipes. Decisions add ~200-500 bytes per recipe.
  Map<String, dynamic> toFirestore({bool includeDecisions = false}) {
    // M15: Sort tags for consistent ordering across all storage
    final sortedTags = tags.toList()..sort();
    final result = <String, dynamic>{
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

    // Persist draft ingredient warning so it survives reload
    result['hasDraftIngredients'] = hasDraftIngredients;

    // V2: Include errorReason if present
    if (errorReason != null) {
      result['errorReason'] = errorReason;
    }

    // MED-1: Optionally include decisions for debugging/auditing
    if (includeDecisions && decisions != null && decisions!.isNotEmpty) {
      result['decisions'] = decisions!.map((d) => d.toJson()).toList();
    }

    return result;
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
      // Persist draft ingredient warning
      'hasDraftIngredients': hasDraftIngredients,
      // V2: Include errorReason if present
      if (errorReason != null) 'errorReason': errorReason,
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
    if (migratedData['generatedAt'] == null) {
      AppLogger.warning(
        'TagResult.fromJson: generatedAt is null, defaulting to now(). '
            'This may indicate corrupted data.',
        'TagResult',
      );
    }

    // H7/CRIT-2: Clamp coverage to valid [0.0, 1.0] range and track anomaly
    final rawCoverage = SerializationUtils.safeDouble(migratedData, 'coverage',
        defaultValue: 0.0);
    final hasCoverageAnomaly = rawCoverage < 0.0 || rawCoverage > 1.0;
    final coverage = rawCoverage.clamp(0.0, 1.0);
    if (hasCoverageAnomaly) {
      AppLogger.warning(
        'CRIT-2: Coverage anomaly detected in JSON data: $rawCoverage',
        'TagResult',
      );
    }

    return TagResult(
      tags: _parseStringSet(migratedData['tags']),
      // M11: Use validated parsing for allergen/dietary status
      allergenStatus: _parseAllergenStatus(migratedData['allergenStatus']),
      dietaryStatus: _parseDietaryStatus(migratedData['dietaryStatus']),
      coverage: coverage,
      unknownIngredients: _parseStringList(migratedData['unknownIngredients']),
      generatedAt: SerializationUtils.parseRequiredDateTimeValue(
          migratedData['generatedAt']),
      generatorVersion: SerializationUtils.safeNullableString(
          migratedData, 'generatorVersion'),
      isPartial: SerializationUtils.safeBool(migratedData, 'isPartial',
          defaultValue: false),
      // H3: Parse decisions if present
      decisions: _parseDecisions(migratedData['decisions']),
      // V2: Read errorReason field
      errorReason:
          SerializationUtils.safeNullableString(migratedData, 'errorReason'),
      // Persist draft ingredient warning across reloads
      hasDraftIngredients: SerializationUtils.safeBool(
          migratedData, 'hasDraftIngredients',
          defaultValue: false),
      // CRIT-2: Track coverage anomaly from stored data
      hasCoverageAnomaly: hasCoverageAnomaly,
    );
  }

  // Schema migration helpers

  /// L12: Migrates data from older schema versions to current version.
  ///
  /// Currently supports:
  /// - V0 → V1: Add schemaVersion field (no data transformation needed)
  /// - V1 → V2: Add errorReason field (extract from unknownIngredients if failed)
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

    // V1 → V2: Extract errorReason from unknownIngredients for failed results
    if (fromVersion < 2) {
      final version = migrated['generatorVersion'];
      if (version == 'failed') {
        // Extract error reason from unknownIngredients (old misuse of the field)
        final unknowns = migrated['unknownIngredients'] as List?;
        if (unknowns != null && unknowns.isNotEmpty) {
          migrated['errorReason'] = unknowns.first.toString();
        }
      }
      migrated['schemaVersion'] = 2;
      AppLogger.debug(
        'TagResult: Migrated from schema v$fromVersion to v2',
        'TagResult',
      );
    }

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

  /// HIGH-5: Valid TriState value strings for validation.
  /// Accepts both lowercase (current) and uppercase (legacy) formats.
  static const _validTriStateValues = {
    'free', 'contains', 'unknown', // Current lowercase format
    'FREE', 'CONTAINS', 'UNKNOWN', // Legacy uppercase format
  };

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
        // LOW-1: Handle null explicitly to avoid "null" string (using null-aware)
        final rawValue = entry.value?.toString();

        // M11: Validate key if validKeys provided
        if (validKeys != null && !validKeys.contains(key)) {
          AppLogger.warning(
            'TagResult: Unknown ${contextName ?? "status"} key "$key", skipping.',
            'TagResult',
          );
          continue;
        }

        // HIGH-5: Validate value is a valid TriState string
        if (rawValue != null && !_validTriStateValues.contains(rawValue)) {
          AppLogger.warning(
            'TagResult: Invalid ${contextName ?? "status"} value "$rawValue" for key "$key", '
                'treating as UNKNOWN. Valid values: $_validTriStateValues',
            'TagResult',
          );
        }

        final triState = TriStateExtension.fromFirestore(rawValue);
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
  /// MED-1: Logs warnings for malformed entries instead of silently skipping.
  static List<TagDecision>? _parseDecisions(dynamic value) {
    if (value == null) return null;
    if (value is List) {
      final result = <TagDecision>[];
      for (var i = 0; i < value.length; i++) {
        final item = value[i];
        if (item is Map<String, dynamic>) {
          try {
            result.add(TagDecision.fromJson(item));
          } catch (e) {
            AppLogger.warning(
              'TagResult: Failed to parse decision at index $i: $e',
              'TagResult',
            );
          }
        } else {
          AppLogger.warning(
            'TagResult: Skipping malformed decision at index $i '
                '(expected Map, got ${item.runtimeType})',
            'TagResult',
          );
        }
      }
      return result.isNotEmpty ? result : null;
    }
    return null;
  }

  // H3: Decision query helpers

  /// H3: Gets the decision that explains a specific allergen status.
  /// MED-1: Returns null if no decision exists for the allergen or if decisions list is null.
  TagDecision? getAllergenDecision(String allergen) => decisions
      ?.where((d) => d.type == 'allergen' && d.key == allergen)
      .firstOrNull;

  /// H3: Gets the decision that explains a specific dietary status.
  /// MED-1: Returns null if no decision exists for the dietary key or if decisions list is null.
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

  /// Returns true if all ingredients were unknown during tagging.
  bool get isAllUnknown => generatorVersion == 'all_unknown';

  /// Returns true if ingredient lookup timed out.
  bool get isLookupTimeout => generatorVersion == 'lookup_timeout';

  /// Checks if this result needs retagging due to version mismatch, failure, pending status,
  /// or coverage anomaly.
  ///
  /// Returns true if:
  /// - Generator version is 'failed' (tagging error)
  /// - Generator version is 'pending' (saved offline, awaiting tagging)
  /// - Generator version differs from current version
  /// - Generator version is null (legacy data)
  /// - Coverage value was out of range (CRIT-2)
  bool get needsRetagging {
    if (generatorVersion == null) return true;
    if (hasFailed) return true;
    if (isPending) return true;
    if (hasCoverageAnomaly) {
      return true; // CRIT-2: Coverage anomaly triggers retagging
    }
    return generatorVersion != kTagGeneratorVersion;
  }

  /// HIGH-6: Equality includes decisions but NOT generatedAt.
  /// generatedAt is metadata about when generated, not what was generated.
  /// decisions are part of the result content and should affect equality.
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
          isPartial == other.isPartial &&
          hasCoverageAnomaly == other.hasCoverageAnomaly && // CRIT-2
          hasDraftIngredients == other.hasDraftIngredients &&
          _decisionsEqual(decisions, other.decisions) &&
          errorReason == other.errorReason;

  static bool _setEquals<T>(Set<T> a, Set<T> b) =>
      a.length == b.length && a.containsAll(b);

  static bool _mapEquals<K, V>(Map<K, V> a, Map<K, V> b) =>
      a.length == b.length && a.entries.every((e) => b[e.key] == e.value);

  static bool _listEquals<T>(List<T> a, List<T> b) =>
      a.length == b.length &&
      a.asMap().entries.every((e) => b[e.key] == e.value);

  /// HIGH-6: Compare decisions lists, treating null as empty.
  static bool _decisionsEqual(List<TagDecision>? a, List<TagDecision>? b) {
    final listA = a ?? [];
    final listB = b ?? [];
    if (listA.length != listB.length) return false;
    for (var i = 0; i < listA.length; i++) {
      if (listA[i] != listB[i]) return false;
    }
    return true;
  }

  /// HIGH-6: hashCode includes decisions, errorReason, and hasCoverageAnomaly (consistent with equality).
  @override
  int get hashCode => Object.hash(
        tags,
        allergenStatus,
        dietaryStatus,
        coverage,
        Object.hashAll(unknownIngredients),
        generatorVersion,
        isPartial,
        hasCoverageAnomaly, // CRIT-2
        hasDraftIngredients,
        decisions != null ? Object.hashAll(decisions!) : null,
        errorReason,
      );

  /// LOW-3: Uses coveragePercent for consistent rounding across the codebase.
  @override
  String toString() =>
      'TagResult(${tags.length} tags, coverage: $coveragePercent%)';

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
    String? errorReason,
    bool? hasCoverageAnomaly,
    bool? hasDraftIngredients,
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
      errorReason: errorReason ?? this.errorReason,
      hasCoverageAnomaly: hasCoverageAnomaly ?? this.hasCoverageAnomaly,
      hasDraftIngredients: hasDraftIngredients ?? this.hasDraftIngredients,
    );
  }

  /// Merges tags from another TagResult (used for combining phases).
  TagResult mergeTags(Set<String> additionalTags) {
    return copyWith(tags: {...tags, ...additionalTags});
  }
}
