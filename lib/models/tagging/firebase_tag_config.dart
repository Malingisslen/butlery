/// Firebase-backed tag configuration models.
///
/// These models represent the tag configs loaded from Firebase,
/// replacing the hardcoded Dart configs for admin editability.
library;

import 'package:clock/clock.dart';
import 'package:butlery/core/utils/serialization_utils.dart';
import 'package:butlery/core/extensions/default_value_extensions.dart';

/// Complete tag configuration loaded from Firebase.
class FirebaseTagConfig {
  final AllergenConfigDocument allergens;
  final DietaryConfigDocument dietary;
  final CuisineConfigDocument cuisines;
  final PropertiesConfigDocument properties;
  final DisplayConfigDocument display;

  /// Combined version from all documents.
  final int combinedVersion;

  /// When this config was fetched.
  final DateTime fetchedAt;

  const FirebaseTagConfig({
    required this.allergens,
    required this.dietary,
    required this.cuisines,
    required this.properties,
    required this.display,
    required this.combinedVersion,
    required this.fetchedAt,
  });

  /// Creates a config from individual document data.
  factory FirebaseTagConfig.fromDocuments({
    required Map<String, dynamic> allergensData,
    required Map<String, dynamic> dietaryData,
    required Map<String, dynamic> cuisinesData,
    required Map<String, dynamic> propertiesData,
    required Map<String, dynamic> displayData,
  }) {
    final allergens = AllergenConfigDocument.fromMap(allergensData);
    final dietary = DietaryConfigDocument.fromMap(dietaryData);
    final cuisines = CuisineConfigDocument.fromMap(cuisinesData);
    final properties = PropertiesConfigDocument.fromMap(propertiesData);
    final display = DisplayConfigDocument.fromMap(displayData);

    // Positional encoding avoids both sum collisions and Object.hash
    // non-determinism across VM restarts (important: persisted to SharedPreferences)
    return FirebaseTagConfig(
      allergens: allergens,
      dietary: dietary,
      cuisines: cuisines,
      properties: properties,
      display: display,
      combinedVersion: combineVersions(
        allergens.version,
        dietary.version,
        cuisines.version,
        properties.version,
        display.version,
      ),
      fetchedAt: clock.now(),
    );
  }

  /// Deterministic version combining — stable across VM restarts.
  /// Uses prime multiplication to avoid collisions (e.g. [3,4] vs [4,3]).
  static int combineVersions(int a, int b, int c, int d, int e) {
    return a * 1000003 ^ b * 999983 ^ c * 999979 ^ d * 999961 ^ e * 999931;
  }

  /// Validates that all properties referenced in configs exist.
  List<String> validate() {
    final errors = <String>[];
    final validProps = properties.validProperties;

    // Validate allergen trigger properties
    for (final allergen in allergens.entries) {
      for (final prop in allergen.triggerProperties) {
        if (!validProps.contains(prop)) {
          errors.add(
            'Allergen "${allergen.key}": unknown property "$prop"',
          );
        }
      }
    }

    // Validate dietary properties
    for (final diet in dietary.entries) {
      for (final prop in diet.excludedProperties) {
        if (!validProps.contains(prop)) {
          errors.add(
            'Dietary "${diet.key}": unknown excluded property "$prop"',
          );
        }
      }
      for (final prop in diet.requiredProperties) {
        if (!validProps.contains(prop)) {
          errors.add(
            'Dietary "${diet.key}": unknown required property "$prop"',
          );
        }
      }
    }

    return errors;
  }
}

/// Base document structure for all config types.
abstract class BaseConfigDocument {
  final int schemaVersion;
  final int version;
  final DateTime updatedAt;
  final String updatedBy;

  const BaseConfigDocument({
    required this.schemaVersion,
    required this.version,
    required this.updatedAt,
    required this.updatedBy,
  });
}

/// Allergen configuration document from Firebase.
class AllergenConfigDocument extends BaseConfigDocument {
  final List<String> displayOrder;
  final List<FirebaseAllergenEntry> entries;

  const AllergenConfigDocument({
    required super.schemaVersion,
    required super.version,
    required super.updatedAt,
    required super.updatedBy,
    required this.displayOrder,
    required this.entries,
  });

  factory AllergenConfigDocument.fromMap(Map<String, dynamic> data) {
    return AllergenConfigDocument(
      schemaVersion: SerializationUtils.safeInt(data, 'schemaVersion'),
      version: SerializationUtils.safeInt(data, 'version'),
      updatedAt: SerializationUtils.safeRequiredDateTime(
        data,
        'updatedAt',
        defaultValue: clock.now(),
      ),
      updatedBy: SerializationUtils.safeString(data, 'updatedBy'),
      displayOrder: SerializationUtils.safeStringList(data, 'displayOrder'),
      entries: _parseAllergenEntries(data['entries']),
    );
  }

  static List<FirebaseAllergenEntry> _parseAllergenEntries(dynamic value) {
    if (value == null || value is! List) return [];
    return value
        .whereType<Map<String, dynamic>>()
        .map(FirebaseAllergenEntry.fromMap)
        .toList();
  }

  /// Gets an allergen by key.
  FirebaseAllergenEntry? getByKey(String key) {
    try {
      return entries.firstWhere((e) => e.key == key);
    } catch (_) {
      return null;
    }
  }

  /// Gets enabled allergens in display order.
  List<FirebaseAllergenEntry> get enabledEntries => displayOrder
      .map((key) => getByKey(key))
      .whereType<FirebaseAllergenEntry>()
      .where((e) => e.enabled)
      .toList();

  /// Gets all single-property allergens (not combined).
  List<FirebaseAllergenEntry> get simpleAllergens =>
      enabledEntries.where((e) => !e.isCombined).toList();

  /// Gets all combined allergens (multiple trigger properties).
  List<FirebaseAllergenEntry> get combinedAllergens =>
      enabledEntries.where((e) => e.isCombined).toList();

  /// Gets all EU allergens.
  List<FirebaseAllergenEntry> get euAllergens =>
      enabledEntries.where((e) => e.isEuAllergen).toList();
}

/// Single allergen entry from Firebase config.
class FirebaseAllergenEntry {
  final String key;
  final List<String> triggerProperties;
  final Map<String, AllergenTags> tags;
  final bool isEuAllergen;
  final String? uiGroup;
  final Map<String, String> description;
  final bool enabled;
  final int priority;

  const FirebaseAllergenEntry({
    required this.key,
    required this.triggerProperties,
    required this.tags,
    required this.isEuAllergen,
    this.uiGroup,
    required this.description,
    required this.enabled,
    required this.priority,
  });

  factory FirebaseAllergenEntry.fromMap(Map<String, dynamic> data) {
    return FirebaseAllergenEntry(
      key: SerializationUtils.safeString(data, 'key'),
      triggerProperties:
          SerializationUtils.safeStringList(data, 'triggerProperties'),
      tags: _parseTags(data['tags']),
      isEuAllergen: SerializationUtils.safeBool(data, 'isEuAllergen'),
      uiGroup: SerializationUtils.safeNullableString(data, 'uiGroup'),
      description: _parseStringMap(data['description']),
      enabled: SerializationUtils.safeBool(data, 'enabled', defaultValue: true),
      priority: SerializationUtils.safeInt(data, 'priority'),
    );
  }

  static Map<String, AllergenTags> _parseTags(dynamic value) {
    if (value == null || value is! Map) return {};
    final result = <String, AllergenTags>{};
    for (final entry in value.entries) {
      if (entry.value is Map<String, dynamic>) {
        result[entry.key.toString()] = AllergenTags.fromMap(
          entry.value as Map<String, dynamic>,
        );
      }
    }
    return result;
  }

  static Map<String, String> _parseStringMap(dynamic value) {
    if (value == null || value is! Map) return {};
    return Map<String, String>.from(
      value.map((k, v) => MapEntry(k.toString(), (v?.toString()).orEmpty())),
    );
  }

  /// Gets the contains tag for a locale.
  String getContainsTag(String locale) =>
      tags[locale]?.contains ?? tags['sv']?.contains ?? 'unknown';

  /// Gets the free tag for a locale.
  String? getFreeTag(String locale) => tags[locale]?.free ?? tags['sv']?.free;

  /// Whether this allergen combines multiple properties (OR logic).
  bool get isCombined => triggerProperties.length > 1;
}

/// Allergen tags for a specific locale.
class AllergenTags {
  final String contains;
  final String? free;

  const AllergenTags({required this.contains, this.free});

  factory AllergenTags.fromMap(Map<String, dynamic> data) {
    return AllergenTags(
      contains: SerializationUtils.safeString(data, 'contains'),
      free: SerializationUtils.safeNullableString(data, 'free'),
    );
  }
}

/// Dietary configuration document from Firebase.
class DietaryConfigDocument extends BaseConfigDocument {
  final List<String> displayOrder;
  final List<FirebaseDietaryEntry> entries;

  const DietaryConfigDocument({
    required super.schemaVersion,
    required super.version,
    required super.updatedAt,
    required super.updatedBy,
    required this.displayOrder,
    required this.entries,
  });

  factory DietaryConfigDocument.fromMap(Map<String, dynamic> data) {
    return DietaryConfigDocument(
      schemaVersion: SerializationUtils.safeInt(data, 'schemaVersion'),
      version: SerializationUtils.safeInt(data, 'version'),
      updatedAt: SerializationUtils.safeRequiredDateTime(
        data,
        'updatedAt',
        defaultValue: clock.now(),
      ),
      updatedBy: SerializationUtils.safeString(data, 'updatedBy'),
      displayOrder: SerializationUtils.safeStringList(data, 'displayOrder'),
      entries: _parseDietaryEntries(data['entries']),
    );
  }

  static List<FirebaseDietaryEntry> _parseDietaryEntries(dynamic value) {
    if (value == null || value is! List) return [];
    return value
        .whereType<Map<String, dynamic>>()
        .map(FirebaseDietaryEntry.fromMap)
        .toList();
  }

  /// Gets a dietary entry by key.
  FirebaseDietaryEntry? getByKey(String key) {
    try {
      return entries.firstWhere((e) => e.key == key);
    } catch (_) {
      return null;
    }
  }

  /// Gets enabled dietary entries in display order.
  List<FirebaseDietaryEntry> get enabledEntries => displayOrder
      .map((key) => getByKey(key))
      .whereType<FirebaseDietaryEntry>()
      .where((e) => e.enabled)
      .toList();
}

/// Single dietary entry from Firebase config.
class FirebaseDietaryEntry {
  final String key;
  final Map<String, String> tags;
  final List<String> excludedProperties;
  final List<String> requiredProperties;
  final bool requiresFullCoverage;
  final Map<String, String> description;
  final bool enabled;
  final int priority;

  const FirebaseDietaryEntry({
    required this.key,
    required this.tags,
    required this.excludedProperties,
    required this.requiredProperties,
    required this.requiresFullCoverage,
    required this.description,
    required this.enabled,
    required this.priority,
  });

  factory FirebaseDietaryEntry.fromMap(Map<String, dynamic> data) {
    return FirebaseDietaryEntry(
      key: SerializationUtils.safeString(data, 'key'),
      tags: _parseStringMap(data['tags']),
      excludedProperties:
          SerializationUtils.safeStringList(data, 'excludedProperties'),
      requiredProperties:
          SerializationUtils.safeStringList(data, 'requiredProperties'),
      requiresFullCoverage: SerializationUtils.safeBool(
        data,
        'requiresFullCoverage',
        defaultValue: true,
      ),
      description: _parseStringMap(data['description']),
      enabled: SerializationUtils.safeBool(data, 'enabled', defaultValue: true),
      priority: SerializationUtils.safeInt(data, 'priority'),
    );
  }

  static Map<String, String> _parseStringMap(dynamic value) {
    if (value == null || value is! Map) return {};
    return Map<String, String>.from(
      value.map((k, v) => MapEntry(k.toString(), (v?.toString()).orEmpty())),
    );
  }

  /// Gets the tag for a locale.
  String getTag(String locale) => tags[locale] ?? tags['sv'] ?? key;
}

/// Cuisine configuration document from Firebase.
class CuisineConfigDocument extends BaseConfigDocument {
  final List<String> displayOrder;
  final List<CuisineEntry> entries;

  const CuisineConfigDocument({
    required super.schemaVersion,
    required super.version,
    required super.updatedAt,
    required super.updatedBy,
    required this.displayOrder,
    required this.entries,
  });

  factory CuisineConfigDocument.fromMap(Map<String, dynamic> data) {
    return CuisineConfigDocument(
      schemaVersion: SerializationUtils.safeInt(data, 'schemaVersion'),
      version: SerializationUtils.safeInt(data, 'version'),
      updatedAt: SerializationUtils.safeRequiredDateTime(
        data,
        'updatedAt',
        defaultValue: clock.now(),
      ),
      updatedBy: SerializationUtils.safeString(data, 'updatedBy'),
      displayOrder: SerializationUtils.safeStringList(data, 'displayOrder'),
      entries: _parseCuisineEntries(data['entries']),
    );
  }

  static List<CuisineEntry> _parseCuisineEntries(dynamic value) {
    if (value == null || value is! List) return [];
    return value
        .whereType<Map<String, dynamic>>()
        .map(CuisineEntry.fromMap)
        .toList();
  }

  /// Gets a cuisine entry by key.
  CuisineEntry? getByKey(String key) {
    try {
      return entries.firstWhere((e) => e.key == key);
    } catch (_) {
      return null;
    }
  }

  /// Gets enabled cuisine entries in display order.
  List<CuisineEntry> get enabledEntries => displayOrder
      .map((key) => getByKey(key))
      .whereType<CuisineEntry>()
      .where((e) => e.enabled)
      .toList();
}

/// Cuisine match mode options.
enum CuisineMatchMode {
  titleOrIngredients,
  titleAndIngredients,
  titleOnly,
  ingredientsOnly;

  static CuisineMatchMode fromString(String value) {
    return switch (value) {
      'title_or_ingredients' => CuisineMatchMode.titleOrIngredients,
      'title_and_ingredients' => CuisineMatchMode.titleAndIngredients,
      'title_only' => CuisineMatchMode.titleOnly,
      'ingredients_only' => CuisineMatchMode.ingredientsOnly,
      _ => CuisineMatchMode.titleOrIngredients,
    };
  }
}

/// Single cuisine entry from Firebase config.
class CuisineEntry {
  final String key;
  final Map<String, String> tags;
  final List<String> titleKeywords;
  final List<String> ingredientKeywords;
  final List<String> ingredientGroups;
  final int minIngredientMatches;
  final CuisineMatchMode matchMode;
  final bool enabled;
  final int priority;

  const CuisineEntry({
    required this.key,
    required this.tags,
    required this.titleKeywords,
    required this.ingredientKeywords,
    required this.ingredientGroups,
    required this.minIngredientMatches,
    required this.matchMode,
    required this.enabled,
    required this.priority,
  });

  factory CuisineEntry.fromMap(Map<String, dynamic> data) {
    return CuisineEntry(
      key: SerializationUtils.safeString(data, 'key'),
      tags: _parseStringMap(data['tags']),
      titleKeywords: SerializationUtils.safeStringList(data, 'titleKeywords'),
      ingredientKeywords:
          SerializationUtils.safeStringList(data, 'ingredientKeywords'),
      ingredientGroups:
          SerializationUtils.safeStringList(data, 'ingredientGroups'),
      minIngredientMatches: SerializationUtils.safeInt(
        data,
        'minIngredientMatches',
        defaultValue: 2,
      ),
      matchMode: CuisineMatchMode.fromString(
        SerializationUtils.safeString(
          data,
          'matchMode',
          defaultValue: 'title_or_ingredients',
        ),
      ),
      enabled: SerializationUtils.safeBool(data, 'enabled', defaultValue: true),
      priority: SerializationUtils.safeInt(data, 'priority'),
    );
  }

  static Map<String, String> _parseStringMap(dynamic value) {
    if (value == null || value is! Map) return {};
    return Map<String, String>.from(
      value.map((k, v) => MapEntry(k.toString(), (v?.toString()).orEmpty())),
    );
  }

  /// Gets the tag for a locale.
  String getTag(String locale) => tags[locale] ?? tags['sv'] ?? key;
}

/// Properties configuration document from Firebase.
class PropertiesConfigDocument extends BaseConfigDocument {
  final Set<String> validProperties;

  const PropertiesConfigDocument({
    required super.schemaVersion,
    required super.version,
    required super.updatedAt,
    required super.updatedBy,
    required this.validProperties,
  });

  factory PropertiesConfigDocument.fromMap(Map<String, dynamic> data) {
    return PropertiesConfigDocument(
      schemaVersion: SerializationUtils.safeInt(data, 'schemaVersion'),
      version: SerializationUtils.safeInt(data, 'version'),
      updatedAt: SerializationUtils.safeRequiredDateTime(
        data,
        'updatedAt',
        defaultValue: clock.now(),
      ),
      updatedBy: SerializationUtils.safeString(data, 'updatedBy'),
      validProperties:
          SerializationUtils.safeStringList(data, 'validProperties').toSet(),
    );
  }

  /// Checks if a property is valid.
  bool isValid(String property) => validProperties.contains(property);
}

/// Display configuration document from Firebase.
class DisplayConfigDocument extends BaseConfigDocument {
  final List<String> categoryOrder;
  final Map<String, Map<String, String>> uiGroupNames;

  const DisplayConfigDocument({
    required super.schemaVersion,
    required super.version,
    required super.updatedAt,
    required super.updatedBy,
    required this.categoryOrder,
    required this.uiGroupNames,
  });

  factory DisplayConfigDocument.fromMap(Map<String, dynamic> data) {
    return DisplayConfigDocument(
      schemaVersion: SerializationUtils.safeInt(data, 'schemaVersion'),
      version: SerializationUtils.safeInt(data, 'version'),
      updatedAt: SerializationUtils.safeRequiredDateTime(
        data,
        'updatedAt',
        defaultValue: clock.now(),
      ),
      updatedBy: SerializationUtils.safeString(data, 'updatedBy'),
      categoryOrder: SerializationUtils.safeStringList(data, 'categoryOrder'),
      uiGroupNames: _parseUiGroupNames(data['uiGroupNames']),
    );
  }

  static Map<String, Map<String, String>> _parseUiGroupNames(dynamic value) {
    if (value == null || value is! Map) return {};
    final result = <String, Map<String, String>>{};
    for (final entry in value.entries) {
      if (entry.value is Map) {
        result[entry.key.toString()] = Map<String, String>.from(
          (entry.value as Map).map(
            (k, v) => MapEntry(k.toString(), (v?.toString()).orEmpty()),
          ),
        );
      }
    }
    return result;
  }

  /// Gets UI group name for a locale.
  String getGroupName(String group, String locale) {
    return uiGroupNames[locale]?[group] ?? uiGroupNames['sv']?[group] ?? group;
  }
}
