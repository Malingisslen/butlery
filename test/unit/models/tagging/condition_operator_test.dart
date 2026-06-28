/// Direct unit tests for [ConditionOperator] + its extension (BUT-1149 coverage
/// burndown — previously zero direct coverage).
///
/// Pure enum logic for personal-tag rule conditions: Firestore (de)serialization
/// (camelCase + snake_case aliases, case-insensitive, safe default), the numeric-
/// operator predicate, and that every operator has a non-empty localized label.
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/models/tagging/condition_operator.dart';

void main() {
  group('Firestore serialization', () {
    test('toFirestore is the enum name', () {
      expect(ConditionOperator.startsWith.toFirestore(), 'startsWith');
      expect(ConditionOperator.withinDays.toFirestore(), 'withinDays');
    });

    test('round-trips every operator', () {
      for (final op in ConditionOperator.values) {
        expect(
          ConditionOperatorExtension.fromFirestore(op.toFirestore()),
          op,
          reason: op.name,
        );
      }
    });

    test('accepts snake_case aliases', () {
      expect(
        ConditionOperatorExtension.fromFirestore('starts_with'),
        ConditionOperator.startsWith,
      );
      expect(
        ConditionOperatorExtension.fromFirestore('not_contains'),
        ConditionOperator.notContains,
      );
      expect(
        ConditionOperatorExtension.fromFirestore('greater_than_or_equal'),
        ConditionOperator.greaterThanOrEqual,
      );
      expect(
        ConditionOperatorExtension.fromFirestore('within_days'),
        ConditionOperator.withinDays,
      );
    });

    test('is case-insensitive', () {
      expect(
        ConditionOperatorExtension.fromFirestore('CONTAINS'),
        ConditionOperator.contains,
      );
      expect(
        ConditionOperatorExtension.fromFirestore('StartsWith'),
        ConditionOperator.startsWith,
      );
    });

    test('falls back to contains for null or unknown values', () {
      expect(
        ConditionOperatorExtension.fromFirestore(null),
        ConditionOperator.contains,
      );
      expect(
        ConditionOperatorExtension.fromFirestore('bogus'),
        ConditionOperator.contains,
      );
    });
  });

  group('isNumeric', () {
    test('true for the comparison + withinDays operators', () {
      for (final op in [
        ConditionOperator.lessThan,
        ConditionOperator.lessThanOrEqual,
        ConditionOperator.greaterThan,
        ConditionOperator.greaterThanOrEqual,
        ConditionOperator.withinDays,
      ]) {
        expect(op.isNumeric, isTrue, reason: op.name);
      }
    });

    test('false for the text + property operators', () {
      for (final op in [
        ConditionOperator.contains,
        ConditionOperator.equals,
        ConditionOperator.startsWith,
        ConditionOperator.notContains,
        ConditionOperator.notEquals,
        ConditionOperator.has,
        ConditionOperator.notHas,
      ]) {
        expect(op.isNumeric, isFalse, reason: op.name);
      }
    });
  });

  group('label', () {
    test('every operator has a non-empty localized label', () {
      for (final op in ConditionOperator.values) {
        expect(op.label.trim(), isNotEmpty, reason: op.name);
      }
    });
  });
}
