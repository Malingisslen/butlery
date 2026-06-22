import 'package:flutter_test/flutter_test.dart';
import 'package:butlery/models/parsing/parsed_ingredient.dart';
import 'package:butlery/models/parsing/field_result.dart';
import 'package:butlery/services/parsing/ingredient_parsing_strategy.dart';

void main() {
  late IngredientParsingStrategy strategy;

  setUp(() {
    strategy = IngredientParsingStrategy();
  });

  group('getUncertainLineIndices', () {
    test('should return empty list when all lines are high confidence', () {
      final parsed = [
        _ingredient('mjölk', ParseConfidence.high),
        _ingredient('smör', ParseConfidence.high),
        _ingredient('socker', ParseConfidence.high),
      ];

      final indices = strategy.getUncertainLineIndices(parsed);
      expect(indices, isEmpty);
    });

    test('should return indices of low confidence lines', () {
      final parsed = [
        _ingredient('2 dl mjölk', ParseConfidence.high),
        _ingredient('lite salt', ParseConfidence.low),
        _ingredient('1 msk socker', ParseConfidence.high),
        _ingredient('kryddor', ParseConfidence.low),
      ];

      final indices = strategy.getUncertainLineIndices(parsed);
      expect(indices, [1, 3]);
    });

    test('should return indices of medium confidence lines', () {
      // medium has score 0.7, which is NOT < 0.7, so medium should NOT be included
      final parsed = [
        _ingredient('mjölk', ParseConfidence.medium),
        _ingredient('smör', ParseConfidence.high),
      ];

      final indices = strategy.getUncertainLineIndices(parsed);
      expect(indices, isEmpty);
    });

    test('should include failed confidence lines', () {
      final parsed = [
        _ingredient('???', ParseConfidence.failed),
        _ingredient('mjölk', ParseConfidence.high),
      ];

      final indices = strategy.getUncertainLineIndices(parsed);
      expect(indices, [0]);
    });

    test('should return all indices when all lines are uncertain', () {
      final parsed = [
        _ingredient('a', ParseConfidence.low),
        _ingredient('b', ParseConfidence.low),
        _ingredient('c', ParseConfidence.failed),
      ];

      final indices = strategy.getUncertainLineIndices(parsed);
      expect(indices, [0, 1, 2]);
    });

    test('should return empty list for empty input', () {
      final indices = strategy.getUncertainLineIndices([]);
      expect(indices, isEmpty);
    });
  });

  group('shouldEnhanceSelectively (minority gate)', () {
    test('no uncertain lines → full path (no selective enhancement)', () {
      // All 4 lines confident → nothing to selectively enhance.
      expect(
        IngredientParsingStrategy.shouldEnhanceSelectively(
          uncertainCount: 0,
          totalCount: 4,
        ),
        isFalse,
      );
    });

    test('small minority uncertain → selective path chosen', () {
      // 1 of 8 lines uncertain → cheap to re-parse just that line.
      expect(
        IngredientParsingStrategy.shouldEnhanceSelectively(
          uncertainCount: 1,
          totalCount: 8,
        ),
        isTrue,
      );
    });

    test('exactly half uncertain → still selective (boundary, not majority)',
        () {
      // 2 of 4 is not a *majority*, so selective remains worthwhile.
      expect(
        IngredientParsingStrategy.shouldEnhanceSelectively(
          uncertainCount: 2,
          totalCount: 4,
        ),
        isTrue,
      );
    });

    test('majority uncertain → full enhancement, not selective', () {
      // 3 of 4 uncertain → a full LLM pass is better than patching most lines.
      expect(
        IngredientParsingStrategy.shouldEnhanceSelectively(
          uncertainCount: 3,
          totalCount: 4,
        ),
        isFalse,
      );
    });

    test('empty recipe → no selective enhancement', () {
      expect(
        IngredientParsingStrategy.shouldEnhanceSelectively(
          uncertainCount: 0,
          totalCount: 0,
        ),
        isFalse,
      );
    });
  });

  group('getUncertainLines', () {
    test('should return map of uncertain line indices to original text',
        () async {
      final parsed = [
        _ingredient('2 dl mjölk', ParseConfidence.high),
        _ingredient('lite salt', ParseConfidence.low),
        _ingredient('1 msk socker', ParseConfidence.high),
      ];
      final originalLines = ['2 dl mjölk', 'lite salt', '1 msk socker'];

      final result = await strategy.getUncertainLines(parsed, originalLines);
      expect(result, {1: 'lite salt'});
    });

    test('should return empty map when all lines are confident', () async {
      final parsed = [
        _ingredient('mjölk', ParseConfidence.high),
        _ingredient('smör', ParseConfidence.high),
      ];
      final originalLines = ['2 dl mjölk', '50 g smör'];

      final result = await strategy.getUncertainLines(parsed, originalLines);
      expect(result, isEmpty);
    });

    test('should handle index out of bounds gracefully', () async {
      // More parsed results than original lines
      final parsed = [
        _ingredient('mjölk', ParseConfidence.high),
        _ingredient('salt', ParseConfidence.low),
        _ingredient('extra', ParseConfidence.low),
      ];
      final originalLines = ['2 dl mjölk', 'lite salt'];

      final result = await strategy.getUncertainLines(parsed, originalLines);
      // index 1 maps to 'lite salt', index 2 is out of bounds and skipped
      expect(result, {1: 'lite salt'});
      expect(result.containsKey(2), false);
    });

    test('should return multiple uncertain lines', () async {
      final parsed = [
        _ingredient('a', ParseConfidence.low),
        _ingredient('b', ParseConfidence.high),
        _ingredient('c', ParseConfidence.failed),
        _ingredient('d', ParseConfidence.low),
      ];
      final originalLines = ['line a', 'line b', 'line c', 'line d'];

      final result = await strategy.getUncertainLines(parsed, originalLines);
      expect(result, {0: 'line a', 2: 'line c', 3: 'line d'});
    });

    test('should return empty map for empty input', () async {
      final result = await strategy.getUncertainLines([], []);
      expect(result, isEmpty);
    });
  });
}

ParsedIngredient _ingredient(String name, ParseConfidence confidence) {
  return ParsedIngredient(
    name: name,
    originalLine: name,
    confidence: confidence,
  );
}
