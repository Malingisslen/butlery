// test/unit/services/unified/operations/realtime_recipe/realtime_editing_module_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:butlery/services/unified/operations/realtime_recipe/realtime_editing_module.dart';
import 'package:butlery/models/recipe_unified.dart';
import '../../../../../test_support/base_unit_test.dart';
import '../../../../../infrastructure/di/test_service_locator.dart';
import '../../../../../infrastructure/builders/recipe_builder.dart';
import '../../../../../infrastructure/mocks/production_mocks.dart';
import 'package:butlery/core/providers/application_provider.dart'
    as app_provider;

void main() {
  group('RealtimeEditingModule', () {
    late MockUnifiedRecipeService mockParentService;
    late MockRealtimeSyncService mockRealtimeSyncService;
    late RealtimeEditingModule editingModule;
    late Recipe testRecipe;
    late Recipe collaborativeRecipe;

    setUpAll(() async {
      // Register fallback values for mocktail
      registerFallbackValue(<String, dynamic>{});
    });

    setUp(() async {
      await BaseUnitTest.setupUnit();
      await TestServiceLocator.initialize();

      // Create mocks
      mockParentService = MockUnifiedRecipeService();
      mockRealtimeSyncService = MockRealtimeSyncService();

      // Initialize production ServiceLocator with MockDIContainer
      app_provider.ServiceLocator.reset();
      app_provider.ServiceLocator.initialize(MockDIContainer());

      // Create test data
      testRecipe = RecipeBuilder()
          .withId('recipe_1')
          .withTitle('Test Recipe')
          .withCreatedBy('user_123')
          .build();

      collaborativeRecipe = RecipeBuilder()
          .withId('recipe_2')
          .withTitle('Collaborative Recipe')
          .withCreatedBy('user_123')
          .asCollaborative()
          .build();

      // Configure mock services using centralized mock methods
      mockParentService.setRecipeState(
        currentUserId: 'user_123',
        recipes: [testRecipe, collaborativeRecipe],
      );

      mockRealtimeSyncService.setConnectionState(true);

      // Create editing module instance
      editingModule = RealtimeEditingModule(
        getCurrentUserId: () => mockParentService.currentUserId,
        getCurrentUserDisplayName: () =>
            mockParentService.currentUserDisplayName,
        getRecipes: () => mockParentService.recipes,
        updateRecipeContent: mockParentService.updateRecipeContent,
        realtimeSyncService: mockRealtimeSyncService,
      );
    });

    tearDown(() async {
      BaseUnitTest.resetMocks();
      await TestServiceLocator.reset();
    });

    tearDownAll(() async {
      // Cleanup if needed
    });

    group('Editing Session Management', () {
      test('should start realtime editing session', () async {
        // Act — recipe_2 is the collaborative fixture; production guards
        // realtime editing behind `recipe.isCollaborative`. Calling against
        // recipe_1 (personal) would correctly return false.
        final result = await editingModule.startRealtimeEditing('recipe_2');

        // Assert
        expect(result, isTrue);
      });

      test('should not start editing without proper permissions', () async {
        // Arrange
        mockParentService.setRecipeState(
          currentUserId: 'other_user',
          recipes: [testRecipe],
        );

        // Act
        final result = await editingModule.startRealtimeEditing('recipe_1');

        // Assert
        expect(result, isFalse);
      });

      test('should not start editing when recipe not found', () async {
        // Act
        final result = await editingModule.startRealtimeEditing('nonexistent');

        // Assert
        expect(result, isFalse);
      });

      test('should not start editing without realtime service', () async {
        // Arrange
        editingModule = RealtimeEditingModule(
          getCurrentUserId: () => mockParentService.currentUserId,
          getCurrentUserDisplayName: () =>
              mockParentService.currentUserDisplayName,
          getRecipes: () => mockParentService.recipes,
          updateRecipeContent: mockParentService.updateRecipeContent,
        );

        // Act
        final result = await editingModule.startRealtimeEditing('recipe_1');

        // Assert
        expect(result, isFalse);
      });

      test('should stop realtime editing session', () async {
        // Arrange
        await editingModule.startRealtimeEditing('recipe_1');

        // Act
        final result = await editingModule.stopRealtimeEditing('recipe_1');

        // Assert
        expect(result, isTrue);
      });

      test('should check if recipe is in realtime editing mode', () {
        // Act
        final isEditing = editingModule.isInRealtimeEditingMode('recipe_2');

        // Assert
        expect(isEditing, isTrue); // Collaborative recipe
      });

      test('should report non-collaborative recipe not in editing mode', () {
        // Act
        final isEditing = editingModule.isInRealtimeEditingMode('recipe_1');

        // Assert
        expect(isEditing, isFalse);
      });
    });

    group('Realtime Editing Operations', () {
      test('should make realtime edit successfully', () async {
        // Arrange
        final changes = {'title': 'Updated Title'};

        // Act
        final result = await editingModule.makeRealtimeEdit(
          recipeId: 'recipe_1',
          changes: changes,
          editDescription: 'Updated title',
        );

        // Assert
        expect(result, isTrue);
      });

      test(
        'should fall back to regular edit without realtime service',
        () async {
          // Arrange
          editingModule = RealtimeEditingModule(
            getCurrentUserId: () => mockParentService.currentUserId,
            getCurrentUserDisplayName: () =>
                mockParentService.currentUserDisplayName,
            getRecipes: () => mockParentService.recipes,
            updateRecipeContent: mockParentService.updateRecipeContent,
          );
          // Stub the underlying update to succeed; without this mocktail
          // returns the default (false) and the fallback path appears broken.
          when(
            () => mockParentService.updateRecipeContent(
              recipeId: any(named: 'recipeId'),
              title: any(named: 'title'),
              description: any(named: 'description'),
              ingredients: any(named: 'ingredients'),
              instructions: any(named: 'instructions'),
              imageUrls: any(named: 'imageUrls'),
              mealType: any(named: 'mealType'),
              portions: any(named: 'portions'),
              timeMinutes: any(named: 'timeMinutes'),
              rating: any(named: 'rating'),
              personalTagIds: any(named: 'personalTagIds'),
              sourceUrl: any(named: 'sourceUrl'),
            ),
          ).thenAnswer((_) async => true);
          final changes = {'title': 'Updated Title'};

          // Act
          final result = await editingModule.makeRealtimeEdit(
            recipeId: 'recipe_1',
            changes: changes,
          );

          // Assert
          expect(result, isTrue);
        },
      );
    });
  });
}

// Using centralized mocks from production_mocks.dart:
// MockUnifiedRecipeService, MockRealtimeSyncService
