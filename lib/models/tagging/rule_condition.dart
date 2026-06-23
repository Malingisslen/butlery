import 'package:clock/clock.dart';
import 'package:flutter/foundation.dart';

import 'package:butlery/core/utils/serialization_utils.dart';
import 'package:butlery/core/extensions/default_value_extensions.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/models/tagging/ingredient_lookup_result.dart';
import 'package:butlery/models/tagging/tri_state.dart';
import 'package:butlery/models/tagging/condition_type.dart';
import 'package:butlery/models/tagging/condition_operator.dart';

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
        data['operator']?.toString(),
      ),
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
      case ConditionType.cookedRecency:
        return _evaluateCookedRecency(recipe);
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
    final description = caseSensitive
        ? recipe.description
        : recipe.description.toLowerCase();
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
        return tagResult.tags.any(
          (tag) => tag.toLowerCase().contains(cuisineValue),
        );
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
      timeMinutes.toDouble(),
      numericValue.toDouble(),
    );
  }

  bool _evaluateRating(Recipe recipe) {
    // User rating is stored as 'rating' field on RecipeCore
    final rating = recipe.core.rating ?? 0;
    return _matchNumericOperator(rating.toDouble(), numericValue.toDouble());
  }

  bool _evaluateRecency(Recipe recipe) {
    final createdAt = recipe.core.createdAt;
    final daysSinceCreated = clock.now().difference(createdAt).inDays;

    // For recency, withinDays is the primary operator
    if (operator == ConditionOperator.withinDays) {
      return daysSinceCreated <= numericValue;
    }

    return _matchNumericOperator(
      daysSinceCreated.toDouble(),
      numericValue.toDouble(),
    );
  }

  /// Evaluates days since last cooked. Never-cooked recipes use max int.
  bool _evaluateCookedRecency(Recipe recipe) {
    final lastCooked = recipe.core.lastCookedAt;
    // Never cooked = treat as infinitely old for greaterThan comparisons
    final daysSinceCooked = lastCooked == null
        ? 999999
        : clock.now().difference(lastCooked).inDays;

    if (operator == ConditionOperator.withinDays) {
      return daysSinceCooked <= numericValue;
    }

    return _matchNumericOperator(
      daysSinceCooked.toDouble(),
      numericValue.toDouble(),
    );
  }

  /// Evaluates ownership condition.
  /// Values: 'mine', 'shared', 'collaborative', 'public'
  bool _evaluateOwnership(Recipe recipe, String? currentUserId) {
    final ownershipValue = stringValue.toLowerCase().trim();

    // Get ownership info from recipe and its socialData
    final ownerId = recipe.socialData?.ownerId ?? recipe.core.createdBy;
    final isCollaborative =
        recipe.type == RecipeType.collaborative ||
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
