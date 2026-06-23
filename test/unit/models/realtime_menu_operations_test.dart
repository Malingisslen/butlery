// ignore_for_file: subtype_of_sealed_class

import 'package:flutter_test/flutter_test.dart';
import 'package:butlery/models/realtime/realtime_menu_operations.dart';
import 'package:butlery/models/realtime/realtime_menu_data.dart';
import 'package:butlery/models/recipe_unified.dart';
import '../../infrastructure/factories/recipe_factory.dart';
import 'helpers/model_test_base.dart';

void main() {
  ModelTestBase.testModelGroup('RealtimeMenuOperations', () {
    late RealtimeMenuData testMenuData;
    late Recipe recipe1;
    late Recipe recipe2;
    late Recipe recipe3;
    late Recipe recipe4;

    setUp(() {
      recipe1 = RecipeFactory.build(id: 'recipe_1', title: 'Pannkakor');
      recipe2 = RecipeFactory.build(id: 'recipe_2', title: 'Köttbullar');
      recipe3 = RecipeFactory.build(id: 'recipe_3', title: 'Laxsallad');
      recipe4 = RecipeFactory.build(id: 'recipe_4', title: 'Äppelpaj');

      final menuSnapshot = <String, List<Recipe>>{
        'Frukost': [recipe1],
        'Lunch': [recipe3],
        'Middag': [recipe2],
        'Efterrätt': <Recipe>[],
      };

      testMenuData = RealtimeMenuData(
        menuTitle: 'Test Menu',
        createdForDate: DateTime(2025, 1, 15),
        menuSnapshot: menuSnapshot,
        menuNotes: 'Test notes',
        favoriteRecipeIds: ['recipe_1', 'recipe_2'],
        originalPrompt: 'Generate a test menu',
      );
    });

    group('Recipe Management Operations', () {
      test('should add recipe to existing category', () {
        final updated = RealtimeMenuOperations.addRecipeToCategory(
          testMenuData,
          categoryName: 'Efterrätt',
          recipe: recipe4,
        );

        expect(updated.getRecipesForCategory('Efterrätt').length, equals(1));
        expect(
          updated.getRecipesForCategory('Efterrätt').first.id,
          equals('recipe_4'),
        );
        // Original data should remain unchanged
        expect(
          testMenuData.getRecipesForCategory('Efterrätt').length,
          equals(0),
        );
      });

      test('should add recipe to new category', () {
        final newRecipe = RecipeFactory.build(id: 'snack_1', title: 'Nötter');
        final updated = RealtimeMenuOperations.addRecipeToCategory(
          testMenuData,
          categoryName: 'Mellanmål',
          recipe: newRecipe,
        );

        expect(updated.categories, contains('Mellanmål'));
        expect(updated.getRecipesForCategory('Mellanmål').length, equals(1));
        expect(
          updated.getRecipesForCategory('Mellanmål').first.id,
          equals('snack_1'),
        );
      });

      test('should remove recipe from category', () {
        final updated = RealtimeMenuOperations.removeRecipeFromCategory(
          testMenuData,
          categoryName: 'Frukost',
          recipeIndex: 0,
        );

        expect(updated.getRecipesForCategory('Frukost').length, equals(0));
        // Original data unchanged
        expect(testMenuData.getRecipesForCategory('Frukost').length, equals(1));
      });

      test('should handle invalid index when removing', () {
        final updated = RealtimeMenuOperations.removeRecipeFromCategory(
          testMenuData,
          categoryName: 'Frukost',
          recipeIndex: 10, // Invalid index
        );

        // Should not crash, category should remain unchanged
        expect(updated.getRecipesForCategory('Frukost').length, equals(1));
      });

      test('should handle non-existent category when removing', () {
        final updated = RealtimeMenuOperations.removeRecipeFromCategory(
          testMenuData,
          categoryName: 'NonExistent',
          recipeIndex: 0,
        );

        // Should not crash, menu should remain unchanged
        expect(updated.menuSnapshot, equals(testMenuData.menuSnapshot));
      });

      test('should move recipe between categories', () {
        final updated = RealtimeMenuOperations.moveRecipeBetweenCategories(
          testMenuData,
          fromCategory: 'Frukost',
          fromIndex: 0,
          toCategory: 'Efterrätt',
        );

        expect(updated.getRecipesForCategory('Frukost').length, equals(0));
        expect(updated.getRecipesForCategory('Efterrätt').length, equals(1));
        expect(
          updated.getRecipesForCategory('Efterrätt').first.id,
          equals('recipe_1'),
        );
      });

      test('should move recipe to specific index', () {
        // First add multiple recipes to target category
        var updated = RealtimeMenuOperations.addRecipeToCategory(
          testMenuData,
          categoryName: 'Efterrätt',
          recipe: recipe4,
        );
        updated = RealtimeMenuOperations.addRecipeToCategory(
          updated,
          categoryName: 'Efterrätt',
          recipe: RecipeFactory.build(id: 'recipe_5', title: 'Glass'),
        );

        // Now move recipe to specific index
        updated = RealtimeMenuOperations.moveRecipeBetweenCategories(
          updated,
          fromCategory: 'Frukost',
          fromIndex: 0,
          toCategory: 'Efterrätt',
          toIndex: 1, // Insert in middle
        );

        final desserts = updated.getRecipesForCategory('Efterrätt');
        expect(desserts.length, equals(3));
        expect(desserts[0].id, equals('recipe_4'));
        expect(desserts[1].id, equals('recipe_1')); // Moved recipe
        expect(desserts[2].id, equals('recipe_5'));
      });

      test('should create new category when moving to non-existent', () {
        final updated = RealtimeMenuOperations.moveRecipeBetweenCategories(
          testMenuData,
          fromCategory: 'Frukost',
          fromIndex: 0,
          toCategory: 'Brunch',
        );

        expect(updated.categories, contains('Brunch'));
        expect(updated.getRecipesForCategory('Brunch').length, equals(1));
        expect(
          updated.getRecipesForCategory('Brunch').first.id,
          equals('recipe_1'),
        );
      });

      test('should replace recipe in category', () {
        final newRecipe = RecipeFactory.build(
          id: 'new_breakfast',
          title: 'Yoghurt',
        );
        final updated = RealtimeMenuOperations.replaceRecipeInCategory(
          testMenuData,
          categoryName: 'Frukost',
          recipeIndex: 0,
          newRecipe: newRecipe,
        );

        expect(updated.getRecipesForCategory('Frukost').length, equals(1));
        expect(
          updated.getRecipesForCategory('Frukost').first.id,
          equals('new_breakfast'),
        );
      });

      test('should clear category', () {
        final updated = RealtimeMenuOperations.clearCategory(
          testMenuData,
          categoryName: 'Middag',
        );

        expect(updated.getRecipesForCategory('Middag').length, equals(0));
        expect(updated.categories, contains('Middag')); // Category still exists
      });

      test('should update whole category', () {
        final newRecipes = [
          RecipeFactory.build(id: 'new_1', title: 'Pasta'),
          RecipeFactory.build(id: 'new_2', title: 'Pizza'),
        ];

        final updated = RealtimeMenuOperations.updateWholeCategory(
          testMenuData,
          categoryName: 'Middag',
          recipes: newRecipes,
        );

        expect(updated.getRecipesForCategory('Middag').length, equals(2));
        expect(updated.getRecipesForCategory('Middag')[0].id, equals('new_1'));
        expect(updated.getRecipesForCategory('Middag')[1].id, equals('new_2'));
      });

      test('should regenerate category', () {
        final newRecipes = [
          RecipeFactory.build(id: 'regen_1', title: 'Sallad'),
        ];

        final updated = RealtimeMenuOperations.regenerateCategory(
          testMenuData,
          categoryName: 'Lunch',
          newRecipes: newRecipes,
        );

        expect(updated.getRecipesForCategory('Lunch').length, equals(1));
        expect(
          updated.getRecipesForCategory('Lunch').first.id,
          equals('regen_1'),
        );
      });

      test('should create new category when updating', () {
        final newRecipes = [
          RecipeFactory.build(id: 'snack_1', title: 'Chips'),
        ];

        final updated = RealtimeMenuOperations.updateWholeCategory(
          testMenuData,
          categoryName: 'Snacks',
          recipes: newRecipes,
        );

        expect(updated.categories, contains('Snacks'));
        expect(updated.getRecipesForCategory('Snacks').length, equals(1));
      });
    });

    group('Category Sorting', () {
      test('should get common categories', () {
        final common = RealtimeMenuOperations.commonCategories;

        expect(common, contains('Frukost'));
        expect(common, contains('Lunch'));
        expect(common, contains('Middag'));
        expect(common, contains('Efterrätter'));
        expect(common, contains('Mellanmål'));
      });

      test('should sort categories in logical order', () {
        // Create menu with categories in random order
        final menuData = RealtimeMenuData(
          menuTitle: 'Unsorted',
          createdForDate: DateTime.now(),
          menuSnapshot: {
            'Efterrätter': [],
            'CustomCategory': [],
            'Middag': [],
            'Frukost': [],
            'AnotherCustom': [],
            'Lunch': [],
          },
        );

        final sorted = RealtimeMenuOperations.getCategoriesSorted(menuData);

        // Common categories should come first in order
        expect(sorted[0], equals('Frukost'));
        expect(sorted[1], equals('Lunch'));
        expect(sorted[2], equals('Middag'));
        expect(sorted[3], equals('Efterrätter'));
        // Custom categories should come after
        expect(
          sorted.sublist(4),
          containsAll(['CustomCategory', 'AnotherCustom']),
        );
      });
    });

    group('Statistics and Analysis', () {
      test('should get total recipe count', () {
        final count = RealtimeMenuOperations.getTotalRecipeCount(testMenuData);
        expect(count, equals(3)); // Unique recipes only
      });

      test('should get categories with recipes', () {
        final count = RealtimeMenuOperations.getCategoriesWithRecipes(
          testMenuData,
        );
        expect(count, equals(3)); // Frukost, Lunch, Middag have recipes
      });

      test('should get empty categories count', () {
        final count = RealtimeMenuOperations.getEmptyCategoriesCount(
          testMenuData,
        );
        expect(count, equals(1)); // Efterrätt is empty
      });

      test('should check if menu is complete', () {
        expect(RealtimeMenuOperations.isComplete(testMenuData), isTrue);

        // Test with only one category having recipes
        final sparseMenu = RealtimeMenuData(
          menuTitle: 'Sparse',
          createdForDate: DateTime.now(),
          menuSnapshot: {
            'Lunch': [recipe1],
            'Middag': [],
          },
        );
        expect(RealtimeMenuOperations.isComplete(sparseMenu), isFalse);
      });

      test('should check if menu is well balanced', () {
        expect(RealtimeMenuOperations.isWellBalanced(testMenuData), isTrue);

        // Test with only two categories having recipes
        final unbalancedMenu = RealtimeMenuData(
          menuTitle: 'Unbalanced',
          createdForDate: DateTime.now(),
          menuSnapshot: {
            'Lunch': [recipe1],
            'Middag': [recipe2],
            'Efterrätt': [],
          },
        );
        expect(RealtimeMenuOperations.isWellBalanced(unbalancedMenu), isFalse);
      });

      test('should calculate average recipes per category', () {
        final average = RealtimeMenuOperations.getAverageRecipesPerCategory(
          testMenuData,
        );
        expect(average, equals(0.75)); // 3 recipes / 4 categories
      });

      test('should check if menu has favorites', () {
        expect(RealtimeMenuOperations.hasFavorites(testMenuData), isTrue);

        final noFavoritesMenu = testMenuData.copyWith(favoriteRecipeIds: null);
        expect(RealtimeMenuOperations.hasFavorites(noFavoritesMenu), isFalse);
      });

      test('should get favorites count', () {
        expect(
          RealtimeMenuOperations.getFavoritesCount(testMenuData),
          equals(2),
        );

        final noFavoritesMenu = testMenuData.copyWith(favoriteRecipeIds: null);
        expect(
          RealtimeMenuOperations.getFavoritesCount(noFavoritesMenu),
          equals(0),
        );
      });

      test('should check if menu has notes', () {
        expect(RealtimeMenuOperations.hasNotes(testMenuData), isTrue);

        final noNotesMenu = testMenuData.copyWith(menuNotes: null);
        expect(RealtimeMenuOperations.hasNotes(noNotesMenu), isFalse);

        final emptyNotesMenu = testMenuData.copyWith(menuNotes: '');
        expect(RealtimeMenuOperations.hasNotes(emptyNotesMenu), isFalse);
      });

      test('should check if menu was generated', () {
        expect(RealtimeMenuOperations.wasGenerated(testMenuData), isTrue);

        final manualMenu = testMenuData.copyWith(originalPrompt: null);
        expect(RealtimeMenuOperations.wasGenerated(manualMenu), isFalse);
      });

      test('should get menu summary', () {
        final summary = RealtimeMenuOperations.getMenuSummary(testMenuData);
        expect(summary, equals('3 recept i 3 kategorier'));
      });

      test('should get completion percentage', () {
        final percentage = RealtimeMenuOperations.getCompletionPercentage(
          testMenuData,
        );
        expect(percentage, equals(0.75)); // 3 out of 4 categories have recipes
      });

      test('should get completion status text', () {
        final status = RealtimeMenuOperations.getCompletionStatus(testMenuData);
        expect(status, equals('75% färdig'));
      });

      test('should get progress color name', () {
        expect(
          RealtimeMenuOperations.getProgressColorName(testMenuData),
          equals('green'),
        );

        // Test yellow range
        final yellowMenu = RealtimeMenuData(
          menuTitle: 'Yellow',
          createdForDate: DateTime.now(),
          menuSnapshot: {
            'Cat1': [recipe1],
            'Cat2': [],
            'Cat3': [],
          },
        );
        expect(
          RealtimeMenuOperations.getProgressColorName(yellowMenu),
          equals('yellow'),
        );

        // Test red range
        final redMenu = RealtimeMenuData(
          menuTitle: 'Red',
          createdForDate: DateTime.now(),
          menuSnapshot: {
            'Cat1': [recipe1],
            'Cat2': [],
            'Cat3': [],
            'Cat4': [],
            'Cat5': [],
          },
        );
        expect(
          RealtimeMenuOperations.getProgressColorName(redMenu),
          equals('red'),
        );
      });

      test('should get recipes needing attention', () {
        final recipes = RealtimeMenuOperations.getRecipesNeedingAttention(
          testMenuData,
        );
        expect(recipes, isEmpty); // Placeholder implementation returns empty
      });

      test('should create personal menu copy', () {
        final copy = RealtimeMenuOperations.createPersonalMenuCopy(
          testMenuData,
          'Anna Andersson',
        );

        expect(copy, equals(testMenuData.menuSnapshot));
        // Should be a copy, not the same instance
        expect(identical(copy, testMenuData.menuSnapshot), isFalse);
      });
    });

    group('Edge Cases', () {
      test('should handle empty menu', () {
        final emptyMenu = RealtimeMenuData(
          menuTitle: 'Empty',
          createdForDate: DateTime.now(),
          menuSnapshot: {},
        );

        expect(
          RealtimeMenuOperations.getTotalRecipeCount(emptyMenu),
          equals(0),
        );
        expect(
          RealtimeMenuOperations.getCategoriesWithRecipes(emptyMenu),
          equals(0),
        );
        expect(
          RealtimeMenuOperations.getAverageRecipesPerCategory(emptyMenu),
          equals(0.0),
        );
        expect(
          RealtimeMenuOperations.getCompletionPercentage(emptyMenu),
          equals(0.0),
        );
      });

      test('should handle deep copy properly (no mutation)', () {
        // This tests the fix from P3 for the shallow copy bug
        final original = RealtimeMenuData(
          menuTitle: 'Original',
          createdForDate: DateTime.now(),
          menuSnapshot: {
            'Category': [recipe1, recipe2],
          },
        );

        // Perform multiple operations
        final updated1 = RealtimeMenuOperations.addRecipeToCategory(
          original,
          categoryName: 'Category',
          recipe: recipe3,
        );

        final updated2 = RealtimeMenuOperations.removeRecipeFromCategory(
          original,
          categoryName: 'Category',
          recipeIndex: 0,
        );

        // Original should remain unchanged
        expect(original.getRecipesForCategory('Category').length, equals(2));
        expect(
          original.getRecipesForCategory('Category')[0].id,
          equals('recipe_1'),
        );

        // Updates should be independent
        expect(updated1.getRecipesForCategory('Category').length, equals(3));
        expect(updated2.getRecipesForCategory('Category').length, equals(1));
        expect(
          updated2.getRecipesForCategory('Category')[0].id,
          equals('recipe_2'),
        );
      });

      test('should handle Swedish characters in categories', () {
        final swedishMenu = RealtimeMenuData(
          menuTitle: 'Swedish',
          createdForDate: DateTime.now(),
          menuSnapshot: {
            'Smörgåsbord': [recipe1],
            'Köttbullar & Såser': [recipe2],
            'Äppelpaj med vaniljsås': [recipe3],
          },
        );

        final updated = RealtimeMenuOperations.addRecipeToCategory(
          swedishMenu,
          categoryName: 'Räkmacka',
          recipe: recipe4,
        );

        expect(updated.categories, contains('Räkmacka'));
        expect(updated.getRecipesForCategory('Räkmacka').length, equals(1));
      });
    });
  });
}
