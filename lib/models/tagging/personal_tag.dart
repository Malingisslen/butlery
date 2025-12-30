import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import 'package:butlery/core/utils/serialization_utils.dart';

/// A user-defined personal tag for custom recipe categorization.
///
/// PersonalTags are stored in users/{userId}/personalTags/{tagId} and
/// are completely private to each user. They provide custom categorization
/// separate from the auto-generated tagging system (TagResult).
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

  /// Optional hex color for UI display (e.g., "#FF5733").
  /// Null means use default color.
  final String? color;

  /// Optional icon name for UI display (Material icon name).
  /// Null means use default icon.
  final String? icon;

  /// When this tag was created.
  final DateTime createdAt;

  /// When this tag was last modified.
  final DateTime updatedAt;

  /// Sort order for manual ordering in UI (lower = first).
  final int sortOrder;

  const PersonalTag({
    required this.id,
    required this.name,
    this.color,
    this.icon,
    required this.createdAt,
    required this.updatedAt,
    this.sortOrder = 0,
  });

  /// Creates a new PersonalTag with generated ID and timestamps.
  factory PersonalTag.create({
    required String name,
    String? color,
    String? icon,
    int sortOrder = 0,
  }) {
    final now = DateTime.now();
    return PersonalTag(
      id: const Uuid().v4(),
      name: name.trim(),
      color: _validateColor(color),
      icon: icon,
      createdAt: now,
      updatedAt: now,
      sortOrder: sortOrder,
    );
  }

  /// Validates and normalizes hex color format.
  /// Returns null if invalid, otherwise returns uppercase hex.
  static String? _validateColor(String? color) {
    if (color == null || color.isEmpty) return null;

    // Normalize to uppercase with # prefix
    var normalized = color.toUpperCase().trim();
    if (!normalized.startsWith('#')) {
      normalized = '#$normalized';
    }

    // Validate format: #RGB or #RRGGBB
    final hexPattern = RegExp(r'^#([0-9A-F]{3}|[0-9A-F]{6})$');
    if (!hexPattern.hasMatch(normalized)) {
      return null; // Invalid format
    }

    // Expand #RGB to #RRGGBB
    if (normalized.length == 4) {
      final r = normalized[1];
      final g = normalized[2];
      final b = normalized[3];
      normalized = '#$r$r$g$g$b$b';
    }

    return normalized;
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
      color: SerializationUtils.safeNullableString(data, 'color'),
      icon: SerializationUtils.safeNullableString(data, 'icon'),
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
    );
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
      color: SerializationUtils.safeNullableString(json, 'color'),
      icon: SerializationUtils.safeNullableString(json, 'icon'),
      createdAt: parseDateTime(json['createdAt']),
      updatedAt: parseDateTime(json['updatedAt']),
      sortOrder: SerializationUtils.safeInt(json, 'sortOrder', defaultValue: 0),
    );
  }

  /// Converts to Firestore map (uses Timestamp for dates).
  /// Note: ID is stored as document ID, not in the map.
  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      if (color != null) 'color': color,
      if (icon != null) 'icon': icon,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
      'sortOrder': sortOrder,
    };
  }

  /// Converts to JSON map (uses ISO string for dates).
  /// Includes ID for portable serialization.
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      if (color != null) 'color': color,
      if (icon != null) 'icon': icon,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'sortOrder': sortOrder,
    };
  }

  /// Creates a copy with optional field overrides.
  /// Automatically updates `updatedAt` when changes are made.
  PersonalTag copyWith({
    String? id,
    String? name,
    String? color,
    String? icon,
    DateTime? createdAt,
    DateTime? updatedAt,
    int? sortOrder,
    bool clearColor = false,
    bool clearIcon = false,
  }) {
    return PersonalTag(
      id: id ?? this.id,
      name: name ?? this.name,
      color: clearColor ? null : (color ?? this.color),
      icon: clearIcon ? null : (icon ?? this.icon),
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
      sortOrder: sortOrder ?? this.sortOrder,
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
