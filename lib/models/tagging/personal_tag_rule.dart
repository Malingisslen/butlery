import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import 'package:butlery/core/utils/serialization_utils.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/models/tagging/ingredient_lookup_result.dart';

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

/// Type of condition to evaluate.
enum ConditionType {
  /// Match against recipe ingredient text.
  ingredient,

  /// Match against ingredient database properties (requires lookup).
  property,

  /// Match against recipe title or description.
  keyword,

  /// Match against recipe source URL.
  sourceUrl,
}

/// Extension methods for ConditionType serialization.
extension ConditionTypeExtension on ConditionType {
  String toFirestore() => name;

  static ConditionType fromFirestore(String? value) {
    switch (value?.toLowerCase()) {
      case 'ingredient':
        return ConditionType.ingredient;
      case 'property':
        return ConditionType.property;
      case 'keyword':
        return ConditionType.keyword;
      case 'sourceurl':
      case 'source_url':
        return ConditionType.sourceUrl;
      default:
        return ConditionType.keyword; // Safe default
    }
  }

  /// Human-readable Swedish label for UI.
  String get label {
    switch (this) {
      case ConditionType.ingredient:
        return 'Ingrediens';
      case ConditionType.property:
        return 'Egenskap';
      case ConditionType.keyword:
        return 'Nyckelord';
      case ConditionType.sourceUrl:
        return 'Källa';
    }
  }
}

/// Comparison operator for condition evaluation.
enum ConditionOperator {
  /// Value must be contained in text.
  contains,

  /// Value must equal text exactly.
  equals,

  /// Text must start with value.
  startsWith,

  /// Value must NOT be contained in text.
  notContains,

  /// Value must NOT equal text exactly.
  notEquals,
}

/// Extension methods for ConditionOperator serialization.
extension ConditionOperatorExtension on ConditionOperator {
  String toFirestore() => name;

  static ConditionOperator fromFirestore(String? value) {
    switch (value?.toLowerCase()) {
      case 'contains':
        return ConditionOperator.contains;
      case 'equals':
        return ConditionOperator.equals;
      case 'startswith':
      case 'starts_with':
        return ConditionOperator.startsWith;
      case 'notcontains':
      case 'not_contains':
        return ConditionOperator.notContains;
      case 'notequals':
      case 'not_equals':
        return ConditionOperator.notEquals;
      default:
        return ConditionOperator.contains; // Safe default
    }
  }

  /// Human-readable Swedish label for UI.
  String get label {
    switch (this) {
      case ConditionOperator.contains:
        return 'innehåller';
      case ConditionOperator.equals:
        return 'är exakt';
      case ConditionOperator.startsWith:
        return 'börjar med';
      case ConditionOperator.notContains:
        return 'innehåller inte';
      case ConditionOperator.notEquals:
        return 'är inte';
    }
  }
}

/// A single condition within a PersonalTagRule.
///
/// Conditions are evaluated against recipe data to determine
/// if the rule's tag should be applied.
@immutable
class RuleCondition {
  /// What type of data to match against.
  final ConditionType type;

  /// How to compare the value.
  final ConditionOperator operator;

  /// The value to match.
  final String value;

  /// Whether matching is case-sensitive.
  final bool caseSensitive;

  const RuleCondition({
    required this.type,
    required this.operator,
    required this.value,
    this.caseSensitive = false,
  });

  /// Creates from Firestore/JSON map.
  factory RuleCondition.fromMap(Map<String, dynamic> data) {
    return RuleCondition(
      type: ConditionTypeExtension.fromFirestore(data['type']?.toString()),
      operator:
          ConditionOperatorExtension.fromFirestore(data['operator']?.toString()),
      value: SerializationUtils.safeString(data, 'value', defaultValue: ''),
      caseSensitive: SerializationUtils.safeBool(
        data,
        'caseSensitive',
        defaultValue: false,
      ),
    );
  }

  /// Converts to Firestore/JSON map.
  Map<String, dynamic> toMap() {
    return {
      'type': type.toFirestore(),
      'operator': operator.toFirestore(),
      'value': value,
      'caseSensitive': caseSensitive,
    };
  }

  /// Evaluates this condition against a recipe.
  ///
  /// [recipe] The recipe to evaluate.
  /// [lookup] Optional ingredient lookup result for property matching.
  ///          Required for ConditionType.property.
  bool evaluate(Recipe recipe, IngredientLookupResult? lookup) {
    switch (type) {
      case ConditionType.ingredient:
        return _evaluateIngredient(recipe);
      case ConditionType.property:
        return _evaluateProperty(lookup);
      case ConditionType.keyword:
        return _evaluateKeyword(recipe);
      case ConditionType.sourceUrl:
        return _evaluateSourceUrl(recipe);
    }
  }

  bool _evaluateIngredient(Recipe recipe) {
    final ingredients = recipe.ingredients;
    final searchValue = caseSensitive ? value : value.toLowerCase();

    for (final ingredient in ingredients) {
      final text = caseSensitive ? ingredient : ingredient.toLowerCase();
      if (_matchOperator(text, searchValue)) {
        return true;
      }
    }
    return false;
  }

  bool _evaluateProperty(IngredientLookupResult? lookup) {
    if (lookup == null) return false;

    // Property matching uses the ingredient database
    // Value should be a property name like 'seafood', 'meat', 'dairy'
    final propertyName = value.toLowerCase().trim();

    switch (operator) {
      case ConditionOperator.contains:
      case ConditionOperator.equals:
        // Check if any matched ingredient has this property
        return lookup.matched.any((ing) => ing.hasProperty(propertyName));
      case ConditionOperator.notContains:
      case ConditionOperator.notEquals:
        // Check if NO matched ingredient has this property
        return !lookup.matched.any((ing) => ing.hasProperty(propertyName));
      case ConditionOperator.startsWith:
        // startsWith doesn't make sense for properties, treat as contains
        return lookup.matched.any((ing) => ing.hasProperty(propertyName));
    }
  }

  bool _evaluateKeyword(Recipe recipe) {
    final title = caseSensitive ? recipe.title : recipe.title.toLowerCase();
    final description = caseSensitive
        ? recipe.description
        : recipe.description.toLowerCase();
    final searchValue = caseSensitive ? value : value.toLowerCase();

    return _matchOperator(title, searchValue) ||
        _matchOperator(description, searchValue);
  }

  bool _evaluateSourceUrl(Recipe recipe) {
    final url = recipe.sourceUrl ?? '';
    if (url.isEmpty) return operator == ConditionOperator.notContains;

    final urlLower = caseSensitive ? url : url.toLowerCase();
    final searchValue = caseSensitive ? value : value.toLowerCase();

    return _matchOperator(urlLower, searchValue);
  }

  bool _matchOperator(String text, String searchValue) {
    switch (operator) {
      case ConditionOperator.contains:
        return text.contains(searchValue);
      case ConditionOperator.equals:
        return text == searchValue;
      case ConditionOperator.startsWith:
        return text.startsWith(searchValue);
      case ConditionOperator.notContains:
        return !text.contains(searchValue);
      case ConditionOperator.notEquals:
        return text != searchValue;
    }
  }

  /// Creates a copy with optional field overrides.
  RuleCondition copyWith({
    ConditionType? type,
    ConditionOperator? operator,
    String? value,
    bool? caseSensitive,
  }) {
    return RuleCondition(
      type: type ?? this.type,
      operator: operator ?? this.operator,
      value: value ?? this.value,
      caseSensitive: caseSensitive ?? this.caseSensitive,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RuleCondition &&
          runtimeType == other.runtimeType &&
          type == other.type &&
          operator == other.operator &&
          value == other.value &&
          caseSensitive == other.caseSensitive;

  @override
  int get hashCode => Object.hash(type, operator, value, caseSensitive);

  @override
  String toString() =>
      'RuleCondition(${type.label} ${operator.label} "$value")';
}

/// A rule for automatically applying a PersonalTag to recipes.
///
/// Rules are stored in users/{userId}/personalTagRules/{ruleId} and
/// are evaluated when recipes are saved or edited. If a rule matches,
/// its associated PersonalTag is automatically added to the recipe.
@immutable
class PersonalTagRule {
  /// Unique identifier (Firestore document ID).
  final String id;

  /// The PersonalTag ID this rule applies.
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
    required this.tagId,
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
      matchMode: MatchModeExtension.fromFirestore(data['matchMode']?.toString()),
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
      matchMode: MatchModeExtension.fromFirestore(json['matchMode']?.toString()),
      isEnabled: SerializationUtils.safeBool(
        json,
        'isEnabled',
        defaultValue: true,
      ),
      createdAt: parseDateTime(json['createdAt']),
      updatedAt: parseDateTime(json['updatedAt']),
    );
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
  bool evaluate(Recipe recipe, IngredientLookupResult? lookup) {
    if (!isEnabled) return false;
    if (conditions.isEmpty) return false;

    switch (matchMode) {
      case MatchMode.all:
        return conditions.every((c) => c.evaluate(recipe, lookup));
      case MatchMode.any:
        return conditions.any((c) => c.evaluate(recipe, lookup));
    }
  }

  /// Returns true if this rule requires ingredient lookup data.
  bool get requiresLookup =>
      conditions.any((c) => c.type == ConditionType.property);

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
  static String? validate(PersonalTagRule rule) {
    if (rule.tagId.isEmpty) {
      return 'Regel måste kopplas till en tagg';
    }
    if (rule.name.trim().isEmpty) {
      return 'Regelnamn krävs';
    }
    if (rule.conditions.isEmpty) {
      return 'Regel måste ha minst ett villkor';
    }
    for (final condition in rule.conditions) {
      if (condition.value.trim().isEmpty) {
        return 'Alla villkor måste ha ett värde';
      }
    }
    return null;
  }

  /// Returns true if this rule has valid data.
  bool get isValid => validate(this) == null;

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
