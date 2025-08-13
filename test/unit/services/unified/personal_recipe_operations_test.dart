/// Comprehensive unit tests for PersonalRecipeOperations
/// 
/// Tests the personal recipe operations facade that handles CRUD operations,
/// content management, batch processing, and legacy compatibility for
/// individual recipe management.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:butlery/services/unified/operations/personal_recipe_operations.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/models/recipe/recipe_factory.dart' as recipe_factory;

import '../../../infrastructure/helpers/_base_unit_test.dart';
import '../../../infrastructure/factories/recipe_factory.dart';
import '../../../infrastructure/di/test_service_locator.dart';

// Mock parent service that PersonalRecipeOperations delegates to
class MockParentService extends Mock {
  // Configuration state only
  String? _currentUserId = 'test-user-123';
  List<Recipe> _recipes = [];
  
  // Configuration methods
  void setUserId(String? userId) {
    _currentUserId = userId;
  }
  
  void setRecipes(List<Recipe> recipes) {
    _recipes = recipes;
  }
  
  // Getters return configured state
  String? get currentUserId => _currentUserId;
  List<Recipe> get recipes => _recipes;
  
  // Method declarations for Mock to handle - no implementations
  // These will be stubbed with when() in tests
  Future<String?> createRecipe({
    required String title,
    required String description,
    required List<String> ingredients,
    required List<String> instructions,
    required List<String> imageUrls,
    required String mealType,
    int? portions,
    int? timeMinutes,
    double? rating,
    List<String>? tags,
    String? sourceUrl,
  });
  
  Future<bool> updateRecipe(Recipe recipe);
  Future<bool> deleteRecipe(String id);
  Future<bool> updateRecipeContent({
    required String recipeId,
    String? title,
    String? description,
    String? mealType,
    int? portions,
    int? timeMinutes,
    double? rating,
    List<String>? ingredients,
    List<String>? instructions,
    List<String>? tags,
    String? sourceUrl,
  });
  Future<bool> addIngredient(String recipeId, String ingredient);
  Future<bool> updateIngredient(String recipeId, int index, String ingredient);
  Future<bool> removeIngredient(String recipeId, int index);
  Future<bool> addInstruction(String recipeId, String instruction);
  Future<bool> updateInstruction(String recipeId, int index, String instruction);
  Future<bool> removeInstruction(String recipeId, int index);
  Future<bool> markAsCooked(String recipeId);
  Future<bool> updateRating(String recipeId, double rating);
  Future<bool> addTag(String recipeId, String tag);
  Future<bool> removeTag(String recipeId, String tag);
}

void main() {
  group('PersonalRecipeOperations', () {
    late PersonalRecipeOperations operations;
    late MockParentService mockParent;
    late Recipe testRecipe;
    
    setUpAll(() async {
      await BaseUnitTest.setupUnit();
      registerFallbackValue(RecipeFactory.build());
    });
    
    setUp(() {
      mockParent = MockParentService();
      
      // Configure mock parent
      mockParent.setUserId('test-user-123');
      
      operations = PersonalRecipeOperations(mockParent);
      
      testRecipe = RecipeFactory.build(
        id: 'test-recipe-1',
        title: 'Köttbullar',
        description: 'Svenska köttbullar med potatismos',
        ingredients: ['500g köttfärs', '1 dl ströbröd', '1 ägg'],
        instructions: ['Blanda köttfärs', 'Forma bollar', 'Stek i panna'],
        mealType: 'dinner',
      );
      
      mockParent.setRecipes([testRecipe]);
    });
    
    tearDown(() async {
      BaseUnitTest.resetMocks();
      await TestServiceLocator.reset();
    });
    
    tearDownAll(() async {
      await BaseUnitTest.teardownUnit();
    });
    
    group('Recipe CRUD Operations', () {
      test('should add unified recipe successfully', () async {
        // Arrange
        when(() => mockParent.createRecipe(
          title: any(named: 'title'),
          description: any(named: 'description'),
          ingredients: any(named: 'ingredients'),
          instructions: any(named: 'instructions'),
          imageUrls: any(named: 'imageUrls'),
          mealType: any(named: 'mealType'),
          portions: any(named: 'portions'),
          timeMinutes: any(named: 'timeMinutes'),
          rating: any(named: 'rating'),
          tags: any(named: 'tags'),
          sourceUrl: any(named: 'sourceUrl'),
        )).thenAnswer((_) async => 'recipe-123');
        
        // Act
        final result = await operations.addUnifiedRecipe(testRecipe);
        
        // Assert
        expect(result.isSuccess, isTrue);
        expect(result.message, equals('Recipe added successfully'));
        verify(() => mockParent.createRecipe(
          title: 'Köttbullar',
          description: 'Svenska köttbullar med potatismos',
          ingredients: testRecipe.ingredients,
          instructions: testRecipe.instructions,
          imageUrls: testRecipe.imageUrls,
          mealType: 'dinner',
          portions: testRecipe.portions,
          timeMinutes: testRecipe.timeMinutes,
          rating: testRecipe.rating,
          tags: testRecipe.tags,
          sourceUrl: testRecipe.sourceUrl,
        )).called(1);
      });
      
      test('should handle add recipe failure', () async {
        // Arrange
        when(() => mockParent.createRecipe(
          title: any(named: 'title'),
          description: any(named: 'description'),
          ingredients: any(named: 'ingredients'),
          instructions: any(named: 'instructions'),
          imageUrls: any(named: 'imageUrls'),
          mealType: any(named: 'mealType'),
          portions: any(named: 'portions'),
          timeMinutes: any(named: 'timeMinutes'),
          rating: any(named: 'rating'),
          tags: any(named: 'tags'),
          sourceUrl: any(named: 'sourceUrl'),
        )).thenAnswer((_) async => null);
        
        // Act
        final result = await operations.addUnifiedRecipe(testRecipe);
        
        // Assert
        expect(result.isFailure, isTrue);
        expect(result.message, equals('Failed to add recipe'));
      });
      
      test('should handle add recipe exception', () async {
        // Arrange
        when(() => mockParent.createRecipe(
          title: any(named: 'title'),
          description: any(named: 'description'),
          ingredients: any(named: 'ingredients'),
          instructions: any(named: 'instructions'),
          imageUrls: any(named: 'imageUrls'),
          mealType: any(named: 'mealType'),
          portions: any(named: 'portions'),
          timeMinutes: any(named: 'timeMinutes'),
          rating: any(named: 'rating'),
          tags: any(named: 'tags'),
          sourceUrl: any(named: 'sourceUrl'),
        )).thenThrow(Exception('Network error'));
        
        // Act
        final result = await operations.addUnifiedRecipe(testRecipe);
        
        // Assert
        expect(result.isFailure, isTrue);
        expect(result.message, contains('Failed to add recipe:'));
        expect(result.message, contains('Network error'));
      });
      
      test('should update unified recipe successfully', () async {
        // Arrange
        when(() => mockParent.updateRecipe(any())).thenAnswer((_) async => true);
        
        // Act
        final result = await operations.updateUnifiedRecipe(testRecipe);
        
        // Assert
        expect(result.isSuccess, isTrue);
        expect(result.message, equals('Recipe updated successfully'));
        verify(() => mockParent.updateRecipe(testRecipe)).called(1);
      });
      
      test('should handle update recipe failure', () async {
        // Arrange
        when(() => mockParent.updateRecipe(any())).thenAnswer((_) async => false);
        
        // Act
        final result = await operations.updateUnifiedRecipe(testRecipe);
        
        // Assert
        expect(result.isFailure, isTrue);
        expect(result.message, equals('Failed to update recipe'));
      });
      
      test('should delete recipe successfully', () async {
        // Arrange
        when(() => mockParent.deleteRecipe(any())).thenAnswer((_) async => true);
        
        // Act
        final result = await operations.deleteRecipe('recipe-123');
        
        // Assert
        expect(result, isTrue);
        verify(() => mockParent.deleteRecipe('recipe-123')).called(1);
      });
    });
    
    group('Batch Operations', () {
      test('should add multiple recipes successfully', () async {
        // Arrange
        final recipes = [
          RecipeFactory.build(title: 'Recipe 1'),
          RecipeFactory.build(title: 'Recipe 2'),
          RecipeFactory.build(title: 'Recipe 3'),
        ];
        
        when(() => mockParent.createRecipe(
          title: any(named: 'title'),
          description: any(named: 'description'),
          ingredients: any(named: 'ingredients'),
          instructions: any(named: 'instructions'),
          imageUrls: any(named: 'imageUrls'),
          mealType: any(named: 'mealType'),
          portions: any(named: 'portions'),
          timeMinutes: any(named: 'timeMinutes'),
          rating: any(named: 'rating'),
          tags: any(named: 'tags'),
          sourceUrl: any(named: 'sourceUrl'),
        )).thenAnswer((_) async => 'recipe-id');
        
        // Act
        final result = await operations.addMultipleUnifiedRecipes(recipes);
        
        // Assert
        expect(result.isSuccess, isTrue);
        expect(result.message, equals('Alla 3 recept importerade'));
      });
      
      test('should handle partial batch import success', () async {
        // Arrange
        final recipes = [
          RecipeFactory.build(title: 'Recipe 1'),
          RecipeFactory.build(title: 'Recipe 2'),
          RecipeFactory.build(title: 'Recipe 3'),
        ];
        
        int callCount = 0;
        when(() => mockParent.createRecipe(
          title: any(named: 'title'),
          description: any(named: 'description'),
          ingredients: any(named: 'ingredients'),
          instructions: any(named: 'instructions'),
          imageUrls: any(named: 'imageUrls'),
          mealType: any(named: 'mealType'),
          portions: any(named: 'portions'),
          timeMinutes: any(named: 'timeMinutes'),
          rating: any(named: 'rating'),
          tags: any(named: 'tags'),
          sourceUrl: any(named: 'sourceUrl'),
        )).thenAnswer((_) async {
          callCount++;
          return callCount == 2 ? null : 'recipe-id-$callCount';
        });
        
        // Act
        final result = await operations.addMultipleUnifiedRecipes(recipes);
        
        // Assert
        expect(result.isSuccess, isTrue);
        expect(result.message, contains('2 av 3 recept importerade'));
        expect(result.message, contains('Recipe 2:'));
      });
      
      test('should handle complete batch import failure', () async {
        // Arrange
        final recipes = [
          RecipeFactory.build(title: 'Recipe 1'),
          RecipeFactory.build(title: 'Recipe 2'),
        ];
        
        when(() => mockParent.createRecipe(
          title: any(named: 'title'),
          description: any(named: 'description'),
          ingredients: any(named: 'ingredients'),
          instructions: any(named: 'instructions'),
          imageUrls: any(named: 'imageUrls'),
          mealType: any(named: 'mealType'),
          portions: any(named: 'portions'),
          timeMinutes: any(named: 'timeMinutes'),
          rating: any(named: 'rating'),
          tags: any(named: 'tags'),
          sourceUrl: any(named: 'sourceUrl'),
        )).thenAnswer((_) async => null);
        
        // Act
        final result = await operations.addMultipleUnifiedRecipes(recipes);
        
        // Assert
        expect(result.isFailure, isTrue);
        expect(result.message, contains('Kunde inte importera några recept'));
      });
      
      test('should handle batch import with exception', () async {
        // Arrange
        final recipes = [testRecipe];
        
        when(() => mockParent.createRecipe(
          title: any(named: 'title'),
          description: any(named: 'description'),
          ingredients: any(named: 'ingredients'),
          instructions: any(named: 'instructions'),
          imageUrls: any(named: 'imageUrls'),
          mealType: any(named: 'mealType'),
          portions: any(named: 'portions'),
          timeMinutes: any(named: 'timeMinutes'),
          rating: any(named: 'rating'),
          tags: any(named: 'tags'),
          sourceUrl: any(named: 'sourceUrl'),
        )).thenThrow(Exception('Database error'));
        
        // Act
        final result = await operations.addMultipleUnifiedRecipes(recipes);
        
        // Assert
        expect(result.isFailure, isTrue);
        expect(result.message, contains('Kunde inte importera några recept. Fel:'));
      });
    });
    
    group('Content Management', () {
      test('should update recipe content successfully', () async {
        // Arrange
        when(() => mockParent.updateRecipeContent(
          recipeId: any(named: 'recipeId'),
          title: any(named: 'title'),
          description: any(named: 'description'),
          mealType: any(named: 'mealType'),
          portions: any(named: 'portions'),
          timeMinutes: any(named: 'timeMinutes'),
          rating: any(named: 'rating'),
          ingredients: any(named: 'ingredients'),
          instructions: any(named: 'instructions'),
          tags: any(named: 'tags'),
          sourceUrl: any(named: 'sourceUrl'),
        )).thenAnswer((_) async => true);
        
        // Act
        final result = await operations.updateRecipeContent(
          recipeId: 'recipe-123',
          title: 'Updated Title',
          description: 'Updated Description',
        );
        
        // Assert
        expect(result, isTrue);
        verify(() => mockParent.updateRecipeContent(
          recipeId: 'recipe-123',
          title: 'Updated Title',
          description: 'Updated Description',
        )).called(1);
      });
      
      test('should add ingredient successfully', () async {
        // Arrange
        when(() => mockParent.addIngredient(any(), any()))
            .thenAnswer((_) async => true);
        
        // Act
        final result = await operations.addIngredient('recipe-123', '2 dl mjölk');
        
        // Assert
        expect(result, isTrue);
        verify(() => mockParent.addIngredient('recipe-123', '2 dl mjölk')).called(1);
      });
      
      test('should update ingredient successfully', () async {
        // Arrange
        when(() => mockParent.updateIngredient(any(), any(), any()))
            .thenAnswer((_) async => true);
        
        // Act
        final result = await operations.updateIngredient('recipe-123', 0, '3 dl mjölk');
        
        // Assert
        expect(result, isTrue);
        verify(() => mockParent.updateIngredient('recipe-123', 0, '3 dl mjölk')).called(1);
      });
      
      test('should remove ingredient successfully', () async {
        // Arrange
        when(() => mockParent.removeIngredient(any(), any()))
            .thenAnswer((_) async => true);
        
        // Act
        final result = await operations.removeIngredient('recipe-123', 2);
        
        // Assert
        expect(result, isTrue);
        verify(() => mockParent.removeIngredient('recipe-123', 2)).called(1);
      });
      
      test('should add instruction successfully', () async {
        // Arrange
        when(() => mockParent.addInstruction(any(), any()))
            .thenAnswer((_) async => true);
        
        // Act
        final result = await operations.addInstruction('recipe-123', 'Värm ugnen till 200°C');
        
        // Assert
        expect(result, isTrue);
        verify(() => mockParent.addInstruction('recipe-123', 'Värm ugnen till 200°C')).called(1);
      });
      
      test('should update instruction successfully', () async {
        // Arrange
        when(() => mockParent.updateInstruction(any(), any(), any()))
            .thenAnswer((_) async => true);
        
        // Act
        final result = await operations.updateInstruction('recipe-123', 1, 'Värm ugnen till 175°C');
        
        // Assert
        expect(result, isTrue);
        verify(() => mockParent.updateInstruction('recipe-123', 1, 'Värm ugnen till 175°C')).called(1);
      });
      
      test('should remove instruction successfully', () async {
        // Arrange
        when(() => mockParent.removeInstruction(any(), any()))
            .thenAnswer((_) async => true);
        
        // Act
        final result = await operations.removeInstruction('recipe-123', 3);
        
        // Assert
        expect(result, isTrue);
        verify(() => mockParent.removeInstruction('recipe-123', 3)).called(1);
      });
    });
    
    group('Recipe Metadata', () {
      test('should mark recipe as cooked', () async {
        // Arrange
        when(() => mockParent.markAsCooked(any()))
            .thenAnswer((_) async => true);
        
        // Act
        final result = await operations.markAsCooked('recipe-123');
        
        // Assert
        expect(result, isTrue);
        verify(() => mockParent.markAsCooked('recipe-123')).called(1);
      });
    });
    
    group('Edge Cases', () {
      test('should handle empty batch import', () async {
        // Act
        final result = await operations.addMultipleUnifiedRecipes([]);
        
        // Assert
        expect(result.isSuccess, isTrue);
        expect(result.message, equals('Alla 0 recept importerade'));
      });
      
      test('should handle recipe with minimal data', () async {
        // Arrange
        final minimalRecipe = recipe_factory.RecipeFactory.createQuickPersonal(
          title: 'Minimal Recipe',
          ingredients: [],
          instructions: [],
        );
        
        when(() => mockParent.createRecipe(
          title: any(named: 'title'),
          description: any(named: 'description'),
          ingredients: any(named: 'ingredients'),
          instructions: any(named: 'instructions'),
          imageUrls: any(named: 'imageUrls'),
          mealType: any(named: 'mealType'),
          portions: any(named: 'portions'),
          timeMinutes: any(named: 'timeMinutes'),
          rating: any(named: 'rating'),
          tags: any(named: 'tags'),
          sourceUrl: any(named: 'sourceUrl'),
        )).thenAnswer((_) async => 'minimal-id');
        
        // Act
        final result = await operations.addUnifiedRecipe(minimalRecipe);
        
        // Assert
        expect(result.isSuccess, isTrue);
      });
      
      test('should handle special characters in recipe content', () async {
        // Arrange
        final specialRecipe = RecipeFactory.build(
          title: 'Räksmörgås & lax',
          description: 'En "klassisk" rätt med <special> tecken',
          ingredients: ['100g räkor & lax', '1 msk "majonnäs"'],
        );
        
        when(() => mockParent.createRecipe(
          title: any(named: 'title'),
          description: any(named: 'description'),
          ingredients: any(named: 'ingredients'),
          instructions: any(named: 'instructions'),
          imageUrls: any(named: 'imageUrls'),
          mealType: any(named: 'mealType'),
          portions: any(named: 'portions'),
          timeMinutes: any(named: 'timeMinutes'),
          rating: any(named: 'rating'),
          tags: any(named: 'tags'),
          sourceUrl: any(named: 'sourceUrl'),
        )).thenAnswer((_) async => 'special-id');
        
        // Act
        final result = await operations.addUnifiedRecipe(specialRecipe);
        
        // Assert
        expect(result.isSuccess, isTrue);
        verify(() => mockParent.createRecipe(
          title: 'Räksmörgås & lax',
          description: 'En "klassisk" rätt med <special> tecken',
          ingredients: ['100g räkor & lax', '1 msk "majonnäs"'],
          instructions: any(named: 'instructions'),
          imageUrls: any(named: 'imageUrls'),
          mealType: any(named: 'mealType'),
          portions: any(named: 'portions'),
          timeMinutes: any(named: 'timeMinutes'),
          rating: any(named: 'rating'),
          tags: any(named: 'tags'),
          sourceUrl: any(named: 'sourceUrl'),
        )).called(1);
      });
    });
  });
}