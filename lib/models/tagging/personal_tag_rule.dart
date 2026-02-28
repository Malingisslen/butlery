import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import 'package:butlery/core/utils/serialization_utils.dart';
import 'package:butlery/core/extensions/default_value_extensions.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/models/tagging/ingredient_lookup_result.dart';
import 'package:butlery/models/tagging/tri_state.dart';
import 'package:butlery/core/l10n/app_locale.dart';

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

  /// Match against recipe source URL (contains substring).
  sourceUrl,

  /// Match against auto-generated cuisine tags.
  cuisine,

  /// Match against dietary status (vegetarian, vegan, etc.).
  dietary,

  /// Match against cooking time in minutes.
  time,

  /// Match against user rating (1-5).
  rating,

  /// Match against recipe age (days since added).
  recency,

  /// Match against recipe ownership/collaboration status.
  /// Values: 'mine', 'shared', 'collaborative', 'public'
  ownership,

  /// Match against whether recipe has an image.
  /// Boolean condition: true = has image, false = no image.
  hasImage,

  /// Match against recipe completeness.
  /// Values: 'missing_image', 'missing_description', 'incomplete'
  completeness,
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
      case 'cuisine':
        return ConditionType.cuisine;
      case 'dietary':
        return ConditionType.dietary;
      case 'time':
        return ConditionType.time;
      case 'rating':
        return ConditionType.rating;
      case 'recency':
        return ConditionType.recency;
      case 'ownership':
        return ConditionType.ownership;
      case 'hasimage':
      case 'has_image':
        return ConditionType.hasImage;
      case 'completeness':
        return ConditionType.completeness;
      default:
        return ConditionType.keyword; // Safe default
    }
  }

  /// Human-readable localized label for UI.
  String get label {
    final l = AppLocale.current;
    switch (this) {
      case ConditionType.ingredient:
        return l.conditionTypeIngredient;
      case ConditionType.property:
        return l.conditionTypeProperty;
      case ConditionType.keyword:
        return l.conditionTypeKeyword;
      case ConditionType.sourceUrl:
        return l.conditionTypeSource;
      case ConditionType.cuisine:
        return l.conditionTypeCuisine;
      case ConditionType.dietary:
        return l.conditionTypeDiet;
      case ConditionType.time:
        return l.conditionTypeTime;
      case ConditionType.rating:
        return l.conditionTypeRating;
      case ConditionType.recency:
        return l.conditionTypeRecent;
      case ConditionType.ownership:
        return l.conditionTypeOwnership;
      case ConditionType.hasImage:
        return l.conditionTypeHasImage;
      case ConditionType.completeness:
        return l.conditionTypeCompleteness;
    }
  }

  /// Returns true if this condition type uses numeric values.
  bool get isNumeric {
    switch (this) {
      case ConditionType.time:
      case ConditionType.rating:
      case ConditionType.recency:
        return true;
      default:
        return false;
    }
  }

  /// Returns true if this condition type uses boolean values.
  bool get isBoolean {
    switch (this) {
      case ConditionType.hasImage:
        return true;
      default:
        return false;
    }
  }
}

/// Comparison operator for condition evaluation.
enum ConditionOperator {
  // Text operators
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

  // Property operators
  /// Ingredient must have property.
  has,

  /// Ingredient must NOT have property.
  notHas,

  // Numeric operators
  /// Numeric value must be less than.
  lessThan,

  /// Numeric value must be less than or equal.
  lessThanOrEqual,

  /// Numeric value must be greater than.
  greaterThan,

  /// Numeric value must be greater than or equal.
  greaterThanOrEqual,

  /// Recipe must be added within X days.
  withinDays,
}

/// Extension methods for ConditionOperator serialization.
extension ConditionOperatorExtension on ConditionOperator {
  String toFirestore() => name;

  static ConditionOperator fromFirestore(String? value) {
    switch (value?.toLowerCase()) {
      // Text operators
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
      // Property operators
      case 'has':
        return ConditionOperator.has;
      case 'nothas':
      case 'not_has':
        return ConditionOperator.notHas;
      // Numeric operators
      case 'lessthan':
      case 'less_than':
        return ConditionOperator.lessThan;
      case 'lessthanorequal':
      case 'less_than_or_equal':
        return ConditionOperator.lessThanOrEqual;
      case 'greaterthan':
      case 'greater_than':
        return ConditionOperator.greaterThan;
      case 'greaterthanorequal':
      case 'greater_than_or_equal':
        return ConditionOperator.greaterThanOrEqual;
      case 'withindays':
      case 'within_days':
        return ConditionOperator.withinDays;
      default:
        return ConditionOperator.contains; // Safe default
    }
  }

  /// Human-readable localized label for UI.
  String get label {
    final l = AppLocale.current;
    switch (this) {
      case ConditionOperator.contains:
        return l.operatorContains;
      case ConditionOperator.equals:
        return l.operatorExact;
      case ConditionOperator.startsWith:
        return l.operatorStartsWith;
      case ConditionOperator.notContains:
        return l.operatorNotContains;
      case ConditionOperator.notEquals:
        return l.operatorNotExact;
      case ConditionOperator.has:
        return l.operatorHas;
      case ConditionOperator.notHas:
        return l.operatorNotHas;
      case ConditionOperator.lessThan:
        return l.operatorLessThan;
      case ConditionOperator.lessThanOrEqual:
        return l.operatorAtMost;
      case ConditionOperator.greaterThan:
        return l.operatorGreaterThan;
      case ConditionOperator.greaterThanOrEqual:
        return l.operatorAtLeast;
      case ConditionOperator.withinDays:
        return l.operatorWithinDays;
    }
  }

  /// Returns true if this operator works with numeric values.
  bool get isNumeric {
    switch (this) {
      case ConditionOperator.lessThan:
      case ConditionOperator.lessThanOrEqual:
      case ConditionOperator.greaterThan:
      case ConditionOperator.greaterThanOrEqual:
      case ConditionOperator.withinDays:
        return true;
      default:
        return false;
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
  /// String for text-based conditions, num for numeric conditions.
  final dynamic value;

  /// Whether matching is case-sensitive (text conditions only).
  final bool caseSensitive;

  const RuleCondition({
    required this.type,
    required this.operator,
    required this.value,
    this.caseSensitive = false,
  });

  /// Creates from Firestore/JSON map.
  factory RuleCondition.fromMap(Map<String, dynamic> data) {
    final type = ConditionTypeExtension.fromFirestore(data['type']?.toString());
    return RuleCondition(
      type: type,
      operator: ConditionOperatorExtension.fromFirestore(
          data['operator']?.toString()),
      value: type.isNumeric
          ? SerializationUtils.safeDouble(data, 'value', defaultValue: 0)
          : SerializationUtils.safeString(data, 'value', defaultValue: ''),
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

  /// Returns the value as a string (for text-based conditions).
  String get stringValue => (value?.toString()).orEmpty();

  /// Returns the value as a number (for numeric conditions).
  num get numericValue {
    if (value is num) return value;
    if (value is String) return num.tryParse(value) ?? 0;
    return 0;
  }

  /// Evaluates this condition against a recipe.
  ///
  /// [recipe] The recipe to evaluate.
  /// [lookup] Optional ingredient lookup result for property matching.
  ///          Required for ConditionType.property.
  /// [currentUserId] Optional current user ID for ownership evaluation.
  bool evaluate(
    Recipe recipe,
    IngredientLookupResult? lookup, {
    String? currentUserId,
  }) {
    switch (type) {
      case ConditionType.ingredient:
        return _evaluateIngredient(recipe);
      case ConditionType.property:
        return _evaluateProperty(lookup);
      case ConditionType.keyword:
        return _evaluateKeyword(recipe);
      case ConditionType.sourceUrl:
        return _evaluateSourceUrl(recipe);
      case ConditionType.cuisine:
        return _evaluateCuisine(recipe);
      case ConditionType.dietary:
        return _evaluateDietary(recipe);
      case ConditionType.time:
        return _evaluateTime(recipe);
      case ConditionType.rating:
        return _evaluateRating(recipe);
      case ConditionType.recency:
        return _evaluateRecency(recipe);
      case ConditionType.ownership:
        return _evaluateOwnership(recipe, currentUserId);
      case ConditionType.hasImage:
        return _evaluateHasImage(recipe);
      case ConditionType.completeness:
        return _evaluateCompleteness(recipe);
    }
  }

  bool _evaluateIngredient(Recipe recipe) {
    final ingredients = recipe.ingredients;
    final searchVal = caseSensitive ? stringValue : stringValue.toLowerCase();

    for (final ingredient in ingredients) {
      final text = caseSensitive ? ingredient : ingredient.toLowerCase();
      if (_matchTextOperator(text, searchVal)) {
        return true;
      }
    }
    return false;
  }

  bool _evaluateProperty(IngredientLookupResult? lookup) {
    if (lookup == null) return false;

    // Property matching uses the ingredient database
    // Value should be a property name like 'seafood', 'meat', 'dairy'
    final propertyName = stringValue.toLowerCase().trim();

    switch (operator) {
      case ConditionOperator.has:
      case ConditionOperator.contains:
      case ConditionOperator.equals:
        // Check if any matched ingredient has this property
        return lookup.matched.any((ing) => ing.hasProperty(propertyName));
      case ConditionOperator.notHas:
      case ConditionOperator.notContains:
      case ConditionOperator.notEquals:
        // Check if NO matched ingredient has this property
        return !lookup.matched.any((ing) => ing.hasProperty(propertyName));
      default:
        // Other operators don't apply to properties
        return lookup.matched.any((ing) => ing.hasProperty(propertyName));
    }
  }

  bool _evaluateKeyword(Recipe recipe) {
    final title = caseSensitive ? recipe.title : recipe.title.toLowerCase();
    final description =
        caseSensitive ? recipe.description : recipe.description.toLowerCase();
    final searchVal = caseSensitive ? stringValue : stringValue.toLowerCase();

    return _matchTextOperator(title, searchVal) ||
        _matchTextOperator(description, searchVal);
  }

  bool _evaluateSourceUrl(Recipe recipe) {
    final url = recipe.sourceUrl.orEmpty();
    if (url.isEmpty) return operator == ConditionOperator.notContains;

    final urlLower = caseSensitive ? url : url.toLowerCase();
    final searchVal = caseSensitive ? stringValue : stringValue.toLowerCase();

    return _matchTextOperator(urlLower, searchVal);
  }

  bool _evaluateCuisine(Recipe recipe) {
    final tagResult = recipe.core.tagResult;
    if (tagResult == null) return false;

    // Cuisine tags are stored without prefix in tags set
    final cuisineValue = stringValue.toLowerCase().trim();

    switch (operator) {
      case ConditionOperator.equals:
        return tagResult.tags.any((tag) => tag.toLowerCase() == cuisineValue);
      case ConditionOperator.notEquals:
        return !tagResult.tags.any((tag) => tag.toLowerCase() == cuisineValue);
      case ConditionOperator.contains:
        return tagResult.tags
            .any((tag) => tag.toLowerCase().contains(cuisineValue));
      default:
        return tagResult.tags.any((tag) => tag.toLowerCase() == cuisineValue);
    }
  }

  bool _evaluateDietary(Recipe recipe) {
    final tagResult = recipe.core.tagResult;
    if (tagResult == null) return false;

    final dietaryKey = stringValue.toLowerCase().trim();
    final status = tagResult.dietaryStatus[dietaryKey];

    switch (operator) {
      case ConditionOperator.equals:
        // Check if dietary status is explicitly FREE
        return status?.isFree ?? false;
      case ConditionOperator.notEquals:
        // Check if dietary status is NOT free (contains or unknown)
        return !(status?.isFree ?? false);
      default:
        return status?.isFree ?? false;
    }
  }

  bool _evaluateTime(Recipe recipe) {
    final timeMinutes = recipe.core.timeMinutes ?? 0;
    return _matchNumericOperator(
        timeMinutes.toDouble(), numericValue.toDouble());
  }

  bool _evaluateRating(Recipe recipe) {
    // User rating is stored as 'rating' field on RecipeCore
    final rating = recipe.core.rating ?? 0;
    return _matchNumericOperator(rating.toDouble(), numericValue.toDouble());
  }

  bool _evaluateRecency(Recipe recipe) {
    final createdAt = recipe.core.createdAt;
    final daysSinceCreated = DateTime.now().difference(createdAt).inDays;

    // For recency, withinDays is the primary operator
    if (operator == ConditionOperator.withinDays) {
      return daysSinceCreated <= numericValue;
    }

    return _matchNumericOperator(
        daysSinceCreated.toDouble(), numericValue.toDouble());
  }

  /// Evaluates ownership condition.
  /// Values: 'mine', 'shared', 'collaborative', 'public'
  bool _evaluateOwnership(Recipe recipe, String? currentUserId) {
    final ownershipValue = stringValue.toLowerCase().trim();

    // Get ownership info from recipe and its socialData
    final ownerId = recipe.socialData?.ownerId ?? recipe.core.createdBy;
    final isCollaborative = recipe.type == RecipeType.collaborative ||
        recipe.type == RecipeType.realtime;
    final isPublic = recipe.isPublic;

    String actualOwnership;
    if (currentUserId != null && ownerId == currentUserId) {
      actualOwnership = 'mine';
    } else if (isCollaborative) {
      actualOwnership = 'collaborative';
    } else if (isPublic) {
      actualOwnership = 'public';
    } else {
      actualOwnership = 'shared';
    }

    switch (operator) {
      case ConditionOperator.equals:
        return actualOwnership == ownershipValue;
      case ConditionOperator.notEquals:
        return actualOwnership != ownershipValue;
      default:
        return actualOwnership == ownershipValue;
    }
  }

  /// Evaluates hasImage condition.
  /// Boolean: true = has image, false = no image.
  bool _evaluateHasImage(Recipe recipe) {
    final hasImage = recipe.hasImages;

    // For boolean conditions, value should be 'true' or 'false'
    final expectedHasImage = stringValue.toLowerCase() == 'true';

    switch (operator) {
      case ConditionOperator.equals:
        return hasImage == expectedHasImage;
      case ConditionOperator.notEquals:
        return hasImage != expectedHasImage;
      default:
        return hasImage == expectedHasImage;
    }
  }

  /// Evaluates completeness condition.
  /// Values: 'missing_image', 'missing_description', 'incomplete'
  bool _evaluateCompleteness(Recipe recipe) {
    final completenessValue = stringValue.toLowerCase().trim();

    final hasImage = recipe.hasImages;
    final hasDescription = recipe.description.isNotEmpty;

    bool matches;
    switch (completenessValue) {
      case 'missing_image':
        matches = !hasImage;
        break;
      case 'missing_description':
        matches = !hasDescription;
        break;
      case 'incomplete':
        matches = !hasImage || !hasDescription;
        break;
      case 'complete':
        matches = hasImage && hasDescription;
        break;
      default:
        matches = false;
    }

    switch (operator) {
      case ConditionOperator.equals:
        return matches;
      case ConditionOperator.notEquals:
        return !matches;
      default:
        return matches;
    }
  }

  bool _matchTextOperator(String text, String searchValue) {
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
      default:
        // Numeric operators don't apply to text
        return text.contains(searchValue);
    }
  }

  bool _matchNumericOperator(double actual, double expected) {
    switch (operator) {
      case ConditionOperator.equals:
        return actual == expected;
      case ConditionOperator.notEquals:
        return actual != expected;
      case ConditionOperator.lessThan:
        return actual < expected;
      case ConditionOperator.lessThanOrEqual:
        return actual <= expected;
      case ConditionOperator.greaterThan:
        return actual > expected;
      case ConditionOperator.greaterThanOrEqual:
        return actual >= expected;
      case ConditionOperator.withinDays:
        return actual <= expected;
      default:
        // Text operators don't apply to numbers
        return actual == expected;
    }
  }

  /// Creates a copy with optional field overrides.
  RuleCondition copyWith({
    ConditionType? type,
    ConditionOperator? operator,
    dynamic value,
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
  String toString() {
    final displayValue = type.isNumeric ? numericValue : '"$stringValue"';
    return 'RuleCondition(${type.label} ${operator.label} $displayValue)';
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
