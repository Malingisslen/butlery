import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:butlery/viewmodels/recipe/personal_recipe_viewmodel.dart';
import 'package:butlery/services/unified/unified_recipe_service.dart';
import 'package:butlery/services/unified/types/recipe_types.dart';
import 'package:butlery/models/recipe_unified.dart';

import '../../infrastructure/helpers/_base_unit_test.dart';
import '../../infrastructure/factories/recipe_factory.dart';
import '../../infrastructure/di/test_service_locator.dart';
import '../../infrastructure/mocks/production_mocks.dart';


void main() {
  group('PersonalRecipeViewModel', () {
    late PersonalRecipeViewModel viewModel;
    late MockUnifiedRecipeService mockRecipeService;
    late MockPersonalRecipeOperations mockPersonalOps;

    setUpAll(() async {
      await BaseUnitTest.setupUnit();
      registerFallbackValue(RecipeFactory.build());
      registerFallbackValue(RecipeOperationResult.success('test'));
    });

    setUp(() async {
      await TestServiceLocator.initialize();
      
      // Create mocks
      mockRecipeService = MockUnifiedRecipeService();
      mockPersonalOps = MockPersonalRecipeOperations();
      
      // Configure mock state using configuration method
      mockRecipeService.setRecipeState(
        recipes: [],
        currentUserId: 'test-user-123',
        currentUserDisplayName: 'Test User',
        isInitialized: true,
      );
      
      // Setup remaining mock behaviors
      when(() => mockRecipeService.personal).thenReturn(mockPersonalOps);
      
      // Mock personal operations
      when(() => mockPersonalOps.createRecipe(
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
      
      when(() => mockPersonalOps.updateRecipe(any())).thenAnswer((_) async => true);
      when(() => mockPersonalOps.deleteRecipe(any())).thenAnswer((_) async => true);
      when(() => mockPersonalOps.updateRecipeContent(
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
      
      when(() => mockPersonalOps.addIngredient(any(), any())).thenAnswer((_) async => true);
      when(() => mockPersonalOps.updateIngredient(any(), any(), any())).thenAnswer((_) async => true);
      when(() => mockPersonalOps.removeIngredient(any(), any())).thenAnswer((_) async => true);
      
      when(() => mockPersonalOps.addInstruction(any(), any())).thenAnswer((_) async => true);
      when(() => mockPersonalOps.updateInstruction(any(), any(), any())).thenAnswer((_) async => true);
      when(() => mockPersonalOps.removeInstruction(any(), any())).thenAnswer((_) async => true);
      
      when(() => mockPersonalOps.markAsCooked(any())).thenAnswer((_) async => true);
      
      when(() => mockPersonalOps.addLegacyRecipe(any())).thenAnswer(
        (_) async => RecipeOperationResult.success('Added'),
      );
      when(() => mockPersonalOps.updateLegacyRecipe(any())).thenAnswer(
        (_) async => RecipeOperationResult.success('Updated'),
      );
      
      // Register mocks in test service locator
      TestServiceLocator.registerMock<UnifiedRecipeService>(mockRecipeService);
      
      // TestServiceLocator already handles production ServiceLocator initialization
      
      // Create viewModel
      viewModel = PersonalRecipeViewModel();
    });

    tearDown(() async {
      BaseUnitTest.resetMocks();
      await TestServiceLocator.reset();
      viewModel.dispose();
    });

    tearDownAll(() async {
      await BaseUnitTest.teardownUnit();
    });

    group('State Accessors', () {
      test('should return personal recipes', () {
        // Arrange
        final recipes = [
          RecipeFactory.build(id: 'r1', type: RecipeType.personal),
          RecipeFactory.build(id: 'r2', type: RecipeType.personal),
        ];
        mockRecipeService.setRecipeState(recipes: recipes);
        
        // Act - accessing personalRecipes property
        
        // Assert
        expect(viewModel.personalRecipes, equals(recipes));
        expect(viewModel.hasPersonalRecipes, isTrue);
        expect(viewModel.personalRecipeCount, equals(2));
      });

      test('should return user information', () {
        // Arrange - state already configured in setUp
        
        // Act - accessing user properties
        
        // Assert
        expect(viewModel.currentUserId, equals('test-user-123'));
        expect(viewModel.currentUserDisplayName, equals('Test User'));
      });

      test('should handle empty personal recipes', () {
        // Arrange - initial empty state from setUp
        
        // Act - accessing recipe properties
        
        // Assert
        expect(viewModel.personalRecipes, isEmpty);
        expect(viewModel.hasPersonalRecipes, isFalse);
        expect(viewModel.personalRecipeCount, equals(0));
      });
    });

    group('Recipe Creation', () {
      test('should create personal recipe with required fields', () async {
        // Arrange - mock already configured in setUp
        
        // Act
        final result = await viewModel.createPersonalRecipe(
          name: 'Test Recipe',
        );
        
        // Assert
        expect(result, isTrue);
        verify(() => mockPersonalOps.createRecipe(
          title: 'Test Recipe',
          description: '',
          ingredients: const [],
          instructions: const [],
          imageUrls: const [],
          mealType: 'Lunch',
          portions: null,
          timeMinutes: null,
          rating: null,
          tags: null,
          sourceUrl: null,
        )).called(1);
      });

      test('should create personal recipe with all fields', () async {
        // Arrange - mock already configured in setUp
        
        // Act
        final result = await viewModel.createPersonalRecipe(
          name: 'Full Recipe',
          description: 'A complete recipe',
          ingredients: ['Ingredient 1', 'Ingredient 2'],
          instructions: ['Step 1', 'Step 2'],
          imageUrls: ['url1', 'url2'],
          mealType: 'Dinner',
          portions: 4,
          timeMinutes: 30,
          rating: 4.5,
          tags: ['healthy', 'quick'],
          sourceUrl: 'https://example.com',
        );
        
        // Assert
        expect(result, isTrue);
      });

      test('should reject empty recipe name', () async {
        // Arrange - initial state
        
        // Act
        final result = await viewModel.createPersonalRecipe(
          name: '',
        );
        
        // Assert
        expect(result, isFalse);
        verifyNever(() => mockPersonalOps.createRecipe(
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
        ));
      });
    });

    group('Recipe Management', () {
      test('should update personal recipe', () async {
        // Arrange
        final recipe = RecipeFactory.build(id: 'r1', type: RecipeType.personal);
        final recipes = [recipe];
        mockRecipeService.setRecipeState(recipes: recipes);
        
        // Act
        final result = await viewModel.updatePersonalRecipe(recipe);
        
        // Assert
        expect(result, isTrue);
        verify(() => mockPersonalOps.updateRecipe(recipe)).called(1);
      });

      test('should reject non-personal recipe update', () async {
        // Arrange - create a recipe that is not personal (shared type)
        final recipe = RecipeFactory.build(
          id: 'r1',
          type: RecipeType.shared,
          createdBy: 'other-user',
        );
        
        // Act
        final result = await viewModel.updatePersonalRecipe(recipe);
        
        // Assert
        expect(result, isFalse);
        verifyNever(() => mockPersonalOps.updateRecipe(any()));
      });

      test('should delete personal recipe', () async {
        // Arrange
        final recipe = RecipeFactory.build(id: 'r1', type: RecipeType.personal);
        final recipes = [recipe];
        mockRecipeService.setRecipeState(recipes: recipes);
        
        // Act
        final result = await viewModel.deletePersonalRecipe('r1');
        
        // Assert
        expect(result, isTrue);
        verify(() => mockPersonalOps.deleteRecipe('r1')).called(1);
      });

      test('should not delete non-existent recipe', () async {
        // Arrange - no recipes exist
        
        // Act
        final result = await viewModel.deletePersonalRecipe('non-existent');
        
        // Assert
        expect(result, isFalse);
        verifyNever(() => mockPersonalOps.deleteRecipe(any()));
      });
    });

    group('Content Editing', () {
      test('should update recipe content', () async {
        // Arrange
        final recipe = RecipeFactory.build(id: 'r1', type: RecipeType.personal);
        final recipes = [recipe];
        mockRecipeService.setRecipeState(recipes: recipes);
        
        // Act
        final result = await viewModel.updateRecipeContent(
          recipeId: 'r1',
          name: 'Updated Name',
          description: 'Updated description',
        );
        
        // Assert
        expect(result, isTrue);
        verify(() => mockPersonalOps.updateRecipeContent(
          recipeId: 'r1',
          title: 'Updated Name',
          description: 'Updated description',
          mealType: null,
          portions: null,
          timeMinutes: null,
          rating: null,
          ingredients: null,
          instructions: null,
          tags: null,
          sourceUrl: null,
        )).called(1);
      });

      test('should reject empty name in content update', () async {
        // Arrange
        final recipe = RecipeFactory.build(id: 'r1', type: RecipeType.personal);
        final recipes = [recipe];
        mockRecipeService.setRecipeState(recipes: recipes);
        
        // Act
        final result = await viewModel.updateRecipeContent(
          recipeId: 'r1',
          name: '',
        );
        
        // Assert
        expect(result, isFalse);
      });
    });

    group('Ingredient Management', () {
      test('should add ingredient', () async {
        // Arrange
        final recipe = RecipeFactory.build(id: 'r1', type: RecipeType.personal);
        final recipes = [recipe];
        mockRecipeService.setRecipeState(recipes: recipes);
        
        // Act
        final result = await viewModel.addIngredient('r1', 'New ingredient');
        
        // Assert
        expect(result, isTrue);
        verify(() => mockPersonalOps.addIngredient('r1', 'New ingredient')).called(1);
      });

      test('should update ingredient', () async {
        // Arrange
        final recipe = RecipeFactory.build(id: 'r1', type: RecipeType.personal);
        final recipes = [recipe];
        mockRecipeService.setRecipeState(recipes: recipes);
        
        // Act
        final result = await viewModel.updateIngredient('r1', 0, 'Updated ingredient');
        
        // Assert
        expect(result, isTrue);
        verify(() => mockPersonalOps.updateIngredient('r1', 0, 'Updated ingredient')).called(1);
      });

      test('should remove ingredient', () async {
        // Arrange
        final recipe = RecipeFactory.build(id: 'r1', type: RecipeType.personal);
        final recipes = [recipe];
        mockRecipeService.setRecipeState(recipes: recipes);
        
        // Act
        final result = await viewModel.removeIngredient('r1', 0);
        
        // Assert
        expect(result, isTrue);
        verify(() => mockPersonalOps.removeIngredient('r1', 0)).called(1);
      });
    });

    group('Query Utilities', () {
      test('should get recipe by ID', () {
        // Arrange
        final recipe = RecipeFactory.build(id: 'r1', type: RecipeType.personal);
        final recipes = [recipe];
        mockRecipeService.setRecipeState(recipes: recipes);
        
        // Act
        final result = viewModel.getPersonalRecipeById('r1');
        
        // Assert
        expect(result, equals(recipe));
      });

      test('should return null for non-existent ID', () {
        // Arrange - no recipes exist
        
        // Act
        final result = viewModel.getPersonalRecipeById('non-existent');
        
        // Assert
        expect(result, isNull);
      });

      test('should filter recipes by meal type', () {
        // Arrange
        final breakfast = RecipeFactory.build(id: 'b1', mealType: 'Frukost', type: RecipeType.personal);
        final lunch = RecipeFactory.build(id: 'l1', mealType: 'Lunch', type: RecipeType.personal);
        final recipes = [breakfast, lunch];
        mockRecipeService.setRecipeState(recipes: recipes);
        
        // Act
        final result = viewModel.getPersonalRecipesByMealType('Lunch');
        
        // Assert
        expect(result, hasLength(1));
        expect(result.first.id, equals('l1'));
      });

      test('should search recipes by query', () {
        // Arrange
        final recipe1 = RecipeFactory.build(
          id: 'r1',
          title: 'Pasta Carbonara',
          type: RecipeType.personal,
        );
        final recipe2 = RecipeFactory.build(
          id: 'r2',
          title: 'Chicken Salad',
          type: RecipeType.personal,
        );
        final recipes = [recipe1, recipe2];
        mockRecipeService.setRecipeState(recipes: recipes);
        
        // Act
        final result = viewModel.searchPersonalRecipes('pasta');
        
        // Assert
        expect(result, hasLength(1));
        expect(result.first.id, equals('r1'));
      });
    });

    group('Analytics', () {
      test('should calculate meal type counts', () {
        // Arrange
        final recipes = [
          RecipeFactory.build(mealType: 'Lunch', type: RecipeType.personal),
          RecipeFactory.build(mealType: 'Lunch', type: RecipeType.personal),
          RecipeFactory.build(mealType: 'Dinner', type: RecipeType.personal),
        ];
        mockRecipeService.setRecipeState(recipes: recipes);
        
        // Act
        final counts = viewModel.getPersonalMealTypeCounts();
        
        // Assert
        expect(counts['Lunch'], equals(2));
        expect(counts['Dinner'], equals(1));
      });

      test('should calculate tag counts', () {
        // Arrange
        final recipes = [
          RecipeFactory.build(tags: ['healthy', 'quick'], type: RecipeType.personal),
          RecipeFactory.build(tags: ['healthy', 'vegetarian']),
          RecipeFactory.build(tags: ['quick']),
        ];
        mockRecipeService.setRecipeState(recipes: recipes);
        
        // Act
        final counts = viewModel.getPersonalTagCounts();
        
        // Assert
        expect(counts['healthy'], equals(2));
        expect(counts['quick'], equals(2));
        expect(counts['vegetarian'], equals(1));
      });
    });

    group('Legacy Compatibility', () {
      test('should add legacy recipe', () async {
        // Arrange
        final recipe = RecipeFactory.build(id: 'r1', type: RecipeType.personal);
        
        // Act
        final result = await viewModel.addLegacyRecipe(recipe);
        
        // Assert
        expect(result.isSuccess, isTrue);
        verify(() => mockPersonalOps.addLegacyRecipe(recipe)).called(1);
      });

      test('should update legacy recipe', () async {
        // Arrange
        final recipe = RecipeFactory.build(id: 'r1', type: RecipeType.personal);
        
        // Act
        final result = await viewModel.updateLegacyRecipe(recipe);
        
        // Assert
        expect(result.isSuccess, isTrue);
        verify(() => mockPersonalOps.updateLegacyRecipe(recipe)).called(1);
      });
    });
  });
}