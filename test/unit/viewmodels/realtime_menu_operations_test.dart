// test/unit/viewmodels/realtime_menu_operations_test.dart

import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:butlery/viewmodels/realtime_menu/realtime_menu_operations.dart';

import '../../infrastructure/di/test_service_locator.dart';
import '../../infrastructure/factories/recipe_factory.dart';
import '../../infrastructure/mocks/production_mocks.dart';
import '../../infrastructure/factories/mock_factory.dart';
import 'package:butlery/core/di/di_container.dart';
import 'package:butlery/core/providers/application_provider.dart'
    as prod_locator;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('RealtimeMenuOperations - Ultrathink Enhanced Tests', () {
    late RealtimeMenuOperations operations;
    late MockRealtimeMenuService mockMenuService;
    late MockOptimisticUpdateManager mockOptimisticManager;

    // Test data
    const testMenuId = 'menu_123';
    const testCategoryName = 'Middag';
    const testFromCategory = 'Frukost';
    const testToCategory = 'Middag';

    final testRecipe = RecipeFactory.build(
      id: 'recipe_123',
      title: 'Köttbullar med potatismos',
      ingredients: ['500g köttfärs', '3 ägg', '1 dl ströbröd'],
      instructions: ['Blanda ingredienserna', 'Forma bullar', 'Stek i panna'],
      mealType: 'Middag',
      portions: 4,
      timeMinutes: 30,
    );

    final testRecipe2 = RecipeFactory.build(
      id: 'recipe_456',
      title: 'Pannkakor',
      ingredients: ['3 ägg', '3 dl mjöl', '3 dl mjölk'],
      instructions: ['Vispa ihop smeten', 'Stek tunna pannkakor'],
      mealType: 'Frukost',
      portions: 4,
      timeMinutes: 20,
    );

    final testRecipes = [testRecipe, testRecipe2];
    final testMultipleRecipes = [testRecipe, testRecipe2];

    setUpAll(() async {
      await TestServiceLocator.initialize();
      registerFallbackValue(testRecipe);
      registerFallbackValue(testRecipes);
    });

    setUp(() {
      // ULTRATHINK FIX: Bridge production ServiceLocator to test mocks
      // This solves "ServiceLocator not initialized" errors when production code
      // calls ServiceLocator.get() but only TestServiceLocator was initialized
      final productionContainer = DIContainer();
      prod_locator.ServiceLocator.initialize(productionContainer);

      // Create mocks using centralized versions
      mockMenuService = MockFactory.createRealtimeMenuService();
      mockOptimisticManager = MockFactory.createOptimisticUpdateManager();

      // Configure default optimistic manager behavior
      when(() => mockOptimisticManager.applyChange(any(), any(), any()))
          .thenReturn(null);
      when(() => mockOptimisticManager.rollback()).thenReturn(null);
      when(() => mockOptimisticManager.clear()).thenReturn(null);
      when(() => mockOptimisticManager.hasChanges).thenReturn(false);
      when(() => mockOptimisticManager.allChanges).thenReturn({});
      when(() => mockOptimisticManager.applyToMenu(any())).thenReturn({});

      // Configure default menu service behavior - success
      when(() => mockMenuService.addRecipeToCategory(
            resourceId: any(named: 'resourceId'),
            categoryName: any(named: 'categoryName'),
            recipe: any(named: 'recipe'),
          )).thenAnswer((_) async {});

      when(() => mockMenuService.removeRecipeFromCategory(
            resourceId: any(named: 'resourceId'),
            categoryName: any(named: 'categoryName'),
            recipeIndex: any(named: 'recipeIndex'),
          )).thenAnswer((_) async {});

      when(() => mockMenuService.moveRecipeBetweenCategories(
            resourceId: any(named: 'resourceId'),
            fromCategory: any(named: 'fromCategory'),
            fromIndex: any(named: 'fromIndex'),
            toCategory: any(named: 'toCategory'),
            toIndex: any(named: 'toIndex'),
          )).thenAnswer((_) async {});

      when(() => mockMenuService.clearCategory(
            resourceId: any(named: 'resourceId'),
            categoryName: any(named: 'categoryName'),
          )).thenAnswer((_) async {});

      operations = RealtimeMenuOperations(
        menuService: mockMenuService,
        optimisticManager: mockOptimisticManager,
      );
    });

    tearDown(() async {
      await TestServiceLocator.reset();
    });

    tearDownAll(() async {
      await TestServiceLocator.reset();
    });

    group('Recipe Operations - Add Recipe', () {
      test('should add recipe to category successfully', () async {
        // Act
        await operations.addRecipeToCategory(
          menuId: testMenuId,
          categoryName: testCategoryName,
          recipe: testRecipe,
        );

        // Assert
        verify(() => mockOptimisticManager.applyChange(
              testCategoryName,
              any(),
            )).called(1);

        verify(() => mockMenuService.addRecipeToCategory(
              resourceId: testMenuId,
              categoryName: testCategoryName,
              recipe: testRecipe,
            )).called(1);

        verifyNever(() => mockOptimisticManager.rollback());
      });

      test('should apply optimistic update before service call', () async {
        // Arrange
        bool optimisticUpdateCalled = false;
        bool serviceCalled = false;
        final callOrder = <String>[];

        when(() => mockOptimisticManager.applyChange(any(), any(), any()))
            .thenAnswer((_) {
          optimisticUpdateCalled = true;
          callOrder.add('optimistic');
        });

        when(() => mockMenuService.addRecipeToCategory(
              resourceId: any(named: 'resourceId'),
              categoryName: any(named: 'categoryName'),
              recipe: any(named: 'recipe'),
            )).thenAnswer((_) async {
          serviceCalled = true;
          callOrder.add('service');
        });

        // Act
        await operations.addRecipeToCategory(
          menuId: testMenuId,
          categoryName: testCategoryName,
          recipe: testRecipe,
        );

        // Assert
        expect(optimisticUpdateCalled, isTrue);
        expect(serviceCalled, isTrue);
        expect(callOrder, equals(['optimistic', 'service']));
      });

      test('should rollback on service error and rethrow', () async {
        // Arrange
        final error = Exception('Service error');
        when(() => mockMenuService.addRecipeToCategory(
              resourceId: any(named: 'resourceId'),
              categoryName: any(named: 'categoryName'),
              recipe: any(named: 'recipe'),
            )).thenThrow(error);

        // Act & Assert
        expect(
          () => operations.addRecipeToCategory(
            menuId: testMenuId,
            categoryName: testCategoryName,
            recipe: testRecipe,
          ),
          throwsA(isA<Exception>()),
        );

        verify(() => mockOptimisticManager.rollback()).called(1);
      });

      test('should handle empty category name', () async {
        // Act & Assert - should not crash
        await operations.addRecipeToCategory(
          menuId: testMenuId,
          categoryName: '',
          recipe: testRecipe,
        );

        verify(() => mockMenuService.addRecipeToCategory(
              resourceId: testMenuId,
              categoryName: '',
              recipe: testRecipe,
            )).called(1);
      });

      test('should handle recipe with empty title', () async {
        // Arrange
        final recipeWithEmptyTitle = RecipeFactory.build(
          id: 'recipe_empty',
          title: '',
        );

        // Act
        await operations.addRecipeToCategory(
          menuId: testMenuId,
          categoryName: testCategoryName,
          recipe: recipeWithEmptyTitle,
        );

        // Assert - should still attempt to add
        verify(() => mockMenuService.addRecipeToCategory(
              resourceId: testMenuId,
              categoryName: testCategoryName,
              recipe: recipeWithEmptyTitle,
            )).called(1);
      });
    });

    group('Recipe Operations - Remove Recipe', () {
      test('should remove recipe from category successfully', () async {
        // Act
        await operations.removeRecipeFromCategory(
          menuId: testMenuId,
          categoryName: testCategoryName,
          recipeIndex: 0,
          currentRecipes: testRecipes,
        );

        // Assert
        verify(() => mockOptimisticManager.applyChange(
              testCategoryName,
              any(),
              testRecipes,
            )).called(1);

        verify(() => mockMenuService.removeRecipeFromCategory(
              resourceId: testMenuId,
              categoryName: testCategoryName,
              recipeIndex: 0,
            )).called(1);
      });

      test('should throw on invalid recipe index (negative)', () async {
        // Act & Assert
        expect(
          () => operations.removeRecipeFromCategory(
            menuId: testMenuId,
            categoryName: testCategoryName,
            recipeIndex: -1,
            currentRecipes: testRecipes,
          ),
          throwsA(isA<ArgumentError>()),
        );

        verifyNever(
            () => mockOptimisticManager.applyChange(any(), any(), any()));
        verifyNever(() => mockMenuService.removeRecipeFromCategory(
              resourceId: any(named: 'resourceId'),
              categoryName: any(named: 'categoryName'),
              recipeIndex: any(named: 'recipeIndex'),
            ));
      });

      test('should throw on invalid recipe index (too high)', () async {
        // Act & Assert
        expect(
          () => operations.removeRecipeFromCategory(
            menuId: testMenuId,
            categoryName: testCategoryName,
            recipeIndex: 10,
            currentRecipes: testRecipes,
          ),
          throwsA(isA<ArgumentError>()),
        );
      });

      test('should rollback on service error', () async {
        // Arrange
        final error = Exception('Remove failed');
        when(() => mockMenuService.removeRecipeFromCategory(
              resourceId: any(named: 'resourceId'),
              categoryName: any(named: 'categoryName'),
              recipeIndex: any(named: 'recipeIndex'),
            )).thenThrow(error);

        // Act & Assert
        expect(
          () => operations.removeRecipeFromCategory(
            menuId: testMenuId,
            categoryName: testCategoryName,
            recipeIndex: 0,
            currentRecipes: testRecipes,
          ),
          throwsA(isA<Exception>()),
        );

        verify(() => mockOptimisticManager.rollback()).called(1);
      });

      test('should handle empty recipes list', () async {
        // Act & Assert
        expect(
          () => operations.removeRecipeFromCategory(
            menuId: testMenuId,
            categoryName: testCategoryName,
            recipeIndex: 0,
            currentRecipes: [],
          ),
          throwsA(isA<ArgumentError>()),
        );
      });
    });

    group('Recipe Operations - Move Between Categories', () {
      test('should move recipe between categories successfully', () async {
        // Arrange
        final fromRecipes = [testRecipe];
        final toRecipes = [testRecipe2];

        // Act
        await operations.moveRecipeBetweenCategories(
          menuId: testMenuId,
          fromCategory: testFromCategory,
          fromIndex: 0,
          toCategory: testToCategory,
          fromRecipes: fromRecipes,
          toRecipes: toRecipes,
        );

        // Assert - should apply optimistic updates to both categories
        verify(() => mockOptimisticManager.applyChange(
              testFromCategory,
              any(),
              fromRecipes,
            )).called(1);

        verify(() => mockOptimisticManager.applyChange(
              testToCategory,
              any(),
              toRecipes,
            )).called(1);

        verify(() => mockMenuService.moveRecipeBetweenCategories(
              resourceId: testMenuId,
              fromCategory: testFromCategory,
              fromIndex: 0,
              toCategory: testToCategory,
              toIndex: null,
            )).called(1);
      });

      test('should move recipe with specific toIndex', () async {
        // Arrange
        final fromRecipes = [testRecipe];
        final toRecipes = [testRecipe2];

        // Act
        await operations.moveRecipeBetweenCategories(
          menuId: testMenuId,
          fromCategory: testFromCategory,
          fromIndex: 0,
          toCategory: testToCategory,
          fromRecipes: fromRecipes,
          toRecipes: toRecipes,
          toIndex: 1,
        );

        // Assert
        verify(() => mockMenuService.moveRecipeBetweenCategories(
              resourceId: testMenuId,
              fromCategory: testFromCategory,
              fromIndex: 0,
              toCategory: testToCategory,
              toIndex: 1,
            )).called(1);
      });

      test('should throw on invalid fromIndex', () async {
        // Act & Assert
        expect(
          () => operations.moveRecipeBetweenCategories(
            menuId: testMenuId,
            fromCategory: testFromCategory,
            fromIndex: -1,
            toCategory: testToCategory,
            fromRecipes: testRecipes,
            toRecipes: [],
          ),
          throwsA(isA<ArgumentError>()),
        );
      });

      test('should rollback both categories on service error', () async {
        // Arrange
        final error = Exception('Move failed');
        when(() => mockMenuService.moveRecipeBetweenCategories(
              resourceId: any(named: 'resourceId'),
              fromCategory: any(named: 'fromCategory'),
              fromIndex: any(named: 'fromIndex'),
              toCategory: any(named: 'toCategory'),
              toIndex: any(named: 'toIndex'),
            )).thenThrow(error);

        // Act & Assert
        expect(
          () => operations.moveRecipeBetweenCategories(
            menuId: testMenuId,
            fromCategory: testFromCategory,
            fromIndex: 0,
            toCategory: testToCategory,
            fromRecipes: testRecipes,
            toRecipes: [],
          ),
          throwsA(isA<Exception>()),
        );

        verify(() => mockOptimisticManager.rollback()).called(1);
      });
    });

    group('Recipe Operations - Reorder Within Category', () {
      test('should reorder recipes within category successfully', () async {
        // Act
        await operations.reorderRecipesInCategory(
          menuId: testMenuId,
          categoryName: testCategoryName,
          fromIndex: 0,
          toIndex: 1,
          currentRecipes: testRecipes,
        );

        // Assert
        verify(() => mockOptimisticManager.applyChange(
              testCategoryName,
              any(),
              testRecipes,
            )).called(1);

        verify(() => mockMenuService.moveRecipeBetweenCategories(
              resourceId: testMenuId,
              fromCategory: testCategoryName,
              fromIndex: 0,
              toCategory: testCategoryName,
              toIndex: 1,
            )).called(1);
      });

      test('should skip reorder when fromIndex equals toIndex', () async {
        // Act
        await operations.reorderRecipesInCategory(
          menuId: testMenuId,
          categoryName: testCategoryName,
          fromIndex: 1,
          toIndex: 1,
          currentRecipes: testRecipes,
        );

        // Assert - no operations should be called
        verifyNever(
            () => mockOptimisticManager.applyChange(any(), any(), any()));
        verifyNever(() => mockMenuService.moveRecipeBetweenCategories(
              resourceId: any(named: 'resourceId'),
              fromCategory: any(named: 'fromCategory'),
              fromIndex: any(named: 'fromIndex'),
              toCategory: any(named: 'toCategory'),
              toIndex: any(named: 'toIndex'),
            ));
      });

      test('should throw on invalid fromIndex for reorder', () async {
        // Act & Assert
        expect(
          () => operations.reorderRecipesInCategory(
            menuId: testMenuId,
            categoryName: testCategoryName,
            fromIndex: -1,
            toIndex: 1,
            currentRecipes: testRecipes,
          ),
          throwsA(isA<ArgumentError>()),
        );
      });

      test('should throw on invalid toIndex for reorder', () async {
        // Act & Assert
        expect(
          () => operations.reorderRecipesInCategory(
            menuId: testMenuId,
            categoryName: testCategoryName,
            fromIndex: 0,
            toIndex: 10,
            currentRecipes: testRecipes,
          ),
          throwsA(isA<ArgumentError>()),
        );
      });
    });

    group('Category Operations - Clear Category', () {
      test('should clear category successfully', () async {
        // Act
        await operations.clearCategory(
          menuId: testMenuId,
          categoryName: testCategoryName,
          currentRecipes: testRecipes,
        );

        // Assert
        verify(() => mockOptimisticManager.applyChange(
              testCategoryName,
              any(),
              testRecipes,
            )).called(1);

        verify(() => mockMenuService.clearCategory(
              resourceId: testMenuId,
              categoryName: testCategoryName,
            )).called(1);
      });

      test('should rollback on clear category error', () async {
        // Arrange
        final error = Exception('Clear failed');
        when(() => mockMenuService.clearCategory(
              resourceId: any(named: 'resourceId'),
              categoryName: any(named: 'categoryName'),
            )).thenThrow(error);

        // Act & Assert
        expect(
          () => operations.clearCategory(
            menuId: testMenuId,
            categoryName: testCategoryName,
            currentRecipes: testRecipes,
          ),
          throwsA(isA<Exception>()),
        );

        verify(() => mockOptimisticManager.rollback()).called(1);
      });

      test('should handle empty category name for clear', () async {
        // Act
        await operations.clearCategory(
          menuId: testMenuId,
          categoryName: '',
          currentRecipes: testRecipes,
        );

        // Assert - should still call service
        verify(() => mockMenuService.clearCategory(
              resourceId: testMenuId,
              categoryName: '',
            )).called(1);
      });
    });

    group('Category Operations - Regenerate Category', () {
      test('should throw UnimplementedError for regenerate category', () async {
        // Act & Assert
        expect(
          () => operations.regenerateCategory(
            menuId: testMenuId,
            categoryName: testCategoryName,
          ),
          throwsA(isA<UnimplementedError>()),
        );
      });

      test('should include proper error message for regenerate', () async {
        // Act & Assert
        try {
          await operations.regenerateCategory(
            menuId: testMenuId,
            categoryName: testCategoryName,
          );
          fail('Should have thrown UnimplementedError');
        } catch (e) {
          expect(e, isA<UnimplementedError>());
          expect(e.toString(), contains('AI menu regeneration feature'));
        }
      });
    });

    group('Batch Operations - Multiple Recipes', () {
      test('should add multiple recipes to category successfully', () async {
        // Act
        await operations.addMultipleRecipesToCategory(
          menuId: testMenuId,
          categoryName: testCategoryName,
          recipes: testMultipleRecipes,
        );

        // Assert
        verify(() => mockOptimisticManager.applyChange(
              testCategoryName,
              any(),
            )).called(1);

        // Should call add for each recipe
        verify(() => mockMenuService.addRecipeToCategory(
              resourceId: testMenuId,
              categoryName: testCategoryName,
              recipe: testRecipe,
            )).called(1);

        verify(() => mockMenuService.addRecipeToCategory(
              resourceId: testMenuId,
              categoryName: testCategoryName,
              recipe: testRecipe2,
            )).called(1);
      });

      test('should skip adding empty recipes list', () async {
        // Arrange - create fresh isolated mocks to avoid contamination
        final isolatedMenuService = MockRealtimeMenuService();
        final isolatedOptimisticManager = MockOptimisticUpdateManager();

        // Configure default behavior
        when(() => isolatedOptimisticManager.applyChange(any(), any(), any()))
            .thenReturn(null);
        when(() => isolatedOptimisticManager.rollback()).thenReturn(null);

        final isolatedOperations = RealtimeMenuOperations(
          menuService: isolatedMenuService,
          optimisticManager: isolatedOptimisticManager,
        );

        // Act
        await isolatedOperations.addMultipleRecipesToCategory(
          menuId: testMenuId,
          categoryName: testCategoryName,
          recipes: [],
        );

        // Assert - no operations should be called due to early return
        verifyNever(() => isolatedOptimisticManager.applyChange(any(), any()));
        verifyNever(
            () => isolatedOptimisticManager.applyChange(any(), any(), any()));
        verifyNever(() => isolatedMenuService.addRecipeToCategory(
              resourceId: any(named: 'resourceId'),
              categoryName: any(named: 'categoryName'),
              recipe: any(named: 'recipe'),
            ));
      });

      test('should rollback on partial failure in multiple add', () async {
        // Arrange - second recipe fails
        when(() => mockMenuService.addRecipeToCategory(
              resourceId: testMenuId,
              categoryName: testCategoryName,
              recipe: testRecipe,
            )).thenAnswer((_) async {});

        when(() => mockMenuService.addRecipeToCategory(
              resourceId: testMenuId,
              categoryName: testCategoryName,
              recipe: testRecipe2,
            )).thenThrow(Exception('Second recipe failed'));

        // Act & Assert
        expect(
          () => operations.addMultipleRecipesToCategory(
            menuId: testMenuId,
            categoryName: testCategoryName,
            recipes: testMultipleRecipes,
          ),
          throwsA(isA<Exception>()),
        );

        verify(() => mockOptimisticManager.rollback()).called(1);
      });

      test('should remove multiple recipes by indices', () async {
        // Arrange
        final indices = [1, 0]; // Reversed order for proper removal

        // Act
        await operations.removeMultipleRecipesFromCategory(
          menuId: testMenuId,
          categoryName: testCategoryName,
          indices: indices,
          currentRecipes: testRecipes,
        );

        // Assert - should remove in descending order
        verify(() => mockMenuService.removeRecipeFromCategory(
              resourceId: testMenuId,
              categoryName: testCategoryName,
              recipeIndex: 1, // Higher index first
            )).called(1);

        verify(() => mockMenuService.removeRecipeFromCategory(
              resourceId: testMenuId,
              categoryName: testCategoryName,
              recipeIndex: 0,
            )).called(1);
      });

      test('should skip removing empty indices list', () async {
        // Arrange - create fresh isolated mocks to avoid contamination
        final isolatedMenuService = MockRealtimeMenuService();
        final isolatedOptimisticManager = MockOptimisticUpdateManager();

        // Configure default behavior
        when(() => isolatedOptimisticManager.applyChange(any(), any(), any()))
            .thenReturn(null);
        when(() => isolatedOptimisticManager.rollback()).thenReturn(null);

        final isolatedOperations = RealtimeMenuOperations(
          menuService: isolatedMenuService,
          optimisticManager: isolatedOptimisticManager,
        );

        // Act
        await isolatedOperations.removeMultipleRecipesFromCategory(
          menuId: testMenuId,
          categoryName: testCategoryName,
          indices: [],
          currentRecipes: testRecipes,
        );

        // Assert - no operations should be called due to early return
        verifyNever(() => isolatedOptimisticManager.applyChange(any(), any()));
        verifyNever(
            () => isolatedOptimisticManager.applyChange(any(), any(), any()));
        verifyNever(() => isolatedMenuService.removeRecipeFromCategory(
              resourceId: any(named: 'resourceId'),
              categoryName: any(named: 'categoryName'),
              recipeIndex: any(named: 'recipeIndex'),
            ));
      });

      test('should throw on invalid indices in multiple remove', () async {
        // Act & Assert
        expect(
          () => operations.removeMultipleRecipesFromCategory(
            menuId: testMenuId,
            categoryName: testCategoryName,
            indices: [0, 10], // 10 is invalid
            currentRecipes: testRecipes,
          ),
          throwsA(isA<ArgumentError>()),
        );
      });
    });

    group('Optimistic Updates Management', () {
      test('should apply optimistic changes to menu snapshot', () {
        // Arrange
        final baseMenu = {
          'Middag': [testRecipe]
        };
        final optimisticMenu = {
          'Middag': [testRecipe, testRecipe2]
        };

        when(() => mockOptimisticManager.applyToMenu(baseMenu))
            .thenReturn(optimisticMenu);

        // Act
        final result = operations.applyOptimisticChanges(baseMenu);

        // Assert
        expect(result, equals(optimisticMenu));
        verify(() => mockOptimisticManager.applyToMenu(baseMenu)).called(1);
      });

      test('should check for optimistic changes', () {
        // Arrange
        when(() => mockOptimisticManager.hasChanges).thenReturn(true);

        // Act
        final hasChanges = operations.hasOptimisticChanges;

        // Assert
        expect(hasChanges, isTrue);
      });

      test('should get all optimistic changes', () {
        // Arrange
        final changes = {
          'Middag': [testRecipe]
        };
        when(() => mockOptimisticManager.allChanges).thenReturn(changes);

        // Act
        final result = operations.optimisticChanges;

        // Assert
        expect(result, equals(changes));
      });

      test('should clear optimistic changes', () {
        // Act
        operations.clearOptimisticChanges();

        // Assert
        verify(() => mockOptimisticManager.clear()).called(1);
      });

      test('should rollback optimistic changes', () {
        // Act
        operations.rollbackOptimisticChanges();

        // Assert
        verify(() => mockOptimisticManager.rollback()).called(1);
      });
    });

    group('Validation Methods', () {
      test('should validate recipe for category - valid recipe', () {
        // Act
        final isValid =
            operations.validateRecipeForCategory(testRecipe, testCategoryName);

        // Assert
        expect(isValid, isTrue);
      });

      test('should validate recipe for category - empty title', () {
        // Arrange
        final recipeWithEmptyTitle = RecipeFactory.build(
          id: 'empty_title',
          title: '',
        );

        // Act
        final isValid = operations.validateRecipeForCategory(
          recipeWithEmptyTitle,
          testCategoryName,
        );

        // Assert
        expect(isValid, isFalse);
      });

      test('should validate category name - valid name', () {
        // Act
        final isValid = operations.validateCategoryName('Middag');

        // Assert
        expect(isValid, isTrue);
      });

      test('should validate category name - empty name', () {
        // Act
        final isValid = operations.validateCategoryName('');

        // Assert
        expect(isValid, isFalse);
      });

      test('should validate category name - whitespace only', () {
        // Act
        final isValid = operations.validateCategoryName('   ');

        // Assert
        expect(isValid, isFalse);
      });
    });

    group('Utility Methods', () {
      test('should get recipe count with optimistic changes', () {
        // Arrange
        final baseRecipes = [testRecipe];
        final optimisticChanges = {
          testCategoryName: [testRecipe, testRecipe2]
        };

        when(() => mockOptimisticManager.hasChanges).thenReturn(true);
        when(() => mockOptimisticManager.allChanges)
            .thenReturn(optimisticChanges);

        // Act
        final count =
            operations.getRecipeCountForCategory(testCategoryName, baseRecipes);

        // Assert
        expect(count, equals(2));
      });

      test('should get recipe count without optimistic changes', () {
        // Arrange
        final baseRecipes = [testRecipe];

        when(() => mockOptimisticManager.hasChanges).thenReturn(false);

        // Act
        final count =
            operations.getRecipeCountForCategory(testCategoryName, baseRecipes);

        // Assert
        expect(count, equals(1));
      });

      test('should get recipes with optimistic changes', () {
        // Arrange
        final baseRecipes = [testRecipe];
        final optimisticRecipes = [testRecipe, testRecipe2];
        final optimisticChanges = {testCategoryName: optimisticRecipes};

        when(() => mockOptimisticManager.hasChanges).thenReturn(true);
        when(() => mockOptimisticManager.allChanges)
            .thenReturn(optimisticChanges);

        // Act
        final recipes =
            operations.getRecipesForCategory(testCategoryName, baseRecipes);

        // Assert
        expect(recipes, equals(optimisticRecipes));
      });

      test('should get recipes without optimistic changes', () {
        // Arrange
        final baseRecipes = [testRecipe];

        when(() => mockOptimisticManager.hasChanges).thenReturn(false);

        // Act
        final recipes =
            operations.getRecipesForCategory(testCategoryName, baseRecipes);

        // Assert
        expect(recipes, equals(baseRecipes));
      });
    });

    group('Edge Cases and Integration Scenarios', () {
      test('should handle concurrent operations gracefully', () async {
        // Arrange - simulate concurrent add operations
        final futures = <Future>[];

        // Act - start multiple operations simultaneously
        for (int i = 0; i < 3; i++) {
          futures.add(operations.addRecipeToCategory(
            menuId: testMenuId,
            categoryName: testCategoryName,
            recipe: RecipeFactory.build(id: 'recipe_$i'),
          ));
        }

        await Future.wait(futures);

        // Assert - all operations should complete
        verify(() => mockMenuService.addRecipeToCategory(
              resourceId: testMenuId,
              categoryName: testCategoryName,
              recipe: any(named: 'recipe'),
            )).called(3);
      });

      test('should handle null and empty values safely', () async {
        // Test various edge cases without crashing
        expect(operations.validateCategoryName(''), isFalse);
        expect(
            operations.validateRecipeForCategory(
              RecipeFactory.build(title: ''),
              'test',
            ),
            isFalse);

        // Test utility methods with empty data
        expect(operations.getRecipeCountForCategory('test', []), equals(0));
        expect(operations.getRecipesForCategory('test', []), isEmpty);

        // Validation methods handle edge cases properly
        expect(operations.validateCategoryName('   '), isFalse);
        expect(operations.validateCategoryName('Valid Category'), isTrue);
      });

      test('should maintain operation order consistency', () async {
        // Arrange
        final operationOrder = <String>[];

        when(() => mockOptimisticManager.applyChange(any(), any(), any()))
            .thenAnswer((_) {
          operationOrder.add('optimistic');
        });

        when(() => mockMenuService.addRecipeToCategory(
              resourceId: any(named: 'resourceId'),
              categoryName: any(named: 'categoryName'),
              recipe: any(named: 'recipe'),
            )).thenAnswer((_) async {
          operationOrder.add('service');
        });

        // Act
        await operations.addRecipeToCategory(
          menuId: testMenuId,
          categoryName: testCategoryName,
          recipe: testRecipe,
        );

        // Assert - optimistic update should always come before service call
        expect(operationOrder, equals(['optimistic', 'service']));
      });

      test('should handle service timeout scenarios', () async {
        // Arrange - simulate timeout
        when(() => mockMenuService.addRecipeToCategory(
                  resourceId: any(named: 'resourceId'),
                  categoryName: any(named: 'categoryName'),
                  recipe: any(named: 'recipe'),
                ))
            .thenThrow(
                TimeoutException('Operation timed out', Duration(seconds: 30)));

        // Act & Assert
        expect(
          () => operations.addRecipeToCategory(
            menuId: testMenuId,
            categoryName: testCategoryName,
            recipe: testRecipe,
          ),
          throwsA(isA<TimeoutException>()),
        );

        verify(() => mockOptimisticManager.rollback()).called(1);
      });
    });
  });
}
