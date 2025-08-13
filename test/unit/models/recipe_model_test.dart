/// Example unit test demonstrating the gold standard test patterns
/// 
/// This test shows how to use the test infrastructure for model testing
/// with proper AAA pattern, Swedish defaults, and comprehensive coverage.

import 'package:flutter_test/flutter_test.dart';
import '../../infrastructure/helpers/_base_unit_test.dart';
import '../../infrastructure/factories/test_data_builders.dart';
import '../../infrastructure/di/test_service_locator.dart';

void main() {
  // Use the base unit test group pattern
  BaseUnitTest.groupUnit('Recipe Model', () {
    // Setup that runs before each test
    setUp(() async {
      await TestServiceLocator.initialize();
    });
    
    // Cleanup that runs after each test
    tearDown(() async {
      BaseUnitTest.resetMocks();
      await TestServiceLocator.reset();
    });
    
    group('Construction and Properties', () {
      BaseUnitTest.testUnit(
        'should create recipe with all required properties',
        () async {
          // Arrange
          final builder = RecipeBuilder()
            ..withId('recipe_123')
            ..withTitle('Test Recipe')
            ..withAuthor('user_456', 'Test Chef');
          
          // Act
          final recipe = builder.build();
          
          // Assert
          expect(recipe.id, equals('recipe_123'));
          expect(recipe.title, equals('Test Recipe'));
          expect(recipe.userId, equals('user_456'));
          expect(recipe.authorDisplayName, equals('Test Chef'));
        },
      );
      
      BaseUnitTest.testUnit(
        'should create Swedish breakfast recipe with defaults',
        () async {
          // Arrange
          final recipe = RecipeBuilder()
            .asSwedishBreakfast()
            .build();
          
          // Act & Assert
          expect(recipe.title, equals('Havregrynsgröt'));
          expect(recipe.category, equals('Frukost'));
          expect(recipe.timeMinutes, equals(10));
          expect(recipe.tags, contains('frukost'));
          expect(recipe.tags, contains('svensk'));
          expect(recipe.ingredients, contains('1 dl havregryn'));
        },
      );
      
      BaseUnitTest.testUnit(
        'should create Swedish dinner recipe with defaults',
        () async {
          // Arrange
          final recipe = RecipeBuilder()
            .asSwedishDinner()
            .build();
          
          // Act & Assert
          expect(recipe.title, equals('Laxpudding'));
          expect(recipe.category, equals('Middag'));
          expect(recipe.timeMinutes, equals(60));
          expect(recipe.tags, contains('middag'));
          expect(recipe.tags, contains('fisk'));
          expect(recipe.ingredients, contains('300g gravlax'));
        },
      );
      
      BaseUnitTest.testUnit(
        'should create Swedish fika recipe with defaults',
        () async {
          // Arrange
          final recipe = RecipeBuilder()
            .asSwedishFika()
            .build();
          
          // Act & Assert
          expect(recipe.title, equals('Kanelbullar'));
          expect(recipe.category, equals('Bakverk'));
          expect(recipe.timeMinutes, equals(120));
          expect(recipe.tags, contains('fika'));
          expect(recipe.tags, contains('bullar'));
          expect(recipe.ingredients.any((i) => i.contains('jäst')), isTrue);
        },
      );
    });
    
    group('Builder Pattern Features', () {
      BaseUnitTest.testUnit(
        'should support method chaining',
        () async {
          // Arrange & Act
          final recipe = RecipeBuilder()
            .withTitle('Chained Recipe')
            .withTime(30)
            .withPortions(6)
            .addIngredient('Extra ingredient')
            .asFavorite()
            .build();
          
          // Assert
          expect(recipe.title, equals('Chained Recipe'));
          expect(recipe.timeMinutes, equals(30));
          expect(recipe.portions, equals(6));
          expect(recipe.ingredients, contains('Extra ingredient'));
          expect(recipe.isFavorite, isTrue);
        },
      );
      
      BaseUnitTest.testUnit(
        'should generate unique IDs for each recipe',
        () async {
          // Arrange & Act
          final recipe1 = RecipeBuilder().build();
          await Future.delayed(const Duration(milliseconds: 1));
          final recipe2 = RecipeBuilder().build();
          
          // Assert
          expect(recipe1.id, isNot(equals(recipe2.id)));
          expect(recipe1.id, startsWith('recipe_'));
          expect(recipe2.id, startsWith('recipe_'));
        },
      );
      
      BaseUnitTest.testUnit(
        'should build multiple recipes with buildMany',
        () async {
          // Arrange & Act
          final recipes = List.generate(5, (_) => 
            RecipeBuilder()
              .withTitle('Batch Recipe')
              .build()
          );
          
          // Assert
          expect(recipes.length, equals(5));
          expect(recipes.every((r) => r.title == 'Batch Recipe'), isTrue);
          // Each should have unique ID
          final ids = recipes.map((r) => r.id).toSet();
          expect(ids.length, equals(5));
        },
      );
    });
    
    group('Recipe Type Variations', () {
      BaseUnitTest.testUnit(
        'should create personal recipe by default',
        () async {
          // Arrange & Act
          final recipe = RecipeBuilder().build();
          
          // Assert
          expect(recipe.recipeType, equals(RecipeType.personal));
        },
      );
      
      BaseUnitTest.testUnit(
        'should create collaborative recipe',
        () async {
          // Arrange & Act
          final recipe = RecipeBuilder()
            .withType(RecipeType.collaborative)
            .build();
          
          // Assert
          expect(recipe.recipeType, equals(RecipeType.collaborative));
        },
      );
      
      BaseUnitTest.testUnit(
        'should create shared recipe',
        () async {
          // Arrange & Act
          final recipe = RecipeBuilder()
            .withType(RecipeType.shared)
            .build();
          
          // Assert
          expect(recipe.recipeType, equals(RecipeType.shared));
        },
      );
    });
    
    group('Data Validation', () {
      BaseUnitTest.testUnit(
        'should have valid default Swedish ingredients',
        () async {
          // Arrange
          final recipe = RecipeBuilder().build();
          
          // Act & Assert
          expect(recipe.ingredients, isNotEmpty);
          expect(recipe.ingredients, contains('500g köttfärs'));
          expect(recipe.ingredients, contains('1 ägg'));
          expect(recipe.ingredients, contains('1 dl ströbröd'));
        },
      );
      
      BaseUnitTest.testUnit(
        'should have valid default Swedish instructions',
        () async {
          // Arrange
          final recipe = RecipeBuilder().build();
          
          // Act & Assert
          expect(recipe.instructions, isNotEmpty);
          expect(recipe.instructions.first, equals('Finhacka löken'));
          expect(recipe.instructions.last, equals('Servera med lingon och pressgurka'));
        },
      );
      
      BaseUnitTest.testUnit(
        'should set timestamps correctly',
        () async {
          // Arrange
          final now = DateTime.now();
          
          // Act
          final recipe = RecipeBuilder().build();
          
          // Assert
          expect(recipe.createdAt.difference(now).inSeconds.abs(), lessThan(1));
          expect(recipe.updatedAt.difference(now).inSeconds.abs(), lessThan(1));
        },
      );
    });
    
    group('Edge Cases', () {
      BaseUnitTest.testUnit(
        'should handle empty ingredients list',
        () async {
          // Arrange & Act
          final recipe = RecipeBuilder()
            .withIngredients([])
            .build();
          
          // Assert
          expect(recipe.ingredients, isEmpty);
        },
      );
      
      BaseUnitTest.testUnit(
        'should handle empty instructions list',
        () async {
          // Arrange & Act
          final recipe = RecipeBuilder()
            .withInstructions([])
            .build();
          
          // Assert
          expect(recipe.instructions, isEmpty);
        },
      );
      
      BaseUnitTest.testUnit(
        'should handle special characters in title',
        () async {
          // Arrange & Act
          final recipe = RecipeBuilder()
            .withTitle('Räksmörgås à la carte')
            .build();
          
          // Assert
          expect(recipe.title, equals('Räksmörgås à la carte'));
        },
      );
      
      BaseUnitTest.testUnit(
        'should handle very long cooking times',
        () async {
          // Arrange & Act
          final recipe = RecipeBuilder()
            .withTime(480) // 8 hours
            .build();
          
          // Assert
          expect(recipe.timeMinutes, equals(480));
        },
      );
    });
  });
}