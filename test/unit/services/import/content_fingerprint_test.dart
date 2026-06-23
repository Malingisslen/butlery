import 'package:flutter_test/flutter_test.dart';
import 'package:butlery/services/import/cache/content_fingerprint.dart';

void main() {
  late ContentFingerprint fingerprinter;

  setUp(() {
    fingerprinter = ContentFingerprint();
  });

  group('generate', () {
    test('returns null for empty title', () {
      expect(
        fingerprinter.generate(
          title: '',
          ingredients: ['mjol'],
          instructionCount: 1,
        ),
        isNull,
      );
    });

    test('returns null for empty ingredients', () {
      expect(
        fingerprinter.generate(
          title: 'Pannkakor',
          ingredients: [],
          instructionCount: 1,
        ),
        isNull,
      );
    });

    test('returns a 16-character hash for valid input', () {
      final hash = fingerprinter.generate(
        title: 'Pannkakor med sylt',
        ingredients: ['3 dl mjol', '5 dl mjolk', '3 st agg', 'smor'],
        instructionCount: 4,
      );
      expect(hash, isNotNull);
      expect(hash!.length, 16);
    });

    test('same input produces same hash', () {
      final h1 = fingerprinter.generate(
        title: 'Pannkakor',
        ingredients: ['mjol', 'mjolk', 'agg'],
        instructionCount: 3,
      );
      final h2 = fingerprinter.generate(
        title: 'Pannkakor',
        ingredients: ['mjol', 'mjolk', 'agg'],
        instructionCount: 3,
      );
      expect(h1, equals(h2));
    });

    test('different titles produce different hashes', () {
      final h1 = fingerprinter.generate(
        title: 'Pannkakor',
        ingredients: ['mjol', 'mjolk'],
        instructionCount: 2,
      );
      final h2 = fingerprinter.generate(
        title: 'Kottbullar',
        ingredients: ['mjol', 'mjolk'],
        instructionCount: 2,
      );
      expect(h1, isNot(equals(h2)));
    });
  });

  group('similarity (hash-based)', () {
    test('returns 1.0 for identical fingerprints', () {
      expect(fingerprinter.similarity('abc123', 'abc123'), 1.0);
    });

    test('returns 0.0 for different fingerprints', () {
      expect(fingerprinter.similarity('abc123', 'def456'), 0.0);
    });

    test('returns 0.0 when either is null', () {
      expect(fingerprinter.similarity(null, 'abc'), 0.0);
      expect(fingerprinter.similarity('abc', null), 0.0);
    });
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
