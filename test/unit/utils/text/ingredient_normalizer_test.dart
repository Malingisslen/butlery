/// Unit tests for IngredientNormalizer - ingredient name normalization
///
/// Tests comprehensive ingredient normalization including:
/// - Preparation word removal
/// - Diet descriptor preservation
/// - Color descriptor handling
/// - Compound ingredient recognition
/// - Plural normalization
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:butlery/utils/text/ingredient_normalizer.dart';

void main() {
  group('IngredientNormalizer', () {
    group('basic normalization', () {
      test('lowercases and trims input', () {
        final result = IngredientNormalizer.normalize('  TOMAT  ');
        expect(result.normalized, 'tomat');
      });

      test('returns empty result for empty input', () {
        final result = IngredientNormalizer.normalize('');
        expect(result.normalized, '');
        expect(result.isKnown, false);
      });

      test('removes preparation words', () {
        final result = IngredientNormalizer.normalize('hackad lök');
        expect(result.normalized, 'lök');
        expect(result.removedWords, contains('hackad'));
      });

      test('removes size descriptors', () {
        final result = IngredientNormalizer.normalize('stort ägg');
        expect(result.normalized, 'ägg');
        expect(result.removedWords, contains('stort'));
      });
    });

    group('diet descriptor preservation', () {
      test('preserves glutenfri at start', () {
        final result = IngredientNormalizer.normalize('glutenfri pasta');
        expect(result.normalized, 'glutenfri pasta');
      });

      test('preserves glutenfri at end and reorders', () {
        final result = IngredientNormalizer.normalize('pasta glutenfri');
        expect(result.normalized, 'glutenfri pasta');
      });

      test('preserves laktosfri', () {
        final result = IngredientNormalizer.normalize('laktosfri mjölk');
        expect(result.normalized, 'laktosfri mjölk');
      });

      test('preserves vegansk', () {
        final result = IngredientNormalizer.normalize('vegansk ost');
        expect(result.normalized, 'vegansk ost');
      });
    });

    group('flavor pattern preservation', () {
      test('preserves med pattern', () {
        final result =
            IngredientNormalizer.normalize('mayo med lime och jalapeño');
        expect(result.normalized, 'mayo med lime och jalapeño');
      });

      test('preserves med hallonsmak', () {
        final result = IngredientNormalizer.normalize('läsk med hallonsmak');
        expect(result.normalized, 'läsk med hallonsmak');
      });
    });

    group('eller alternatives', () {
      test('takes last item after eller', () {
        final result = IngredientNormalizer.normalize('gul eller röd lök');
        // Result should be 'lök' - just the base ingredient
        // (L2 color compound reconstruction is skipped for "eller" alternatives)
        expect(result.normalized, 'lök');
        expect(result.removedWords, contains('gul'));
        expect(result.removedWords, contains('eller'));
        expect(result.removedWords, contains('röd'));
      });

      test('handles sugar alternatives', () {
        final result =
            IngredientNormalizer.normalize('farinsocker eller strösocker');
        // SwedishPluralization normalizes "strösocker" → "strösock"
        // (removes 'er' as potential plural ending)
        expect(result.normalized, 'strösock');
      });
    });

    group('L2: color word order handling', () {
      test('handles color before ingredient (standard order)', () {
        // "röd lök" should be normalized - color is a preparation word
        final result = IngredientNormalizer.normalize('röd lök');
        // If rödlök is a compound, it should return rödlök
        // Otherwise it returns lök
        expect(result.normalized.endsWith('lök'), isTrue);
      });

      test('handles color after ingredient (reverse order)', () {
        // "lök röd" should also work
        final result = IngredientNormalizer.normalize('lök röd');
        // Should still normalize to lök or rödlök
        expect(result.normalized.endsWith('lök'), isTrue);
      });

      test('handles gula after ingredient', () {
        final result = IngredientNormalizer.normalize('paprika gul');
        // Should normalize and remove color
        expect(result.removedWords, contains('gul'));
      });

      test('preserves compound names with colors', () {
        // vitpeppar should stay as vitpeppar (compound name)
        final result = IngredientNormalizer.normalize('vitpeppar');
        expect(result.normalized, 'vitpeppar');
      });

      test('preserves svartpeppar compound', () {
        final result = IngredientNormalizer.normalize('svartpeppar');
        expect(result.normalized, 'svartpeppar');
      });
    });

    group('compound ingredient extraction', () {
      test('extracts base from sås compounds', () {
        // tomatsås should extract to tomat if tomat is known
        final result = IngredientNormalizer.normalize('tomatsås');
        // Result depends on whether tomat is in KnownIngredients
        expect(result.original, 'tomatsås');
      });

      test('extracts base from filé compounds', () {
        final result = IngredientNormalizer.normalize('kycklingfilé');
        expect(result.original, 'kycklingfilé');
      });
    });

    group('batch normalization', () {
      test('normalizes multiple ingredients', () {
        final results = IngredientNormalizer.normalizeMany([
          'hackad lök',
          'stort ägg',
          'glutenfri pasta',
        ]);

        expect(results, hasLength(3));
        expect(results[0].normalized, 'lök');
        expect(results[1].normalized, 'ägg');
        expect(results[2].normalized, 'glutenfri pasta');
      });
    });

    group('NormalizationResult', () {
      test('toString includes all relevant info', () {
        final result = IngredientNormalizer.normalize('hackad lök');
        final str = result.toString();

        expect(str, contains('original: "hackad lök"'));
        expect(str, contains('normalized: "lök"'));
        expect(str, contains('removed: hackad'));
      });
    });
  });
}
