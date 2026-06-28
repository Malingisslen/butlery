/// Direct unit tests for [ConditionType] + its extension (BUT-1149 coverage
/// burndown — previously zero direct coverage).
///
/// Pure enum logic for personal-tag rule condition types: Firestore
/// (de)serialization (camelCase + snake_case aliases, case-insensitive, safe
/// keyword default), the numeric/boolean value-kind predicates, and a non-empty
/// localized label for every type.
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/models/tagging/condition_type.dart';

void main() {
  group('Firestore serialization', () {
    test('toFirestore is the enum name', () {
      expect(ConditionType.sourceUrl.toFirestore(), 'sourceUrl');
      expect(ConditionType.cookedRecency.toFirestore(), 'cookedRecency');
    });

    test('round-trips every type', () {
      for (final t in ConditionType.values) {
        expect(
          ConditionTypeExtension.fromFirestore(t.toFirestore()),
          t,
          reason: t.name,
        );
      }
    });

    test('accepts snake_case aliases', () {
      expect(
        ConditionTypeExtension.fromFirestore('source_url'),
        ConditionType.sourceUrl,
      );
      expect(
        ConditionTypeExtension.fromFirestore('cooked_recency'),
        ConditionType.cookedRecency,
      );
      expect(
        ConditionTypeExtension.fromFirestore('has_image'),
        ConditionType.hasImage,
      );
    });

    test('is case-insensitive', () {
      expect(
        ConditionTypeExtension.fromFirestore('INGREDIENT'),
        ConditionType.ingredient,
      );
    });

    test('falls back to keyword for null or unknown values', () {
      expect(
        ConditionTypeExtension.fromFirestore(null),
        ConditionType.keyword,
      );
      expect(
        ConditionTypeExtension.fromFirestore('bogus'),
        ConditionType.keyword,
      );
    });
  });

  group('value-kind predicates', () {
    test('isNumeric is true for time/rating/recency/cookedRecency only', () {
      for (final t in ConditionType.values) {
        final expected = const {
          ConditionType.time,
          ConditionType.rating,
          ConditionType.recency,
          ConditionType.cookedRecency,
        }.contains(t);
        expect(t.isNumeric, expected, reason: t.name);
      }
    });

    test('isBoolean is true for hasImage only', () {
      for (final t in ConditionType.values) {
        expect(t.isBoolean, t == ConditionType.hasImage, reason: t.name);
      }
    });
  });

  group('label', () {
    test('every type has a non-empty localized label', () {
      for (final t in ConditionType.values) {
        expect(t.label.trim(), isNotEmpty, reason: t.name);
      }
    });
  });
}
