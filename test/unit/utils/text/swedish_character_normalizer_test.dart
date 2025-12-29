import 'package:flutter_test/flutter_test.dart';
import 'package:butlery/utils/text/swedish_character_normalizer.dart';

/// CRIT-5: Swedish Character Normalization Consistency Tests
///
/// These tests verify that the Dart normalization matches the expected
/// contract that TypeScript must also follow.
///
/// The TypeScript implementation is in:
/// `functions/src/ingredients/on-ingredient-soft-deleted.ts`
///
/// If these tests fail, the cascade retagging system will break silently.
void main() {
  group('SwedishCharacterNormalizer', () {
    group('normalize', () {
      test('converts å to a', () {
        expect(SwedishCharacterNormalizer.normalize('å'), equals('a'));
        expect(SwedishCharacterNormalizer.normalize('Å'), equals('a'));
        expect(SwedishCharacterNormalizer.normalize('åå'), equals('aa'));
      });

      test('converts ä to a', () {
        expect(SwedishCharacterNormalizer.normalize('ä'), equals('a'));
        expect(SwedishCharacterNormalizer.normalize('Ä'), equals('a'));
        expect(SwedishCharacterNormalizer.normalize('ää'), equals('aa'));
      });

      test('converts ö to o', () {
        expect(SwedishCharacterNormalizer.normalize('ö'), equals('o'));
        expect(SwedishCharacterNormalizer.normalize('Ö'), equals('o'));
        expect(SwedishCharacterNormalizer.normalize('öö'), equals('oo'));
      });

      test('lowercases input', () {
        expect(SwedishCharacterNormalizer.normalize('ABC'), equals('abc'));
        expect(SwedishCharacterNormalizer.normalize('Hello'), equals('hello'));
      });

      test('handles empty string', () {
        expect(SwedishCharacterNormalizer.normalize(''), equals(''));
      });

      test('preserves non-Swedish characters', () {
        expect(
            SwedishCharacterNormalizer.normalize('abc123'), equals('abc123'));
        expect(SwedishCharacterNormalizer.normalize('hello world'),
            equals('hello world'));
        expect(SwedishCharacterNormalizer.normalize('test-string'),
            equals('test-string'));
      });
    });

    group('CRIT-5: test vectors for TypeScript consistency', () {
      // These tests document the exact expected output for each input.
      // The TypeScript implementation MUST produce identical results.

      test('all test vectors produce expected output', () {
        for (final entry in SwedishCharacterNormalizer.testVectors.entries) {
          final input = entry.key;
          final expectedOutput = entry.value;
          final actualOutput = SwedishCharacterNormalizer.normalize(input);

          expect(
            actualOutput,
            equals(expectedOutput),
            reason:
                'normalize("$input") should be "$expectedOutput" but was "$actualOutput"',
          );
        }
      });

      // Individual test cases for documentation
      test('Köttfärs → kottfars', () {
        expect(SwedishCharacterNormalizer.normalize('Köttfärs'),
            equals('kottfars'));
      });

      test('Räkor → rakor', () {
        expect(SwedishCharacterNormalizer.normalize('Räkor'), equals('rakor'));
      });

      test('Ägg → agg', () {
        expect(SwedishCharacterNormalizer.normalize('Ägg'), equals('agg'));
      });

      test('Löksoppa → loksoppa', () {
        expect(SwedishCharacterNormalizer.normalize('Löksoppa'),
            equals('loksoppa'));
      });

      test('Grädde → gradde', () {
        expect(
            SwedishCharacterNormalizer.normalize('Grädde'), equals('gradde'));
      });

      test('Smör → smor', () {
        expect(SwedishCharacterNormalizer.normalize('Smör'), equals('smor'));
      });

      test('Mjölk → mjolk', () {
        expect(SwedishCharacterNormalizer.normalize('Mjölk'), equals('mjolk'));
      });

      test('fläsk → flask', () {
        expect(SwedishCharacterNormalizer.normalize('fläsk'), equals('flask'));
      });

      test('vitlök → vitlok', () {
        expect(
            SwedishCharacterNormalizer.normalize('vitlök'), equals('vitlok'));
      });

      test('åäö → aao (all three Swedish chars)', () {
        expect(SwedishCharacterNormalizer.normalize('åäö'), equals('aao'));
      });
    });

    group('normalizeAll', () {
      test('normalizes list of strings', () {
        final inputs = ['Köttfärs', 'Räkor', 'Ägg'];
        final expected = ['kottfars', 'rakor', 'agg'];

        expect(
            SwedishCharacterNormalizer.normalizeAll(inputs), equals(expected));
      });

      test('handles empty list', () {
        expect(SwedishCharacterNormalizer.normalizeAll([]), equals([]));
      });
    });

    group('edge cases', () {
      test('handles strings with only Swedish characters', () {
        expect(SwedishCharacterNormalizer.normalize('åäö'), equals('aao'));
        expect(SwedishCharacterNormalizer.normalize('ÅÄÖ'), equals('aao'));
      });

      test('handles strings with repeated Swedish characters', () {
        expect(SwedishCharacterNormalizer.normalize('ååååäääöö'),
            equals('aaaaaaaoo'));
      });

      test('handles mixed Swedish and regular characters', () {
        expect(
          SwedishCharacterNormalizer.normalize('Rödbetssoppa med gräddfil'),
          equals('rodbetssoppa med graddfil'),
        );
      });

      test('handles numbers and special characters', () {
        expect(
          SwedishCharacterNormalizer.normalize('2 dl grädde'),
          equals('2 dl gradde'),
        );
        expect(
          SwedishCharacterNormalizer.normalize('röd-lök'),
          equals('rod-lok'),
        );
      });
    });
  });
}
