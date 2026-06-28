/// Direct unit tests for the [RecipeCompleteness] extension (BUT-1149 coverage
/// burndown — previously zero direct coverage).
///
/// Pure weighted scoring over a Recipe: completenessScore (title .20 +
/// ingredients .30 + instructions .30 + portions .10 + time .05 + image .05)
/// and the matching missingFields list. Recipes are built via RecipeFactory.
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/models/recipe/recipe_completeness.dart';

import '../../../infrastructure/factories/recipe_factory.dart';

void main() {
  group('completenessScore', () {
    test('a fully populated recipe scores 1.0', () {
      final r = RecipeFactory.build(
        title: 'Pasta',
        ingredients: ['a', 'b', 'c'],
        instructions: ['s1', 's2'],
        portions: 4,
        timeMinutes: 30,
        imageUrls: ['https://img/x.jpg'],
      );
      expect(r.completenessScore, 1.0);
      expect(r.missingFields, isEmpty);
    });

    test('an empty recipe scores 0.0 and lists every field missing', () {
      final r = RecipeFactory.build(
        title: 'ab', // < 3 chars
        ingredients: const [],
        instructions: const [],
        portions: 0,
        timeMinutes: 0,
        imageUrls: const [],
      );
      expect(r.completenessScore, 0.0);
      expect(r.missingFields, <RecipeField>[
        RecipeField.title,
        RecipeField.ingredients,
        RecipeField.instructions,
        RecipeField.portions,
        RecipeField.time,
        RecipeField.image,
      ]);
    });

    test('title + ingredients + instructions alone scores 0.80', () {
      final r = RecipeFactory.build(
        title: 'Pasta',
        ingredients: ['a', 'b', 'c'],
        instructions: ['s1', 's2'],
        portions: 0,
        timeMinutes: 0,
        imageUrls: const [],
      );
      expect(r.completenessScore, closeTo(0.80, 1e-9));
      expect(r.missingFields, <RecipeField>[
        RecipeField.portions,
        RecipeField.time,
        RecipeField.image,
      ]);
    });
  });

  group('incompleteThreshold', () {
    test('a recipe below the threshold is flagged incomplete', () {
      final r = RecipeFactory.build(
        title: 'Pasta',
        ingredients: ['a', 'b', 'c'],
        instructions: const [], // only title + ingredients = 0.50
        portions: 0,
        timeMinutes: 0,
        imageUrls: const [],
      );
      expect(r.completenessScore, lessThan(incompleteThreshold));
    });
  });
}
