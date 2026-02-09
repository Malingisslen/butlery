import 'package:butlery/models/tagging/personal_tag_rule.dart';

/// Central registry of valid operators per condition type.
///
/// Both TagDetailView and PersonalTagRuleDialog use this to ensure
/// only valid operator/type combinations are presented to users.
class OperatorRegistry {
  OperatorRegistry._();

  /// Returns the list of valid operators for a given condition type.
  static List<ConditionOperator> getValidOperators(ConditionType type) {
    if (type.isNumeric) {
      return [
        ConditionOperator.lessThan,
        ConditionOperator.lessThanOrEqual,
        ConditionOperator.greaterThan,
        ConditionOperator.greaterThanOrEqual,
        ConditionOperator.equals,
        if (type == ConditionType.recency) ConditionOperator.withinDays,
      ];
    }
    if (type == ConditionType.property) {
      return [ConditionOperator.has, ConditionOperator.notHas];
    }
    return [
      ConditionOperator.contains,
      ConditionOperator.equals,
      ConditionOperator.startsWith,
      ConditionOperator.notContains,
      ConditionOperator.notEquals,
    ];
  }

  /// Returns true if the given operator is valid for the condition type.
  static bool isValidCombination(
    ConditionType type,
    ConditionOperator operator,
  ) {
    return getValidOperators(type).contains(operator);
  }
}
