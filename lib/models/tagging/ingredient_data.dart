import 'dart:developer' as developer;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart' show immutable;

import 'package:butlery/core/utils/serialization_utils.dart';

/// Represents an ingredient with its properties and group classification.
///
/// Used by the tagging system to determine allergens, dietary status,
/// and identity tags for recipes.
///
/// ## CRIT-1: ID Immutability Contract
///
/// **CRITICAL**: The [id] field is the canonical identifier and MUST be:
/// - **Globally unique**: No two ingredients may share the same ID
/// - **Immutable**: Once assigned, an ID must NEVER change
/// - **Stable**: The same ingredient always has the same ID across systems
///
/// This class uses ID-only equality (see [operator ==]), which means:
/// - Two [IngredientData] objects with the same [id] are considered equal
/// - This enables efficient Set/Map operations and caching
/// - If IDs were mutable, cache corruption and silent data loss would occur
///
/// If you need to compare all fields (e.g., for sync or cache invalidation),
/// use [contentEquals] instead.
///
/// ### Why ID-Only Equality?
///
/// The tagging system relies on this contract for:
/// 1. **LRU Cache**: Uses ID as cache key; ID change = cache corruption
/// 2. **Deduplication**: Sets use ID equality; ID change = duplicates
/// 3. **Cascade Retagging**: TypeScript uses ID to find affected recipes
///
/// ### Breaking This Contract
///
/// If an ingredient ID changes:
/// - All cached lookups for the old ID become stale
/// - Recipes using the old ID won't get retagged
/// - Allergen safety data may become incorrect
///
/// See: docs/tagging/tagging_system.md
@immutable
class IngredientData {
  /// Unique identifier (kebab-case, e.g., 'chicken-breast').
  final String id;

  /// Swedish name (e.g., 'kycklingbröst').
  final String swedish;

  /// English name (e.g., 'chicken breast').
  final String english;

  /// Hierarchical group path (e.g., 'protein/meat/poultry').
  final String group;

  /// Properties this ingredient has (e.g., {'meat', 'poultry', 'animal-product'}).
  final Set<String> properties;

  /// Alternative Swedish names for matching.
  final List<String> aliasesSv;

  /// Alternative English names for matching.
  final List<String> aliasesEn;

  /// Search terms for fuzzy matching.
  final List<String> searchTerms;

  /// Status: 'verified', 'draft', 'needs-review', 'user-defined'.
  final String status;

  /// When this ingredient was created.
  final DateTime? createdAt;

  /// When this ingredient was last updated.
  final DateTime? updatedAt;

  // --- New fields for sustainability and metadata (Sprint 1) ---

  /// Seasons when this ingredient is available (vår, sommar, höst, vinter).
  /// Empty list means year-round or unknown.
  final List<String> seasonAvailability;

  /// Price category: budget, medium, or premium.
  final String? priceCategory;

  /// Carbon footprint category: low, medium, or high.
  final String? carbonFootprintCategory;

  /// Swedish description/notes about this ingredient.
  final String? notesSv;

  /// English description/notes about this ingredient.
  final String? notesEn;

  /// Typical storage method: refrigerated, frozen, or ambient.
  final String? typicalStorage;

  /// Typical unit of measurement: g, ml, st, bag, etc.
  final String? typicalUnit;

  /// Average price in SEK.
  final double? avgPriceSek;

  /// Whether this ingredient is a compound name that should NOT be split
  /// during normalization (e.g., "vitpeppar", "rödlök").
  final bool isCompoundName;

  const IngredientData({
    required this.id,
    required this.swedish,
    required this.english,
    required this.group,
    required this.properties,
    this.aliasesSv = const [],
    this.aliasesEn = const [],
    this.searchTerms = const [],
    this.status = 'verified',
    this.createdAt,
    this.updatedAt,
    // New sustainability and metadata fields
    this.seasonAvailability = const [],
    this.priceCategory,
    this.carbonFootprintCategory,
    this.notesSv,
    this.notesEn,
    this.typicalStorage,
    this.typicalUnit,
    this.avgPriceSek,
    this.isCompoundName = false,
  });

  /// Creates from Firestore document.
  factory IngredientData.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return IngredientData.fromMap(data, doc.id);
  }

  /// Creates from map data with optional ID override.
  ///
  /// Supports both camelCase (current) and snake_case (legacy) field names.
  /// Legacy fields are logged for migration tracking.
  factory IngredientData.fromMap(Map<String, dynamic> data, [String? id]) {
    // Log legacy field usage for migration tracking
    _checkLegacyFields(data);

    return IngredientData(
      id: id ?? SerializationUtils.safeString(data, 'id'),
      swedish: SerializationUtils.safeString(data, 'swedish'),
      english: SerializationUtils.safeString(data, 'english'),
      group: SerializationUtils.safeString(data, 'group'),
      properties: _parseProperties(data['properties'] ?? data['props']),
      aliasesSv: _parseStringList(data['aliasesSv'] ?? data['aliases_sv']),
      aliasesEn: _parseStringList(data['aliasesEn'] ?? data['aliases_en']),
      searchTerms:
          _parseStringList(data['searchTerms'] ?? data['search_terms']),
      status: SerializationUtils.safeString(data, 'status',
          defaultValue: 'verified'),
      createdAt: SerializationUtils.safeDateTime(data, 'createdAt') ??
          SerializationUtils.safeDateTime(data, 'created_at'),
      updatedAt: SerializationUtils.safeDateTime(data, 'updatedAt') ??
          SerializationUtils.safeDateTime(data, 'updated_at'),
      // New sustainability and metadata fields
      seasonAvailability: SerializationUtils.safeStringList(
        data,
        'seasonAvailability',
        defaultValue: const [],
      ),
      priceCategory:
          SerializationUtils.safeNullableString(data, 'priceCategory'),
      carbonFootprintCategory: SerializationUtils.safeNullableString(
          data, 'carbonFootprintCategory'),
      notesSv: SerializationUtils.safeNullableString(data, 'notesSv'),
      notesEn: SerializationUtils.safeNullableString(data, 'notesEn'),
      typicalStorage:
          SerializationUtils.safeNullableString(data, 'typicalStorage'),
      typicalUnit: SerializationUtils.safeNullableString(data, 'typicalUnit'),
      avgPriceSek: SerializationUtils.safeNullableDouble(data, 'avgPriceSek'),
      isCompoundName: SerializationUtils.safeBool(data, 'isCompoundName'),
    );
  }

  /// Checks for legacy field names and logs migration opportunities.
  static void _checkLegacyFields(Map<String, dynamic> data) {
    final legacyFields = <String>[];

    // Check for snake_case fields that should be migrated to camelCase
    if (data.containsKey('aliases_sv') && !data.containsKey('aliasesSv')) {
      legacyFields.add('aliases_sv');
    }
    if (data.containsKey('aliases_en') && !data.containsKey('aliasesEn')) {
      legacyFields.add('aliases_en');
    }
    if (data.containsKey('search_terms') && !data.containsKey('searchTerms')) {
      legacyFields.add('search_terms');
    }
    if (data.containsKey('created_at') && !data.containsKey('createdAt')) {
      legacyFields.add('created_at');
    }
    if (data.containsKey('updated_at') && !data.containsKey('updatedAt')) {
      legacyFields.add('updated_at');
    }
    if (data.containsKey('props') && !data.containsKey('properties')) {
      legacyFields.add('props');
    }

    if (legacyFields.isNotEmpty) {
      developer.log(
        'Legacy ingredient fields found for "${data['swedish'] ?? data['id']}": '
        '${legacyFields.join(", ")}',
        name: 'IngredientData',
      );
    }
  }

  /// Parses properties from various formats (comma-separated string or list).
  static Set<String> _parseProperties(dynamic value) {
    if (value == null) return {};
    if (value is List) {
      return value
          .map((e) => e.toString().trim())
          .where((e) => e.isNotEmpty)
          .toSet();
    }
    if (value is String) {
      return value
          .split(',')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toSet();
    }
    return {};
  }

  /// Parses string list from various formats.
  static List<String> _parseStringList(dynamic value) {
    if (value == null) return [];
    if (value is List) {
      return value
          .map((e) => e.toString().trim())
          .where((e) => e.isNotEmpty)
          .toList();
    }
    if (value is String) {
      return value
          .split(';')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();
    }
    return [];
  }

  /// Converts to Firestore map.
  Map<String, dynamic> toFirestore() {
    return {
      'id': id,
      'swedish': swedish,
      'english': english,
      'group': group,
      'properties': properties.toList(),
      'aliasesSv': aliasesSv,
      'aliasesEn': aliasesEn,
      'searchTerms': searchTerms,
      'status': status,
      if (createdAt != null) 'createdAt': Timestamp.fromDate(createdAt!),
      if (updatedAt != null) 'updatedAt': Timestamp.fromDate(updatedAt!),
      // New sustainability and metadata fields
      if (seasonAvailability.isNotEmpty)
        'seasonAvailability': seasonAvailability,
      if (priceCategory != null) 'priceCategory': priceCategory,
      if (carbonFootprintCategory != null)
        'carbonFootprintCategory': carbonFootprintCategory,
      if (notesSv != null) 'notesSv': notesSv,
      if (notesEn != null) 'notesEn': notesEn,
      if (typicalStorage != null) 'typicalStorage': typicalStorage,
      if (typicalUnit != null) 'typicalUnit': typicalUnit,
      if (avgPriceSek != null) 'avgPriceSek': avgPriceSek,
      'isCompoundName': isCompoundName,
    };
  }

  // Group hierarchy helpers

  /// Gets the top-level group (e.g., 'protein' from 'protein/meat/poultry').
  String get topLevelGroup => group.split('/').first;

  /// Gets the mid-level group (e.g., 'meat' from 'protein/meat/poultry').
  String? get midLevelGroup {
    final parts = group.split('/');
    return parts.length > 1 ? parts[1] : null;
  }

  /// Gets the leaf group (e.g., 'poultry' from 'protein/meat/poultry').
  String? get leafGroup {
    final parts = group.split('/');
    return parts.length > 2 ? parts[2] : null;
  }

  /// Gets the group depth (1-3).
  int get groupDepth => group.split('/').length;

  /// Checks if this ingredient belongs to a group or its children.
  bool isInGroup(String groupPath) {
    return group == groupPath || group.startsWith('$groupPath/');
  }

  // Property helpers

  /// Checks if ingredient has a specific property.
  bool hasProperty(String property) => properties.contains(property);

  /// Checks if ingredient has any of the given properties.
  bool hasAnyProperty(Iterable<String> props) =>
      props.any((p) => properties.contains(p));

  /// Checks if ingredient has all of the given properties.
  bool hasAllProperties(Iterable<String> props) =>
      props.every((p) => properties.contains(p));

  // Common property checks

  /// True if this is an animal product (meat, dairy, eggs, etc.).
  bool get isAnimalProduct => hasProperty('animal-product');

  /// True if this is vegan-friendly.
  bool get isVeganFriendly => hasProperty('vegan-friendly');

  /// True if this is plant-based.
  bool get isPlantBased => hasProperty('plant-based');

  /// True if this contains gluten.
  bool get containsGluten => hasProperty('contains-gluten');

  /// True if this contains lactose.
  bool get containsLactose => hasProperty('contains-lactose');

  /// True if this is spicy.
  bool get isSpicy => hasProperty('is-spicy');

  /// True if this needs cooking.
  bool get needsCooking => hasProperty('needs-cooking');

  /// True if this doesn't freeze well.
  bool get doesntFreezeWell => hasProperty('doesnt-freeze-well');

  // Matching helpers

  /// Gets all names for matching (Swedish, English, all aliases).
  List<String> get allNames => [
        swedish,
        english,
        ...aliasesSv,
        ...aliasesEn,
        ...searchTerms,
      ];

  /// Gets all names normalized for matching (lowercase, trimmed).
  List<String> get allNamesNormalized =>
      allNames.map((n) => n.toLowerCase().trim()).toList();

  /// Checks if any name matches the given query (case-insensitive).
  bool matchesName(String query) {
    final normalizedQuery = query.toLowerCase().trim();
    return allNamesNormalized.any((n) => n == normalizedQuery);
  }

  /// Checks if any name contains the given query (case-insensitive).
  bool containsName(String query) {
    final normalizedQuery = query.toLowerCase().trim();
    return allNamesNormalized.any((n) => n.contains(normalizedQuery));
  }

  /// CRIT-1: Equality based on [id] only, following the domain model where:
  /// - Each ingredient has a globally unique ID
  /// - The ID is the canonical identifier for the ingredient
  /// - Two IngredientData objects with the same ID represent the same ingredient
  ///
  /// This design enables:
  /// - Efficient Set/Map operations for deduplication
  /// - Cache-friendly comparisons
  /// - Consistent behavior in lookups (same ID = same ingredient)
  ///
  /// IMPORTANT: This assumes IDs are immutable and globally unique.
  /// If you need to compare all fields (e.g., for sync/cache invalidation),
  /// use [contentEquals] instead.
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is IngredientData &&
          runtimeType == other.runtimeType &&
          id == other.id;

  /// CRIT-1: HashCode contract - consistent with ID-only equality.
  @override
  int get hashCode => id.hashCode;

  /// CRIT-1: Compares all fields for content equality.
  ///
  /// Use this when you need to detect changes to ingredient data,
  /// such as in cache invalidation, sync operations, or testing.
  ///
  /// Returns true if all fields are equal, false otherwise.
  bool contentEquals(IngredientData other) {
    if (id != other.id) return false;
    if (swedish != other.swedish) return false;
    if (english != other.english) return false;
    if (group != other.group) return false;
    if (status != other.status) return false;

    // Compare collections
    if (!_setEquals(properties, other.properties)) return false;
    if (!_listEquals(aliasesSv, other.aliasesSv)) return false;
    if (!_listEquals(aliasesEn, other.aliasesEn)) return false;
    if (!_listEquals(searchTerms, other.searchTerms)) return false;

    // DateTime comparison (both null or both equal)
    if (createdAt != other.createdAt) return false;
    if (updatedAt != other.updatedAt) return false;

    // New sustainability and metadata fields
    if (!_listEquals(seasonAvailability, other.seasonAvailability)) {
      return false;
    }
    if (priceCategory != other.priceCategory) return false;
    if (carbonFootprintCategory != other.carbonFootprintCategory) return false;
    if (notesSv != other.notesSv) return false;
    if (notesEn != other.notesEn) return false;
    if (typicalStorage != other.typicalStorage) return false;
    if (typicalUnit != other.typicalUnit) return false;
    if (avgPriceSek != other.avgPriceSek) return false;
    if (isCompoundName != other.isCompoundName) return false;

    return true;
  }

  /// CRIT-1: Helper for Set equality comparison.
  static bool _setEquals<T>(Set<T> a, Set<T> b) {
    if (a.length != b.length) return false;
    return a.containsAll(b);
  }

  /// CRIT-1: Helper for List equality comparison (order-sensitive).
  static bool _listEquals<T>(List<T> a, List<T> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  @override
  String toString() => 'IngredientData($id: $swedish)';

  /// Creates a copy with optional field overrides.
  IngredientData copyWith({
    String? id,
    String? swedish,
    String? english,
    String? group,
    Set<String>? properties,
    List<String>? aliasesSv,
    List<String>? aliasesEn,
    List<String>? searchTerms,
    String? status,
    DateTime? createdAt,
    DateTime? updatedAt,
    // New sustainability and metadata fields
    List<String>? seasonAvailability,
    String? priceCategory,
    String? carbonFootprintCategory,
    String? notesSv,
    String? notesEn,
    String? typicalStorage,
    String? typicalUnit,
    double? avgPriceSek,
    bool? isCompoundName,
  }) {
    return IngredientData(
      id: id ?? this.id,
      swedish: swedish ?? this.swedish,
      english: english ?? this.english,
      group: group ?? this.group,
      properties: properties ?? this.properties,
      aliasesSv: aliasesSv ?? this.aliasesSv,
      aliasesEn: aliasesEn ?? this.aliasesEn,
      searchTerms: searchTerms ?? this.searchTerms,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      seasonAvailability: seasonAvailability ?? this.seasonAvailability,
      priceCategory: priceCategory ?? this.priceCategory,
      carbonFootprintCategory:
          carbonFootprintCategory ?? this.carbonFootprintCategory,
      notesSv: notesSv ?? this.notesSv,
      notesEn: notesEn ?? this.notesEn,
      typicalStorage: typicalStorage ?? this.typicalStorage,
      typicalUnit: typicalUnit ?? this.typicalUnit,
      avgPriceSek: avgPriceSek ?? this.avgPriceSek,
      isCompoundName: isCompoundName ?? this.isCompoundName,
    );
  }
}
