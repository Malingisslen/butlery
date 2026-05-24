// BUT-985: boundary-detection helper for multi-recipe paste support.
// Covers the three separator styles + edge cases that prove the helper
// behaves predictably so the UI (filed as follow-up) can rely on it.

import 'package:butlery/services/parsing/common/recipe_boundary_detector.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('RecipeBoundaryDetector.splitRecipes', () {
    test('empty input returns empty list', () {
      expect(RecipeBoundaryDetector.splitRecipes(''), isEmpty);
      expect(RecipeBoundaryDetector.splitRecipes('   \n\n  '), isEmpty);
    });

    test('single recipe with no separators returns a one-element list', () {
      const text = 'Pannkakor\n200 ml mjölk\n1 ägg\nBlanda och stek.';
      final result = RecipeBoundaryDetector.splitRecipes(text);
      expect(result, hasLength(1));
      expect(result.first, equals(text.trim()));
    });

    test('dash separator splits into two recipes', () {
      const text = '''
Pannkakor
200 ml mjölk
1 ägg

---

Våfflor
300 ml mjölk
2 ägg
''';
      final result = RecipeBoundaryDetector.splitRecipes(text);
      expect(result, hasLength(2));
      expect(result[0], startsWith('Pannkakor'));
      expect(result[1], startsWith('Våfflor'));
    });

    test('equals separator works the same as dash', () {
      const text = 'Recipe A\nbody A\n===\nRecipe B\nbody B';
      final result = RecipeBoundaryDetector.splitRecipes(text);
      expect(result, hasLength(2));
      expect(result[0], equals('Recipe A\nbody A'));
      expect(result[1], equals('Recipe B\nbody B'));
    });

    test('triple blank line acts as a separator', () {
      const text = '''
First recipe
two short lines



Second recipe
also two short lines''';
      final result = RecipeBoundaryDetector.splitRecipes(text);
      expect(result, hasLength(2));
      expect(result[0], contains('First recipe'));
      expect(result[1], contains('Second recipe'));
    });

    test('double blank line is NOT a separator (paragraph spacing is fine)',
        () {
      // Common case: a recipe has a blank line between ingredients and
      // instructions sections. Two blank lines must NOT split it.
      const text = 'Pannkakor\n\nIngredienser\n\nGör så här';
      final result = RecipeBoundaryDetector.splitRecipes(text);
      expect(result, hasLength(1));
      expect(result.first, equals(text));
    });

    test('leading/trailing separator does not emit empty blocks', () {
      const text = '---\nReal recipe\n---';
      final result = RecipeBoundaryDetector.splitRecipes(text);
      expect(result, hasLength(1));
      expect(result.first, equals('Real recipe'));
    });

    test('mixed separators in one paste split correctly', () {
      const text = 'A\n===\nB\n\n\n\nC\n---\nD';
      final result = RecipeBoundaryDetector.splitRecipes(text);
      expect(result, equals(['A', 'B', 'C', 'D']));
    });

    test('dashes inside a recipe body do NOT split (need own line)', () {
      // The line must be ONLY dashes/equals + whitespace. Mid-line dashes
      // (e.g. "1-2 tsk salt") must not trip the splitter.
      const text =
          'Köttbullar\n1-2 tsk salt — efter smak\nBlanda och rulla bollar.';
      final result = RecipeBoundaryDetector.splitRecipes(text);
      expect(result, hasLength(1));
    });
  });

  group('RecipeBoundaryDetector.isMultiRecipePaste', () {
    test('returns false for single recipe', () {
      expect(
        RecipeBoundaryDetector.isMultiRecipePaste('Just one recipe here'),
        isFalse,
      );
    });

    test('returns true when an explicit separator splits the input', () {
      expect(
        RecipeBoundaryDetector.isMultiRecipePaste('A\n---\nB'),
        isTrue,
      );
    });

    test('returns false for empty input', () {
      expect(RecipeBoundaryDetector.isMultiRecipePaste(''), isFalse);
    });
  });
}
