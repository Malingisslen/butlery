import 'package:flutter_test/flutter_test.dart';
import 'package:butlery/services/realtime/modules/menu_operations.dart';
import 'package:butlery/models/recipe_unified.dart';
import '../../../../test_support/base_unit_test.dart';
import '../../../../infrastructure/builders/realtime_menu_builder.dart';
import '../../../../infrastructure/builders/recipe_builder.dart';

void main() {
  group('MenuOperations', () {
    late RealtimeMenuBuilder menuBuilder;
    late RecipeBuilder recipeBuilder;
    
    setUp(() async {
      await BaseUnitTest.setupUnit();
      menuBuilder = RealtimeMenuBuilder();
      recipeBuilder = RecipeBuilder();
    });
    
    tearDown(() async {
      await BaseUnitTest.teardownUnit();
    });
    
    group('Initialization', () {
      test('should work with default menu creation', () {
        // Arrange
        final menu = menuBuilder.build();
        
        // Act & Assert
        expect(menu.menuTitle, 'Test Menu');
        expect(menu.menuSnapshot, isA<Map<String, List<Recipe>>>());
        expect(menu.id, isNotEmpty);
      });
      
      test('should handle menu with Swedish categories', () {
        // Arrange
        final menu = menuBuilder.asSwedishWeeklyMenu().build();
        
        // Act
        final categories = menu.categories;
        
        // Assert
        expect(categories, contains('Måndag'));
        expect(categories, contains('Helg'));
        expect(menu.menuSnapshot['Måndag'], isNotEmpty);
      });
      
      test('should validate menu structure', () {
        // Arrange
        final menu = menuBuilder.asMinimalMenu().build();
        
        // Act & Assert
        expect(menu.menuTitle, 'Min');
        expect(menu.menuSnapshot['Dag'], isEmpty);
        expect(menu.menuNotes, isNull);
      });
    });
    
    group('Basic Info Updates', () {
      test('should update menu title successfully', () {
        // Arrange
        final menu = menuBuilder.build();
        
        // Act
        final updated = MenuOperations.updateBasicInfo(
          menu,
          menuTitle: 'Uppdaterad meny',
          editedBy: 'test_user',
          editedByDisplayName: 'Test User',
        );
        
        // Assert
        expect(updated.menuTitle, 'Uppdaterad meny');
        expect(identical(menu, updated), false); // New instance
      });
      
      test('should update menu notes', () {
        // Arrange
        final menu = menuBuilder.build();
        
        // Act
        final updated = MenuOperations.updateBasicInfo(
          menu,
          menuNotes: 'Nya anteckningar för menyn',
          editedBy: 'test_user',
          editedByDisplayName: 'Test User',
        );
        
        // Assert
        expect(updated.menuNotes, 'Nya anteckningar för menyn');
      });
      
      test('should update favorite recipe IDs', () {
        // Arrange
        final menu = menuBuilder.build();
        final favoriteIds = ['recipe_1', 'recipe_2', 'recipe_3'];
        
        // Act
        final updated = MenuOperations.updateBasicInfo(
          menu,
          favoriteRecipeIds: favoriteIds,
          editedBy: 'test_user',
          editedByDisplayName: 'Test User',
        );
        
        // Assert
        expect(updated.favoriteRecipeIds, favoriteIds);
        expect(updated.favoriteRecipeIds!.length, 3);
      });
      
      test('should validate immutability - returns new instance', () {
        // Arrange
        final original = menuBuilder.withTitle('Original').build();
        
        // Act
        final updated = MenuOperations.updateBasicInfo(
          original,
          menuTitle: 'Updated',
          editedBy: 'test_user',
          editedByDisplayName: 'Test User',
        );
        
        // Assert
        expect(original.menuTitle, 'Original');
        expect(updated.menuTitle, 'Updated');
        expect(identical(original, updated), false);
      });
    });
    
    group('Recipe Management', () {
      test('should add recipe to category successfully', () {
        // Arrange
        final menu = menuBuilder.withCategory('Måndag', []).build();
        final recipe = recipeBuilder.asSwedishDinner().build();
        
        // Act
        final updated = MenuOperations.addRecipeToCategory(
          menu,
          categoryName: 'Måndag',
          recipe: recipe,
          editedBy: 'test_user',
          editedByDisplayName: 'Test User',
        );
        
        // Assert
        expect(updated.menuSnapshot['Måndag']!.length, 1);
        expect(updated.menuSnapshot['Måndag']!.first.title, 'Köttbullar med potatismos');
      });
      
      test('should remove recipe from category by index', () {
        // Arrange
        final recipe1 = recipeBuilder.withTitle('Recipe 1').build();
        final recipe2 = recipeBuilder.withTitle('Recipe 2').build();
        final menu = menuBuilder.withCategory('Tisdag', [recipe1, recipe2]).build();
        
        // Act
        final updated = MenuOperations.removeRecipeFromCategory(
          menu,
          categoryName: 'Tisdag',
          recipeIndex: 0,
          editedBy: 'test_user',
          editedByDisplayName: 'Test User',
        );
        
        // Assert
        expect(updated.menuSnapshot['Tisdag']!.length, 1);
        expect(updated.menuSnapshot['Tisdag']!.first.title, 'Recipe 2');
      });
      
      test('should move recipe between categories', () {
        // Arrange
        final recipe = recipeBuilder.asItalianPasta().build();
        final menu = menuBuilder
            .withCategory('Måndag', [recipe])
            .withCategory('Tisdag', [])
            .build();
        
        // Act
        final updated = MenuOperations.moveRecipeBetweenCategories(
          menu,
          fromCategory: 'Måndag',
          fromIndex: 0,
          toCategory: 'Tisdag',
          editedBy: 'test_user',
          editedByDisplayName: 'Test User',
        );
        
        // Assert
        expect(updated.menuSnapshot['Måndag'], isEmpty);
        expect(updated.menuSnapshot['Tisdag']!.length, 1);
        expect(updated.menuSnapshot['Tisdag']!.first.title, 'Pasta Carbonara');
      });
      
      test('should replace recipe in category', () {
        // Arrange
        final oldRecipe = recipeBuilder.withTitle('Old Recipe').build();
        final newRecipe = recipeBuilder.withTitle('New Recipe').build();
        final menu = menuBuilder.withCategory('Onsdag', [oldRecipe]).build();
        
        // Act
        final updated = MenuOperations.replaceRecipeInCategory(
          menu,
          categoryName: 'Onsdag',
          recipeIndex: 0,
          newRecipe: newRecipe,
          editedBy: 'test_user',
          editedByDisplayName: 'Test User',
        );
        
        // Assert
        expect(updated.menuSnapshot['Onsdag']!.length, 1);
        expect(updated.menuSnapshot['Onsdag']!.first.title, 'New Recipe');
      });
      
      test('should clear entire category', () {
        // Arrange
        final recipes = [
          recipeBuilder.withTitle('Recipe 1').build(),
          recipeBuilder.withTitle('Recipe 2').build(),
          recipeBuilder.withTitle('Recipe 3').build(),
        ];
        final menu = menuBuilder.withCategory('Torsdag', recipes).build();
        
        // Act
        final updated = MenuOperations.clearCategory(
          menu,
          categoryName: 'Torsdag',
          editedBy: 'test_user',
          editedByDisplayName: 'Test User',
        );
        
        // Assert
        expect(updated.menuSnapshot['Torsdag'], isEmpty);
      });
      
      test('should update whole category with new recipes', () {
        // Arrange
        final oldRecipes = [recipeBuilder.withTitle('Old').build()];
        final newRecipes = [
          recipeBuilder.withTitle('New 1').build(),
          recipeBuilder.withTitle('New 2').build(),
        ];
        final menu = menuBuilder.withCategory('Fredag', oldRecipes).build();
        
        // Act
        final updated = MenuOperations.updateWholeCategory(
          menu,
          categoryName: 'Fredag',
          recipes: newRecipes,
          editedBy: 'test_user',
          editedByDisplayName: 'Test User',
        );
        
        // Assert
        expect(updated.menuSnapshot['Fredag']!.length, 2);
        expect(updated.menuSnapshot['Fredag']!.first.title, 'New 1');
        expect(updated.menuSnapshot['Fredag']!.last.title, 'New 2');
      });
      
      test('should add recipe to new category', () {
        // Arrange
        final menu = menuBuilder.build();
        final recipe = recipeBuilder.build();
        
        // Act - Adding to non-existent category creates it
        final updated = MenuOperations.addRecipeToCategory(
          menu,
          categoryName: 'NonExistent',
          recipe: recipe,
          editedBy: 'test_user',
          editedByDisplayName: 'Test User',
        );
        
        // Assert
        expect(updated.menuSnapshot.containsKey('NonExistent'), true);
        expect(updated.menuSnapshot['NonExistent']!.length, 1);
      });
      
      test('should handle index bounds when removing recipe', () {
        // Arrange
        final recipe = recipeBuilder.build();
        final menu = menuBuilder.withCategory('Lördag', [recipe]).build();
        
        // Act - Out of bounds index removes nothing
        final updated = MenuOperations.removeRecipeFromCategory(
          menu,
          categoryName: 'Lördag',
          recipeIndex: 5, // Out of bounds
          editedBy: 'test_user',
          editedByDisplayName: 'Test User',
        );
        
        // Assert - Recipe still there
        expect(updated.menuSnapshot['Lördag']!.length, 1);
      });
    });
    
    group('Utilities', () {
      test('should generate menu statistics', () {
        // Arrange
        final menu = menuBuilder.asSwedishWeeklyMenu().build();
        
        // Act
        final stats = MenuOperations.getMenuStatistics(menu);
        
        // Assert
        expect(stats['totalCategories'], greaterThan(0));
        expect(stats['totalRecipes'], greaterThan(0));
        expect(stats['categoryBreakdown'], contains('Måndag'));
      });
      
      test('should create personal copy of menu', () {
        // Arrange
        final menu = menuBuilder
            .withId('original_id')
            .withOwner('original_owner', 'Original Owner')
            .asCollaborativeMenu()
            .build();
        // Act
        final copy = MenuOperations.createPersonalCopy(menu);
        
        // Assert
        // createPersonalCopy returns Map<String, List<Recipe>> not RealtimeMenu
        expect(copy, isA<Map<String, List<Recipe>>>());
        expect(copy.keys, equals(menu.menuSnapshot.keys));
        // Verify the copy contains the same recipes
        for (final category in copy.keys) {
          expect(copy[category]?.length, equals(menu.menuSnapshot[category]?.length));
        }
      });
      
      test('should handle regenerate category placeholder', () {
        // Arrange
        final menu = menuBuilder.withCategory('Söndag', []).build();
        final newRecipes = [
          recipeBuilder.asSwedishDinner().build(),
          recipeBuilder.asSwedishDessert().build(),
        ];
        
        // Act
        final result = MenuOperations.regenerateCategory(
          menu,
          categoryName: 'Söndag',
          newRecipes: newRecipes,
          editedBy: 'test_user',
          editedByDisplayName: 'Test User',
        );
        
        // Assert
        // Category should now have the new recipes
        expect(result.menuSnapshot['Söndag']?.length, 2);
        expect(result.menuSnapshot['Söndag']?.first.title, 'Köttbullar med potatismos');
      });
      
      test('should generate menu statistics', () {
        // Arrange
        final menu = menuBuilder.asSwedishWeeklyMenu().build();
        
        // Act
        final stats = MenuOperations.getMenuStatistics(menu);
        
        // Assert
        expect(stats, isNotEmpty);
        expect(stats['totalCategories'], greaterThan(0));
        expect(stats['totalRecipes'], greaterThan(0));
      });
    });
    
    group('Error Handling', () {
      test('should handle empty category name', () {
        // Arrange
        final menu = menuBuilder.build();
        final recipe = recipeBuilder.build();
        
        // Act & Assert - Empty category name throws error
        expect(
          () => MenuOperations.addRecipeToCategory(
            menu,
            categoryName: '',
            recipe: recipe,
            editedBy: 'test_user',
            editedByDisplayName: 'Test User',
          ),
          throwsA(isA<MenuOperationError>()),
        );
      });
      
      test('should handle negative index', () {
        // Arrange
        final recipe = recipeBuilder.build();
        final menu = menuBuilder.withCategory('Test', [recipe]).build();
        
        // Act - Negative index removes nothing
        final updated = MenuOperations.removeRecipeFromCategory(
          menu,
          categoryName: 'Test',
          recipeIndex: -1,
          editedBy: 'test_user',
          editedByDisplayName: 'Test User',
        );
        
        // Assert - Recipe still there
        expect(updated.menuSnapshot['Test']!.length, 1);
      });
      
      test('should handle empty recipe lists gracefully', () {
        // Arrange
        final menu = menuBuilder.withCategory('Empty', []).build();
        
        // Act - Removing from empty list does nothing
        final updated = MenuOperations.removeRecipeFromCategory(
          menu,
          categoryName: 'Empty',
          recipeIndex: 0,
          editedBy: 'test_user',
          editedByDisplayName: 'Test User',
        );
        
        // Assert - Still empty
        expect(updated.menuSnapshot['Empty'], isEmpty);
      });
      
      test('should support Swedish characters in category names', () {
        // Arrange
        final menu = menuBuilder.withCategory('Årets Högtider', []).build();
        final recipe = recipeBuilder.asSwedishDessert().build();
        
        // Act
        final updated = MenuOperations.addRecipeToCategory(
          menu,
          categoryName: 'Årets Högtider',
          recipe: recipe,
          editedBy: 'test_user',
          editedByDisplayName: 'Test User',
        );
        
        // Assert
        expect(updated.menuSnapshot['Årets Högtider']!.length, 1);
        expect(updated.menuSnapshot['Årets Högtider']!.first.title, 'Kladdkaka');
      });
      
      test('should handle null favorites when updating', () {
        // Arrange
        final menu = menuBuilder.build();
        
        // Act
        final updated = MenuOperations.updateBasicInfo(
          menu,
          favoriteRecipeIds: null,
          editedBy: 'test_user',
          editedByDisplayName: 'Test User',
        );
        
        // Assert
        expect(updated.favoriteRecipeIds, isNull);
      });
    });
  });
}