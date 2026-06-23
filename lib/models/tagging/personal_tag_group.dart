import 'package:clock/clock.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import 'package:butlery/core/utils/serialization_utils.dart';
import 'package:butlery/core/l10n/app_locale.dart';

/// A group/folder for organizing PersonalTags.
///
/// Groups are stored in `users/{userId}/personalTagGroups/{groupId}`.
/// PersonalTags reference groups via their `groupId` field.
///
/// Groups can be exclusive (radio mode) or non-exclusive (checkbox mode):
/// - Exclusive: Only one tag from the group can be applied to a recipe
/// - Non-exclusive: Multiple tags from the group can be applied
///
/// Example groups:
/// - "Difficulty" (exclusive) - Easy/Medium/Hard
/// - "Meal Planning" - tags for weekly meal planning
/// - "Favorites" - tags for favorite recipe categories
@immutable
class PersonalTagGroup {
  /// Unique identifier (Firestore document ID).
  final String id;

  /// Display name for the group (e.g., "Meal Planning").
  /// Must be 1-50 characters.
  final String name;

  /// Sort order for manual ordering in UI (lower = first).
  final int sortOrder;

  /// When true, only one tag from this group can be applied to a recipe.
  /// UI displays as dropdown instead of chips.
  /// If multiple rules match exclusive tags, no auto-apply occurs.
  final bool isExclusive;

  /// When this group was created.
  final DateTime createdAt;

  /// When this group was last modified.
  final DateTime updatedAt;

  const PersonalTagGroup({
    required this.id,
    required this.name,
    this.sortOrder = 0,
    this.isExclusive = false,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Creates a new PersonalTagGroup with generated ID and timestamps.
  factory PersonalTagGroup.create({
    required String name,
    int sortOrder = 0,
    bool isExclusive = false,
  }) {
    final now = clock.now();
    return PersonalTagGroup(
      id: const Uuid().v4(),
      name: name.trim(),
      sortOrder: sortOrder,
      isExclusive: isExclusive,
      createdAt: now,
      updatedAt: now,
    );
  }

  /// Creates from Firestore document snapshot.
  factory PersonalTagGroup.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>?;
    if (data == null) {
      throw ArgumentError('Document data is null');
    }
    return PersonalTagGroup.fromMap(doc.id, data);
  }

  /// Creates from map data with explicit ID.
  factory PersonalTagGroup.fromMap(String id, Map<String, dynamic> data) {
    return PersonalTagGroup(
      id: id,
      name: SerializationUtils.safeString(data, 'name', defaultValue: ''),
      sortOrder: SerializationUtils.safeInt(data, 'sortOrder', defaultValue: 0),
      isExclusive: SerializationUtils.safeBool(
        data,
        'isExclusive',
        defaultValue: false,
      ),
      createdAt: SerializationUtils.safeRequiredDateTime(
        data,
        'createdAt',
        defaultValue: clock.now(),
      ),
      updatedAt: SerializationUtils.safeRequiredDateTime(
        data,
        'updatedAt',
        defaultValue: clock.now(),
      ),
    );
  }

  /// Creates from JSON map (expects ISO string for dates).
  factory PersonalTagGroup.fromJson(Map<String, dynamic> json) {
    final id = SerializationUtils.safeString(json, 'id', defaultValue: '');
    if (id.isEmpty) {
      throw ArgumentError('PersonalTagGroup.fromJson requires id field');
    }

    return PersonalTagGroup(
      id: id,
      name: SerializationUtils.safeString(json, 'name', defaultValue: ''),
      sortOrder: SerializationUtils.safeInt(json, 'sortOrder', defaultValue: 0),
      isExclusive: SerializationUtils.safeBool(
        json,
        'isExclusive',
        defaultValue: false,
      ),
      createdAt: SerializationUtils.parseRequiredDateTimeValue(
        json['createdAt'],
      ),
      updatedAt: SerializationUtils.parseRequiredDateTimeValue(
        json['updatedAt'],
      ),
    );
  }

  /// Converts to Firestore map (uses Timestamp for dates).
  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'sortOrder': sortOrder,
      'isExclusive': isExclusive,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  /// Converts to JSON map (uses ISO string for dates).
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'sortOrder': sortOrder,
      'isExclusive': isExclusive,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  /// Creates a copy with optional field overrides.
  PersonalTagGroup copyWith({
    String? id,
    String? name,
    int? sortOrder,
    bool? isExclusive,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return PersonalTagGroup(
      id: id ?? this.id,
      name: name ?? this.name,
      sortOrder: sortOrder ?? this.sortOrder,
      isExclusive: isExclusive ?? this.isExclusive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? clock.now(),
    );
  }

  /// Validates the group name.
  /// Returns null if valid, error message if invalid.
  static String? validateName(String? name) {
    final l = AppLocale.current;
    if (name == null || name.trim().isEmpty) {
      return l.validationGroupNameRequired;
    }
    final trimmed = name.trim();
    if (trimmed.length > 50) {
      return l.validationGroupNameTooLong;
    }
    return null;
  }

  /// Returns true if this group has valid data.
  bool get isValid => validateName(name) == null;

  // ID-based equality
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PersonalTagGroup &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'PersonalTagGroup(id: $id, name: $name)';
}
