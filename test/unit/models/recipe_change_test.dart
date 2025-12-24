import 'package:flutter_test/flutter_test.dart';
import 'package:butlery/models/recipe_change.dart';
import 'package:butlery/models/recipe_unified.dart';
import '../../infrastructure/factories/recipe_factory.dart';
import 'helpers/model_test_base.dart';

void main() {
  ModelTestBase.testModelGroup('RecipeChange', () {
    late Recipe testRecipe;
    late Recipe testRecipe2;

    setUp(() {
      testRecipe = RecipeFactory.build(
        id: 'recipe_123',
        title: 'Köttbullar med potatismos',
        description: 'Klassiska svenska köttbullar',
        ingredients: ['Köttfärs', 'Mjölk', 'Ströbröd'],
        instructions: ['Blanda och forma köttbullar...'],
        timeMinutes: 50,
        portions: 4,
        createdBy: 'user_789',
        createdAt: DateTime(2024, 1, 15),
        updatedAt: DateTime(2024, 1, 15),
      );

      testRecipe2 = RecipeFactory.build(
        id: 'recipe_456',
        title: 'Pannkakor',
        description: 'Svenska tunnbröd',
        ingredients: ['Mjöl', 'Mjölk', 'Ägg'],
        instructions: ['Vispa samman...'],
        timeMinutes: 25,
        portions: 4,
        createdBy: 'user_999',
        createdAt: DateTime(2024, 1, 20),
        updatedAt: DateTime(2024, 1, 20),
      );
    });

    group('Construction', () {
      test('should create with required parameters', () {
        final change = RecipeChange(
          type: RecipeChangeType.added,
          recipe: testRecipe,
        );

        expect(change.type, equals(RecipeChangeType.added));
        expect(change.recipe, equals(testRecipe));
        expect(change.recipeId, equals('recipe_123'));
      });

      test('should handle all change types', () {
        final addedChange = RecipeChange(
          type: RecipeChangeType.added,
          recipe: testRecipe,
        );

        final modifiedChange = RecipeChange(
          type: RecipeChangeType.modified,
          recipe: testRecipe,
        );

        final removedChange = RecipeChange(
          type: RecipeChangeType.removed,
          recipe: testRecipe,
        );

        expect(addedChange.type, equals(RecipeChangeType.added));
        expect(modifiedChange.type, equals(RecipeChangeType.modified));
        expect(removedChange.type, equals(RecipeChangeType.removed));
      });

      test('should preserve complete recipe state', () {
        final change = RecipeChange(
          type: RecipeChangeType.modified,
          recipe: testRecipe,
        );

        expect(change.recipe.id, equals('recipe_123'));
        expect(change.recipe.title, equals('Köttbullar med potatismos'));
        expect(
            change.recipe.description, equals('Klassiska svenska köttbullar'));
        expect(change.recipe.ingredients,
            equals(['Köttfärs', 'Mjölk', 'Ströbröd']));
        expect(change.recipe.createdBy, equals('user_789'));
      });

      test('should handle different recipes with same change type', () {
        final change1 = RecipeChange(
          type: RecipeChangeType.added,
          recipe: testRecipe,
        );

        final change2 = RecipeChange(
          type: RecipeChangeType.added,
          recipe: testRecipe2,
        );

        expect(change1.recipeId, equals('recipe_123'));
        expect(change2.recipeId, equals('recipe_456'));
        expect(change1.type, equals(change2.type));
      });
    });

    group('Change Type Classification', () {
      test('should identify addition changes', () {
        final change = RecipeChange(
          type: RecipeChangeType.added,
          recipe: testRecipe,
        );

        expect(change.isAddition, isTrue);
        expect(change.isModification, isFalse);
        expect(change.isRemoval, isFalse);
      });

      test('should identify modification changes', () {
        final change = RecipeChange(
          type: RecipeChangeType.modified,
          recipe: testRecipe,
        );

        expect(change.isAddition, isFalse);
        expect(change.isModification, isTrue);
        expect(change.isRemoval, isFalse);
      });

      test('should identify removal changes', () {
        final change = RecipeChange(
          type: RecipeChangeType.removed,
          recipe: testRecipe,
        );

        expect(change.isAddition, isFalse);
        expect(change.isModification, isFalse);
        expect(change.isRemoval, isTrue);
      });
    });

    group('Recipe ID Access', () {
      test('should provide convenient recipe ID access', () {
        final change = RecipeChange(
          type: RecipeChangeType.modified,
          recipe: testRecipe,
        );

        expect(change.recipeId, equals('recipe_123'));
        expect(change.recipeId, equals(change.recipe.id));
      });

      test('should handle recipe with complex ID', () {
        final complexRecipe = RecipeFactory.build(
          id: 'recipe_abc123_xyz789_complex',
          title: 'Complex Recipe',
          description: 'Test',
          ingredients: [],
          instructions: [],
          timeMinutes: 0,
          portions: 1,
          createdBy: 'user',
        );

        final change = RecipeChange(
          type: RecipeChangeType.added,
          recipe: complexRecipe,
        );

        expect(change.recipeId, equals('recipe_abc123_xyz789_complex'));
      });
    });

    group('Swedish Localization', () {
      test('should provide Swedish text for added type', () {
        final change = RecipeChange(
          type: RecipeChangeType.added,
          recipe: testRecipe,
        );

        expect(change.changeTypeText, equals('Tillagd'));
      });

      test('should provide Swedish text for modified type', () {
        final change = RecipeChange(
          type: RecipeChangeType.modified,
          recipe: testRecipe,
        );

        expect(change.changeTypeText, equals('Ändrad'));
      });

      test('should provide Swedish text for removed type', () {
        final change = RecipeChange(
          type: RecipeChangeType.removed,
          recipe: testRecipe,
        );

        expect(change.changeTypeText, equals('Borttagen'));
      });

      test('should handle all change types with Swedish text', () {
        final changes = [
          RecipeChange(type: RecipeChangeType.added, recipe: testRecipe),
          RecipeChange(type: RecipeChangeType.modified, recipe: testRecipe),
          RecipeChange(type: RecipeChangeType.removed, recipe: testRecipe),
        ];

        final texts = changes.map((c) => c.changeTypeText).toList();

        expect(texts, equals(['Tillagd', 'Ändrad', 'Borttagen']));
      });
    });

    group('Equality and Hashing', () {
      test('should be equal when type and recipe ID match', () {
        final change1 = RecipeChange(
          type: RecipeChangeType.modified,
          recipe: testRecipe,
        );

        // Same recipe ID, same type, but potentially different recipe content
        final modifiedRecipe = RecipeFactory.build(
          id: 'recipe_123', // Same ID
          title: 'Updated Name',
          description: 'Updated description',
          ingredients: ['Different'],
          instructions: ['Different'],
          timeMinutes: 99,
          portions: 99,
          createdBy: 'different_user',
        );

        final change2 = RecipeChange(
          type: RecipeChangeType.modified,
          recipe: modifiedRecipe,
        );

        expect(change1, equals(change2));
        expect(change1.hashCode, equals(change2.hashCode));
      });

      test('should not be equal when type differs', () {
        final change1 = RecipeChange(
          type: RecipeChangeType.added,
          recipe: testRecipe,
        );

        final change2 = RecipeChange(
          type: RecipeChangeType.modified,
          recipe: testRecipe,
        );

        expect(change1, isNot(equals(change2)));
      });

      test('should not be equal when recipe ID differs', () {
        final change1 = RecipeChange(
          type: RecipeChangeType.added,
          recipe: testRecipe,
        );

        final change2 = RecipeChange(
          type: RecipeChangeType.added,
          recipe: testRecipe2,
        );

        expect(change1, isNot(equals(change2)));
      });

      test('should be equal to itself', () {
        final change = RecipeChange(
          type: RecipeChangeType.modified,
          recipe: testRecipe,
        );

        expect(change, equals(change));
      });

      test('should handle hash collisions properly', () {
        final changes = <RecipeChange>{};

        changes.add(RecipeChange(
          type: RecipeChangeType.added,
          recipe: testRecipe,
        ));

        // Try to add duplicate (same type and recipe ID)
        changes.add(RecipeChange(
          type: RecipeChangeType.added,
          recipe: testRecipe,
        ));

        expect(changes.length, equals(1)); // Should not add duplicate

        // Add different change
        changes.add(RecipeChange(
          type: RecipeChangeType.modified,
          recipe: testRecipe,
        ));

        expect(changes.length, equals(2));
      });
    });

    group('toString', () {
      test('should provide meaningful string representation', () {
        final change = RecipeChange(
          type: RecipeChangeType.modified,
          recipe: testRecipe,
        );

        final str = change.toString();

        expect(str, contains('RecipeChange'));
        expect(str, contains('modified'));
        expect(str, contains('recipe_123'));
      });

      test('should include change type in string', () {
        final added = RecipeChange(
          type: RecipeChangeType.added,
          recipe: testRecipe,
        );

        final modified = RecipeChange(
          type: RecipeChangeType.modified,
          recipe: testRecipe,
        );

        final removed = RecipeChange(
          type: RecipeChangeType.removed,
          recipe: testRecipe,
        );

        expect(added.toString(), contains('added'));
        expect(modified.toString(), contains('modified'));
        expect(removed.toString(), contains('removed'));
      });
    });

    group('Use Cases', () {
      test('should support change tracking list', () {
        final changes = <RecipeChange>[
          RecipeChange(type: RecipeChangeType.added, recipe: testRecipe),
          RecipeChange(type: RecipeChangeType.modified, recipe: testRecipe),
          RecipeChange(type: RecipeChangeType.removed, recipe: testRecipe2),
        ];

        expect(changes.length, equals(3));
        expect(changes[0].isAddition, isTrue);
        expect(changes[1].isModification, isTrue);
        expect(changes[2].isRemoval, isTrue);
      });

      test('should support filtering by change type', () {
        final changes = [
          RecipeChange(type: RecipeChangeType.added, recipe: testRecipe),
          RecipeChange(type: RecipeChangeType.added, recipe: testRecipe2),
          RecipeChange(type: RecipeChangeType.modified, recipe: testRecipe),
          RecipeChange(type: RecipeChangeType.removed, recipe: testRecipe2),
        ];

        final additions = changes.where((c) => c.isAddition).toList();
        final modifications = changes.where((c) => c.isModification).toList();
        final removals = changes.where((c) => c.isRemoval).toList();

        expect(additions.length, equals(2));
        expect(modifications.length, equals(1));
        expect(removals.length, equals(1));
      });

      test('should support grouping by recipe ID', () {
        final changes = [
          RecipeChange(type: RecipeChangeType.added, recipe: testRecipe),
          RecipeChange(type: RecipeChangeType.modified, recipe: testRecipe),
          RecipeChange(type: RecipeChangeType.removed, recipe: testRecipe),
        ];

        final grouped = <String, List<RecipeChange>>{};
        for (final change in changes) {
          grouped.putIfAbsent(change.recipeId, () => []).add(change);
        }

        expect(grouped['recipe_123']!.length, equals(3));
      });

      test('should support change history timeline', () {
        final timeline = <RecipeChange>[];

        // Recipe lifecycle
        timeline.add(RecipeChange(
          type: RecipeChangeType.added,
          recipe: testRecipe,
        ));

        // Multiple modifications
        for (int i = 0; i < 5; i++) {
          timeline.add(RecipeChange(
            type: RecipeChangeType.modified,
            recipe: testRecipe,
          ));
        }

        // Final removal
        timeline.add(RecipeChange(
          type: RecipeChangeType.removed,
          recipe: testRecipe,
        ));

        expect(timeline.length, equals(7));
        expect(timeline.first.isAddition, isTrue);
        expect(timeline.last.isRemoval, isTrue);
        expect(timeline.where((c) => c.isModification).length, equals(5));
      });
    });

    group('Edge Cases', () {
      test('should handle recipe with minimal data', () {
        final minimalRecipe = RecipeFactory.build(
          id: 'r',
          title: '',
          description: '',
          ingredients: [],
          instructions: [],
          timeMinutes: 0,
          portions: 1,
          createdBy: '',
        );

        final change = RecipeChange(
          type: RecipeChangeType.added,
          recipe: minimalRecipe,
        );

        expect(change.recipeId, equals('r'));
        expect(change.recipe.title, isEmpty);
      });

      test('should handle recipe with Swedish characters', () {
        final swedishRecipe = RecipeFactory.build(
          id: 'recipe_åäö',
          title: 'Räksmörgås à la Skåne',
          description: 'Öländsk specialitet',
          ingredients: ['Räkor', 'Ägg', 'Majonnäs'],
          instructions: ['Lägg på smörgåsen'],
          timeMinutes: 10,
          portions: 2,
          createdBy: 'user_åsa',
        );

        final change = RecipeChange(
          type: RecipeChangeType.added,
          recipe: swedishRecipe,
        );

        expect(change.recipeId, equals('recipe_åäö'));
        expect(change.recipe.title, contains('Räksmörgås'));
        expect(change.recipe.createdBy, equals('user_åsa'));
      });

      test('should handle very large recipe data', () {
        final largeIngredients = List.generate(100, (i) => 'Ingredient $i');
        final largeInstructions =
            List.generate(100, (i) => 'Step $i: Do something');

        final largeRecipe = RecipeFactory.build(
          id: 'recipe_large',
          title: 'Large Recipe',
          description: 'A' * 1000,
          ingredients: largeIngredients,
          instructions: largeInstructions,
          timeMinutes: 999,
          portions: 100,
          createdBy: 'user',
        );

        final change = RecipeChange(
          type: RecipeChangeType.modified,
          recipe: largeRecipe,
        );

        expect(change.recipe.ingredients.length, equals(100));
        expect(change.recipe.description.length, equals(1000));
      });

      test('should maintain referential integrity', () {
        final change = RecipeChange(
          type: RecipeChangeType.modified,
          recipe: testRecipe,
        );

        // Verify the recipe reference is maintained
        expect(identical(change.recipe, testRecipe), isTrue);

        // Modifying original should not affect change
        final newRecipe = RecipeFactory.build(
          id: 'new_id',
          title: 'New',
          description: 'New',
          ingredients: [],
          instructions: [],
          timeMinutes: 0,
          portions: 1,
          createdBy: 'new',
        );

        final newChange = RecipeChange(
          type: RecipeChangeType.added,
          recipe: newRecipe,
        );

        expect(change.recipeId, equals('recipe_123'));
        expect(newChange.recipeId, equals('new_id'));
      });

      test('should handle change type enum values', () {
        // Ensure all enum values are handled
        expect(RecipeChangeType.values.length, equals(3));

        for (final changeType in RecipeChangeType.values) {
          final change = RecipeChange(
            type: changeType,
            recipe: testRecipe,
          );

          expect(change.changeTypeText, isNotEmpty);
          expect(change.changeTypeText, isNot(contains('RecipeChangeType')));
        }
      });
    });
  });
}
