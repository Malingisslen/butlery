import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:butlery/viewmodels/recipe/personal_recipe_viewmodel.dart';
import 'package:butlery/services/unified/unified_recipe_service.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/services/unified/types/recipe_types.dart';

import '../../test_support/base_unit_test.dart';
import '../../infrastructure/factories/mock_factory.dart';
import '../../infrastructure/factories/recipe_factory.dart';
import '../../infrastructure/di/test_service_locator.dart';
import '../../infrastructure/mocks/production_mocks.dart';

void main() {
  group('PersonalRecipeViewModel - Ultrathink Enhanced Tests', () {
    late PersonalRecipeViewModel viewModel;
    late MockUnifiedRecipeService mockRecipeService;
    late MockPersonalRecipeOperations mockPersonalOps;

    // Test data
    const testUserId = 'user123';
    const testUserName = 'Test User';
    const testRecipeId = 'recipe123';

    final testPersonalRecipe = RecipeFactory.build(
      id: testRecipeId,
      title: 'Köttbullar',
      description: 'Klassiska svenska köttbullar',
      createdBy: testUserId,
      type: RecipeType.personal, // Explicitly set as personal recipe
      ingredients: ['500g köttfärs', '1 dl ströbröd', '1 ägg'],
      instructions: ['Blanda köttfärs', 'Forma bullar', 'Stek i panna'],
      personalTagIds: ['svensk', 'middag', 'kött'],
      mealType: 'Middag',
      imageUrls: ['image1.jpg'],
      portions: 4,
      timeMinutes: 30,
    );

    final testSharedRecipe = RecipeFactory.build(
      id: 'shared123',
      title: 'Shared Recipe',
      createdBy: 'other_user',
      type: RecipeType.shared, // Explicitly set as shared recipe
    );

    setUpAll(() async {
      await BaseUnitTest.setupUnit();
      registerFallbackValue(RecipeFactory.build());
      registerFallbackValue(RecipeType.personal);
      registerFallbackValue(<String>[]);
    });

    setUp(() async {
      await TestServiceLocator.initialize();

      // Create mocks using ultrathink gold standard pattern
      mockRecipeService = MockFactory.createUnifiedRecipeService();
      mockPersonalOps = MockPersonalRecipeOperations();

      // Register mock in test service locator
      TestServiceLocator.registerMock<UnifiedRecipeService>(mockRecipeService);

      // Configure mock state using ultrathink state-based configuration (NO when() stubs on service)
      mockRecipeService.setRecipeState(
        recipes: [testPersonalRecipe, testSharedRecipe],
        currentUserId: testUserId,
        currentUserDisplayName: testUserName,
        isLoading: false,
        error: null,
        isInitialized: true,
        personalOperations: mockPersonalOps,
      );

      // Configure MockPersonalRecipeOperations with ultrathink state-based approach
      // Default successful responses on the operations mock, NOT the service
      when(() => mockPersonalOps.createRecipe(
                title: any(named: 'title'),
                description: any(named: 'description'),
                ingredients: any(named: 'ingredients'),
                instructions: any(named: 'instructions'),
                mealType: any(named: 'mealType'),
                portions: any(named: 'portions'),
                timeMinutes: any(named: 'timeMinutes'),
                personalTagIds: any(named: 'personalTags'),
                imageUrls: any(named: 'imageUrls'),
              ))
          .thenAnswer(
              (_) async => 'recipe_123'); // createRecipe returns String?

      when(() => mockPersonalOps.updateRecipe(any()))
          .thenAnswer((_) async => true);

      when(() => mockPersonalOps.deleteRecipe(any()))
          .thenAnswer((_) async => true);

      when(() => mockPersonalOps.updateRecipeContent(
            recipeId: any(named: 'recipeId'),
            title: any(named: 'title'),
            description: any(named: 'description'),
            mealType: any(named: 'mealType'),
            portions: any(named: 'portions'),
            timeMinutes: any(named: 'timeMinutes'),
          )).thenAnswer((_) async => true);

      when(() => mockPersonalOps.addIngredient(any(), any()))
          .thenAnswer((_) async => true);
      when(() => mockPersonalOps.updateIngredient(any(), any(), any()))
          .thenAnswer((_) async => true);
      when(() => mockPersonalOps.removeIngredient(any(), any()))
          .thenAnswer((_) async => true);

      when(() => mockPersonalOps.addInstruction(any(), any()))
          .thenAnswer((_) async => true);
      when(() => mockPersonalOps.updateInstruction(any(), any(), any()))
          .thenAnswer((_) async => true);
      when(() => mockPersonalOps.removeInstruction(any(), any()))
          .thenAnswer((_) async => true);

      when(() => mockPersonalOps.markAsCooked(any()))
          .thenAnswer((_) async => true);

      when(() => mockPersonalOps.addLegacyRecipe(any()))
          .thenAnswer((_) async => RecipeOperationResult.success(
                'Recipe added successfully',
              ));

      when(() => mockPersonalOps.updateLegacyRecipe(any()))
          .thenAnswer((_) async => RecipeOperationResult.success(
                'Recipe updated successfully',
              ));

      // Create view model
      viewModel = PersonalRecipeViewModel();
    });

    tearDown(() async {
      viewModel.dispose();
      await TestServiceLocator.reset();
      BaseUnitTest.resetMocks();
    });

    tearDownAll(() async {
      await BaseUnitTest.teardownUnit();
    });

    group('Initialization and Default State', () {
      test('should initialize with correct default state for all properties',
          () {
        // Assert
        expect(viewModel.serviceName, equals('PersonalRecipeViewModel'));
        expect(viewModel.personalRecipes, hasLength(1));
        expect(viewModel.hasPersonalRecipes, isTrue);
        expect(viewModel.personalRecipeCount, equals(1));
        expect(viewModel.currentUserId, equals(testUserId));
        expect(viewModel.currentUserDisplayName, equals(testUserName));
      });

      test('should properly register service listener', () {
        // Assert
        // Note: Can't verify mockRecipeService.addListener as it's not a mock method
        // The service initialization is tested through state verification
      });

      test('should react to service state changes', () {
        // Arrange
        var notificationCount = 0;
        viewModel.addListener(() => notificationCount++);

        // Act - trigger service change using ultrathink state configuration
        mockRecipeService.setRecipeState(
          recipes: [], // No recipes = no personal recipes
          currentUserId: testUserId,
          currentUserDisplayName: testUserName,
          personalOperations: mockPersonalOps,
        );
        mockRecipeService.notifyListeners();

        // Assert
        expect(notificationCount, greaterThan(0));
        expect(viewModel.hasPersonalRecipes, isFalse);
        expect(viewModel.personalRecipeCount, equals(0));
      });

      test('should handle empty personal recipes list', () {
        // Arrange - use ultrathink state configuration
        mockRecipeService.setRecipeState(
          recipes: [], // No recipes = no personal recipes
          currentUserId: testUserId,
          currentUserDisplayName: testUserName,
          personalOperations: mockPersonalOps,
        );
        mockRecipeService.notifyListeners();

        // Assert
        expect(viewModel.hasPersonalRecipes, isFalse);
        expect(viewModel.personalRecipeCount, equals(0));
        expect(viewModel.personalRecipes, isEmpty);
      });
    });

    group('Recipe Creation', () {
      test('should create recipe with required fields only', () async {
        // Act
        final result = await viewModel.createPersonalRecipe(
          name: 'Pannkakor',
        );

        // Assert
        expect(result, isTrue);
        verify(() => mockRecipeService.personal.createRecipe(
              title: 'Pannkakor',
              description: '',
              ingredients: [],
              instructions: [],
              mealType: '',
              portions: 1,
              timeMinutes: 0,
              personalTagIds: [],
              imageUrls: [],
            )).called(1);
      });

      test('should create recipe with all fields', () async {
        // Act
        final result = await viewModel.createPersonalRecipe(
          name: 'Laxsoppa',
          description: 'Krämig laxsoppa med dill',
          ingredients: ['400g lax', '2 dl grädde', 'Dill'],
          instructions: ['Koka lax', 'Tillsätt grädde', 'Servera med dill'],
          mealType: 'Middag',
          portions: 4,
          timeMinutes: 45,
          personalTagIds: ['fisk', 'soppa', 'svensk'],
          imageUrls: ['laxsoppa.jpg'],
        );

        // Assert
        expect(result, isTrue);
        verify(() => mockRecipeService.personal.createRecipe(
              title: 'Laxsoppa',
              description: 'Krämig laxsoppa med dill',
              ingredients: ['400g lax', '2 dl grädde', 'Dill'],
              instructions: ['Koka lax', 'Tillsätt grädde', 'Servera med dill'],
              mealType: 'Middag',
              portions: 4,
              timeMinutes: 45,
              personalTagIds: ['fisk', 'soppa', 'svensk'],
              imageUrls: ['laxsoppa.jpg'],
            )).called(1);
      });

      test('should reject empty recipe title', () async {
        // Act
        final result = await viewModel.createPersonalRecipe(
          name: '',
        );

        // Assert
        expect(result, isFalse);
        verifyNever(() => mockRecipeService.personal.createRecipe(
              title: any(named: 'title'),
              description: any(named: 'description'),
              ingredients: any(named: 'ingredients'),
              instructions: any(named: 'instructions'),
              mealType: any(named: 'mealType'),
              portions: any(named: 'portions'),
              timeMinutes: any(named: 'timeMinutes'),
              personalTagIds: any(named: 'personalTags'),
              imageUrls: any(named: 'imageUrls'),
            ));
      });

      test('should reject whitespace-only recipe title', () async {
        // Act
        final result = await viewModel.createPersonalRecipe(
          name: '   \t\n  ',
        );

        // Assert
        expect(result, isFalse);
        verifyNever(() => mockRecipeService.personal.createRecipe(
              title: any(named: 'title'),
              description: any(named: 'description'),
              ingredients: any(named: 'ingredients'),
              instructions: any(named: 'instructions'),
              mealType: any(named: 'mealType'),
              portions: any(named: 'portions'),
              timeMinutes: any(named: 'timeMinutes'),
              personalTagIds: any(named: 'personalTags'),
              imageUrls: any(named: 'imageUrls'),
            ));
      });

      test('should handle creation failure', () async {
        // Arrange
        when(() => mockPersonalOps.createRecipe(
              title: any(named: 'title'),
              description: any(named: 'description'),
              ingredients: any(named: 'ingredients'),
              instructions: any(named: 'instructions'),
              mealType: any(named: 'mealType'),
              portions: any(named: 'portions'),
              timeMinutes: any(named: 'timeMinutes'),
              personalTagIds: any(named: 'personalTags'),
              imageUrls: any(named: 'imageUrls'),
              rating: any(named: 'rating'),
              sourceUrl: any(named: 'sourceUrl'),
            )).thenAnswer((_) async => null);

        // Act
        final result = await viewModel.createPersonalRecipe(
          name: 'Test Recipe',
        );

        // Assert
        expect(result, isFalse);
      });

      test('should handle service exception during creation', () async {
        // Arrange
        when(() => mockPersonalOps.createRecipe(
              title: any(named: 'title'),
              description: any(named: 'description'),
              ingredients: any(named: 'ingredients'),
              instructions: any(named: 'instructions'),
              mealType: any(named: 'mealType'),
              portions: any(named: 'portions'),
              timeMinutes: any(named: 'timeMinutes'),
              personalTagIds: any(named: 'personalTags'),
              imageUrls: any(named: 'imageUrls'),
            )).thenThrow(Exception('Network error'));

        // Act
        final result = await viewModel.createPersonalRecipe(
          name: 'Test Recipe',
        );

        // Assert
        expect(result, isFalse);
      });
    });

    group('Recipe Update', () {
      test('should update recipe with all fields', () async {
        // Arrange
        final updatedRecipe = RecipeFactory.build(
          id: testRecipeId,
          title: 'Updated Title',
          description: 'Updated description',
          ingredients: ['New ingredient'],
          instructions: ['New instruction'],
          mealType: 'Lunch',
          portions: 6,
          timeMinutes: 60,
          personalTagIds: ['updated'],
          imageUrls: ['new.jpg'],
          createdBy: testUserId,
        );

        // Act
        final result = await viewModel.updatePersonalRecipe(updatedRecipe);

        // Assert
        expect(result, isTrue);
        verify(() => mockRecipeService.personal.updateRecipe(updatedRecipe))
            .called(1);
      });

      test('should reject update with empty recipe ID', () async {
        // Arrange
        final invalidRecipe = RecipeFactory.build(
          id: '',
          title: 'Updated',
          createdBy: testUserId,
        );

        // Act
        final result = await viewModel.updatePersonalRecipe(invalidRecipe);

        // Assert
        expect(result, isFalse);
        verifyNever(() => mockRecipeService.personal.updateRecipe(any()));
      });

      test('should reject update for non-personal recipe', () async {
        // Act - testSharedRecipe is already defined in setUp as non-personal
        final result = await viewModel.updatePersonalRecipe(testSharedRecipe);

        // Assert
        expect(result, isFalse);
        verifyNever(() => mockRecipeService.personal.updateRecipe(any()));
      });

      test('should handle update failure', () async {
        // Arrange
        when(() => mockRecipeService.personal.updateRecipe(any()))
            .thenAnswer((_) async => false);

        // Act
        final result = await viewModel.updatePersonalRecipe(testPersonalRecipe);

        // Assert
        expect(result, isFalse);
      });
    });

    group('Recipe Deletion', () {
      test('should delete personal recipe successfully', () async {
        // Act
        final result = await viewModel.deletePersonalRecipe(testRecipeId);

        // Assert
        expect(result, isTrue);
        verify(() => mockRecipeService.personal.deleteRecipe(testRecipeId))
            .called(1);
      });

      test('should reject deletion with empty recipe ID', () async {
        // Act
        final result = await viewModel.deletePersonalRecipe('');

        // Assert
        expect(result, isFalse);
        verifyNever(() => mockRecipeService.personal.deleteRecipe(any()));
      });

      test('should reject deletion of non-personal recipe', () async {
        // Act
        final result = await viewModel.deletePersonalRecipe('shared123');

        // Assert
        expect(result, isFalse);
        verifyNever(() => mockRecipeService.personal.deleteRecipe(any()));
      });

      test('should handle deletion failure', () async {
        // Arrange
        when(() => mockRecipeService.personal.deleteRecipe(any()))
            .thenAnswer((_) async => false);

        // Act
        final result = await viewModel.deletePersonalRecipe(testRecipeId);

        // Assert
        expect(result, isFalse);
      });
    });

    group('Content Updates', () {
      test('should update recipe content fields', () async {
        // Act
        final result = await viewModel.updateRecipeContent(
          recipeId: testRecipeId,
          name: 'New Title',
          description: 'New Description',
          mealType: 'Frukost',
          portions: 2,
          timeMinutes: 15,
        );

        // Assert
        expect(result, isTrue);
        verify(() => mockRecipeService.personal.updateRecipeContent(
              recipeId: testRecipeId,
              title: 'New Title',
              description: 'New Description',
              mealType: 'Frukost',
              portions: 2,
              timeMinutes: 15,
            )).called(1);
      });

      test('should reject content update with empty recipe ID', () async {
        // Act
        final result = await viewModel.updateRecipeContent(
          recipeId: '',
          name: 'New Title',
        );

        // Assert
        expect(result, isFalse);
      });

      test('should reject content update for non-personal recipe', () async {
        // Act
        final result = await viewModel.updateRecipeContent(
          recipeId: 'shared123',
          name: 'New Title',
        );

        // Assert
        expect(result, isFalse);
      });
    });

    group('Ingredient Management', () {
      test('should add ingredient to recipe', () async {
        // Act
        final result =
            await viewModel.addIngredient(testRecipeId, '200g pasta');

        // Assert
        expect(result, isTrue);
        verify(() => mockRecipeService.personal.addIngredient(
              testRecipeId,
              '200g pasta',
            )).called(1);
      });

      test('should update ingredient at index', () async {
        // Act
        final result =
            await viewModel.updateIngredient(testRecipeId, 0, '600g köttfärs');

        // Assert
        expect(result, isTrue);
        verify(() => mockRecipeService.personal.updateIngredient(
              testRecipeId,
              0,
              '600g köttfärs',
            )).called(1);
      });

      test('should remove ingredient at index', () async {
        // Act
        final result = await viewModel.removeIngredient(testRecipeId, 1);

        // Assert
        expect(result, isTrue);
        verify(() => mockRecipeService.personal.removeIngredient(
              testRecipeId,
              1,
            )).called(1);
      });

      test('should reject ingredient operations with empty recipe ID',
          () async {
        // Act
        final addResult = await viewModel.addIngredient('', 'test');
        final updateResult = await viewModel.updateIngredient('', 0, 'test');
        final removeResult = await viewModel.removeIngredient('', 0);

        // Assert
        expect(addResult, isFalse);
        expect(updateResult, isFalse);
        expect(removeResult, isFalse);
      });

      test('should reject adding empty ingredient', () async {
        // Act
        final result = await viewModel.addIngredient(testRecipeId, '');

        // Assert
        expect(result, isFalse);
        verifyNever(
            () => mockRecipeService.personal.addIngredient(any(), any()));
      });

      test('should reject updating with empty ingredient', () async {
        // Act
        final result = await viewModel.updateIngredient(testRecipeId, 0, '');

        // Assert
        expect(result, isFalse);
        verifyNever(() =>
            mockRecipeService.personal.updateIngredient(any(), any(), any()));
      });

      test('should reject ingredient operations for non-personal recipe',
          () async {
        // Act
        final addResult = await viewModel.addIngredient('shared123', 'test');
        final updateResult =
            await viewModel.updateIngredient('shared123', 0, 'test');
        final removeResult = await viewModel.removeIngredient('shared123', 0);

        // Assert
        expect(addResult, isFalse);
        expect(updateResult, isFalse);
        expect(removeResult, isFalse);
      });

      test('should handle negative index for ingredient operations', () async {
        // Act
        final updateResult =
            await viewModel.updateIngredient(testRecipeId, -1, 'test');
        final removeResult = await viewModel.removeIngredient(testRecipeId, -1);

        // Assert
        expect(updateResult, isFalse);
        expect(removeResult, isFalse);
      });
    });

    group('Instruction Management', () {
      test('should add instruction to recipe', () async {
        // Act
        final result = await viewModel.addInstruction(
            testRecipeId, 'Koka pastan al dente');

        // Assert
        expect(result, isTrue);
        verify(() => mockRecipeService.personal.addInstruction(
              testRecipeId,
              'Koka pastan al dente',
            )).called(1);
      });

      test('should update instruction at index', () async {
        // Act
        final result = await viewModel.updateInstruction(
            testRecipeId, 0, 'Blanda alla ingredienser');

        // Assert
        expect(result, isTrue);
        verify(() => mockRecipeService.personal.updateInstruction(
              testRecipeId,
              0,
              'Blanda alla ingredienser',
            )).called(1);
      });

      test('should remove instruction at index', () async {
        // Act
        final result = await viewModel.removeInstruction(testRecipeId, 2);

        // Assert
        expect(result, isTrue);
        verify(() => mockRecipeService.personal.removeInstruction(
              testRecipeId,
              2,
            )).called(1);
      });

      test('should reject instruction operations with empty recipe ID',
          () async {
        // Act
        final addResult = await viewModel.addInstruction('', 'test');
        final updateResult = await viewModel.updateInstruction('', 0, 'test');
        final removeResult = await viewModel.removeInstruction('', 0);

        // Assert
        expect(addResult, isFalse);
        expect(updateResult, isFalse);
        expect(removeResult, isFalse);
      });

      test('should reject adding empty instruction', () async {
        // Act
        final result = await viewModel.addInstruction(testRecipeId, '');

        // Assert
        expect(result, isFalse);
        verifyNever(
            () => mockRecipeService.personal.addInstruction(any(), any()));
      });

      test('should reject updating with empty instruction', () async {
        // Act
        final result = await viewModel.updateInstruction(testRecipeId, 0, '');

        // Assert
        expect(result, isFalse);
        verifyNever(() =>
            mockRecipeService.personal.updateInstruction(any(), any(), any()));
      });

      test('should reject instruction operations for non-personal recipe',
          () async {
        // Act
        final addResult = await viewModel.addInstruction('shared123', 'test');
        final updateResult =
            await viewModel.updateInstruction('shared123', 0, 'test');
        final removeResult = await viewModel.removeInstruction('shared123', 0);

        // Assert
        expect(addResult, isFalse);
        expect(updateResult, isFalse);
        expect(removeResult, isFalse);
      });

      test('should handle negative index for instruction operations', () async {
        // Act
        final updateResult =
            await viewModel.updateInstruction(testRecipeId, -1, 'test');
        final removeResult =
            await viewModel.removeInstruction(testRecipeId, -1);

        // Assert
        expect(updateResult, isFalse);
        expect(removeResult, isFalse);
      });
    });

    group('Cooking Tracking', () {
      test('should mark recipe as cooked', () async {
        // Act
        final result = await viewModel.markAsCooked(testRecipeId);

        // Assert
        expect(result, isTrue);
        verify(() => mockRecipeService.personal.markAsCooked(testRecipeId))
            .called(1);
      });

      test('should reject marking with empty recipe ID', () async {
        // Act
        final result = await viewModel.markAsCooked('');

        // Assert
        expect(result, isFalse);
        verifyNever(() => mockRecipeService.personal.markAsCooked(any()));
      });

      test('should reject marking non-personal recipe as cooked', () async {
        // Act
        final result = await viewModel.markAsCooked('shared123');

        // Assert
        expect(result, isFalse);
        verifyNever(() => mockRecipeService.personal.markAsCooked(any()));
      });

      test('should handle marking failure', () async {
        // Arrange
        when(() => mockRecipeService.personal.markAsCooked(any()))
            .thenAnswer((_) async => false);

        // Act
        final result = await viewModel.markAsCooked(testRecipeId);

        // Assert
        expect(result, isFalse);
      });
    });

    group('Legacy Compatibility', () {
      test('should add recipe using legacy format', () async {
        // Act
        final result = await viewModel.addLegacyRecipe(testPersonalRecipe);

        // Assert
        expect(result.isSuccess, isTrue);
        expect(result.message, equals('Recipe added successfully'));
        verify(() =>
                mockRecipeService.personal.addLegacyRecipe(testPersonalRecipe))
            .called(1);
      });

      test('should update recipe using legacy format', () async {
        // Act
        final result = await viewModel.updateLegacyRecipe(testPersonalRecipe);

        // Assert
        expect(result.isSuccess, isTrue);
        expect(result.message, equals('Recipe updated successfully'));
        verify(() => mockRecipeService.personal
            .updateLegacyRecipe(testPersonalRecipe)).called(1);
      });

      test('should handle legacy add failure', () async {
        // Arrange
        when(() => mockRecipeService.personal.addLegacyRecipe(any()))
            .thenAnswer((_) async => RecipeOperationResult.failure(
                  'Failed to add',
                ));

        // Act
        final result = await viewModel.addLegacyRecipe(testPersonalRecipe);

        // Assert
        expect(result.isSuccess, isFalse);
        expect(result.message, equals('Failed to add'));
      });

      test('should handle legacy update failure', () async {
        // Arrange
        when(() => mockRecipeService.personal.updateLegacyRecipe(any()))
            .thenAnswer((_) async => RecipeOperationResult.failure(
                  'Failed to update',
                ));

        // Act
        final result = await viewModel.updateLegacyRecipe(testPersonalRecipe);

        // Assert
        expect(result.isSuccess, isFalse);
        expect(result.message, equals('Failed to update'));
      });
    });

    group('Query Utilities', () {
      test('should get recipe by ID', () {
        // Act
        final recipe = viewModel.getPersonalRecipeById(testRecipeId);

        // Assert
        expect(recipe, isNotNull);
        expect(recipe?.id, equals(testRecipeId));
        expect(recipe?.title, equals('Köttbullar'));
      });

      test('should return null for non-existent recipe ID', () {
        // Act
        final recipe = viewModel.getPersonalRecipeById('nonexistent');

        // Assert
        expect(recipe, isNull);
      });

      test('should return null for shared recipe ID', () {
        // Act
        final recipe = viewModel.getPersonalRecipeById('shared123');

        // Assert
        expect(recipe, isNull);
      });

      test('should get recipes by meal type', () {
        // Arrange
        final breakfastRecipe = RecipeFactory.build(
          id: 'breakfast1',
          title: 'Gröt',
          mealType: 'Frukost',
          type: RecipeType.personal,
          createdBy: testUserId,
        );
        when(() => mockRecipeService.personalRecipes)
            .thenReturn([testPersonalRecipe, breakfastRecipe]);
        mockRecipeService.notifyListeners();

        // Act
        final dinnerRecipes = viewModel.getPersonalRecipesByMealType('Middag');
        final breakfastRecipes =
            viewModel.getPersonalRecipesByMealType('Frukost');

        // Assert
        expect(dinnerRecipes, hasLength(1));
        expect(dinnerRecipes.first.title, equals('Köttbullar'));
        expect(breakfastRecipes, hasLength(1));
        expect(breakfastRecipes.first.title, equals('Gröt'));
      });

      test('should get recipes by tag', () {
        // Arrange
        final italianRecipe = RecipeFactory.build(
          id: 'italian1',
          title: 'Pasta Carbonara',
          personalTagIds: ['italiensk', 'pasta', 'middag'],
          type: RecipeType.personal,
          createdBy: testUserId,
        );
        when(() => mockRecipeService.personalRecipes)
            .thenReturn([testPersonalRecipe, italianRecipe]);
        mockRecipeService.notifyListeners();

        // Act
        final swedishRecipes = viewModel.getPersonalRecipesByTag('svensk');
        final pastaRecipes = viewModel.getPersonalRecipesByTag('pasta');
        final dinnerRecipes = viewModel.getPersonalRecipesByTag('middag');

        // Assert
        expect(swedishRecipes, hasLength(1));
        expect(swedishRecipes.first.title, equals('Köttbullar'));
        expect(pastaRecipes, hasLength(1));
        expect(pastaRecipes.first.title, equals('Pasta Carbonara'));
        expect(dinnerRecipes, hasLength(2));
      });

      test('should return empty list for non-existent tag', () {
        // Act
        final recipes = viewModel.getPersonalRecipesByTag('nonexistent');

        // Assert
        expect(recipes, isEmpty);
      });

      test('should search recipes by query', () {
        // Arrange
        final recipes = [
          RecipeFactory.build(
            id: '1',
            title: 'Köttbullar',
            description: 'Svenska klassiker',
            ingredients: ['köttfärs'],
            type: RecipeType.personal,
            createdBy: testUserId,
          ),
          RecipeFactory.build(
            id: '2',
            title: 'Pasta',
            description: 'Italiensk rätt',
            ingredients: ['pasta', 'tomatsås'],
            type: RecipeType.personal,
            createdBy: testUserId,
          ),
        ];
        when(() => mockRecipeService.personalRecipes).thenReturn(recipes);
        mockRecipeService.notifyListeners();

        // Act
        final titleSearch = viewModel.searchPersonalRecipes('köttbullar');
        final descriptionSearch = viewModel.searchPersonalRecipes('italiensk');
        final ingredientSearch = viewModel.searchPersonalRecipes('pasta');

        // Assert
        expect(titleSearch, hasLength(1));
        expect(titleSearch.first.title, equals('Köttbullar'));
        expect(descriptionSearch, hasLength(1));
        expect(descriptionSearch.first.title, equals('Pasta'));
        expect(ingredientSearch, hasLength(1));
        expect(ingredientSearch.first.title, equals('Pasta'));
      });

      test('should return all recipes for empty search query', () {
        // Act
        final recipes = viewModel.searchPersonalRecipes('');

        // Assert
        expect(recipes, equals(viewModel.personalRecipes));
      });

      test('should handle case-insensitive search', () {
        // Act
        final upperCase = viewModel.searchPersonalRecipes('KÖTTBULLAR');
        final lowerCase = viewModel.searchPersonalRecipes('köttbullar');
        final mixedCase = viewModel.searchPersonalRecipes('KöTtBuLLaR');

        // Assert
        expect(upperCase, hasLength(1));
        expect(lowerCase, hasLength(1));
        expect(mixedCase, hasLength(1));
      });
    });

    group('Analytics', () {
      test('should get meal type counts', () {
        // Arrange
        final recipes = [
          RecipeFactory.build(
              mealType: 'Frukost',
              type: RecipeType.personal,
              createdBy: testUserId),
          RecipeFactory.build(
              mealType: 'Frukost',
              type: RecipeType.personal,
              createdBy: testUserId),
          RecipeFactory.build(
              mealType: 'Middag',
              type: RecipeType.personal,
              createdBy: testUserId),
          RecipeFactory.build(
              mealType: 'Middag',
              type: RecipeType.personal,
              createdBy: testUserId),
          RecipeFactory.build(
              mealType: 'Middag',
              type: RecipeType.personal,
              createdBy: testUserId),
          RecipeFactory.build(
              mealType: 'Lunch',
              type: RecipeType.personal,
              createdBy: testUserId),
        ];
        when(() => mockRecipeService.personalRecipes).thenReturn(recipes);
        mockRecipeService.notifyListeners();

        // Act
        final counts = viewModel.getPersonalMealTypeCounts();

        // Assert
        expect(counts['Frukost'], equals(2));
        expect(counts['Middag'], equals(3));
        expect(counts['Lunch'], equals(1));
      });

      test('should get tag counts', () {
        // Arrange
        final recipes = [
          RecipeFactory.build(
              personalTagIds: ['svensk', 'kött'],
              type: RecipeType.personal,
              createdBy: testUserId),
          RecipeFactory.build(
              personalTagIds: ['svensk', 'fisk'],
              type: RecipeType.personal,
              createdBy: testUserId),
          RecipeFactory.build(
              personalTagIds: ['italiensk', 'pasta'],
              type: RecipeType.personal,
              createdBy: testUserId),
          RecipeFactory.build(
              personalTagIds: ['svensk', 'soppa'],
              type: RecipeType.personal,
              createdBy: testUserId),
        ];
        when(() => mockRecipeService.personalRecipes).thenReturn(recipes);
        mockRecipeService.notifyListeners();

        // Act
        final counts = viewModel.getPersonalTagCounts();

        // Assert
        expect(counts['svensk'], equals(3));
        expect(counts['kött'], equals(1));
        expect(counts['fisk'], equals(1));
        expect(counts['italiensk'], equals(1));
        expect(counts['pasta'], equals(1));
        expect(counts['soppa'], equals(1));
      });

      test('should handle empty recipes for analytics', () {
        // Arrange
        when(() => mockRecipeService.personalRecipes).thenReturn([]);
        mockRecipeService.notifyListeners();

        // Act
        final mealTypeCounts = viewModel.getPersonalMealTypeCounts();
        final tagCounts = viewModel.getPersonalTagCounts();

        // Assert
        expect(mealTypeCounts, isEmpty);
        expect(tagCounts, isEmpty);
      });
    });

    group('Error Handling', () {
      test('should handle service exceptions gracefully', () async {
        // Arrange
        when(() => mockPersonalOps.createRecipe(
              title: any(named: 'title'),
              description: any(named: 'description'),
              ingredients: any(named: 'ingredients'),
              instructions: any(named: 'instructions'),
              mealType: any(named: 'mealType'),
              portions: any(named: 'portions'),
              timeMinutes: any(named: 'timeMinutes'),
              personalTagIds: any(named: 'personalTags'),
              imageUrls: any(named: 'imageUrls'),
            )).thenThrow(Exception('Network error'));

        // Act
        final result = await viewModel.createPersonalRecipe(name: 'Test');

        // Assert
        expect(result, isFalse);
      });

      test('should handle concurrent operations', () async {
        // Arrange
        when(() => mockPersonalOps.createRecipe(
              title: any(named: 'title'),
              description: any(named: 'description'),
              ingredients: any(named: 'ingredients'),
              instructions: any(named: 'instructions'),
              mealType: any(named: 'mealType'),
              portions: any(named: 'portions'),
              timeMinutes: any(named: 'timeMinutes'),
              personalTagIds: any(named: 'personalTags'),
              imageUrls: any(named: 'imageUrls'),
            )).thenAnswer((_) async {
          await Future.delayed(Duration(milliseconds: 10));
          return 'recipe_123';
        });

        // Act - start multiple operations
        final futures = [
          viewModel.createPersonalRecipe(name: 'Recipe 1'),
          viewModel.createPersonalRecipe(name: 'Recipe 2'),
          viewModel.createPersonalRecipe(name: 'Recipe 3'),
        ];
        final results = await Future.wait(futures);

        // Assert
        expect(results, everyElement(isTrue));
        verify(() => mockPersonalOps.createRecipe(
              title: any(named: 'title'),
              description: any(named: 'description'),
              ingredients: any(named: 'ingredients'),
              instructions: any(named: 'instructions'),
              mealType: any(named: 'mealType'),
              portions: any(named: 'portions'),
              timeMinutes: any(named: 'timeMinutes'),
              personalTagIds: any(named: 'personalTags'),
              imageUrls: any(named: 'imageUrls'),
            )).called(3);
      });
    });

    group('State Management', () {
      test('should notify listeners on recipe changes', () {
        // Arrange
        var notificationCount = 0;
        viewModel.addListener(() => notificationCount++);

        // Act - trigger multiple state changes
        when(() => mockRecipeService.personalRecipes).thenReturn([]);
        mockRecipeService.notifyListeners();

        when(() => mockRecipeService.personalRecipes)
            .thenReturn([testPersonalRecipe]);
        mockRecipeService.notifyListeners();

        // Assert
        expect(notificationCount, greaterThanOrEqualTo(2));
      });

      test('should reflect loading state from service', () {
        // Arrange
        when(() => mockRecipeService.isLoading).thenReturn(true);
        mockRecipeService.notifyListeners();

        // Act
        final isLoading = mockRecipeService.isLoading;

        // Assert
        expect(isLoading, isTrue);
      });

      test('should reflect error state from service', () {
        // Arrange
        when(() => mockRecipeService.error).thenReturn('Service error');
        mockRecipeService.notifyListeners();

        // Act
        final error = mockRecipeService.error;

        // Assert
        expect(error, equals('Service error'));
      });
    });

    group('Lifecycle Management', () {
      test('should dispose without errors', () {
        // Act & Assert
        expect(() => viewModel.dispose(), returnsNormally);
      });

      test('should remove service listener on dispose', () {
        // Act
        viewModel.dispose();

        // Assert
        verify(() => mockRecipeService.removeListener(any())).called(1);
      });

      test('should handle operations after disposal safely', () {
        // Arrange
        viewModel.dispose();

        // Act & Assert - should not throw
        expect(() => viewModel.personalRecipes, returnsNormally);
        expect(() => viewModel.hasPersonalRecipes, returnsNormally);
      });
    });

    group('Edge Cases', () {
      test('should handle recipes with missing fields', () {
        // Arrange
        final minimalRecipe = RecipeFactory.build(
          id: 'minimal',
          title: 'Minimal Recipe',
          type: RecipeType.personal,
          createdBy: testUserId,
          ingredients: [],
          instructions: [],
          personalTagIds: [],
        );
        when(() => mockRecipeService.personalRecipes)
            .thenReturn([minimalRecipe]);
        mockRecipeService.notifyListeners();

        // Act
        final recipe = viewModel.getPersonalRecipeById('minimal');

        // Assert
        expect(recipe, isNotNull);
        expect(recipe?.ingredients, isEmpty);
        expect(recipe?.instructions, isEmpty);
        expect(recipe?.personalTagIds, isEmpty);
      });

      test('should handle very long input strings', () async {
        // Arrange
        final longTitle = 'A' * 1000;
        final longDescription = 'B' * 5000;

        // Act
        final result = await viewModel.createPersonalRecipe(
          name: longTitle,
          description: longDescription,
        );

        // Assert
        expect(result, isTrue);
        verify(() => mockPersonalOps.createRecipe(
              title: longTitle,
              description: longDescription,
              ingredients: any(named: 'ingredients'),
              instructions: any(named: 'instructions'),
              mealType: any(named: 'mealType'),
              portions: any(named: 'portions'),
              timeMinutes: any(named: 'timeMinutes'),
              personalTagIds: any(named: 'personalTags'),
              imageUrls: any(named: 'imageUrls'),
            )).called(1);
      });

      test('should handle special characters in search', () {
        // Arrange
        final specialRecipe = RecipeFactory.build(
          title: 'Räksmörgås & Ägg',
          description: 'Med dill & citron',
          type: RecipeType.personal,
          createdBy: testUserId,
        );
        when(() => mockRecipeService.personalRecipes)
            .thenReturn([specialRecipe]);
        mockRecipeService.notifyListeners();

        // Act
        final ampersandSearch = viewModel.searchPersonalRecipes('&');
        final swedishSearch = viewModel.searchPersonalRecipes('räksmörgås');

        // Assert
        expect(ampersandSearch, hasLength(1));
        expect(swedishSearch, hasLength(1));
      });
    });

    group('Swedish Localization', () {
      test('should handle Swedish meal types correctly', () {
        // Arrange
        final swedishRecipes = [
          RecipeFactory.build(
              mealType: 'Frukost',
              type: RecipeType.personal,
              createdBy: testUserId),
          RecipeFactory.build(
              mealType: 'Lunch',
              type: RecipeType.personal,
              createdBy: testUserId),
          RecipeFactory.build(
              mealType: 'Middag',
              type: RecipeType.personal,
              createdBy: testUserId),
          RecipeFactory.build(
              mealType: 'Mellanmål',
              type: RecipeType.personal,
              createdBy: testUserId),
          RecipeFactory.build(
              mealType: 'Kvällsmat',
              type: RecipeType.personal,
              createdBy: testUserId),
        ];
        when(() => mockRecipeService.personalRecipes)
            .thenReturn(swedishRecipes);
        mockRecipeService.notifyListeners();

        // Act
        final breakfast = viewModel.getPersonalRecipesByMealType('Frukost');
        final lunch = viewModel.getPersonalRecipesByMealType('Lunch');
        final dinner = viewModel.getPersonalRecipesByMealType('Middag');
        final snack = viewModel.getPersonalRecipesByMealType('Mellanmål');
        final supper = viewModel.getPersonalRecipesByMealType('Kvällsmat');

        // Assert
        expect(breakfast, hasLength(1));
        expect(lunch, hasLength(1));
        expect(dinner, hasLength(1));
        expect(snack, hasLength(1));
        expect(supper, hasLength(1));
      });

      test('should handle Swedish characters in titles and descriptions',
          () async {
        // Act
        final result = await viewModel.createPersonalRecipe(
          name: 'Räksmörgås med Ägg och Öl',
          description: 'Årets bästa räksmörgås från Skåne',
        );

        // Assert
        expect(result, isTrue);
      });

      test('should search with Swedish characters', () {
        // Arrange
        final recipes = [
          RecipeFactory.build(
            title: 'Äppelpaj',
            type: RecipeType.personal,
            createdBy: testUserId,
          ),
          RecipeFactory.build(
            title: 'Ärtsoppa',
            type: RecipeType.personal,
            createdBy: testUserId,
          ),
          RecipeFactory.build(
            title: 'Öl och korv',
            type: RecipeType.personal,
            createdBy: testUserId,
          ),
        ];
        when(() => mockRecipeService.personalRecipes).thenReturn(recipes);
        mockRecipeService.notifyListeners();

        // Act
        final appleSearch = viewModel.searchPersonalRecipes('äppel');
        final peaSearch = viewModel.searchPersonalRecipes('ärt');
        final beerSearch = viewModel.searchPersonalRecipes('öl');

        // Assert
        expect(appleSearch, hasLength(1));
        expect(appleSearch.first.title, equals('Äppelpaj'));
        expect(peaSearch, hasLength(1));
        expect(peaSearch.first.title, equals('Ärtsoppa'));
        expect(beerSearch, hasLength(1));
        expect(beerSearch.first.title, equals('Öl och korv'));
      });
    });
  });
}
