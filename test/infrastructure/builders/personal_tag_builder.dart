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
  String? color = '#4CAF50';
  String? icon;
  DateTime createdAt = DateTime.now();
  DateTime updatedAt = DateTime.now();
  int sortOrder = 0;

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

  /// Sets the tag color (hex format).
  PersonalTagBuilder withColor(String? value) {
    color = value;
    return this;
  }

  /// Sets the tag icon (emoji or icon name).
  PersonalTagBuilder withIcon(String? value) {
    icon = value;
    return this;
  }

  /// Sets the sort order.
  PersonalTagBuilder withSortOrder(int value) {
    sortOrder = value;
    return this;
  }

  /// Creates a "Swedish" tag preset.
  PersonalTagBuilder asSwedish() {
    name = 'Svenska';
    color = '#1976D2';
    icon = '\u{1F1F8}\u{1F1EA}'; // Swedish flag
    return this;
  }

  /// Creates a "Favorite" tag preset.
  PersonalTagBuilder asFavorite() {
    name = 'Favorit';
    color = '#E91E63';
    icon = '\u{2764}\u{FE0F}'; // Heart
    return this;
  }

  /// Creates a "Quick" tag preset.
  PersonalTagBuilder asQuick() {
    name = 'Snabb';
    color = '#FF9800';
    icon = '\u{26A1}'; // Lightning
    return this;
  }

  /// Builds the PersonalTag instance.
  PersonalTag build() {
    return PersonalTag(
      id: id,
      name: name,
      color: color,
      icon: icon,
      createdAt: createdAt,
      updatedAt: updatedAt,
      sortOrder: sortOrder,
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
