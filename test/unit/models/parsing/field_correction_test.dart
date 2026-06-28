/// Direct unit tests for [FieldCorrection] (BUT-1149 coverage burndown —
/// previously zero direct coverage).
///
/// Captures original→corrected edits for scalar recipe fields. The logic worth
/// pinning: the trim-aware hasDifference, the three create factories that return
/// null when nothing changed (string / int / duration, the last comparing whole
/// minutes), and JSON (de)serialization that omits nulls.
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/models/parsing/field_correction.dart';

void main() {
  group('hasDifference', () {
    test('false for identical or whitespace-only differences', () {
      expect(
        const FieldCorrection(
          originalValue: 'x',
          correctedValue: 'x',
        ).hasDifference,
        isFalse,
      );
      expect(
        const FieldCorrection(
          originalValue: ' x ',
          correctedValue: 'x',
        ).hasDifference,
        isFalse,
      );
    });

    test('true for a real change, including null↔value', () {
      expect(
        const FieldCorrection(
          originalValue: 'a',
          correctedValue: 'b',
        ).hasDifference,
        isTrue,
      );
      expect(
        const FieldCorrection(correctedValue: 'b').hasDifference,
        isTrue,
      );
    });
  });

  group('create (string)', () {
    test('returns null when there is no meaningful difference', () {
      expect(FieldCorrection.create(original: 'x', corrected: ' x '), isNull);
    });

    test('returns a correction when the values differ', () {
      final c = FieldCorrection.create(original: 'a', corrected: 'b');
      expect(c, isNotNull);
      expect(c!.originalValue, 'a');
      expect(c.correctedValue, 'b');
    });
  });

  group('createFromInt', () {
    test('returns null when the ints are equal', () {
      expect(FieldCorrection.createFromInt(original: 4, corrected: 4), isNull);
    });

    test('stringifies differing ints (and null)', () {
      final c = FieldCorrection.createFromInt(original: null, corrected: 6);
      expect(c, isNotNull);
      expect(c!.originalValue, isNull);
      expect(c.correctedValue, '6');
    });
  });

  group('createFromDuration', () {
    test('compares whole minutes — sub-minute equality is no change', () {
      expect(
        FieldCorrection.createFromDuration(
          original: const Duration(minutes: 1),
          corrected: const Duration(seconds: 90), // 1 minute
        ),
        isNull,
      );
    });

    test('records differing minutes as strings', () {
      final c = FieldCorrection.createFromDuration(
        original: const Duration(minutes: 30),
        corrected: const Duration(minutes: 45),
      );
      expect(c, isNotNull);
      expect(c!.originalValue, '30');
      expect(c.correctedValue, '45');
    });
  });

  group('JSON', () {
    test('toJson omits null fields', () {
      expect(const FieldCorrection(correctedValue: 'b').toJson(), {
        'corrected': 'b',
      });
    });

    test('round-trips through fromJson', () {
      const original = FieldCorrection(originalValue: 'a', correctedValue: 'b');
      final restored = FieldCorrection.fromJson(original.toJson());
      expect(restored.originalValue, 'a');
      expect(restored.correctedValue, 'b');
    });
  });
}
