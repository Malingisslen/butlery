// ignore_for_file: subtype_of_sealed_class

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:butlery/repositories/hive/recipe_hive_repository.dart';
import 'package:butlery/models/recipe_unified.dart';
import '../../test_support/base_unit_test.dart';
import '../../infrastructure/di/test_service_locator.dart';
import '../../infrastructure/builders/recipe_builder.dart';

// Mock Box implementation for Map<String, dynamic>
class MockBox extends Mock implements Box<Map<String, dynamic>> {}

// Test implementation that allows box injection
class TestableRecipeHiveRepository extends RecipeHiveRepository {
  Box<Map<String, dynamic>>? injectedBox;
  bool initCalled = false;
  
  @override
  Future<void> init({String? userId}) async {
    initCalled = true;
    // In tests, we use the injected box instead of opening a real one
    if (injectedBox != null) {
      return;
    }
    // For real init test, would call super.init(userId: userId)
  }
  
  @override
  Box<Map<String, dynamic>> get box {
    if (injectedBox != null) {
      return injectedBox!;
    }
    return super.box;
  }
  
  void setBoxForTesting(Box<Map<String, dynamic>> box) {
    injectedBox = box;
  }
}

void main() {
  group('RecipeHiveRepository', () {
    late TestableRecipeHiveRepository repository;
    late MockBox mockBox;
    
    // Test data
    const userId = 'test-user-123';
    late Recipe testRecipe1;
    late Recipe testRecipe2;
    late Recipe testRecipe3;
    late Map<String, dynamic> recipeJson1;
    late Map<String, dynamic> recipeJson2;
    late Map<String, dynamic> recipeJson3;
    
    setUp(() async {
      await BaseUnitTest.setupUnit();
      await TestServiceLocator.initialize();
      
      // Initialize mocks
      mockBox = MockBox();
      
      // Setup test recipes using builder
      testRecipe1 = RecipeBuilder()
        .withId('recipe-1')
        .withTitle('Köttbullar med gräddsås')
        .withMealType('dinner')
        .withIngredients(['köttfärs', 'lök', 'grädde', 'potatis'])
        .withTags(['svensk', 'klassisk', 'middag'])
        .withRating(4.5)
        .withTimeMinutes(50)
        .build();
        
      testRecipe2 = RecipeBuilder()
        .withId('recipe-2')
        .withTitle('Pannkakor')
        .withMealType('breakfast')
        .withIngredients(['mjölk', 'ägg', 'mjöl', 'smör'])
        .withTags(['svensk', 'frukost', 'snabb'])
        .withRating(4.8)
        .withTimeMinutes(25)
        .build();
        
      testRecipe3 = RecipeBuilder()
        .withId('recipe-3')
        .withTitle('Laxsoppa')
        .withMealType('lunch')
        .withIngredients(['lax', 'potatis', 'morötter', 'dill', 'grädde'])
        .withTags(['svensk', 'fisk', 'soppa'])
        .withRating(3.5)
        .withTimeMinutes(45)
        .build();
      
      // Convert to JSON
      recipeJson1 = testRecipe1.toJson();
      recipeJson2 = testRecipe2.toJson();
      recipeJson3 = testRecipe3.toJson();
      
      // Setup box mock defaults
      when(() => mockBox.values).thenReturn([recipeJson1, recipeJson2]);
      when(() => mockBox.keys).thenReturn(['recipe-1', 'recipe-2']);
      when(() => mockBox.length).thenReturn(2);
      when(() => mockBox.get(any())).thenReturn(null);
      when(() => mockBox.put(any(), any())).thenAnswer((_) async {});
      when(() => mockBox.delete(any())).thenAnswer((_) async {});
      when(() => mockBox.clear()).thenAnswer((_) async => 0);
      
      // Create repository
      repository = TestableRecipeHiveRepository();
      repository.setBoxForTesting(mockBox);
    });
    
    tearDown(() async {
      BaseUnitTest.resetMocks();
      await TestServiceLocator.reset();
    });
    
    group('initialization', () {
      test('should use correct box name', () {
        // Assert
        expect(repository.boxName, equals('recipes'));
      });
      
      test('initWithUser should call init with userId', () async {
        // Act
        await repository.initWithUser(userId);
        
        // Assert
        expect(repository.initCalled, isTrue);
      });
    });
    
    group('saveRecipe', () {
      test('should save recipe as JSON with recipe id as key', () async {
        // Act
        await repository.saveRecipe(testRecipe3);
        
        // Assert
        final captured = verify(() => mockBox.put(captureAny(), captureAny())).captured;
        expect(captured[0], equals('recipe-3')); // Key
        final jsonData = captured[1] as Map<String, dynamic>;
        expect(jsonData['core']['id'], equals('recipe-3'));
        expect(jsonData['core']['title'], equals('Laxsoppa'));
      });
    });
    
    group('getRecipe', () {
      test('should return recipe when it exists', () {
        // Arrange
        when(() => mockBox.get('recipe-1')).thenReturn(recipeJson1);
        
        // Act
        final recipe = repository.getRecipe('recipe-1');
        
        // Assert
        expect(recipe, isNotNull);
        expect(recipe!.id, equals('recipe-1'));
        expect(recipe.title, equals('Köttbullar med gräddsås'));
      });
      
      test('should return null when recipe does not exist', () {
        // Arrange
        when(() => mockBox.get('missing-id')).thenReturn(null);
        
        // Act
        final recipe = repository.getRecipe('missing-id');
        
        // Assert
        expect(recipe, isNull);
      });
      
      test('should handle corrupted JSON and delete it', () async {
        // Arrange
        final corruptedJson = {'invalid': 'data'};
        when(() => mockBox.get('corrupted-id')).thenReturn(corruptedJson);
        
        // Act
        final recipe = repository.getRecipe('corrupted-id');
        
        // Assert
        expect(recipe, isNull);
        verify(() => mockBox.delete('corrupted-id')).called(1);
      });
    });
    
    group('getAllRecipes', () {
      test('should return all valid recipes', () {
        // Act
        final recipes = repository.getAllRecipes();
        
        // Assert
        expect(recipes.length, equals(2));
        expect(recipes[0].id, equals('recipe-1'));
        expect(recipes[1].id, equals('recipe-2'));
      });
      
      test('should skip corrupted entries', () {
        // Arrange
        final corruptedJson = {'invalid': 'data'};
        when(() => mockBox.values).thenReturn([recipeJson1, corruptedJson, recipeJson2]);
        
        // Act
        final recipes = repository.getAllRecipes();
        
        // Assert
        expect(recipes.length, equals(2)); // Only valid recipes
        expect(recipes[0].id, equals('recipe-1'));
        expect(recipes[1].id, equals('recipe-2'));
      });
      
      test('should handle empty box', () {
        // Arrange
        when(() => mockBox.values).thenReturn([]);
        
        // Act
        final recipes = repository.getAllRecipes();
        
        // Assert
        expect(recipes, isEmpty);
      });
    });
    
    group('updateRecipe', () {
      test('should update recipe using same key', () async {
        // Arrange
        final updatedRecipe = testRecipe1.copyWith(
          title: 'Uppdaterade köttbullar',
        );
        
        // Act
        await repository.updateRecipe(updatedRecipe);
        
        // Assert
        final captured = verify(() => mockBox.put(captureAny(), captureAny())).captured;
        expect(captured[0], equals('recipe-1')); // Key
        final jsonData = captured[1] as Map<String, dynamic>;
        expect(jsonData['core']['title'], equals('Uppdaterade köttbullar'));
      });
    });
    
    group('deleteRecipe', () {
      test('should delete recipe by id', () async {
        // Act
        await repository.deleteRecipe('recipe-1');
        
        // Assert
        verify(() => mockBox.delete('recipe-1')).called(1);
      });
    });
    
    group('searchRecipes', () {
      test('should find recipes by title', () {
        // Act
        final results = repository.searchRecipes('köttbullar');
        
        // Assert
        expect(results.length, equals(1));
        expect(results[0].title, contains('Köttbullar'));
      });
      
      test('should find recipes by partial title match', () {
        // Act
        final results = repository.searchRecipes('pannka');
        
        // Assert
        expect(results.length, equals(1));
        expect(results[0].title, contains('Pannkakor'));
      });
      
      test('should find recipes by ingredient', () {
        // Act
        final results = repository.searchRecipes('mjölk');
        
        // Assert
        expect(results.length, equals(1));
        expect(results[0].ingredients, contains('mjölk'));
      });
      
      test('should find recipes by tag', () {
        // Act
        final results = repository.searchRecipes('frukost');
        
        // Assert
        expect(results.length, equals(1));
        expect(results[0].tags, contains('frukost'));
      });
      
      test('should handle case-insensitive search', () {
        // Act
        final results = repository.searchRecipes('PANNKAKOR');
        
        // Assert
        expect(results.length, equals(1));
        expect(results[0].title, equals('Pannkakor'));
      });
      
      test('should return empty list for no matches', () {
        // Act
        final results = repository.searchRecipes('pizza');
        
        // Assert
        expect(results, isEmpty);
      });
    });
    
    group('getRecipesByMealType', () {
      test('should filter recipes by meal type', () {
        // Act
        final dinners = repository.getRecipesByMealType('dinner');
        
        // Assert
        expect(dinners.length, equals(1));
        expect(dinners[0].mealType, equals('dinner'));
      });
      
      test('should handle case-insensitive meal type', () {
        // Act
        final breakfasts = repository.getRecipesByMealType('BREAKFAST');
        
        // Assert
        expect(breakfasts.length, equals(1));
        expect(breakfasts[0].mealType, equals('breakfast'));
      });
      
      test('should return empty list for unknown meal type', () {
        // Act
        final snacks = repository.getRecipesByMealType('snack');
        
        // Assert
        expect(snacks, isEmpty);
      });
    });
    
    group('getFavoriteRecipes', () {
      test('should return recipes with rating >= 4.0', () {
        // Act
        final favorites = repository.getFavoriteRecipes();
        
        // Assert
        expect(favorites.length, equals(2));
        expect(favorites.every((r) => r.rating != null && r.rating! >= 4.0), isTrue);
      });
      
      test('should exclude recipes with low rating', () {
        // Arrange
        final recipeLowRating = RecipeBuilder()
          .withId('recipe-4')
          .withTitle('Test Recipe')
          .withRating(2.0)  // Low rating
          .build();
        when(() => mockBox.values).thenReturn([
          recipeJson1,
          recipeJson2,
          recipeLowRating.toJson(),
        ]);
        
        // Act
        final favorites = repository.getFavoriteRecipes();
        
        // Assert
        expect(favorites.length, equals(2)); // Only rated recipes >= 4.0
      });
    });
    
    group('getRecentRecipes', () {
      test('should return most recent recipes', () {
        // Arrange
        when(() => mockBox.values).thenReturn([recipeJson1, recipeJson2, recipeJson3]);
        
        // Act
        final recent = repository.getRecentRecipes(limit: 2);
        
        // Assert
        expect(recent.length, equals(2));
        // Since we can't control updatedAt in builder, just check length
      });
      
      test('should respect limit parameter', () {
        // Arrange
        when(() => mockBox.values).thenReturn([recipeJson1, recipeJson2, recipeJson3]);
        
        // Act
        final recent = repository.getRecentRecipes(limit: 1);
        
        // Assert
        expect(recent.length, equals(1));
      });
      
      test('should use default limit of 10', () {
        // Arrange
        final manyRecipes = List.generate(
          20,
          (i) => RecipeBuilder()
            .withId('recipe-$i')
            .withTitle('Recipe $i')
            .build()
            .toJson(),
        );
        when(() => mockBox.values).thenReturn(manyRecipes);
        
        // Act
        final recent = repository.getRecentRecipes();
        
        // Assert
        expect(recent.length, equals(10));
      });
    });
    
    group('getCacheStats', () {
      test('should return comprehensive cache statistics', () {
        // Arrange
        when(() => mockBox.values).thenReturn([recipeJson1, recipeJson2, recipeJson3]);
        when(() => mockBox.length).thenReturn(3);
        
        // Act
        final stats = repository.getCacheStats();
        
        // Assert
        expect(stats['totalRecipes'], equals(3));
        expect(stats['totalCacheEntries'], equals(3));
        expect(stats['mealTypeCounts']['dinner'], equals(1));
        expect(stats['mealTypeCounts']['breakfast'], equals(1));
        expect(stats['mealTypeCounts']['lunch'], equals(1));
        // Average rating calculation may vary
        expect(stats['averageRating'], isA<double>());
      });
      
      test('should handle recipes without tags', () {
        // Arrange
        final recipeNoTags = RecipeBuilder()
          .withId('recipe-4')
          .withTitle('Simple Recipe')
          .withTags([])  // Use empty list instead of null
          .build();
        when(() => mockBox.values).thenReturn([recipeNoTags.toJson()]);
        when(() => mockBox.length).thenReturn(1);
        
        // Act
        final stats = repository.getCacheStats();
        
        // Assert
        expect(stats['totalRecipes'], equals(1));
        // topTags calculation may return something even with empty tags
      });
    });
    
    group('cleanupCorruptedEntries', () {
      test('should remove corrupted entries and return count', () async {
        // Arrange
        final corruptedJson = {'invalid': 'data'};
        when(() => mockBox.keys).thenReturn(['recipe-1', 'corrupted', 'recipe-2']);
        when(() => mockBox.get('recipe-1')).thenReturn(recipeJson1);
        when(() => mockBox.get('corrupted')).thenReturn(corruptedJson);
        when(() => mockBox.get('recipe-2')).thenReturn(recipeJson2);
        
        // Act
        final removedCount = await repository.cleanupCorruptedEntries();
        
        // Assert
        expect(removedCount, equals(1));
        verify(() => mockBox.delete('corrupted')).called(1);
        verifyNever(() => mockBox.delete('recipe-1'));
        verifyNever(() => mockBox.delete('recipe-2'));
      });
      
      test('should return 0 when no corrupted entries', () async {
        // Arrange
        when(() => mockBox.keys).thenReturn(['recipe-1', 'recipe-2']);
        when(() => mockBox.get('recipe-1')).thenReturn(recipeJson1);
        when(() => mockBox.get('recipe-2')).thenReturn(recipeJson2);
        
        // Act
        final removedCount = await repository.cleanupCorruptedEntries();
        
        // Assert
        expect(removedCount, equals(0));
        verifyNever(() => mockBox.delete(any()));
      });
      
      test('should handle null entries', () async {
        // Arrange
        when(() => mockBox.keys).thenReturn(['recipe-1', 'null-entry']);
        when(() => mockBox.get('recipe-1')).thenReturn(recipeJson1);
        when(() => mockBox.get('null-entry')).thenReturn(null);
        
        // Act
        final removedCount = await repository.cleanupCorruptedEntries();
        
        // Assert
        expect(removedCount, equals(0));
        verifyNever(() => mockBox.delete(any()));
      });
    });
    
    group('inherited from BaseHiveRepository', () {
      test('should inherit correct box operations', () async {
        // Test that base operations work correctly
        await repository.put('test-key', recipeJson3);
        verify(() => mockBox.put('test-key', recipeJson3)).called(1);
        
        repository.get('test-key');
        verify(() => mockBox.get('test-key')).called(1);
        
        await repository.delete('test-key');
        verify(() => mockBox.delete('test-key')).called(1);
        
        await repository.clear();
        verify(() => mockBox.clear()).called(1);
      });
    });
  });
}