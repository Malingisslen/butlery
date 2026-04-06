/// Unit tests for RecipeQualityScorer — recipe completeness scoring.
library;

import 'package:flutter_test/flutter_test.dart';
import '../../../../test_support/base_unit_test.dart';
import 'package:butlery/services/extraction/site_parsers/recipe_quality_scorer.dart';

void main() {
  group('RecipeQualityScore', () {
    setUp(() async => await BaseUnitTest.setupUnit());
    tearDown(() => BaseUnitTest.resetMocks());

    group('completeness', () {
      test('all fields present gives 1.0', () {
        final score = RecipeQualityScore(
          hasTitle: true,
          hasIngredients: true,
          hasInstructions: true,
          hasPortions: true,
          hasTime: true,
          hasImage: true,
          ingredientCount: 5,
          instructionCount: 3,
        );
        expect(score.completeness, 1.0);
      });

      test('no fields gives 0.0', () {
        final score = RecipeQualityScore(
          hasTitle: false,
          hasIngredients: false,
          hasInstructions: false,
          hasPortions: false,
          hasTime: false,
          hasImage: false,
          ingredientCount: 0,
          instructionCount: 0,
        );
        expect(score.completeness, 0.0);
      });

      test('title + ingredients gives 0.5', () {
        final score = RecipeQualityScore(
          hasTitle: true,
          hasIngredients: true,
          hasInstructions: false,
          hasPortions: false,
          hasTime: false,
          hasImage: false,
          ingredientCount: 3,
          instructionCount: 0,
        );
        expect(score.completeness, closeTo(0.5, 0.001));
      });
    });

    group('quality thresholds', () {
      test('meetsHighQuality requires >= 0.95', () {
        final high = RecipeQualityScore(
          hasTitle: true,
          hasIngredients: true,
          hasInstructions: true,
          hasPortions: true,
          hasTime: true,
          hasImage: true,
          ingredientCount: 5,
          instructionCount: 3,
        );
        expect(high.meetsHighQuality, isTrue);
        expect(high.meetsAcceptableQuality, isTrue);
        expect(high.meetsMinimumQuality, isTrue);
      });

      test('0.5 does not meet minimum quality', () {
        final low = RecipeQualityScore(
          hasTitle: true,
          hasIngredients: true,
          hasInstructions: false,
          hasPortions: false,
          hasTime: false,
          hasImage: false,
          ingredientCount: 3,
          instructionCount: 0,
        );
        expect(low.meetsMinimumQuality, isFalse);
      });
    });

    group('qualityLevel', () {
      test('1.0 is Excellent', () {
        final score = RecipeQualityScore(
          hasTitle: true,
          hasIngredients: true,
          hasInstructions: true,
          hasPortions: true,
          hasTime: true,
          hasImage: true,
          ingredientCount: 5,
          instructionCount: 3,
        );
        expect(score.qualityLevel, 'Excellent');
      });

      test('0.0 is Very Poor', () {
        final score = RecipeQualityScore(
          hasTitle: false,
          hasIngredients: false,
          hasInstructions: false,
          hasPortions: false,
          hasTime: false,
          hasImage: false,
          ingredientCount: 0,
          instructionCount: 0,
        );
        expect(score.qualityLevel, 'Very Poor');
      });
    });
  });

  group('RecipeQualityScorer', () {
    setUp(() async => await BaseUnitTest.setupUnit());
    tearDown(() => BaseUnitTest.resetMocks());

    test('complete recipe scores high', () {
      final score = RecipeQualityScorer.score({
        'name': 'Pasta Carbonara',
        'recipeIngredient': ['pasta', 'eggs', 'cheese', 'bacon'],
        'recipeInstructions': ['Boil pasta', 'Mix sauce', 'Combine'],
        'recipeYield': '4 servings',
        'totalTime': 'PT30M',
        'image': 'https://example.com/photo.jpg',
      });
      expect(score.completeness, 1.0);
    });

    test('empty recipe scores zero', () {
      final score = RecipeQualityScorer.score({});
      expect(score.completeness, 0.0);
    });

    test('default title name rejected', () {
      final score = RecipeQualityScorer.score({
        'name': 'Importerat recept',
      });
      expect(score.hasTitle, isFalse);
    });

    test('short title rejected', () {
      final score = RecipeQualityScorer.score({'name': 'ab'});
      expect(score.hasTitle, isFalse);
    });

    test('too few ingredients rejected', () {
      final score = RecipeQualityScorer.score({
        'recipeIngredient': ['one', 'two'],
      });
      expect(score.hasIngredients, isFalse);
    });

    test('HowToStep maps counted as instructions', () {
      final score = RecipeQualityScorer.score({
        'recipeInstructions': [
          {'text': 'Step 1'},
          {'text': 'Step 2'},
        ],
      });
      expect(score.hasInstructions, isTrue);
    });

    test('recipeYield without digit rejected', () {
      final score = RecipeQualityScorer.score({
        'recipeYield': 'a few',
      });
      expect(score.hasPortions, isFalse);
    });

    test('image as Map with url key accepted', () {
      final score = RecipeQualityScorer.score({
        'image': {'url': 'https://example.com/img.jpg'},
      });
      expect(score.hasImage, isTrue);
    });
  });
}
