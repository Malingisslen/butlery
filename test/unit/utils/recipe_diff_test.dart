/// Unit tests for [diffRecipeFields] (BUT-569).
///
/// Verifies the recipe diff util emits stable, snake_case field names for
/// each top-level recipe field, and that order-sensitive list equality is
/// applied to ingredients/instructions/imageUrls.
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/utils/recipe_diff.dart';

import '../../infrastructure/builders/recipe_builder.dart';

void main() {
  group('diffRecipeFields', () {
    test('returns empty list when nothing changed', () {
      final base = RecipeBuilder().asSwedishDinner().build();
      final after = base.copyWith(); // identical content

      expect(diffRecipeFields(base, after), isEmpty);
    });

    test('detects title-only change', () {
      final before = RecipeBuilder().withTitle('Original').build();
      final after = before.copyWith(title: 'Updated');

      expect(diffRecipeFields(before, after), equals([RecipeDiffField.title]));
    });

    test('detects ingredients-only change', () {
      final before = RecipeBuilder().withIngredients(['a', 'b']).build();
      final after = before.copyWith(ingredients: ['a', 'b', 'c']);

      expect(
        diffRecipeFields(before, after),
        equals([RecipeDiffField.ingredients]),
      );
    });

    test('detects instruction reorder as a change (order-sensitive)', () {
      final before = RecipeBuilder().withInstructions([
        'step1',
        'step2',
      ]).build();
      final after = before.copyWith(instructions: ['step2', 'step1']);

      expect(
        diffRecipeFields(before, after),
        equals([RecipeDiffField.instructions]),
      );
    });

    test('detects multi-field change in stable order', () {
      final before = RecipeBuilder()
          .withTitle('Old')
          .withPortions(2)
          .withIngredients(['a'])
          .build();
      final after = before.copyWith(
        title: 'New',
        portions: 4,
        ingredients: ['a', 'b'],
      );

      // Order matches the implementation's traversal order, not insertion.
      expect(
        diffRecipeFields(before, after),
        equals([
          RecipeDiffField.title,
          RecipeDiffField.portions,
          RecipeDiffField.ingredients,
        ]),
      );
    });

    test('treats null ↔ value as a change', () {
      final before = RecipeBuilder().withPortions(null).build();
      final after = before.copyWith(portions: 4);

      expect(
        diffRecipeFields(before, after),
        equals([RecipeDiffField.portions]),
      );
    });

    test('description and meal type changes are detected', () {
      final before = RecipeBuilder()
          .withDescription('orig')
          .withMealType('Lunch')
          .build();
      final after = before.copyWith(
        description: 'updated',
        mealType: 'Middag',
      );

      expect(
        diffRecipeFields(before, after),
        equals([RecipeDiffField.description, RecipeDiffField.mealType]),
      );
    });

    test('image url list change is detected', () {
      final before = RecipeBuilder().build();
      final after = before.copyWith(imageUrls: ['https://x/a.jpg']);

      expect(
        diffRecipeFields(before, after),
        equals([RecipeDiffField.imageUrls]),
      );
    });
  });
}
