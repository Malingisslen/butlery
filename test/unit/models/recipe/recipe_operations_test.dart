// ignore_for_file: subtype_of_sealed_class

import 'package:flutter_test/flutter_test.dart';
import 'package:butlery/models/recipe/recipe_operations.dart';
import 'package:butlery/models/recipe/recipe_factory.dart';
import 'package:butlery/models/recipe/recipe_ingredient.dart';
import 'package:butlery/models/recipe_unified.dart';
import '../helpers/model_test_base.dart';

void main() {
  ModelTestBase.testModelGroup('RecipeOperations', () {
    late Recipe testRecipe;

    setUp(() {
      testRecipe = RecipeFactory.createPersonal(
        title: 'Test Recipe',
        description: 'Test description',
        ingredients: ['Ingredient 1', 'Ingredient 2', 'Ingredient 3'],
        instructions: ['Step 1', 'Step 2', 'Step 3'],
        mealType: 'Middag',
        portions: 4,
        timeMinutes: 30,
        personalTagIds: ['Test', 'Recipe'],
      );
    });

    group('Ingredient Operations', () {
      test('should add ingredient with user tracking', () {
        final updated = RecipeOperations.addIngredient(
          testRecipe,
          'New Ingredient',
          userId: 'user_123',
          userDisplayName: 'Test User',
        );

        expect(updated.core.ingredients.length, equals(4));
        expect(updated.core.ingredients.last, equals('New Ingredient'));
      });

      test('should not add empty ingredient', () {
        final updated = RecipeOperations.addIngredient(testRecipe, '   ');
        expect(updated.core.ingredients.length, equals(3));
      });

      test('should update ingredient at specific index', () {
        final updated = RecipeOperations.updateIngredient(
          testRecipe,
          1,
          'Updated Ingredient',
          userId: 'user_123',
        );

        expect(updated.core.ingredients[1], equals('Updated Ingredient'));
        expect(updated.core.ingredients.length, equals(3));
      });

      test('should not update with invalid index', () {
        final updated = RecipeOperations.updateIngredient(
          testRecipe,
          10,
          'Invalid',
        );

        expect(updated, equals(testRecipe));
      });

      test('should not update with empty ingredient', () {
        final updated = RecipeOperations.updateIngredient(
          testRecipe,
          1,
          '   ',
        );

        expect(updated, equals(testRecipe));
      });

      test('should remove ingredient at specific index', () {
        final updated = RecipeOperations.removeIngredient(
          testRecipe,
          1,
          userId: 'user_123',
        );

        expect(updated.core.ingredients.length, equals(2));
        expect(
            updated.core.ingredients, equals(['Ingredient 1', 'Ingredient 3']));
      });

      test('should not remove with invalid index', () {
        final updated = RecipeOperations.removeIngredient(testRecipe, -1);
        expect(updated, equals(testRecipe));

        final updated2 = RecipeOperations.removeIngredient(testRecipe, 10);
        expect(updated2, equals(testRecipe));
      });

      test('should update all ingredients', () {
        final newIngredients = ['New 1', '  New 2  ', '', 'New 3'];
        final updated = RecipeOperations.updateAllIngredients(
          testRecipe,
          newIngredients,
          userId: 'user_123',
        );

        expect(updated.core.ingredients, equals(['New 1', 'New 2', 'New 3']));
      });

      test('should reorder ingredients', () {
        final updated = RecipeOperations.reorderIngredients(
          testRecipe,
          0,
          2,
          userId: 'user_123',
        );

        expect(updated.core.ingredients,
            equals(['Ingredient 2', 'Ingredient 3', 'Ingredient 1']));
      });

      test('should not reorder with invalid indices', () {
        final updated = RecipeOperations.reorderIngredients(testRecipe, -1, 2);
        expect(updated, equals(testRecipe));

        final updated2 = RecipeOperations.reorderIngredients(testRecipe, 0, 10);
        expect(updated2, equals(testRecipe));

        final updated3 = RecipeOperations.reorderIngredients(testRecipe, 1, 1);
        expect(updated3, equals(testRecipe));
      });
    });

    group('BUT-1232 structured ingredient lockstep', () {
      // Intention: ingredient edits keep the persisted structured list
      // index-aligned (raw == ingredients[i]) instead of leaving stale
      // entries in Firestore that the facade getter silently discards.
      const flour = RecipeIngredient(
          amount: 3, unit: 'dl', name: 'vetemjöl', raw: '3 dl vetemjöl');
      const eggs = RecipeIngredient(amount: 2, name: 'ägg', raw: '2 ägg');

      Recipe buildStructuredRecipe() => RecipeFactory.createPersonal(
            title: 'Strukturerat recept',
            description: 'Med strukturerade ingredienser',
            ingredients: ['3 dl vetemjöl', '2 ägg'],
            structuredIngredients: [flour, eggs],
            instructions: ['Blanda allt'],
            mealType: 'Middag',
          );

      void expectAligned(Recipe recipe) {
        final stored = recipe.core.structuredIngredients!;
        expect(stored.length, recipe.core.ingredients.length);
        for (var i = 0; i < stored.length; i++) {
          expect(stored[i].raw, recipe.core.ingredients[i]);
        }
      }

      test('legacy recipe (no structured data) stays legacy after edits', () {
        final updated = RecipeOperations.addIngredient(testRecipe, '1 dl olja');

        expect(updated.core.structuredIngredients, isNull,
            reason: 'derivation for legacy recipes happens at import/save, '
                'not in model-level edits');
      });

      test('addIngredient appends a derived entry in lockstep', () {
        final updated = RecipeOperations.addIngredient(
          buildStructuredRecipe(),
          '  1,5 dl mjölk  ',
        );

        expectAligned(updated);
        final added = updated.core.structuredIngredients!.last;
        expect(added.raw, '1,5 dl mjölk');
        expect(added.amount, 1.5);
        expect(added.unit, 'dl');
      });

      test('updateIngredient replaces the entry at the same index', () {
        final updated = RecipeOperations.updateIngredient(
          buildStructuredRecipe(),
          0,
          '4 dl rågmjöl',
        );

        expectAligned(updated);
        expect(updated.core.structuredIngredients![0].amount, 4);
        expect(updated.core.structuredIngredients![0].name, 'rågmjöl');
        expect(updated.core.structuredIngredients![1], equals(eggs),
            reason: 'untouched entries are preserved');
      });

      test('removeIngredient removes the entry at the same index', () {
        final updated =
            RecipeOperations.removeIngredient(buildStructuredRecipe(), 0);

        expectAligned(updated);
        expect(updated.core.structuredIngredients, equals([eggs]));
      });

      test('reorderIngredients moves the entry with its line', () {
        final updated =
            RecipeOperations.reorderIngredients(buildStructuredRecipe(), 0, 1);

        expectAligned(updated);
        expect(updated.core.structuredIngredients, equals([eggs, flour]));
      });

      test('updateAllIngredients reuses matching entries and derives new ones',
          () {
        final updated = RecipeOperations.updateAllIngredients(
          buildStructuredRecipe(),
          ['2 ägg', '1 dl socker'],
        );

        expectAligned(updated);
        expect(updated.core.structuredIngredients![0], equals(eggs),
            reason: 'kept line keeps its entry across reorder/removal');
        expect(updated.core.structuredIngredients![1].amount, 1);
        expect(updated.core.structuredIngredients![1].unit, 'dl');
      });

      test('stale persisted data is replaced with aligned entries on edit', () {
        // Simulates pre-BUT-1232 garbage: structured list no longer matches
        // the strings (the getter ignores it, but it sits in Firestore).
        const stale = RecipeIngredient(
            amount: 9, unit: 'kg', name: 'fel', raw: 'gammal rad');
        final recipe = buildStructuredRecipe()
            .copyWith(structuredIngredients: const [stale]);

        final updated = RecipeOperations.removeIngredient(recipe, 0);

        expectAligned(updated);
        expect(
          updated.core.structuredIngredients!.map((e) => e.raw),
          isNot(contains('gammal rad')),
          reason: 'misaligned garbage must not survive the edit',
        );
      });
    });

    group('Instruction Operations', () {
      test('should add instruction with user tracking', () {
        final updated = RecipeOperations.addInstruction(
          testRecipe,
          'New Step',
          userId: 'user_456',
          userDisplayName: 'Another User',
        );

        expect(updated.core.instructions.length, equals(4));
        expect(updated.core.instructions.last, equals('New Step'));
      });

      test('should not add empty instruction', () {
        final updated = RecipeOperations.addInstruction(testRecipe, '   ');
        expect(updated.core.instructions.length, equals(3));
      });

      test('should update instruction at specific index', () {
        final updated = RecipeOperations.updateInstruction(
          testRecipe,
          2,
          'Updated Step',
        );

        expect(updated.core.instructions[2], equals('Updated Step'));
        expect(updated.core.instructions.length, equals(3));
      });

      test('should remove instruction at specific index', () {
        final updated = RecipeOperations.removeInstruction(testRecipe, 0);

        expect(updated.core.instructions.length, equals(2));
        expect(updated.core.instructions, equals(['Step 2', 'Step 3']));
      });

      test('should update all instructions', () {
        final newInstructions = ['  First  ', 'Second', '', '  Third'];
        final updated = RecipeOperations.updateAllInstructions(
          testRecipe,
          newInstructions,
        );

        expect(updated.core.instructions, equals(['First', 'Second', 'Third']));
      });

      test('should reorder instructions', () {
        final updated = RecipeOperations.reorderInstructions(
          testRecipe,
          2,
          0,
        );

        expect(
            updated.core.instructions, equals(['Step 3', 'Step 1', 'Step 2']));
      });
    });

    group('Image Operations', () {
      test('should add image URL', () {
        final updated = RecipeOperations.addImageUrl(
          testRecipe,
          'https://example.com/image.jpg',
          userId: 'user_789',
        );

        expect(updated.core.imageUrls.length, equals(1));
        expect(updated.core.imageUrls.first,
            equals('https://example.com/image.jpg'));
      });

      test('should not add empty image URL', () {
        final updated = RecipeOperations.addImageUrl(testRecipe, '   ');
        expect(updated.core.imageUrls, isEmpty);
      });

      test('should remove image URL at index', () {
        final recipeWithImages = testRecipe.copyWith(
          imageUrls: ['image1.jpg', 'image2.jpg', 'image3.jpg'],
        );

        final updated = RecipeOperations.removeImageUrl(recipeWithImages, 1);

        expect(updated.core.imageUrls.length, equals(2));
        expect(updated.core.imageUrls, equals(['image1.jpg', 'image3.jpg']));
      });

      test('should update all image URLs', () {
        final newUrls = ['  url1.jpg  ', '', 'url2.jpg', '  '];
        final updated = RecipeOperations.updateImageUrls(testRecipe, newUrls);

        expect(updated.core.imageUrls, equals(['url1.jpg', 'url2.jpg']));
      });
    });

    group('Recipe State Operations', () {
      test('should mark recipe as cooked', () {
        final before = DateTime.now();
        final updated = RecipeOperations.markAsCooked(
          testRecipe,
          userId: 'user_123',
          userDisplayName: 'Test User',
        );
        final after = DateTime.now();

        expect(updated.core.lastCookedAt, isNotNull);
        expect(
            updated.core.lastCookedAt!.isAfter(before) ||
                updated.core.lastCookedAt!.isAtSameMomentAs(before),
            isTrue);
        expect(
            updated.core.lastCookedAt!.isBefore(after) ||
                updated.core.lastCookedAt!.isAtSameMomentAs(after),
            isTrue);
      });

      test('should update basic recipe information', () {
        final updated = RecipeOperations.updateBasicInfo(
          testRecipe,
          title: 'Updated Title',
          description: 'Updated description',
          mealType: 'Frukost',
          portions: 6,
          timeMinutes: 45,
          rating: 4.5,
          personalTagIds: ['Updated', 'Tags'],
          sourceUrl: 'https://source.com',
          isPublic: true,
          userId: 'user_123',
          userDisplayName: 'Updater',
        );

        expect(updated.core.title, equals('Updated Title'));
        expect(updated.core.description, equals('Updated description'));
        expect(updated.core.mealType, equals('Frukost'));
        expect(updated.core.portions, equals(6));
        expect(updated.core.timeMinutes, equals(45));
        expect(updated.core.rating, equals(4.5));
        expect(updated.core.personalTagIds, equals(['Updated', 'Tags']));
        expect(updated.core.sourceUrl, equals('https://source.com'));
        expect(updated.core.isPublic, isTrue);
      });

      test('should update only specified fields', () {
        final updated = RecipeOperations.updateBasicInfo(
          testRecipe,
          title: 'New Title',
          portions: 8,
        );

        expect(updated.core.title, equals('New Title'));
        expect(updated.core.portions, equals(8));
        expect(updated.core.description, equals('Test description'));
        expect(updated.core.mealType, equals('Middag'));
        expect(updated.core.timeMinutes, equals(30));
      });
    });

    group('Validation', () {
      test('should validate complete recipe', () {
        expect(RecipeOperations.isValidRecipe(testRecipe), isTrue);
      });

      test('should invalidate recipe with empty title', () {
        final invalidRecipe = testRecipe.copyWith(title: '   ');
        expect(RecipeOperations.isValidRecipe(invalidRecipe), isFalse);
      });

      test('should invalidate recipe with no ingredients', () {
        final invalidRecipe = testRecipe.copyWith(ingredients: []);
        expect(RecipeOperations.isValidRecipe(invalidRecipe), isFalse);
      });

      test('should invalidate recipe with no instructions', () {
        final invalidRecipe = testRecipe.copyWith(instructions: []);
        expect(RecipeOperations.isValidRecipe(invalidRecipe), isFalse);
      });

      test('should invalidate recipe with empty meal type', () {
        final invalidRecipe = testRecipe.copyWith(mealType: '   ');
        expect(RecipeOperations.isValidRecipe(invalidRecipe), isFalse);
      });

      test('should get validation errors in Swedish', () {
        final invalidRecipe = RecipeFactory.createPersonal(
          title: '   ',
          description: 'Test',
          ingredients: [],
          instructions: [],
          mealType: '   ',
        );

        final errors = RecipeOperations.getValidationErrors(invalidRecipe);

        expect(errors.length, equals(4));
        expect(errors, contains('Titel saknas'));
        expect(errors, contains('Ingredienser saknas'));
        expect(errors, contains('Instruktioner saknas'));
        expect(errors, contains('Måltidstyp saknas'));
      });

      test('should check if recipe is publishable', () {
        expect(RecipeOperations.isPublishable(testRecipe), isTrue);

        final unpublishable = testRecipe.copyWith(description: '   ');
        expect(RecipeOperations.isPublishable(unpublishable), isFalse);

        // Create a recipe without portions from scratch since copyWith won't set to null
        final noPortions = RecipeFactory.createPersonal(
          title: 'Test',
          description: 'Test description',
          ingredients: ['A'],
          instructions: ['B'],
          mealType: 'Lunch',
          portions: null, // No portions
        );
        expect(RecipeOperations.isPublishable(noPortions), isFalse);

        final zeroPortions = testRecipe.copyWith(portions: 0);
        expect(RecipeOperations.isPublishable(zeroPortions), isFalse);

        // Test invalid recipe not publishable
        final invalidRecipe = testRecipe.copyWith(ingredients: []);
        expect(RecipeOperations.isPublishable(invalidRecipe), isFalse);
      });
    });

    group('Statistics', () {
      test('should get recipe statistics', () {
        final recipeWithTags = testRecipe.copyWith(
          imageUrls: ['image1.jpg', 'image2.jpg'],
        );

        final stats = RecipeOperations.getRecipeStats(recipeWithTags);

        expect(stats['ingredientCount'], equals(3));
        expect(stats['instructionCount'], equals(3));
        expect(stats['imageCount'], equals(2));
        expect(stats['tagCount'], equals(2));
        expect(stats['estimatedMinutes'], equals(30));
        expect(stats['portions'], equals(4));
      });

      test('should calculate complexity score', () {
        // Simple recipe (score = 1)
        final simple = RecipeFactory.createPersonal(
          title: 'Simple',
          description: 'Simple recipe',
          ingredients: ['A', 'B'], // 2 ingredients: no bonus
          instructions: ['Step 1'], // 1 instruction: no bonus
          mealType: 'Lunch',
          timeMinutes: 15, // < 30 minutes: no bonus
        );
        expect(RecipeOperations.getComplexityScore(simple), equals(1));

        // Medium complexity (score = 4)
        // Base: 1
        // 7 ingredients > 5: +1
        // 4 instructions > 3: +1
        // 35 minutes > 30: +1
        // Total: 4
        final medium = RecipeFactory.createPersonal(
          title: 'Medium',
          description: 'Medium recipe',
          ingredients: List.generate(7, (i) => 'Ingredient $i'),
          instructions: List.generate(4, (i) => 'Step $i'),
          mealType: 'Middag',
          timeMinutes: 35,
        );
        expect(RecipeOperations.getComplexityScore(medium), equals(4));

        // Complex recipe (score = 5, clamped)
        // Base: 1
        // 15 ingredients > 5: +1, > 10: +1
        // 8 instructions > 3: +1, > 6: +1
        // 90 minutes > 30: +1, > 60: +1
        // Total: 7, but clamped to 5
        final complex = RecipeFactory.createPersonal(
          title: 'Complex',
          description: 'Complex recipe',
          ingredients: List.generate(15, (i) => 'Ingredient $i'),
          instructions: List.generate(8, (i) => 'Step $i'),
          mealType: 'Middag',
          timeMinutes: 90,
        );
        expect(RecipeOperations.getComplexityScore(complex), equals(5));
      });

      test('should estimate preparation time', () {
        final recipe = RecipeFactory.createPersonal(
          title: 'Test',
          description: 'Test',
          ingredients: ['Onion', 'Garlic', 'Tomato'],
          instructions: [
            'Chop the onion',
            'Dice the tomato',
            'Mince the garlic',
            'Marinate for 30 minutes',
            'Let it rest',
          ],
          mealType: 'Middag',
        );

        final estimatedTime = RecipeOperations.estimatePreparationTime(recipe);

        // Base 15 + (3 ingredients * 2) + 3 chop/dice/mince * 5 + 2 marinate/rest * 10
        // = 15 + 6 + 15 + 20 = 56
        expect(estimatedTime, equals(56));
      });

      test('should handle Swedish keywords in preparation time estimation', () {
        final recipe = RecipeFactory.createPersonal(
          title: 'Test',
          description: 'Test',
          ingredients: ['Lök', 'Vitlök'],
          instructions: [
            'Hacka löken', // Contains 'chop' in Swedish (would need translation)
            'Låt det vila', // Contains 'rest' in Swedish (would need translation)
          ],
          mealType: 'Middag',
        );

        final estimatedTime = RecipeOperations.estimatePreparationTime(recipe);

        // Currently only checks English keywords
        // Base 15 + (2 ingredients * 2) = 19
        expect(estimatedTime, equals(19));
      });
    });

    group('Edge Cases', () {
      test('should handle recipe with minimal data', () {
        final minimal = RecipeFactory.createPersonal(
          title: 'Minimal',
          description: 'Min',
          ingredients: ['A'],
          instructions: ['B'],
          mealType: 'Lunch',
        );

        expect(RecipeOperations.isValidRecipe(minimal), isTrue);
        expect(RecipeOperations.isPublishable(minimal), isFalse); // No portions
        expect(RecipeOperations.getComplexityScore(minimal), equals(1));
      });

      test('should handle very long lists', () {
        final longRecipe = RecipeFactory.createPersonal(
          title: 'Long',
          description: 'Long recipe',
          ingredients: List.generate(100, (i) => 'Ingredient $i'),
          instructions: List.generate(50, (i) => 'Step $i'),
          mealType: 'Middag',
        );

        expect(RecipeOperations.isValidRecipe(longRecipe), isTrue);
        expect(RecipeOperations.getComplexityScore(longRecipe),
            equals(5)); // Max complexity

        final stats = RecipeOperations.getRecipeStats(longRecipe);
        expect(stats['ingredientCount'], equals(100));
        expect(stats['instructionCount'], equals(50));
      });

      test('should preserve immutability in all operations', () {
        final original = testRecipe;

        RecipeOperations.addIngredient(original, 'New');
        expect(original.core.ingredients.length, equals(3));

        RecipeOperations.removeInstruction(original, 0);
        expect(original.core.instructions.length, equals(3));

        RecipeOperations.markAsCooked(original);
        expect(original.core.lastCookedAt, isNull);
      });

      test('should handle collaborative recipe operations', () {
        final collaborative = RecipeFactory.createCollaborative(
          title: 'Collab',
          description: 'Collaborative recipe',
          ingredients: ['A', 'B'],
          instructions: ['Step 1', 'Step 2'],
          mealType: 'Middag',
          ownerId: 'owner_123',
          ownerDisplayName: 'Owner',
        );

        final updated = RecipeOperations.addIngredient(
          collaborative,
          'New Ingredient',
          userId: 'editor_456',
          userDisplayName: 'Editor',
        );

        expect(updated.core.ingredients.length, equals(3));
        expect(updated.type, equals(RecipeType.collaborative));
        expect(updated.socialData, isNotNull);
      });
    });
  });
}
