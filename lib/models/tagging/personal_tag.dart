import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import 'package:butlery/core/utils/serialization_utils.dart';
import 'package:butlery/models/tagging/personal_tag_rule.dart';
import 'package:butlery/services/tagging/config/reserved_tags.dart';

/// A user-defined personal tag for custom recipe categorization.
///
/// PersonalTags are stored in users/{userId}/personalTags/{tagId} and
/// are completely private to each user. They provide custom categorization
/// separate from the auto-generated tagging system (TagResult).
///
/// Display uses fixed colors (no custom colors):
/// - Auto-generated tags: Gray
/// - Personal tags: App accent color
///
/// Example uses:
/// - "Mamma's Recipes" for family recipes
/// - "Quick Weeknight" for fast meals
/// - "Party Food" for special occasions
@immutable
class PersonalTag {
  /// Unique identifier (Firestore document ID).
  final String id;

  /// Display name shown to the user (e.g., "Mamma's Recipes").
  /// Must be 1-50 characters, no commas.
  final String name;

  /// When this tag was created.
  final DateTime createdAt;

  /// When this tag was last modified.
  final DateTime updatedAt;

  /// Sort order for manual ordering in UI (lower = first).
  final int sortOrder;

  /// Optional reference to a PersonalTagGroup for organizing tags.
  /// Null means the tag is ungrouped.
  final String? groupId;

  /// Embedded automation rules for this tag.
  /// Rules are evaluated when recipes are saved to auto-apply this tag.
  final List<PersonalTagRule> rules;

  const PersonalTag({
    required this.id,
    required this.name,
    required this.createdAt,
    required this.updatedAt,
    this.sortOrder = 0,
    this.groupId,
    this.rules = const [],
  });

  /// Creates a new PersonalTag with generated ID and timestamps.
  factory PersonalTag.create({
    required String name,
    int sortOrder = 0,
    String? groupId,
    List<PersonalTagRule>? rules,
  }) {
    final now = DateTime.now();
    return PersonalTag(
      id: const Uuid().v4(),
      name: name.trim(),
      createdAt: now,
      updatedAt: now,
      sortOrder: sortOrder,
      groupId: groupId,
      rules: rules ?? const [],
    );
  }

  /// Creates from Firestore document snapshot.
  factory PersonalTag.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>?;
    if (data == null) {
      throw ArgumentError('Document data is null');
    }
    return PersonalTag.fromMap(doc.id, data);
  }

  /// Creates from map data with explicit ID.
  factory PersonalTag.fromMap(String id, Map<String, dynamic> data) {
    return PersonalTag(
      id: id,
      name: SerializationUtils.safeString(data, 'name', defaultValue: ''),
      createdAt: SerializationUtils.safeRequiredDateTime(
        data,
        'createdAt',
        defaultValue: DateTime.now(),
      ),
      updatedAt: SerializationUtils.safeRequiredDateTime(
        data,
        'updatedAt',
        defaultValue: DateTime.now(),
      ),
      sortOrder: SerializationUtils.safeInt(data, 'sortOrder', defaultValue: 0),
      groupId: SerializationUtils.safeNullableString(data, 'groupId'),
      rules: _parseRules(data['rules']),
    );
  }

  /// Parses embedded rules from Firestore/map data.
  static List<PersonalTagRule> _parseRules(dynamic value) {
    if (value == null) return [];
    if (value is! List) return [];
    return value
        .whereType<Map<String, dynamic>>()
        .map((data) => PersonalTagRule.fromEmbeddedMap(data))
        .toList();
  }

  /// Creates from JSON map (expects ISO string for dates).
  factory PersonalTag.fromJson(Map<String, dynamic> json) {
    final id = SerializationUtils.safeString(json, 'id', defaultValue: '');
    if (id.isEmpty) {
      throw ArgumentError('PersonalTag.fromJson requires id field');
    }

    DateTime parseDateTime(dynamic value) {
      if (value == null) return DateTime.now();
      if (value is DateTime) return value;
      if (value is String) return DateTime.parse(value);
      if (value is Timestamp) return value.toDate();
      return DateTime.now();
    }

    return PersonalTag(
      id: id,
      name: SerializationUtils.safeString(json, 'name', defaultValue: ''),
      createdAt: parseDateTime(json['createdAt']),
      updatedAt: parseDateTime(json['updatedAt']),
      sortOrder: SerializationUtils.safeInt(json, 'sortOrder', defaultValue: 0),
      groupId: SerializationUtils.safeNullableString(json, 'groupId'),
      rules: _parseRules(json['rules']),
    );
  }

  /// Converts to Firestore map (uses Timestamp for dates).
  /// Note: ID is stored as document ID, not in the map.
  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
      'sortOrder': sortOrder,
      if (groupId != null) 'groupId': groupId,
      if (rules.isNotEmpty)
        'rules': rules.map((r) => r.toEmbeddedMap()).toList(),
    };
  }

  /// Converts to JSON map (uses ISO string for dates).
  /// Includes ID for portable serialization.
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'sortOrder': sortOrder,
      if (groupId != null) 'groupId': groupId,
      if (rules.isNotEmpty)
        'rules': rules.map((r) => r.toEmbeddedMap()).toList(),
    };
  }

  /// Creates a copy with optional field overrides.
  /// Automatically updates `updatedAt` when changes are made.
  PersonalTag copyWith({
    String? id,
    String? name,
    DateTime? createdAt,
    DateTime? updatedAt,
    int? sortOrder,
    String? groupId,
    List<PersonalTagRule>? rules,
    bool clearGroupId = false,
  }) {
    return PersonalTag(
      id: id ?? this.id,
      name: name ?? this.name,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
      sortOrder: sortOrder ?? this.sortOrder,
      groupId: clearGroupId ? null : (groupId ?? this.groupId),
      rules: rules ?? this.rules,
    );
  }

  /// Validates the tag name.
  /// Returns null if valid, error message if invalid.
  static String? validateName(String? name) {
    if (name == null || name.trim().isEmpty) {
      return 'Taggnamn krävs';
    }
    final trimmed = name.trim();
    if (trimmed.length > 50) {
      return 'Taggnamn för långt (max 50 tecken)';
    }
    if (trimmed.contains(',')) {
      return 'Taggnamn får inte innehålla kommatecken';
    }
    if (ReservedTags.isReserved(trimmed)) {
      return 'Detta namn är reserverat för systemtaggar';
    }
    return null;
  }

  /// Returns true if this tag has valid data.
  bool get isValid => validateName(name) == null;

  // ID-based equality for efficient Set/Map operations
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PersonalTag &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'PersonalTag(id: $id, name: $name)';
}
