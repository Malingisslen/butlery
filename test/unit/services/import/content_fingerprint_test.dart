import 'package:flutter_test/flutter_test.dart';
import 'package:butlery/services/import/cache/content_fingerprint.dart';

void main() {
  late ContentFingerprint fingerprinter;

  setUp(() {
    fingerprinter = ContentFingerprint();
  });

  group('ingredientSimilarity', () {
    test('returns 1.0 for identical ingredient lists', () {
      final score = fingerprinter.ingredientSimilarity(
        ['2 dl mjol', '3 agg', '5 dl mjolk'],
        ['2 dl mjol', '3 agg', '5 dl mjolk'],
      );
      expect(score, 1.0);
    });

    test('returns 0.0 when one list is empty', () {
      expect(fingerprinter.ingredientSimilarity([], ['mjol']), 0.0);
      expect(fingerprinter.ingredientSimilarity(['mjol'], []), 0.0);
    });

    test('returns partial score for overlapping lists', () {
      final score = fingerprinter.ingredientSimilarity(
        ['mjol', 'agg', 'mjolk', 'smor'],
        ['mjol', 'agg', 'mjolk', 'socker'],
      );
      // 3 common out of 5 unique = 0.6
      expect(score, closeTo(0.6, 0.1));
    });

    test('handles quantity normalization', () {
      final score = fingerprinter.ingredientSimilarity(
        ['2 dl mjol', '3 st agg'],
        ['5 dl mjol', '6 st agg'],
      );
      // Same ingredient names after normalization
      expect(score, 1.0);
    });

    test('returns 0.0 for completely different lists', () {
      final score = fingerprinter.ingredientSimilarity(
        ['kyckling', 'ris', 'sojasas'],
        ['lax', 'potatis', 'dill'],
      );
      expect(score, 0.0);
    });
  });

  group('recipeSimilarity', () {
    test('returns 1.0 for identical recipes', () {
      final score = fingerprinter.recipeSimilarity(
        titleA: 'Pannkakor med sylt',
        ingredientsA: ['mjol', 'agg', 'mjolk'],
        titleB: 'Pannkakor med sylt',
        ingredientsB: ['mjol', 'agg', 'mjolk'],
      );
      expect(score, 1.0);
    });

    test('returns high score for same recipe, different source', () {
      final score = fingerprinter.recipeSimilarity(
        titleA: 'Pannkakor',
        ingredientsA: ['mjol', 'agg', 'mjolk', 'smor'],
        titleB: 'Klassiska pannkakor',
        ingredientsB: ['mjol', 'agg', 'mjolk', 'smor', 'salt'],
      );
      // Title overlap is partial, ingredients mostly overlap
      expect(score, greaterThan(0.5));
    });

    test('returns low score for completely different recipes', () {
      final score = fingerprinter.recipeSimilarity(
        titleA: 'Pannkakor',
        ingredientsA: ['mjol', 'agg', 'mjolk'],
        titleB: 'Kottbullar med potatis',
        ingredientsB: ['farskott', 'lok', 'potatis', 'gradde'],
      );
      expect(score, lessThan(0.3));
    });

    test('weights ingredients more than title (70/30)', () {
      // Same ingredients, different title
      final sameIngScore = fingerprinter.recipeSimilarity(
        titleA: 'Pannkakor',
        ingredientsA: ['mjol', 'agg', 'mjolk'],
        titleB: 'Crepes',
        ingredientsB: ['mjol', 'agg', 'mjolk'],
      );
      // Same title, different ingredients
      final sameTitleScore = fingerprinter.recipeSimilarity(
        titleA: 'Pannkakor',
        ingredientsA: ['mjol', 'agg', 'mjolk'],
        titleB: 'Pannkakor',
        ingredientsB: ['kyckling', 'ris', 'soja'],
      );
      // Ingredient match should score higher than title match
      expect(sameIngScore, greaterThan(sameTitleScore));
    });
  });
}
