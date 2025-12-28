import 'dart:developer' as developer;

import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:butlery/core/utils/serialization_utils.dart';

/// Represents an ingredient with its properties and group classification.
///
/// Used by the tagging system to determine allergens, dietary status,
/// and identity tags for recipes.
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

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is IngredientData &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;

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
    );
  }
}
