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
