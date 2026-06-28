/// Direct unit tests for [MenuQualityAnalyzer] (BUT-1149 coverage burndown —
/// previously zero direct coverage).
///
/// These are pure static helpers extracted from MenuGenerator (BUT-1349): menu
/// quality analysis, prompt validation, and the prompt-optimality heuristic.
/// They hold no dependencies, so the tests are plain input→output assertions
/// with no mocks. Recipes come from RecipeFactory, so no real-clock calls live
/// in this test file (keeps the flaky-time guard happy).
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/viewmodels/menu/menu_quality_analyzer.dart';
import 'package:butlery/models/recipe_unified.dart';

import '../../../infrastructure/factories/recipe_factory.dart';

void main() {
  group('MenuQualityAnalyzer.analyzeMenuQuality', () {
    test('empty menu yields zeroed analysis with no variety', () {
      final a = MenuQualityAnalyzer.analyzeMenuQuality(
        <String, List<Recipe>>{},
      );

      expect(a['totalRecipes'], 0);
      expect(a['sections'], 0);
      expect(a['averageRecipesPerSection'], 0.0);
      expect(a['hasVariety'], isFalse);
      expect(a['mealTypes'], isEmpty);
    });

    test('counts total recipes and sections and averages across sections', () {
      final menu = <String, List<Recipe>>{
        'Mon': [
          RecipeFactory.build(mealType: 'Middag'),
          RecipeFactory.build(mealType: 'Middag'),
        ],
        'Tue': [RecipeFactory.build(mealType: 'Middag')],
      };

      final a = MenuQualityAnalyzer.analyzeMenuQuality(menu);

      expect(a['totalRecipes'], 3);
      expect(a['sections'], 2);
      expect(a['averageRecipesPerSection'], 1.5); // 3 / 2
    });

    test('hasVariety is true only when more than one meal type appears', () {
      final mixed = <String, List<Recipe>>{
        'a': [RecipeFactory.build(mealType: 'Middag')],
        'b': [RecipeFactory.build(mealType: 'Lunch')],
      };
      final uniform = <String, List<Recipe>>{
        'a': [
          RecipeFactory.build(mealType: 'Middag'),
          RecipeFactory.build(mealType: 'Middag'),
        ],
      };

      final mixedA = MenuQualityAnalyzer.analyzeMenuQuality(mixed);
      final uniformA = MenuQualityAnalyzer.analyzeMenuQuality(uniform);

      expect(mixedA['hasVariety'], isTrue);
      expect((mixedA['mealTypes'] as Set), {'Middag', 'Lunch'});
      expect(uniformA['hasVariety'], isFalse);
      expect((uniformA['mealTypes'] as Set), {'Middag'});
    });
  });

  group('MenuQualityAnalyzer.isPromptOptimal', () {
    test('true for a prompt with a good keyword and a sensible length', () {
      // "veckomeny" is a good keyword; length is within 10..200.
      expect(
        MenuQualityAnalyzer.isPromptOptimal('en veckomeny för familjen'),
        isTrue,
      );
    });

    test('false when no recognised keyword is present', () {
      // Long enough, but no menu-domain keyword.
      expect(
        MenuQualityAnalyzer.isPromptOptimal('lorem ipsum dolor sit amet'),
        isFalse,
      );
    });

    test('false when too short even with a keyword', () {
      // "meny" is a keyword but the whole prompt is under 10 chars.
      expect(MenuQualityAnalyzer.isPromptOptimal('meny'), isFalse);
    });

    test('false when too long even with a keyword', () {
      final tooLong = 'middag ${'a' * 210}';
      expect(MenuQualityAnalyzer.isPromptOptimal(tooLong), isFalse);
    });

    test('keyword match is case-insensitive', () {
      expect(MenuQualityAnalyzer.isPromptOptimal('MIDDAG till helgen'), isTrue);
    });
  });

  group('MenuQualityAnalyzer.validatePromptNotEmpty', () {
    test('throws ArgumentError on an empty or whitespace-only prompt', () {
      expect(
        () => MenuQualityAnalyzer.validatePromptNotEmpty(''),
        throwsArgumentError,
      );
      expect(
        () => MenuQualityAnalyzer.validatePromptNotEmpty('   '),
        throwsArgumentError,
      );
    });

    test('does not throw for a non-empty prompt', () {
      expect(
        () => MenuQualityAnalyzer.validatePromptNotEmpty('veckomeny'),
        returnsNormally,
      );
    });
  });

  group('MenuQualityAnalyzer.getGenerationSuggestions', () {
    test('returns ten non-empty localized suggestions', () {
      final s = MenuQualityAnalyzer.getGenerationSuggestions();
      expect(s, hasLength(10));
      expect(s.every((x) => x.trim().isNotEmpty), isTrue);
    });
  });
}
