/// Unit tests for IngredientLineDetector.
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/services/import/heuristics/ingredient_line_detector.dart';

void main() {
  group('looksLikeIngredient', () {
    test('false for empty / whitespace-only lines', () {
      expect(IngredientLineDetector.looksLikeIngredient(''), isFalse);
      expect(IngredientLineDetector.looksLikeIngredient('   '), isFalse);
    });

    test('false for too-short lines (< 3 chars after trim)', () {
      expect(IngredientLineDetector.looksLikeIngredient('a'), isFalse);
      expect(IngredientLineDetector.looksLikeIngredient('ab'), isFalse);
    });

    test('false for too-long lines (> 100 chars)', () {
      final long = 'a' * 101;
      expect(IngredientLineDetector.looksLikeIngredient(long), isFalse);
    });

    test('true when a Swedish unit word matches as a whole word', () {
      for (final unit in IngredientLineDetector.measurements) {
        expect(
          IngredientLineDetector.looksLikeIngredient('2 $unit mjölk'),
          isTrue,
          reason: unit,
        );
      }
    });

    test('false when unit appears as a substring of another word', () {
      // "gloss" contains "g" but not as a word boundary
      expect(
        IngredientLineDetector.looksLikeIngredient('gloss is shiny'),
        isFalse,
      );
      // "milligram" contains "g" but not as a whole word
      expect(
        IngredientLineDetector.looksLikeIngredient('milligrampower'),
        isFalse,
      );
    });

    test('true when line starts with a digit', () {
      expect(IngredientLineDetector.looksLikeIngredient('2 äpplen'), isTrue);
      expect(IngredientLineDetector.looksLikeIngredient('15 minuter'), isTrue);
    });

    test('true when line starts with a Unicode fraction', () {
      expect(IngredientLineDetector.looksLikeIngredient('½ tomat'), isTrue);
      expect(IngredientLineDetector.looksLikeIngredient('¼ kopp'), isTrue);
      expect(IngredientLineDetector.looksLikeIngredient('¾ banan'), isTrue);
      expect(IngredientLineDetector.looksLikeIngredient('⅓ avokado'), isTrue);
    });

    test('false for plain prose without unit / leading digit', () {
      expect(
        IngredientLineDetector.looksLikeIngredient('Stek köttet i pannan'),
        isFalse,
      );
      expect(
        IngredientLineDetector.looksLikeIngredient('Häll i mjölken försiktigt'),
        isFalse,
      );
    });

    test('case-insensitive unit matching', () {
      expect(IngredientLineDetector.looksLikeIngredient('2 DL Mjölk'), isTrue);
      expect(IngredientLineDetector.looksLikeIngredient('1 KG Kött'), isTrue);
    });
  });

  group('findIngredientLines', () {
    test('returns empty list for empty input', () {
      expect(IngredientLineDetector.findIngredientLines([]), isEmpty);
    });

    test('returns indices of matching lines, in input order', () {
      final lines = [
        'Recept för pasta',
        '2 dl mjölk',
        'Häll i mjölken i en kastrull',
        '500 g pasta',
        '½ tomat',
        '',
      ];
      expect(
        IngredientLineDetector.findIngredientLines(lines),
        [1, 3, 4],
      );
    });

    test('mixed content: prose and ingredient lines', () {
      final lines = [
        '1 kg potatis',
        'Skala potatisarna',
        '2 msk olja',
      ];
      expect(IngredientLineDetector.findIngredientLines(lines), [0, 2]);
    });
  });

  test('measurements list contains expected Swedish units', () {
    expect(IngredientLineDetector.measurements, contains('dl'));
    expect(IngredientLineDetector.measurements, contains('msk'));
    expect(IngredientLineDetector.measurements, contains('tsk'));
    expect(IngredientLineDetector.measurements, contains('g'));
    expect(IngredientLineDetector.measurements, contains('kg'));
    expect(IngredientLineDetector.measurements, contains('st'));
  });
}
