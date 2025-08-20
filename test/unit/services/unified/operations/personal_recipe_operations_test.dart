import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:butlery/services/unified/operations/personal_recipe_operations.dart';
import 'package:butlery/models/recipe_unified.dart';

import '../../../../test_support/base_unit_test.dart';
import '../../../../infrastructure/di/test_service_locator.dart';
import '../../../../infrastructure/builders/recipe_builder.dart';
import '../../../../infrastructure/mocks/production_mocks.dart';

void main() {
  group('PersonalRecipeOperations', () {
    late PersonalRecipeOperations operations;
    late MockUnifiedRecipeService mockParent;
    late Recipe testRecipe;
    
    setUpAll(() async {
      await BaseUnitTest.setupUnit();
      registerFallbackValue(RecipeBuilder().build());
    });
    
    setUp(() async {
      await TestServiceLocator.initialize();
      
      // Create mock parent service
      mockParent = MockUnifiedRecipeService();
      
      // Create test recipe
      testRecipe = RecipeBuilder()
          .withId('recipe-123')
          .withTitle('Swedish Meatballs')
          .withDescription('Traditional Swedish meatballs')
          .build();
      
      // Configure default mock behavior
      mockParent.setRecipeState(
        recipes: [],
        currentUserId: 'test-user-123',
        currentUserDisplayName: 'Test User',
      );
      
      // Create operations instance
      operations = PersonalRecipeOperations(mockParent);
    });
    
    tearDown(() async {
      BaseUnitTest.resetMocks();
      await TestServiceLocator.reset();
    });
    
    tearDownAll(() async {
      await BaseUnitTest.teardownUnit();
    });
    
    group('Initialization', () {
      test('should initialize with parent service', () {
        // Assert
        expect(operations, isNotNull);
      });
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
        )).thenAnswer((_) async => 'new-recipe-id');
        
        // Act
        final result = await operations.addUnifiedRecipe(testRecipe);
        
        // Assert
        expect(result.isSuccess, isTrue);
        expect(result.message, contains('successfully'));
        verify(() => mockParent.createRecipe(
          title: testRecipe.title,
          description: testRecipe.description,
          ingredients: testRecipe.ingredients,
          instructions: testRecipe.instructions,
          imageUrls: testRecipe.imageUrls,
          mealType: testRecipe.mealType,
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
        expect(result.isSuccess, isFalse);
        expect(result.message, contains('Failed'));
      });
      
      test('should update unified recipe successfully', () async {
        // Arrange
        when(() => mockParent.updateRecipe(any()))
            .thenAnswer((_) async => true);
        
        // Act
        final result = await operations.updateUnifiedRecipe(testRecipe);
        
        // Assert
        expect(result.isSuccess, isTrue);
        expect(result.message, contains('successfully'));
        verify(() => mockParent.updateRecipe(testRecipe)).called(1);
      });
      
      test('should handle update recipe failure', () async {
        // Arrange
        when(() => mockParent.updateRecipe(any()))
            .thenAnswer((_) async => false);
        
        // Act
        final result = await operations.updateUnifiedRecipe(testRecipe);
        
        // Assert
        expect(result.isSuccess, isFalse);
        expect(result.message, contains('Failed'));
      });
      
      test('should delete recipe', () async {
        // Arrange
        when(() => mockParent.deleteRecipe(any()))
            .thenAnswer((_) async => true);
        
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
          RecipeBuilder().withTitle('Recipe 1').build(),
          RecipeBuilder().withTitle('Recipe 2').build(),
          RecipeBuilder().withTitle('Recipe 3').build(),
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
        )).thenAnswer((_) async => 'new-id');
        
        // Act
        final result = await operations.addMultipleUnifiedRecipes(recipes);
        
        // Assert
        expect(result.isSuccess, isTrue);
        expect(result.message, contains('3 recept importerade'));
        verify(() => mockParent.createRecipe(
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
        )).called(3);
      });
      
      test('should handle partial batch success', () async {
        // Arrange
        final recipes = [
          RecipeBuilder().withTitle('Recipe 1').build(),
          RecipeBuilder().withTitle('Recipe 2').build(),
          RecipeBuilder().withTitle('Recipe 3').build(),
        ];
        
        var callCount = 0;
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
          return callCount <= 2 ? 'new-id' : null; // First 2 succeed, last fails
        });
        
        // Act
        final result = await operations.addMultipleUnifiedRecipes(recipes);
        
        // Assert
        expect(result.isSuccess, isTrue);
        expect(result.message, contains('2 av 3 recept importerade'));
      });
      
      test('should handle complete batch failure', () async {
        // Arrange
        final recipes = [
          RecipeBuilder().withTitle('Recipe 1').build(),
          RecipeBuilder().withTitle('Recipe 2').build(),
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
        expect(result.isSuccess, isFalse);
        expect(result.message, contains('Kunde inte importera några recept'));
      });
    });
    
    group('Content Management', () {
      test('should update recipe content', () async {
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
      
      test('should add ingredient', () async {
        // Arrange
        when(() => mockParent.addIngredient(any(), any()))
            .thenAnswer((_) async => true);
        
        // Act
        final result = await operations.addIngredient('recipe-123', '2 dl mjölk');
        
        // Assert
        expect(result, isTrue);
        verify(() => mockParent.addIngredient('recipe-123', '2 dl mjölk')).called(1);
      });
      
      test('should update ingredient', () async {
        // Arrange
        when(() => mockParent.updateIngredient(any(), any(), any()))
            .thenAnswer((_) async => true);
        
        // Act
        final result = await operations.updateIngredient('recipe-123', 0, '3 dl mjölk');
        
        // Assert
        expect(result, isTrue);
        verify(() => mockParent.updateIngredient('recipe-123', 0, '3 dl mjölk')).called(1);
      });
      
      test('should remove ingredient', () async {
        // Arrange
        when(() => mockParent.removeIngredient(any(), any()))
            .thenAnswer((_) async => true);
        
        // Act
        final result = await operations.removeIngredient('recipe-123', 0);
        
        // Assert
        expect(result, isTrue);
        verify(() => mockParent.removeIngredient('recipe-123', 0)).called(1);
      });
      
      test('should add instruction', () async {
        // Arrange
        when(() => mockParent.addInstruction(any(), any()))
            .thenAnswer((_) async => true);
        
        // Act
        final result = await operations.addInstruction('recipe-123', 'Värm ugnen till 200°C');
        
        // Assert
        expect(result, isTrue);
        verify(() => mockParent.addInstruction('recipe-123', 'Värm ugnen till 200°C')).called(1);
      });
      
      test('should update instruction', () async {
        // Arrange
        when(() => mockParent.updateInstruction(any(), any(), any()))
            .thenAnswer((_) async => true);
        
        // Act
        final result = await operations.updateInstruction('recipe-123', 0, 'Värm ugnen till 225°C');
        
        // Assert
        expect(result, isTrue);
        verify(() => mockParent.updateInstruction('recipe-123', 0, 'Värm ugnen till 225°C')).called(1);
      });
      
      test('should remove instruction', () async {
        // Arrange
        when(() => mockParent.removeInstruction(any(), any()))
            .thenAnswer((_) async => true);
        
        // Act
        final result = await operations.removeInstruction('recipe-123', 0);
        
        // Assert
        expect(result, isTrue);
        verify(() => mockParent.removeInstruction('recipe-123', 0)).called(1);
      });
    });
    
    group('Recipe Lifecycle', () {
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
    
    group('Legacy Compatibility', () {
      test('should add legacy recipe', () async {
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
        )).thenAnswer((_) async => 'new-recipe-id');
        
        // Act
        final result = await operations.addLegacyRecipe(testRecipe);
        
        // Assert
        expect(result.isSuccess, isTrue);
        verify(() => mockParent.createRecipe(
          title: testRecipe.title,
          description: testRecipe.description,
          ingredients: testRecipe.ingredients,
          instructions: testRecipe.instructions,
          imageUrls: testRecipe.imageUrls,
          mealType: testRecipe.mealType,
          portions: testRecipe.portions,
          timeMinutes: testRecipe.timeMinutes,
          rating: testRecipe.rating,
          tags: testRecipe.tags,
          sourceUrl: testRecipe.sourceUrl,
        )).called(1);
      });
      
      test('should update legacy recipe', () async {
        // Arrange
        when(() => mockParent.updateRecipe(any()))
            .thenAnswer((_) async => true);
        
        // Act
        final result = await operations.updateLegacyRecipe(testRecipe);
        
        // Assert
        expect(result.isSuccess, isTrue);
        verify(() => mockParent.updateRecipe(testRecipe)).called(1);
      });
    });
  });
}