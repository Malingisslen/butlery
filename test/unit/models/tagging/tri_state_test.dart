import 'package:flutter_test/flutter_test.dart';
import 'package:butlery/models/tagging/tri_state.dart';

void main() {
  group('TriState', () {
    group('orCombine', () {
      test('CONTAINS + anything = CONTAINS', () {
        expect(
          TriState.contains.orCombine(TriState.contains),
          TriState.contains,
        );
        expect(
          TriState.contains.orCombine(TriState.free),
          TriState.contains,
        );
        expect(
          TriState.contains.orCombine(TriState.unknown),
          TriState.contains,
        );
      });

      test('UNKNOWN + non-CONTAINS = UNKNOWN', () {
        expect(
          TriState.unknown.orCombine(TriState.unknown),
          TriState.unknown,
        );
        expect(
          TriState.unknown.orCombine(TriState.free),
          TriState.unknown,
        );
        expect(
          TriState.free.orCombine(TriState.unknown),
          TriState.unknown,
        );
      });

      test('FREE + FREE = FREE', () {
        expect(
          TriState.free.orCombine(TriState.free),
          TriState.free,
        );
      });

      test('priority order: CONTAINS > UNKNOWN > FREE', () {
        // Almond (tree-nut: CONTAINS) + unknown peanut (UNKNOWN) = CONTAINS
        expect(
          TriState.contains.orCombine(TriState.unknown),
          TriState.contains,
        );

        // No tree nuts (FREE) + unknown peanut (UNKNOWN) = UNKNOWN
        expect(
          TriState.free.orCombine(TriState.unknown),
          TriState.unknown,
        );

        // No tree nuts (FREE) + no peanuts (FREE) = FREE
        expect(
          TriState.free.orCombine(TriState.free),
          TriState.free,
        );
      });
    });

    group('andCombine', () {
      test('CONTAINS + anything = CONTAINS', () {
        expect(
          TriState.contains.andCombine(TriState.contains),
          TriState.contains,
        );
        expect(
          TriState.contains.andCombine(TriState.free),
          TriState.contains,
        );
        expect(
          TriState.contains.andCombine(TriState.unknown),
          TriState.contains,
        );
      });

      test('UNKNOWN + non-CONTAINS = UNKNOWN', () {
        expect(
          TriState.unknown.andCombine(TriState.unknown),
          TriState.unknown,
        );
        expect(
          TriState.unknown.andCombine(TriState.free),
          TriState.unknown,
        );
        expect(
          TriState.free.andCombine(TriState.unknown),
          TriState.unknown,
        );
      });

      test('FREE + FREE = FREE', () {
        expect(
          TriState.free.andCombine(TriState.free),
          TriState.free,
        );
      });
    });

    group('convenience getters', () {
      test('isFree returns true only for FREE', () {
        expect(TriState.free.isFree, isTrue);
        expect(TriState.contains.isFree, isFalse);
        expect(TriState.unknown.isFree, isFalse);
      });

      test('containsAllergen returns true only for CONTAINS', () {
        expect(TriState.contains.containsAllergen, isTrue);
        expect(TriState.free.containsAllergen, isFalse);
        expect(TriState.unknown.containsAllergen, isFalse);
      });

      test('isUnknown returns true only for UNKNOWN', () {
        expect(TriState.unknown.isUnknown, isTrue);
        expect(TriState.contains.isUnknown, isFalse);
        expect(TriState.free.isUnknown, isFalse);
      });
    });

    group('Firestore serialization', () {
      test('toFirestore returns lowercase string matching enum name', () {
        expect(TriState.contains.toFirestore(), 'contains');
        expect(TriState.free.toFirestore(), 'free');
        expect(TriState.unknown.toFirestore(), 'unknown');
      });

      test('fromFirestore parses valid strings case-insensitively', () {
        expect(TriStateExtension.fromFirestore('CONTAINS'), TriState.contains);
        expect(TriStateExtension.fromFirestore('contains'), TriState.contains);
        expect(TriStateExtension.fromFirestore('Contains'), TriState.contains);

        expect(TriStateExtension.fromFirestore('FREE'), TriState.free);
        expect(TriStateExtension.fromFirestore('free'), TriState.free);

        expect(TriStateExtension.fromFirestore('UNKNOWN'), TriState.unknown);
        expect(TriStateExtension.fromFirestore('unknown'), TriState.unknown);
      });

      test('fromFirestore defaults to UNKNOWN for invalid input', () {
        expect(TriStateExtension.fromFirestore(null), TriState.unknown);
        expect(TriStateExtension.fromFirestore(''), TriState.unknown);
        expect(TriStateExtension.fromFirestore('invalid'), TriState.unknown);
      });

      test('roundtrip serialization preserves value', () {
        for (final state in TriState.values) {
          final serialized = state.toFirestore();
          final deserialized = TriStateExtension.fromFirestore(serialized);
          expect(deserialized, state);
        }
      });
    });
  });

  group('TriStateCalculator', () {
    group('orAll', () {
      test('empty list returns UNKNOWN', () {
        expect(TriStateCalculator.orAll([]), TriState.unknown);
      });

      test('single value returns that value', () {
        expect(
          TriStateCalculator.orAll([TriState.contains]),
          TriState.contains,
        );
        expect(TriStateCalculator.orAll([TriState.free]), TriState.free);
        expect(TriStateCalculator.orAll([TriState.unknown]), TriState.unknown);
      });

      test('returns CONTAINS if any is CONTAINS', () {
        expect(
          TriStateCalculator.orAll([
            TriState.free,
            TriState.contains,
            TriState.free,
          ]),
          TriState.contains,
        );
      });

      test('returns UNKNOWN if any is UNKNOWN and none is CONTAINS', () {
        expect(
          TriStateCalculator.orAll([
            TriState.free,
            TriState.unknown,
            TriState.free,
          ]),
          TriState.unknown,
        );
      });

      test('returns FREE only if all are FREE', () {
        expect(
          TriStateCalculator.orAll([
            TriState.free,
            TriState.free,
            TriState.free,
          ]),
          TriState.free,
        );
      });
    });

    group('andAll', () {
      test('empty list returns UNKNOWN', () {
        expect(TriStateCalculator.andAll([]), TriState.unknown);
      });

      test('returns CONTAINS if any is CONTAINS', () {
        expect(
          TriStateCalculator.andAll([
            TriState.free,
            TriState.contains,
            TriState.free,
          ]),
          TriState.contains,
        );
      });

      test('returns UNKNOWN if any is UNKNOWN and none is CONTAINS', () {
        expect(
          TriStateCalculator.andAll([
            TriState.free,
            TriState.unknown,
            TriState.free,
          ]),
          TriState.unknown,
        );
      });

      test('returns FREE only if all are FREE', () {
        expect(
          TriStateCalculator.andAll([
            TriState.free,
            TriState.free,
            TriState.free,
          ]),
          TriState.free,
        );
      });
    });
  });
}
