/// Test data builders for PersonalTag and PersonalTagRule
///
/// Provides fluent API for creating test tags and rules with sensible defaults.
library;

import 'package:butlery/models/tagging/personal_tag.dart';
import 'package:butlery/models/tagging/personal_tag_rule.dart';
import 'package:uuid/uuid.dart';

/// Builder pattern for creating test PersonalTag instances.
class PersonalTagBuilder {
  String id = const Uuid().v4();
  String name = 'Test Tag';
  DateTime createdAt = DateTime.now();
  DateTime updatedAt = DateTime.now();
  int sortOrder = 0;
  String? groupId;
  List<PersonalTagRule> rules = [];

  /// Sets a specific ID.
  PersonalTagBuilder withId(String value) {
    id = value;
    return this;
  }

  /// Sets the tag name.
  PersonalTagBuilder withName(String value) {
    name = value;
    return this;
  }

  /// Sets the sort order.
  PersonalTagBuilder withSortOrder(int value) {
    sortOrder = value;
    return this;
  }

  /// Sets the group ID.
  PersonalTagBuilder withGroupId(String? value) {
    groupId = value;
    return this;
  }

  /// Sets the embedded rules.
  PersonalTagBuilder withRules(List<PersonalTagRule> value) {
    rules = value;
    return this;
  }

  /// Adds a single rule to the tag.
  PersonalTagBuilder withRule(PersonalTagRule rule) {
    rules.add(rule);
    return this;
  }

  /// Creates a "Swedish" tag preset.
  PersonalTagBuilder asSwedish() {
    name = 'Svenska';
    return this;
  }

  /// Creates a "Favorite" tag preset.
  PersonalTagBuilder asFavorite() {
    name = 'Favorit';
    return this;
  }

  /// Creates a "Quick" tag preset.
  PersonalTagBuilder asQuick() {
    name = 'Snabb';
    return this;
  }

  /// Builds the PersonalTag instance.
  PersonalTag build() {
    return PersonalTag(
      id: id,
      name: name,
      createdAt: createdAt,
      updatedAt: updatedAt,
      sortOrder: sortOrder,
      groupId: groupId,
      rules: rules,
    );
  }
}

/// Builder pattern for creating test PersonalTagRule instances.
class PersonalTagRuleBuilder {
  String id = const Uuid().v4();
  String tagId = const Uuid().v4();
  String name = 'Test Rule';
  List<RuleCondition> conditions = [];
  MatchMode matchMode = MatchMode.all;
  bool isEnabled = true;
  DateTime createdAt = DateTime.now();
  DateTime updatedAt = DateTime.now();

  /// Sets a specific ID.
  PersonalTagRuleBuilder withId(String value) {
    id = value;
    return this;
  }

  /// Sets the target tag ID.
  PersonalTagRuleBuilder withTagId(String value) {
    tagId = value;
    return this;
  }

  /// Sets the rule name.
  PersonalTagRuleBuilder withName(String value) {
    name = value;
    return this;
  }

  /// Sets the conditions list.
  PersonalTagRuleBuilder withConditions(List<RuleCondition> value) {
    conditions = value;
    return this;
  }

  /// Adds an ingredient condition.
  PersonalTagRuleBuilder withIngredientCondition(
    String value, {
    ConditionOperator operator = ConditionOperator.contains,
  }) {
    conditions.add(RuleCondition(
      type: ConditionType.ingredient,
      operator: operator,
      value: value,
    ));
    return this;
  }

  /// Adds a property condition.
  PersonalTagRuleBuilder withPropertyCondition(
    String value, {
    ConditionOperator operator = ConditionOperator.contains,
  }) {
    conditions.add(RuleCondition(
      type: ConditionType.property,
      operator: operator,
      value: value,
    ));
    return this;
  }

  /// Adds a keyword condition.
  PersonalTagRuleBuilder withKeywordCondition(
    String value, {
    ConditionOperator operator = ConditionOperator.contains,
  }) {
    conditions.add(RuleCondition(
      type: ConditionType.keyword,
      operator: operator,
      value: value,
    ));
    return this;
  }

  /// Adds a sourceUrl condition.
  PersonalTagRuleBuilder withSourceUrlCondition(
    String value, {
    ConditionOperator operator = ConditionOperator.contains,
  }) {
    conditions.add(RuleCondition(
      type: ConditionType.sourceUrl,
      operator: operator,
      value: value,
    ));
    return this;
  }

  /// Adds a cuisine condition.
  PersonalTagRuleBuilder withCuisineCondition(
    String value, {
    ConditionOperator operator = ConditionOperator.equals,
  }) {
    conditions.add(RuleCondition(
      type: ConditionType.cuisine,
      operator: operator,
      value: value,
    ));
    return this;
  }

  /// Adds a dietary condition.
  PersonalTagRuleBuilder withDietaryCondition(
    String value, {
    ConditionOperator operator = ConditionOperator.equals,
  }) {
    conditions.add(RuleCondition(
      type: ConditionType.dietary,
      operator: operator,
      value: value,
    ));
    return this;
  }

  /// Adds a time condition.
  PersonalTagRuleBuilder withTimeCondition(
    num value, {
    ConditionOperator operator = ConditionOperator.lessThan,
  }) {
    conditions.add(RuleCondition(
      type: ConditionType.time,
      operator: operator,
      value: value,
    ));
    return this;
  }

  /// Adds a rating condition.
  PersonalTagRuleBuilder withRatingCondition(
    num value, {
    ConditionOperator operator = ConditionOperator.greaterThanOrEqual,
  }) {
    conditions.add(RuleCondition(
      type: ConditionType.rating,
      operator: operator,
      value: value,
    ));
    return this;
  }

  /// Adds a recency condition.
  PersonalTagRuleBuilder withRecencyCondition(
    num value, {
    ConditionOperator operator = ConditionOperator.withinDays,
  }) {
    conditions.add(RuleCondition(
      type: ConditionType.recency,
      operator: operator,
      value: value,
    ));
    return this;
  }

  /// Sets the match mode.
  PersonalTagRuleBuilder withMatchMode(MatchMode value) {
    matchMode = value;
    return this;
  }

  /// Sets the enabled state.
  PersonalTagRuleBuilder withEnabled(bool value) {
    isEnabled = value;
    return this;
  }

  /// Creates a disabled rule.
  PersonalTagRuleBuilder asDisabled() {
    isEnabled = false;
    return this;
  }

  /// Creates a "Fish recipes" rule preset.
  PersonalTagRuleBuilder asFishRule() {
    name = 'Fiskrecept';
    conditions = [
      const RuleCondition(
        type: ConditionType.property,
        operator: ConditionOperator.contains,
        value: 'fish',
      ),
    ];
    matchMode = MatchMode.any;
    return this;
  }

  /// Creates a "Vegan recipes" rule preset.
  PersonalTagRuleBuilder asVeganRule() {
    name = 'Veganska recept';
    conditions = [
      const RuleCondition(
        type: ConditionType.property,
        operator: ConditionOperator.notContains,
        value: 'animal-product',
      ),
    ];
    matchMode = MatchMode.all;
    return this;
  }

  /// Builds the PersonalTagRule instance.
  PersonalTagRule build() {
    return PersonalTagRule(
      id: id,
      tagId: tagId,
      name: name,
      conditions: conditions,
      matchMode: matchMode,
      isEnabled: isEnabled,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }
}
