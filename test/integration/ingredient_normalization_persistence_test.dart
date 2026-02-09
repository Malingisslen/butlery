/// Integration tests for MODUL1 Phase 3: Normalized Ingredients Persistence
///
/// Tests the auto-population of ingredientsNormalized field during recipe
/// save and update operations for advanced search and shopping list features.

import 'package:flutter_test/flutter_test.dart';
import 'package:butlery/utils/text/ingredient_processor.dart';
import 'package:butlery/models/recipe_unified.dart';

void main() {
  group('Ingredient Normalization Persistence', () {
    group('normalizeIngredientsForRecipe()', () {
      test('normalizes simple ingredients', () {
        final ingredients = ['2 dl mjölk', '3 st ägg', '1 msk smör'];
        final normalized =
            IngredientProcessor.normalizeIngredientsForRecipe(ingredients);

        expect(normalized, isNotNull);
        expect(normalized!.length, 3);
        expect(normalized[0], 'mjölk');
        expect(normalized[1], 'ägg');
        expect(normalized[2], 'smör');
      });

      test('removes preparation words', () {
        final ingredients = [
          '2 dl hackad lök',
          '3 st stora ägg',
          '100 g strimlad ost'
        ];
        final normalized =
            IngredientProcessor.normalizeIngredientsForRecipe(ingredients);

        expect(normalized, isNotNull);
        expect(normalized!.length, 3);
        expect(normalized[0], 'lök',
            reason: 'Should remove "hackad" preparation word');
        expect(normalized[1], 'ägg',
            reason: 'Should remove "stora" preparation word');
        expect(normalized[2], 'ost',
            reason: 'Should remove "strimlad" preparation word');
      });

      test('preserves diet descriptors', () {
        final ingredients = [
          '2 dl glutenfri mjölk',
          '100 g sockerfri choklad',
          '1 förp laktosfri grädde'
        ];
        final normalized =
            IngredientProcessor.normalizeIngredientsForRecipe(ingredients);

        expect(normalized, isNotNull);
        expect(normalized!.length, 3);
        expect(normalized[0], 'glutenfri mjölk',
            reason: 'Diet descriptors must be preserved');
        expect(normalized[1], 'sockerfri choklad',
            reason: 'Diet descriptors must be preserved');
        expect(normalized[2], 'laktosfri grädde',
            reason: 'Diet descriptors must be preserved');
      });

      test('preserves compound ingredient names', () {
        final ingredients = [
          '1 krm vitpeppar',
          '2 st rödlökar',
          '1 msk sesamolja'
        ];
        final normalized =
            IngredientProcessor.normalizeIngredientsForRecipe(ingredients);

        expect(normalized, isNotNull);
        expect(normalized!.length, 3);
        expect(normalized[0], 'vitpeppar',
            reason: 'Compound names should not be split');
        expect(normalized[1], 'rödlök',
            reason: 'Compound names normalized to singular');
        expect(normalized[2], 'sesamolja',
            reason: 'Compound names should not be split');
      });

      test('handles null input', () {
        final normalized =
            IngredientProcessor.normalizeIngredientsForRecipe(null);

        expect(normalized, isNull,
            reason: 'Null input should return null for backward compatibility');
      });

      test('handles empty list', () {
        final normalized =
            IngredientProcessor.normalizeIngredientsForRecipe([]);

        expect(normalized, isNotNull);
        expect(normalized!.isEmpty, true,
            reason: 'Empty list should return empty list');
      });

      test('handles empty strings in list', () {
        final ingredients = ['2 dl mjölk', '', '  ', '3 st ägg'];
        final normalized =
            IngredientProcessor.normalizeIngredientsForRecipe(ingredients);

        expect(normalized, isNotNull);
        expect(normalized!.length, 2,
            reason: 'Empty strings should be skipped');
        expect(normalized[0], 'mjölk');
        expect(normalized[1], 'ägg');
      });

      test('handles mixed Swedish ingredients', () {
        final ingredients = [
          '400 g köttfärs',
          '2 dl hackad lök',
          '3 vitlöksklyftor',
          '1 burk krossade tomater',
          '2 msk tomatpuré',
          '1 tsk oregano',
          '1 tsk basilika',
          'salt och peppar'
        ];
        final normalized =
            IngredientProcessor.normalizeIngredientsForRecipe(ingredients);

        expect(normalized, isNotNull);
        expect(normalized!.length, 8);
        expect(normalized[0], contains('kött'), reason: 'Core meat ingredient');
        expect(normalized[1], 'lök', reason: 'Preparation word removed');
        expect(normalized[2], contains('vitlök'),
            reason: 'Garlic ingredient (may vary)');
        expect(normalized[3], contains('tomat'),
            reason: 'Core ingredient found');
        expect(normalized[4], contains('tomat'),
            reason: 'Tomato-based products may vary in normalization');
        expect(normalized[5], contains('oregano'));
        expect(normalized[6], contains('basilika'));
        expect(normalized[7], isNotEmpty);
      });

      test('handles ingredients with special characters', () {
        final ingredients = [
          '1 burk mayo med lime och jalapeño',
          '2 dl créme fraiche',
          '100 g smör'
        ];
        final normalized =
            IngredientProcessor.normalizeIngredientsForRecipe(ingredients);

        expect(normalized, isNotNull);
        expect(normalized!.length, 3);
        expect(normalized[0], contains('med'),
            reason: 'Flavor descriptions preserved');
        expect(normalized[1], isNotEmpty);
        expect(normalized[2], contains('smör'),
            reason: 'Core ingredient extracted');
      });

      test('gracefully handles parsing failures', () {
        final ingredients = [
          '2 dl mjölk', // Valid
          'invalid garbage text @#\$%', // Invalid
          '3 st ägg', // Valid
        ];
        final normalized =
            IngredientProcessor.normalizeIngredientsForRecipe(ingredients);

        expect(normalized, isNotNull);
        expect(normalized!.length, 3,
            reason: 'Should have 3 items with fallback for invalid');
        expect(normalized[0], 'mjölk');
        // Invalid ingredient should fallback to original (trimmed)
        expect(normalized[1], isNotEmpty);
        expect(normalized[2], 'ägg');
      });
    });

    group('needsNormalization()', () {
      test('returns true when ingredientsNormalized is null', () {
        final recipe = Recipe.personal(
          title: 'Test Recipe',
          description: 'Test',
          ingredients: ['2 dl mjölk', '3 st ägg'],
          instructions: ['Mix', 'Cook'],
          mealType: 'Middag',
          createdBy: 'user123',
        );

        expect(IngredientProcessor.needsNormalization(recipe), true,
            reason: 'Null ingredientsNormalized should trigger normalization');
      });

      test('returns false when both lists are empty', () {
        final recipe = Recipe.personal(
          title: 'Test Recipe',
          description: 'Test',
          ingredients: [],
          instructions: ['Mix', 'Cook'],
          mealType: 'Middag',
          createdBy: 'user123',
        );

        // Manually set ingredientsNormalized to empty list
        final recipeWithEmpty = recipe.copyWith(
          ingredientsNormalized: [],
        );

        expect(IngredientProcessor.needsNormalization(recipeWithEmpty), false,
            reason: 'Empty ingredients with empty normalized needs no update');
      });

      test('returns true when lengths mismatch', () {
        final recipe = Recipe.personal(
          title: 'Test Recipe',
          description: 'Test',
          ingredients: ['2 dl mjölk', '3 st ägg', '1 msk smör'],
          instructions: ['Mix', 'Cook'],
          mealType: 'Middag',
          createdBy: 'user123',
        );

        // Manually set ingredientsNormalized to shorter list
        final recipeWithMismatch = recipe.copyWith(
          ingredientsNormalized: ['mjölk', 'ägg'], // Missing smör
        );

        expect(IngredientProcessor.needsNormalization(recipeWithMismatch), true,
            reason: 'Length mismatch should trigger re-normalization');
      });

      test('returns false when lengths match', () {
        final recipe = Recipe.personal(
          title: 'Test Recipe',
          description: 'Test',
          ingredients: ['2 dl mjölk', '3 st ägg'],
          instructions: ['Mix', 'Cook'],
          mealType: 'Middag',
          createdBy: 'user123',
        );

        // Manually set ingredientsNormalized to matching length
        final recipeWithMatching = recipe.copyWith(
          ingredientsNormalized: ['mjölk', 'ägg'],
        );

        expect(
            IngredientProcessor.needsNormalization(recipeWithMatching), false,
            reason:
                'Matching lengths assumes already normalized (optimization)');
      });

      test('returns true when content changed but count is same', () {
        final recipe = Recipe.personal(
          title: 'Test Recipe',
          description: 'Test',
          ingredients: ['2 dl grädde', '3 st ägg'],
          instructions: ['Mix', 'Cook'],
          mealType: 'Middag',
          createdBy: 'user123',
        );

        // Stale normalized: mjölk was edited to grädde but count stayed same
        final staleRecipe = recipe.copyWith(
          ingredientsNormalized: ['mjölk', 'ägg'],
        );

        expect(IngredientProcessor.needsNormalization(staleRecipe), true,
            reason:
                'Content change (mjölk->grädde) should trigger re-normalization');
      });

      test('handles recipe with no ingredients', () {
        final recipe = Recipe.personal(
          title: 'Test Recipe',
          description: 'Test',
          ingredients: [],
          instructions: ['Mix', 'Cook'],
          mealType: 'Middag',
          createdBy: 'user123',
        );

        expect(IngredientProcessor.needsNormalization(recipe), true,
            reason: 'Null normalized triggers normalization even with empty');
      });
    });

    group('Recipe Model Integration', () {
      test('Recipe.copyWith() updates ingredientsNormalized', () {
        final originalRecipe = Recipe.personal(
          title: 'Original',
          description: 'Test',
          ingredients: ['2 dl mjölk', '3 st ägg'],
          instructions: ['Mix', 'Cook'],
          mealType: 'Middag',
          createdBy: 'user123',
        );

        // Verify starts with null
        expect(originalRecipe.core.ingredientsNormalized, isNull);

        // Update with normalized ingredients
        final updatedRecipe = originalRecipe.copyWith(
          ingredientsNormalized: ['mjölk', 'ägg'],
        );

        // Verify update worked
        expect(updatedRecipe.core.ingredientsNormalized, isNotNull);
        expect(updatedRecipe.core.ingredientsNormalized!.length, 2);
        expect(updatedRecipe.core.ingredientsNormalized![0], 'mjölk');
        expect(updatedRecipe.core.ingredientsNormalized![1], 'ägg');
      });

      test('Recipe serialization includes ingredientsNormalized', () {
        final recipe = Recipe.personal(
          title: 'Test Recipe',
          description: 'Test',
          ingredients: ['2 dl hackad lök', '3 st ägg'],
          instructions: ['Mix', 'Cook'],
          mealType: 'Middag',
          createdBy: 'user123',
        );

        // Add normalized ingredients
        final recipeWithNormalized = recipe.copyWith(
          ingredientsNormalized: ['lök', 'ägg'],
        );

        // Serialize to Firestore format
        final firestoreData = recipeWithNormalized.toFirestore();
        final coreData = firestoreData['core'] as Map<String, dynamic>;

        // Verify ingredientsNormalized is included
        expect(coreData.containsKey('ingredientsNormalized'), true,
            reason: 'Serialization should include ingredientsNormalized');
        expect(coreData['ingredientsNormalized'], isNotNull);
        expect(coreData['ingredientsNormalized'], ['lök', 'ägg']);
      });

      test('Recipe deserialization handles missing ingredientsNormalized', () {
        // Simulate old recipe data without ingredientsNormalized
        final now = DateTime.now();
        final oldRecipeData = {
          'core': {
            'id': 'test-123',
            'title': 'Old Recipe',
            'description': 'Test',
            'portions': 4,
            'timeMinutes': 30,
            'ingredients': ['2 dl mjölk', '3 st ägg'],
            'instructions': ['Mix', 'Cook'],
            'tags': <String>[],
            'mealType': 'Middag',
            'imageUrls': <String>[],
            'createdAt': now.toIso8601String(),
            'updatedAt': now.toIso8601String(),
            'createdBy': 'user123',
            'isPublic': false,
            // NOTE: ingredientsNormalized is missing (old data)
          },
          'type': 0, // RecipeType.personal.index
        };

        // This should not throw - backward compatibility
        final recipeJson = Recipe.fromJson(oldRecipeData);

        expect(recipeJson.core.ingredientsNormalized, isNull,
            reason:
                'Missing field should deserialize as null (backward compat)');
        expect(recipeJson.core.ingredients.length, 2);
      });

      test('Recipe deserialization loads ingredientsNormalized when present',
          () {
        // Simulate new recipe data with ingredientsNormalized
        final now = DateTime.now();
        final newRecipeData = {
          'core': {
            'id': 'test-456',
            'title': 'New Recipe',
            'description': 'Test',
            'portions': 4,
            'timeMinutes': 30,
            'ingredients': ['2 dl hackad lök', '3 st stora ägg'],
            'instructions': ['Mix', 'Cook'],
            'tags': <String>[],
            'mealType': 'Middag',
            'imageUrls': <String>[],
            'createdAt': now.toIso8601String(),
            'updatedAt': now.toIso8601String(),
            'createdBy': 'user123',
            'isPublic': false,
            'ingredientsNormalized': ['lök', 'ägg'], // NEW field present
          },
          'type': 0, // RecipeType.personal.index
        };

        final recipe = Recipe.fromJson(newRecipeData);

        expect(recipe.core.ingredientsNormalized, isNotNull,
            reason: 'Present field should deserialize');
        expect(recipe.core.ingredientsNormalized!.length, 2);
        expect(recipe.core.ingredientsNormalized![0], 'lök');
        expect(recipe.core.ingredientsNormalized![1], 'ägg');
      });
    });

    group('Complete Flow Simulation', () {
      test('simulates recipe creation with auto-population', () {
        // Step 1: User creates recipe
        final userRecipe = Recipe.personal(
          title: 'Köttfärssås',
          description: 'Klassisk köttfärssås',
          ingredients: [
            '400 g köttfärs',
            '2 dl hackad lök',
            '3 vitlöksklyftor',
            '1 burk krossade tomater',
            '2 msk tomatpuré',
            '1 tsk torkad oregano',
            'salt och peppar efter smak'
          ],
          instructions: [
            'Bryn köttfärsen',
            'Tillsätt lök och vitlök',
            'Tillsätt tomater och kryddor',
            'Låt sjuda i 20 minuter'
          ],
          mealType: 'Middag',
          createdBy: 'user123',
        );

        // Step 2: Check if normalization needed (should be true - field is null)
        expect(IngredientProcessor.needsNormalization(userRecipe), true);

        // Step 3: Normalize ingredients (this happens in repository)
        final normalized = IngredientProcessor.normalizeIngredientsForRecipe(
          userRecipe.core.ingredients,
        );

        // Step 4: Create updated recipe with normalized ingredients
        final recipeToSave = userRecipe.copyWith(
          ingredientsNormalized: normalized,
        );

        // Verify final result
        expect(recipeToSave.core.ingredientsNormalized, isNotNull);
        expect(recipeToSave.core.ingredientsNormalized!.length, 7);
        expect(recipeToSave.core.ingredientsNormalized![0], contains('kött'),
            reason: 'Core meat ingredient');
        expect(recipeToSave.core.ingredientsNormalized![1], 'lök',
            reason: 'hackad should be removed');
        expect(recipeToSave.core.ingredientsNormalized![2], contains('vitlök'),
            reason: 'Garlic ingredient (may vary)');
        expect(recipeToSave.core.ingredientsNormalized![3], contains('tomat'));
        expect(recipeToSave.core.ingredientsNormalized![4], contains('tomat'),
            reason: 'Tomato-based products may vary in normalization');
        expect(
            recipeToSave.core.ingredientsNormalized![5], contains('oregano'));
        expect(recipeToSave.core.ingredientsNormalized![6], isNotEmpty);

        // Verify original ingredients unchanged
        expect(recipeToSave.core.ingredients[1], '2 dl hackad lök',
            reason: 'Original ingredients preserved for display');
      });

      test('simulates recipe update refreshing normalized ingredients', () {
        // Step 1: Load existing recipe from database (already has normalized)
        final existingRecipe = Recipe.personal(
          title: 'Pannkakor',
          description: 'Enkla pannkakor',
          ingredients: ['2 dl mjölk', '3 ägg'],
          instructions: ['Vispa', 'Stek'],
          mealType: 'Frukost',
          createdBy: 'user123',
        );

        // Simulate it was previously normalized
        final existingWithNormalized = existingRecipe.copyWith(
          ingredientsNormalized: ['mjölk', 'ägg'],
        );

        // Step 2: User edits recipe, adds ingredient
        final editedRecipe = existingWithNormalized.copyWith(
          ingredients: ['2 dl mjölk', '3 ägg', '1 dl vetemjöl'], // Added flour
        );

        // Step 3: Check if normalization needed (should be true - length mismatch)
        expect(IngredientProcessor.needsNormalization(editedRecipe), true,
            reason: 'Length mismatch should trigger re-normalization');

        // Step 4: Re-normalize
        final normalized = IngredientProcessor.normalizeIngredientsForRecipe(
          editedRecipe.core.ingredients,
        );

        // Step 5: Update recipe
        final recipeToUpdate = editedRecipe.copyWith(
          ingredientsNormalized: normalized,
        );

        // Verify normalized was updated
        expect(recipeToUpdate.core.ingredientsNormalized!.length, 3,
            reason: 'Normalized list should now have 3 items');
        expect(recipeToUpdate.core.ingredientsNormalized![2], 'vetemjöl',
            reason: 'New ingredient should be normalized');
      });

      test('simulates recipe with no changes skipping normalization', () {
        // Existing recipe already normalized
        final recipe = Recipe.personal(
          title: 'Test',
          description: 'Test',
          ingredients: ['2 dl mjölk', '3 ägg'],
          instructions: ['Mix'],
          mealType: 'Middag',
          createdBy: 'user123',
        );

        final recipeWithNormalized = recipe.copyWith(
          ingredientsNormalized: ['mjölk', 'ägg'],
        );

        // User updates title only (no ingredient changes)
        final updatedRecipe = recipeWithNormalized.copyWith(
          title: 'New Title',
        );

        // Check if normalization needed (should be false - lengths match)
        expect(IngredientProcessor.needsNormalization(updatedRecipe), false,
            reason:
                'No normalization needed when lengths match (optimization)');

        // In repository, this would skip normalization for performance
        // The existing normalized ingredients remain valid
        expect(updatedRecipe.core.ingredientsNormalized!.length, 2);
      });
    });

    group('Real-World Scenarios', () {
      test('handles complex Swedish recipe with all features', () {
        final ingredients = [
          'ca 500 g kycklingfilé (i bitar)',
          '2-3 st stora gula lökar (hackade)',
          '3 vitlöksklyftor',
          '2 dl glutenfri crème fraiche',
          '1 burk krossade tomater (400g)',
          '2 msk tomatpuré',
          '1 tsk torkad basilika',
          '1 tsk torkad oregano',
          '1/2 tsk paprikapulver',
          'salt och nymalen svartpeppar',
          '1 dl riven parmesan',
          '2 msk hackad färsk basilika (till servering)',
        ];

        final normalized =
            IngredientProcessor.normalizeIngredientsForRecipe(ingredients);

        expect(normalized, isNotNull);
        expect(normalized!.length, 12, reason: 'All ingredients normalized');

        // Verify specific normalizations
        expect(normalized[0], contains('kyckling'),
            reason: 'Core ingredient extracted');
        expect(normalized[1], contains('lök'),
            reason: 'Preparation and plurals removed');
        expect(normalized[2], contains('vitlök'),
            reason: 'Garlic ingredient (may vary)');
        expect(normalized[3], contains('glutenfri'),
            reason: 'Diet descriptor preserved');
        expect(normalized[4], contains('tomat'));
        expect(normalized[5], contains('tomat'),
            reason: 'Tomato-based products may vary in normalization');
      });

      test('handles recipe imported from blog (messy format)', () {
        final ingredients = [
          'cirka 400 g köttfärs (gärna blandfärs)',
          '1-2 gula lökar, hackade',
          '2 vitlöksklyftor, finhackade',
          '1 burk (400g) krossade tomater',
          'ca 2 msk tomatpuré',
          'Salt och peppar efter smak',
          '1 tsk torkad oregano (valfritt)',
        ];

        final normalized =
            IngredientProcessor.normalizeIngredientsForRecipe(ingredients);

        expect(normalized, isNotNull);
        expect(normalized!.length, 7);

        // Even with messy format, should extract core ingredients
        expect(normalized[0], contains('kött'), reason: 'Core meat ingredient');
        expect(normalized[1], contains('lök'));
        expect(normalized[2], contains('vitlök'),
            reason: 'Garlic ingredient (may vary with commas/punctuation)');
        expect(normalized[3], contains('tomat'));
        expect(normalized[4], contains('tomat'),
            reason: 'Tomato-based products may vary in normalization');
      });
    });
  });
}
