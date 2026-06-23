import 'package:butlery/core/l10n/app_locale.dart';

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
    return switch (this) {
      ConditionOperator.contains => l.operatorContains,
      ConditionOperator.equals => l.operatorExact,
      ConditionOperator.startsWith => l.operatorStartsWith,
      ConditionOperator.notContains => l.operatorNotContains,
      ConditionOperator.notEquals => l.operatorNotExact,
      ConditionOperator.has => l.operatorHas,
      ConditionOperator.notHas => l.operatorNotHas,
      ConditionOperator.lessThan => l.operatorLessThan,
      ConditionOperator.lessThanOrEqual => l.operatorAtMost,
      ConditionOperator.greaterThan => l.operatorGreaterThan,
      ConditionOperator.greaterThanOrEqual => l.operatorAtLeast,
      ConditionOperator.withinDays => l.operatorWithinDays,
    };
  }

  /// Returns true if this operator works with numeric values.
  bool get isNumeric => switch (this) {
    ConditionOperator.lessThan ||
    ConditionOperator.lessThanOrEqual ||
    ConditionOperator.greaterThan ||
    ConditionOperator.greaterThanOrEqual ||
    ConditionOperator.withinDays => true,
    _ => false,
  };
}
