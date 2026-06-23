// test/unit/viewmodels/realtime_menu_operations_test.dart

import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:butlery/viewmodels/realtime_menu/realtime_menu_operations.dart';
import 'package:butlery/services/realtime/realtime_menu_service.dart';
import 'package:butlery/viewmodels/realtime/optimistic_update_manager.dart';
import 'package:butlery/models/recipe_unified.dart';

import '../../infrastructure/di/test_service_locator.dart';
import '../../infrastructure/factories/recipe_factory.dart';
import 'package:butlery/core/di/di_container.dart';
import 'package:butlery/core/providers/application_provider.dart' as production;

// Local pure-Mock classes — the centralized mocks have concrete @override
// methods that prevent mocktail when() from intercepting calls.
class _MockMenuService extends Mock implements RealtimeMenuService {}

class _MockOptimisticManager extends Mock implements OptimisticUpdateManager {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('RealtimeMenuOperations', () {
    late RealtimeMenuOperations operations;
    late _MockMenuService mockMenuService;
    late _MockOptimisticManager mockOptimistic;

    const testMenuId = 'menu_123';
    const testCategory = 'Middag';

    final testRecipe = RecipeFactory.build(
      id: 'recipe_1',
      title: 'Köttbullar',
      mealType: 'Middag',
    );
    final testRecipe2 = RecipeFactory.build(
      id: 'recipe_2',
      title: 'Pannkakor',
      mealType: 'Frukost',
    );

    setUpAll(() async {
      await TestServiceLocator.initialize();
      production.ServiceLocator.initialize(DIContainer());
      registerFallbackValue(testRecipe);
      registerFallbackValue(<Recipe>[]);
    });

    setUp(() {
      mockMenuService = _MockMenuService();
      mockOptimistic = _MockOptimisticManager();

      // Default stubs
      when(
        () => mockOptimistic.applyChange(any(), any(), any()),
      ).thenReturn(null);
      when(() => mockOptimistic.applyChange(any(), any())).thenReturn(null);
      when(() => mockOptimistic.rollback()).thenReturn(null);
      when(() => mockOptimistic.clear()).thenReturn(null);
      when(() => mockOptimistic.hasChanges).thenReturn(false);
      when(() => mockOptimistic.allChanges).thenReturn({});
      when(() => mockOptimistic.applyToMenu(any())).thenReturn({});

      when(
        () => mockMenuService.addRecipeToCategory(
          resourceId: any(named: 'resourceId'),
          categoryName: any(named: 'categoryName'),
          recipe: any(named: 'recipe'),
        ),
      ).thenAnswer((_) async {});

      when(
        () => mockMenuService.removeRecipeFromCategory(
          resourceId: any(named: 'resourceId'),
          categoryName: any(named: 'categoryName'),
          recipeIndex: any(named: 'recipeIndex'),
        ),
      ).thenAnswer((_) async {});

      when(
        () => mockMenuService.moveRecipeBetweenCategories(
          resourceId: any(named: 'resourceId'),
          fromCategory: any(named: 'fromCategory'),
          fromIndex: any(named: 'fromIndex'),
          toCategory: any(named: 'toCategory'),
          toIndex: any(named: 'toIndex'),
        ),
      ).thenAnswer((_) async {});

      when(
        () => mockMenuService.clearCategory(
          resourceId: any(named: 'resourceId'),
          categoryName: any(named: 'categoryName'),
        ),
      ).thenAnswer((_) async {});

      when(
        () => mockMenuService.updateWholeCategory(
          resourceId: any(named: 'resourceId'),
          categoryName: any(named: 'categoryName'),
          recipes: any(named: 'recipes'),
        ),
      ).thenAnswer((_) async {});

      operations = RealtimeMenuOperations(
        menuService: mockMenuService,
        optimisticManager: mockOptimistic,
      );
    });

    tearDown(() async {
      await TestServiceLocator.reset();
    });

    // -- Add Recipe ---------------------------------------------------------

    group('Add Recipe', () {
      test('should call optimistic update then service', () async {
        final order = <String>[];
        when(
          () => mockOptimistic.applyChange(any(), any()),
        ).thenAnswer((_) => order.add('optimistic'));
        when(
          () => mockMenuService.addRecipeToCategory(
            resourceId: any(named: 'resourceId'),
            categoryName: any(named: 'categoryName'),
            recipe: any(named: 'recipe'),
          ),
        ).thenAnswer((_) async => order.add('service'));

        await operations.addRecipeToCategory(
          menuId: testMenuId,
          categoryName: testCategory,
          recipe: testRecipe,
        );

        expect(order, equals(['optimistic', 'service']));
        verifyNever(() => mockOptimistic.rollback());
      });

      test('should rollback and rethrow on service error', () async {
        when(
          () => mockMenuService.addRecipeToCategory(
            resourceId: any(named: 'resourceId'),
            categoryName: any(named: 'categoryName'),
            recipe: any(named: 'recipe'),
          ),
        ).thenThrow(Exception('fail'));

        expect(
          () => operations.addRecipeToCategory(
            menuId: testMenuId,
            categoryName: testCategory,
            recipe: testRecipe,
          ),
          throwsA(isA<Exception>()),
        );

        verify(() => mockOptimistic.rollback()).called(1);
      });

      test('should handle empty category name', () async {
        await operations.addRecipeToCategory(
          menuId: testMenuId,
          categoryName: '',
          recipe: testRecipe,
        );

        verify(
          () => mockMenuService.addRecipeToCategory(
            resourceId: testMenuId,
            categoryName: '',
            recipe: testRecipe,
          ),
        ).called(1);
      });
    });

    // -- Remove Recipe ------------------------------------------------------

    group('Remove Recipe', () {
      test('should remove recipe and call service', () async {
        await operations.removeRecipeFromCategory(
          menuId: testMenuId,
          categoryName: testCategory,
          recipeIndex: 0,
          currentRecipes: [testRecipe, testRecipe2],
        );

        verify(
          () => mockOptimistic.applyChange(
            testCategory,
            any(),
            [testRecipe, testRecipe2],
          ),
        ).called(1);

        verify(
          () => mockMenuService.removeRecipeFromCategory(
            resourceId: testMenuId,
            categoryName: testCategory,
            recipeIndex: 0,
          ),
        ).called(1);
      });

      test('should throw ArgumentError on negative index', () {
        expect(
          () => operations.removeRecipeFromCategory(
            menuId: testMenuId,
            categoryName: testCategory,
            recipeIndex: -1,
            currentRecipes: [testRecipe],
          ),
          throwsA(isA<ArgumentError>()),
        );
      });

      test('should throw ArgumentError on index out of range', () {
        expect(
          () => operations.removeRecipeFromCategory(
            menuId: testMenuId,
            categoryName: testCategory,
            recipeIndex: 5,
            currentRecipes: [testRecipe],
          ),
          throwsA(isA<ArgumentError>()),
        );
      });

      test('should throw ArgumentError on empty list', () {
        expect(
          () => operations.removeRecipeFromCategory(
            menuId: testMenuId,
            categoryName: testCategory,
            recipeIndex: 0,
            currentRecipes: [],
          ),
          throwsA(isA<ArgumentError>()),
        );
      });

      test('should rollback on service error', () {
        when(
          () => mockMenuService.removeRecipeFromCategory(
            resourceId: any(named: 'resourceId'),
            categoryName: any(named: 'categoryName'),
            recipeIndex: any(named: 'recipeIndex'),
          ),
        ).thenThrow(Exception('fail'));

        expect(
          () => operations.removeRecipeFromCategory(
            menuId: testMenuId,
            categoryName: testCategory,
            recipeIndex: 0,
            currentRecipes: [testRecipe],
          ),
          throwsA(isA<Exception>()),
        );

        verify(() => mockOptimistic.rollback()).called(1);
      });
    });

    // -- Move Between Categories --------------------------------------------

    group('Move Between Categories', () {
      test(
        'should move recipe applying optimistic updates to both categories',
        () async {
          final from = [testRecipe];
          final to = [testRecipe2];

          await operations.moveRecipeBetweenCategories(
            menuId: testMenuId,
            fromCategory: 'Frukost',
            fromIndex: 0,
            toCategory: 'Middag',
            fromRecipes: from,
            toRecipes: to,
          );

          verify(
            () => mockOptimistic.applyChange('Frukost', any(), from),
          ).called(1);
          verify(
            () => mockOptimistic.applyChange('Middag', any(), to),
          ).called(1);
          verify(
            () => mockMenuService.moveRecipeBetweenCategories(
              resourceId: testMenuId,
              fromCategory: 'Frukost',
              fromIndex: 0,
              toCategory: 'Middag',
              toIndex: null,
            ),
          ).called(1);
        },
      );

      test('should pass toIndex when specified', () async {
        await operations.moveRecipeBetweenCategories(
          menuId: testMenuId,
          fromCategory: 'Frukost',
          fromIndex: 0,
          toCategory: 'Middag',
          fromRecipes: [testRecipe],
          toRecipes: [testRecipe2],
          toIndex: 1,
        );

        verify(
          () => mockMenuService.moveRecipeBetweenCategories(
            resourceId: testMenuId,
            fromCategory: 'Frukost',
            fromIndex: 0,
            toCategory: 'Middag',
            toIndex: 1,
          ),
        ).called(1);
      });

      test('should throw on invalid fromIndex', () {
        expect(
          () => operations.moveRecipeBetweenCategories(
            menuId: testMenuId,
            fromCategory: 'A',
            fromIndex: -1,
            toCategory: 'B',
            fromRecipes: [testRecipe],
            toRecipes: [],
          ),
          throwsA(isA<ArgumentError>()),
        );
      });

      test('should rollback on service error', () {
        when(
          () => mockMenuService.moveRecipeBetweenCategories(
            resourceId: any(named: 'resourceId'),
            fromCategory: any(named: 'fromCategory'),
            fromIndex: any(named: 'fromIndex'),
            toCategory: any(named: 'toCategory'),
            toIndex: any(named: 'toIndex'),
          ),
        ).thenThrow(Exception('fail'));

        expect(
          () => operations.moveRecipeBetweenCategories(
            menuId: testMenuId,
            fromCategory: 'A',
            fromIndex: 0,
            toCategory: 'B',
            fromRecipes: [testRecipe],
            toRecipes: [],
          ),
          throwsA(isA<Exception>()),
        );

        verify(() => mockOptimistic.rollback()).called(1);
      });
    });

    // -- Reorder Within Category --------------------------------------------

    group('Reorder Within Category', () {
      test(
        'should reorder via moveRecipeBetweenCategories (same category)',
        () async {
          await operations.reorderRecipesInCategory(
            menuId: testMenuId,
            categoryName: testCategory,
            fromIndex: 0,
            toIndex: 1,
            currentRecipes: [testRecipe, testRecipe2],
          );

          verify(
            () => mockMenuService.moveRecipeBetweenCategories(
              resourceId: testMenuId,
              fromCategory: testCategory,
              fromIndex: 0,
              toCategory: testCategory,
              toIndex: 1,
            ),
          ).called(1);
        },
      );

      test('should skip when fromIndex equals toIndex', () async {
        await operations.reorderRecipesInCategory(
          menuId: testMenuId,
          categoryName: testCategory,
          fromIndex: 1,
          toIndex: 1,
          currentRecipes: [testRecipe, testRecipe2],
        );

        verifyNever(() => mockOptimistic.applyChange(any(), any(), any()));
        verifyNever(
          () => mockMenuService.moveRecipeBetweenCategories(
            resourceId: any(named: 'resourceId'),
            fromCategory: any(named: 'fromCategory'),
            fromIndex: any(named: 'fromIndex'),
            toCategory: any(named: 'toCategory'),
            toIndex: any(named: 'toIndex'),
          ),
        );
      });

      test('should throw on invalid fromIndex', () {
        expect(
          () => operations.reorderRecipesInCategory(
            menuId: testMenuId,
            categoryName: testCategory,
            fromIndex: -1,
            toIndex: 0,
            currentRecipes: [testRecipe],
          ),
          throwsA(isA<ArgumentError>()),
        );
      });

      test('should throw on invalid toIndex', () {
        expect(
          () => operations.reorderRecipesInCategory(
            menuId: testMenuId,
            categoryName: testCategory,
            fromIndex: 0,
            toIndex: 10,
            currentRecipes: [testRecipe],
          ),
          throwsA(isA<ArgumentError>()),
        );
      });
    });

    // -- Clear Category -----------------------------------------------------

    group('Clear Category', () {
      test('should clear category and call service', () async {
        await operations.clearCategory(
          menuId: testMenuId,
          categoryName: testCategory,
          currentRecipes: [testRecipe],
        );

        verify(
          () => mockOptimistic.applyChange(
            testCategory,
            any(),
            [testRecipe],
          ),
        ).called(1);
        verify(
          () => mockMenuService.clearCategory(
            resourceId: testMenuId,
            categoryName: testCategory,
          ),
        ).called(1);
      });

      test('should rollback on error', () {
        when(
          () => mockMenuService.clearCategory(
            resourceId: any(named: 'resourceId'),
            categoryName: any(named: 'categoryName'),
          ),
        ).thenThrow(Exception('fail'));

        expect(
          () => operations.clearCategory(
            menuId: testMenuId,
            categoryName: testCategory,
            currentRecipes: [testRecipe],
          ),
          throwsA(isA<Exception>()),
        );
        verify(() => mockOptimistic.rollback()).called(1);
      });
    });

    // -- Regenerate Category ------------------------------------------------

    group('Regenerate Category', () {
      test('should complete without error (feature stub)', () async {
        // Production code logs a warning but does NOT throw
        await operations.regenerateCategory(
          menuId: testMenuId,
          categoryName: testCategory,
        );
        // No service call expected
      });
    });

    // -- Batch Operations ---------------------------------------------------

    group('Batch Operations', () {
      test('should add multiple recipes calling service for each', () async {
        await operations.addMultipleRecipesToCategory(
          menuId: testMenuId,
          categoryName: testCategory,
          recipes: [testRecipe, testRecipe2],
        );

        verify(
          () => mockMenuService.addRecipeToCategory(
            resourceId: testMenuId,
            categoryName: testCategory,
            recipe: testRecipe,
          ),
        ).called(1);
        verify(
          () => mockMenuService.addRecipeToCategory(
            resourceId: testMenuId,
            categoryName: testCategory,
            recipe: testRecipe2,
          ),
        ).called(1);
      });

      test('should skip when recipes list is empty', () async {
        await operations.addMultipleRecipesToCategory(
          menuId: testMenuId,
          categoryName: testCategory,
          recipes: [],
        );

        verifyNever(() => mockOptimistic.applyChange(any(), any()));
        verifyNever(
          () => mockMenuService.addRecipeToCategory(
            resourceId: any(named: 'resourceId'),
            categoryName: any(named: 'categoryName'),
            recipe: any(named: 'recipe'),
          ),
        );
      });

      test('should rollback on partial failure in batch add', () async {
        when(
          () => mockMenuService.addRecipeToCategory(
            resourceId: testMenuId,
            categoryName: testCategory,
            recipe: testRecipe2,
          ),
        ).thenThrow(Exception('second failed'));

        // expect(() => future, throwsA) doesn't await; verify() then runs
        // before the catch-block fires. expectLater awaits the future so
        // rollback() has actually been called by the time we verify.
        await expectLater(
          operations.addMultipleRecipesToCategory(
            menuId: testMenuId,
            categoryName: testCategory,
            recipes: [testRecipe, testRecipe2],
          ),
          throwsA(isA<Exception>()),
        );
        verify(() => mockOptimistic.rollback()).called(1);
      });

      test('should remove multiple recipes via updateWholeCategory', () async {
        await operations.removeMultipleRecipesFromCategory(
          menuId: testMenuId,
          categoryName: testCategory,
          indices: [1, 0],
          currentRecipes: [testRecipe, testRecipe2],
        );

        verify(
          () => mockMenuService.updateWholeCategory(
            resourceId: testMenuId,
            categoryName: testCategory,
            recipes: any(named: 'recipes'),
          ),
        ).called(1);
      });

      test('should skip when indices list is empty', () async {
        await operations.removeMultipleRecipesFromCategory(
          menuId: testMenuId,
          categoryName: testCategory,
          indices: [],
          currentRecipes: [testRecipe],
        );

        verifyNever(() => mockOptimistic.applyChange(any(), any(), any()));
      });

      test('should throw on invalid index in batch remove', () {
        expect(
          () => operations.removeMultipleRecipesFromCategory(
            menuId: testMenuId,
            categoryName: testCategory,
            indices: [0, 10],
            currentRecipes: [testRecipe],
          ),
          throwsA(isA<ArgumentError>()),
        );
      });
    });

    // -- Optimistic Update Management ---------------------------------------

    group('Optimistic Update Management', () {
      test('should delegate applyOptimisticChanges to manager', () {
        final base = {
          'Middag': [testRecipe],
        };
        final result = {
          'Middag': [testRecipe, testRecipe2],
        };
        when(() => mockOptimistic.applyToMenu(base)).thenReturn(result);

        expect(operations.applyOptimisticChanges(base), equals(result));
        verify(() => mockOptimistic.applyToMenu(base)).called(1);
      });

      test('should delegate hasOptimisticChanges', () {
        when(() => mockOptimistic.hasChanges).thenReturn(true);
        expect(operations.hasOptimisticChanges, isTrue);
      });

      test('should delegate optimisticChanges', () {
        final changes = {
          'A': [testRecipe],
        };
        when(() => mockOptimistic.allChanges).thenReturn(changes);
        expect(operations.optimisticChanges, equals(changes));
      });

      test('should delegate clearOptimisticChanges', () {
        operations.clearOptimisticChanges();
        verify(() => mockOptimistic.clear()).called(1);
      });

      test('should delegate rollbackOptimisticChanges', () {
        operations.rollbackOptimisticChanges();
        verify(() => mockOptimistic.rollback()).called(1);
      });
    });

    // -- Validation ---------------------------------------------------------

    group('Validation', () {
      test('valid recipe returns true', () {
        expect(operations.validateRecipeForCategory(testRecipe, 'X'), isTrue);
      });

      test('recipe with empty title returns false', () {
        final r = RecipeFactory.build(id: 'x', title: '');
        expect(operations.validateRecipeForCategory(r, 'X'), isFalse);
      });

      test('valid category name returns true', () {
        expect(operations.validateCategoryName('Middag'), isTrue);
      });

      test('empty category name returns false', () {
        expect(operations.validateCategoryName(''), isFalse);
      });

      test('whitespace-only category name returns false', () {
        expect(operations.validateCategoryName('   '), isFalse);
      });
    });

    // -- Utility methods ----------------------------------------------------

    group('Utility Methods', () {
      test('getRecipeCountForCategory with optimistic changes', () {
        when(() => mockOptimistic.hasChanges).thenReturn(true);
        when(() => mockOptimistic.allChanges).thenReturn({
          testCategory: [testRecipe, testRecipe2],
        });

        expect(
          operations.getRecipeCountForCategory(testCategory, [testRecipe]),
          equals(2),
        );
      });

      test('getRecipeCountForCategory without optimistic changes', () {
        when(() => mockOptimistic.hasChanges).thenReturn(false);

        expect(
          operations.getRecipeCountForCategory(testCategory, [testRecipe]),
          equals(1),
        );
      });

      test('getRecipesForCategory with optimistic changes', () {
        final optimistic = [testRecipe, testRecipe2];
        when(() => mockOptimistic.hasChanges).thenReturn(true);
        when(
          () => mockOptimistic.allChanges,
        ).thenReturn({testCategory: optimistic});

        expect(
          operations.getRecipesForCategory(testCategory, [testRecipe]),
          equals(optimistic),
        );
      });

      test('getRecipesForCategory without optimistic changes', () {
        when(() => mockOptimistic.hasChanges).thenReturn(false);

        final base = [testRecipe];
        expect(
          operations.getRecipesForCategory(testCategory, base),
          equals(base),
        );
      });
    });

    // -- Edge Cases ---------------------------------------------------------

    group('Edge Cases', () {
      test('concurrent add operations all complete', () async {
        final futures = <Future>[];
        for (int i = 0; i < 3; i++) {
          futures.add(
            operations.addRecipeToCategory(
              menuId: testMenuId,
              categoryName: testCategory,
              recipe: RecipeFactory.build(id: 'r_$i'),
            ),
          );
        }
        await Future.wait(futures);

        verify(
          () => mockMenuService.addRecipeToCategory(
            resourceId: testMenuId,
            categoryName: testCategory,
            recipe: any(named: 'recipe'),
          ),
        ).called(3);
      });

      test('timeout exception triggers rollback', () {
        when(
          () => mockMenuService.addRecipeToCategory(
            resourceId: any(named: 'resourceId'),
            categoryName: any(named: 'categoryName'),
            recipe: any(named: 'recipe'),
          ),
        ).thenThrow(
          TimeoutException('timed out', const Duration(seconds: 30)),
        );

        expect(
          () => operations.addRecipeToCategory(
            menuId: testMenuId,
            categoryName: testCategory,
            recipe: testRecipe,
          ),
          throwsA(isA<TimeoutException>()),
        );
        verify(() => mockOptimistic.rollback()).called(1);
      });
    });
  });
}
