import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import 'package:butlery/core/utils/serialization_utils.dart';
import 'package:butlery/core/l10n/app_locale.dart';
import 'package:butlery/models/tagging/ingredient_lookup_result.dart';
import 'package:butlery/models/recipe_unified.dart';

// Re-export extracted models so existing importers continue to work.
export 'package:butlery/models/tagging/condition_type.dart';
export 'package:butlery/models/tagging/condition_operator.dart';
export 'package:butlery/models/tagging/rule_condition.dart';

import 'package:butlery/models/tagging/condition_type.dart';
import 'package:butlery/models/tagging/rule_condition.dart';

/// How multiple conditions are combined in a rule.
enum MatchMode {
  /// All conditions must match (AND logic).
  all,

  /// Any condition must match (OR logic).
  any,
}

/// Extension methods for MatchMode serialization.
extension MatchModeExtension on MatchMode {
  String toFirestore() => name.toUpperCase();

  static MatchMode fromFirestore(String? value) {
    switch (value?.toUpperCase()) {
      case 'ALL':
        return MatchMode.all;
      case 'ANY':
        return MatchMode.any;
      default:
        return MatchMode.all; // Default to AND logic
    }
  }
}

/// A rule for automatically applying a PersonalTag to recipes.
///
/// Rules are embedded within PersonalTag documents:
/// `users/{userId}/personalTags/{tagId}` with a `rules` array.
///
/// When evaluated, if a rule matches, its parent PersonalTag is
/// automatically added to the recipe with source tracking.
@immutable
class PersonalTagRule {
  /// Unique identifier for this rule.
  final String id;

  /// The PersonalTag ID this rule applies.
  /// Note: When embedded in a PersonalTag, this may be empty as
  /// the parent tag context provides the association.
  final String tagId;

  /// Descriptive name for this rule (e.g., "Fish recipes").
  final String name;

  /// Conditions that must be met for the rule to match.
  final List<RuleCondition> conditions;

  /// How conditions are combined (all must match vs any must match).
  final MatchMode matchMode;

  /// Whether this rule is active.
  final bool isEnabled;

  /// When this rule was created.
  final DateTime createdAt;

  /// When this rule was last modified.
  final DateTime updatedAt;

  const PersonalTagRule({
    required this.id,
    this.tagId = '',
    required this.name,
    required this.conditions,
    this.matchMode = MatchMode.all,
    this.isEnabled = true,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Creates a new PersonalTagRule with generated ID and timestamps.
  factory PersonalTagRule.create({
    required String tagId,
    required String name,
    required List<RuleCondition> conditions,
    MatchMode matchMode = MatchMode.all,
    bool isEnabled = true,
  }) {
    final now = DateTime.now();
    return PersonalTagRule(
      id: const Uuid().v4(),
      tagId: tagId,
      name: name.trim(),
      conditions: conditions,
      matchMode: matchMode,
      isEnabled: isEnabled,
      createdAt: now,
      updatedAt: now,
    );
  }

  /// Creates from Firestore document snapshot.
  factory PersonalTagRule.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>?;
    if (data == null) {
      throw ArgumentError('Document data is null');
    }
    return PersonalTagRule.fromMap(doc.id, data);
  }

  /// Creates from map data with explicit ID.
  factory PersonalTagRule.fromMap(String id, Map<String, dynamic> data) {
    return PersonalTagRule(
      id: id,
      tagId: SerializationUtils.safeString(data, 'tagId', defaultValue: ''),
      name: SerializationUtils.safeString(data, 'name', defaultValue: ''),
      conditions: _parseConditions(data['conditions']),
      matchMode:
          MatchModeExtension.fromFirestore(data['matchMode']?.toString()),
      isEnabled: SerializationUtils.safeBool(
        data,
        'isEnabled',
        defaultValue: true,
      ),
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
    );
  }

  /// Creates from JSON map (expects ISO string for dates).
  factory PersonalTagRule.fromJson(Map<String, dynamic> json) {
    final id = SerializationUtils.safeString(json, 'id', defaultValue: '');
    if (id.isEmpty) {
      throw ArgumentError('PersonalTagRule.fromJson requires id field');
    }

    DateTime parseDateTime(dynamic value) {
      if (value == null) return DateTime.now();
      if (value is DateTime) return value;
      if (value is String) return DateTime.parse(value);
      if (value is Timestamp) return value.toDate();
      return DateTime.now();
    }

    return PersonalTagRule(
      id: id,
      tagId: SerializationUtils.safeString(json, 'tagId', defaultValue: ''),
      name: SerializationUtils.safeString(json, 'name', defaultValue: ''),
      conditions: _parseConditions(json['conditions']),
      matchMode:
          MatchModeExtension.fromFirestore(json['matchMode']?.toString()),
      isEnabled: SerializationUtils.safeBool(
        json,
        'isEnabled',
        defaultValue: true,
      ),
      createdAt: parseDateTime(json['createdAt']),
      updatedAt: parseDateTime(json['updatedAt']),
    );
  }

  /// Creates from embedded map data (within a PersonalTag document).
  /// Does not require tagId since the parent tag provides context.
  factory PersonalTagRule.fromEmbeddedMap(Map<String, dynamic> data) {
    DateTime parseDateTime(dynamic value) {
      if (value == null) return DateTime.now();
      if (value is DateTime) return value;
      if (value is String) return DateTime.parse(value);
      if (value is Timestamp) return value.toDate();
      return DateTime.now();
    }

    return PersonalTagRule(
      id: SerializationUtils.safeString(data, 'id',
          defaultValue: const Uuid().v4()),
      tagId: '', // Not needed for embedded rules
      name: SerializationUtils.safeString(data, 'name', defaultValue: ''),
      conditions: _parseConditions(data['conditions']),
      matchMode:
          MatchModeExtension.fromFirestore(data['matchMode']?.toString()),
      isEnabled: SerializationUtils.safeBool(
        data,
        'isEnabled',
        defaultValue: true,
      ),
      createdAt: parseDateTime(data['createdAt']),
      updatedAt: parseDateTime(data['updatedAt']),
    );
  }

  /// Converts to embedded map (for storing within PersonalTag).
  /// Excludes tagId since parent tag provides context.
  Map<String, dynamic> toEmbeddedMap() {
    return {
      'id': id,
      'name': name,
      'conditions': conditions.map((c) => c.toMap()).toList(),
      'matchMode': matchMode.toFirestore(),
      'isEnabled': isEnabled,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  static List<RuleCondition> _parseConditions(dynamic value) {
    if (value == null) return [];
    if (value is! List) return [];

    return value
        .whereType<Map<String, dynamic>>()
        .map((data) => RuleCondition.fromMap(data))
        .toList();
  }

  /// Converts to Firestore map (uses Timestamp for dates).
  Map<String, dynamic> toFirestore() {
    return {
      'tagId': tagId,
      'name': name,
      'conditions': conditions.map((c) => c.toMap()).toList(),
      'matchMode': matchMode.toFirestore(),
      'isEnabled': isEnabled,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  /// Converts to JSON map (uses ISO string for dates).
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'tagId': tagId,
      'name': name,
      'conditions': conditions.map((c) => c.toMap()).toList(),
      'matchMode': matchMode.toFirestore(),
      'isEnabled': isEnabled,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  /// Evaluates this rule against a recipe.
  ///
  /// Returns true if the rule matches and the tag should be applied.
  ///
  /// [recipe] The recipe to evaluate.
  /// [lookup] Optional ingredient lookup result for property matching.
  /// [currentUserId] Optional current user ID for ownership evaluation.
  bool evaluate(
    Recipe recipe,
    IngredientLookupResult? lookup, {
    String? currentUserId,
  }) {
    if (!isEnabled) return false;
    if (conditions.isEmpty) return false;

    switch (matchMode) {
      case MatchMode.all:
        return conditions.every(
            (c) => c.evaluate(recipe, lookup, currentUserId: currentUserId));
      case MatchMode.any:
        return conditions.any(
            (c) => c.evaluate(recipe, lookup, currentUserId: currentUserId));
    }
  }

  /// Returns true if this rule requires ingredient lookup data.
  bool get requiresLookup =>
      conditions.any((c) => c.type == ConditionType.property);

  /// Returns true if this rule requires current user ID for ownership evaluation.
  bool get requiresCurrentUser =>
      conditions.any((c) => c.type == ConditionType.ownership);

  /// Creates a copy with optional field overrides.
  PersonalTagRule copyWith({
    String? id,
    String? tagId,
    String? name,
    List<RuleCondition>? conditions,
    MatchMode? matchMode,
    bool? isEnabled,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return PersonalTagRule(
      id: id ?? this.id,
      tagId: tagId ?? this.tagId,
      name: name ?? this.name,
      conditions: conditions ?? this.conditions,
      matchMode: matchMode ?? this.matchMode,
      isEnabled: isEnabled ?? this.isEnabled,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
    );
  }

  /// Validates the rule.
  /// Returns null if valid, error message if invalid.
  ///
  /// [requireTagId] - Set to false for embedded rules where tagId is not needed.
  static String? validate(PersonalTagRule rule, {bool requireTagId = true}) {
    final l = AppLocale.current;
    if (requireTagId && rule.tagId.isEmpty) {
      return l.validationRuleMustBeLinked;
    }
    if (rule.name.trim().isEmpty) {
      return l.validationRuleNameRequired;
    }
    if (rule.conditions.isEmpty) {
      return l.validationRuleMustHaveCondition;
    }
    for (final condition in rule.conditions) {
      // Validate based on condition type
      if (condition.type.isNumeric) {
        // Numeric conditions need a valid number
        if (condition.value == null ||
            (condition.value is String && condition.value.isEmpty)) {
          return l.validationAllConditionsMustHaveValue;
        }
      } else {
        // Text conditions need a non-empty string
        if (condition.stringValue.trim().isEmpty) {
          return l.validationAllConditionsMustHaveValue;
        }
      }
    }
    return null;
  }

  /// Validates this rule for embedded use (within PersonalTag).
  static String? validateEmbedded(PersonalTagRule rule) {
    return validate(rule, requireTagId: false);
  }

  /// Returns true if this rule has valid data.
  bool get isValid => validate(this) == null;

  /// Returns true if this rule has valid data for embedded use.
  bool get isValidEmbedded => validateEmbedded(this) == null;

  // ID-based equality
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PersonalTagRule &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() =>
      'PersonalTagRule(id: $id, name: $name, ${conditions.length} conditions)';
}
