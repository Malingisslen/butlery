// test/unit/viewmodels/recipe_list/recipe_delete_manager_test.dart

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:butlery/viewmodels/recipe_list/recipe_delete_manager.dart';
import 'package:butlery/models/recipe_unified.dart';

import '../../../infrastructure/mocks/production_mocks.dart';
import '../../../infrastructure/factories/recipe_factory.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockUnifiedRecipeService mockRecipeService;
  late RecipeDeleteManager manager;
  late List<String> invalidateCacheCalls;
  late List<String> notifyParentCalls;
  late List<String> errorCalls;

  late Recipe recipe1;
  late Recipe recipe2;
  late Recipe recipe3;

  setUpAll(() {
    registerFallbackValue(RecipeFactory.build(id: 'fallback'));
  });

  setUp(() {
    mockRecipeService = MockUnifiedRecipeService();
    invalidateCacheCalls = [];
    notifyParentCalls = [];
    errorCalls = [];

    recipe1 = RecipeFactory.build(id: 'r1', title: 'Recipe 1');
    recipe2 = RecipeFactory.build(id: 'r2', title: 'Recipe 2');
    recipe3 = RecipeFactory.build(id: 'r3', title: 'Recipe 3');

    mockRecipeService.setRecipeState(
      recipes: [recipe1, recipe2, recipe3],
      isInitialized: true,
    );

    // Stub methods left to mocktail on MockUnifiedRecipeService.
    // getRecipeById has a concrete implementation, so no stub needed.
    when(() => mockRecipeService.optimisticRemoveWithIndex(any()))
        .thenReturn(0);
    when(() => mockRecipeService.optimisticRestoreAt(any(), any()))
        .thenReturn(null);
    when(() => mockRecipeService.deleteRecipe(any()))
        .thenAnswer((_) async => true);

    manager = RecipeDeleteManager(
      recipeService: mockRecipeService,
      invalidateCache: () => invalidateCacheCalls.add('called'),
      notifyParent: () => notifyParentCalls.add('called'),
      onError: (id) => errorCalls.add(id),
    );
  });

  tearDown(() {
    manager.dispose();
  });

  group('RecipeDeleteManager - Initial State', () {
    test('should start with no pending deletes', () {
      expect(manager.hasPendingDeletes, false);
    });
  });

  group('RecipeDeleteManager - Single Delete', () {
    test('should optimistically remove recipe and notify callbacks', () {
      // Behavior: Delete instantly removes the recipe from the UI
      when(() => mockRecipeService.optimisticRemoveWithIndex('r1'))
          .thenReturn(0);

      fakeAsync((async) {
        manager.deleteRecipe('r1');

        expect(manager.hasPendingDeletes, true);
        expect(invalidateCacheCalls.length, 1);
        expect(notifyParentCalls.length, 1);
        verify(() => mockRecipeService.optimisticRemoveWithIndex('r1'))
            .called(1);
      });
    });

    test('should commit deletion to backend after 5-second timer', () {
      // Behavior: After 5s undo window, the delete is persisted to Firestore
      when(() => mockRecipeService.optimisticRemoveWithIndex('r1'))
          .thenReturn(0);
      when(() => mockRecipeService.deleteRecipe('r1'))
          .thenAnswer((_) async => true);

      fakeAsync((async) {
        manager.deleteRecipe('r1');

        // Before 5s: not committed yet
        async.elapse(const Duration(seconds: 4));
        verifyNever(() => mockRecipeService.deleteRecipe('r1'));

        // After 5s: committed
        async.elapse(const Duration(seconds: 1));
        verify(() => mockRecipeService.deleteRecipe('r1')).called(1);
      });
    });

    test('should ignore duplicate delete for same recipe', () {
      when(() => mockRecipeService.optimisticRemoveWithIndex('r1'))
          .thenReturn(0);

      fakeAsync((async) {
        manager.deleteRecipe('r1');
        manager.deleteRecipe('r1'); // duplicate — should be ignored

        verify(() => mockRecipeService.optimisticRemoveWithIndex('r1'))
            .called(1);
        expect(invalidateCacheCalls.length, 1);
      });
    });

    test('should do nothing when recipe not found in service', () {
      // Behavior: If the recipe was already removed elsewhere, skip silently
      mockRecipeService.setRecipeState(
        recipes: [],
        isInitialized: true,
      );

      fakeAsync((async) {
        manager.deleteRecipe('nonexistent');

        expect(manager.hasPendingDeletes, false);
        expect(invalidateCacheCalls, isEmpty);
      });
    });
  });

  group('RecipeDeleteManager - Undo Single Delete', () {
    test('should restore recipe at original index when undone', () {
      // Behavior: "Undo" puts the recipe back exactly where it was
      when(() => mockRecipeService.optimisticRemoveWithIndex('r1'))
          .thenReturn(2);

      fakeAsync((async) {
        manager.deleteRecipe('r1');
        invalidateCacheCalls.clear();
        notifyParentCalls.clear();

        manager.undoDeleteById('r1');

        expect(manager.hasPendingDeletes, false);
        verify(() => mockRecipeService.optimisticRestoreAt(
              any(that: isA<Recipe>()),
              2,
            )).called(1);
        expect(invalidateCacheCalls.length, 1);
        expect(notifyParentCalls.length, 1);

        // Timer should be cancelled — no commit after 5s
        async.elapse(const Duration(seconds: 10));
        verifyNever(() => mockRecipeService.deleteRecipe('r1'));
      });
    });

    test('should do nothing when undoing a non-pending recipe', () {
      fakeAsync((async) {
        manager.undoDeleteById('nonexistent');

        expect(invalidateCacheCalls, isEmpty);
        verifyNever(() => mockRecipeService.optimisticRestoreAt(
              any(that: isA<Recipe>()),
              any(),
            ));
      });
    });
  });

  group('RecipeDeleteManager - Undo Last Delete', () {
    test('should undo the most recently deleted recipe', () {
      // Behavior: Snackbar "Undo" restores the last deleted recipe
      when(() => mockRecipeService.optimisticRemoveWithIndex('r1'))
          .thenReturn(0);
      when(() => mockRecipeService.optimisticRemoveWithIndex('r2'))
          .thenReturn(1);

      fakeAsync((async) {
        manager.deleteRecipe('r1');
        // Small delay so createdAt differs
        async.elapse(const Duration(milliseconds: 100));
        manager.deleteRecipe('r2');

        invalidateCacheCalls.clear();

        manager.undoLastDelete();

        // r2 was deleted last, so it should be restored at index 1
        verify(() => mockRecipeService.optimisticRestoreAt(
              any(that: isA<Recipe>()),
              1,
            )).called(1);

        // r1 should still be pending
        expect(manager.hasPendingDeletes, true);
      });
    });

    test('should do nothing when no pending deletes exist', () {
      fakeAsync((async) {
        manager.undoLastDelete();

        expect(invalidateCacheCalls, isEmpty);
      });
    });
  });

  group('RecipeDeleteManager - Bulk Delete', () {
    test('should optimistically remove all selected recipes', () {
      // Behavior: Bulk delete removes multiple recipes at once
      when(() => mockRecipeService.optimisticRemoveWithIndex('r1'))
          .thenReturn(0);
      when(() => mockRecipeService.optimisticRemoveWithIndex('r2'))
          .thenReturn(1);

      fakeAsync((async) {
        manager.deleteSelected({'r1', 'r2'});

        expect(manager.hasPendingDeletes, true);
        verify(() => mockRecipeService.optimisticRemoveWithIndex('r1'))
            .called(1);
        verify(() => mockRecipeService.optimisticRemoveWithIndex('r2'))
            .called(1);
        // One batch call to invalidateCache and notifyParent
        expect(invalidateCacheCalls.length, 1);
        expect(notifyParentCalls.length, 1);
      });
    });

    test('should commit bulk deletes after 7-second timer', () {
      when(() => mockRecipeService.optimisticRemoveWithIndex('r1'))
          .thenReturn(0);
      when(() => mockRecipeService.optimisticRemoveWithIndex('r2'))
          .thenReturn(1);
      when(() => mockRecipeService.deleteRecipe('r1'))
          .thenAnswer((_) async => true);
      when(() => mockRecipeService.deleteRecipe('r2'))
          .thenAnswer((_) async => true);

      fakeAsync((async) {
        manager.deleteSelected({'r1', 'r2'});

        // Before 7s: not committed
        async.elapse(const Duration(seconds: 6));
        verifyNever(() => mockRecipeService.deleteRecipe(any()));

        // After 7s: committed
        async.elapse(const Duration(seconds: 1));
        verify(() => mockRecipeService.deleteRecipe('r1')).called(1);
        verify(() => mockRecipeService.deleteRecipe('r2')).called(1);
      });
    });

    test('should skip already-pending recipes in bulk delete', () {
      when(() => mockRecipeService.optimisticRemoveWithIndex('r1'))
          .thenReturn(0);
      when(() => mockRecipeService.optimisticRemoveWithIndex('r2'))
          .thenReturn(1);

      fakeAsync((async) {
        manager.deleteRecipe('r1'); // already pending
        manager.deleteSelected({'r1', 'r2'});

        // r1 was optimistically removed once (single), not again in bulk
        verify(() => mockRecipeService.optimisticRemoveWithIndex('r1'))
            .called(1);
        verify(() => mockRecipeService.optimisticRemoveWithIndex('r2'))
            .called(1);
      });
    });
  });

  group('RecipeDeleteManager - Undo Bulk Delete', () {
    test('should restore all bulk-deleted recipes', () {
      // Behavior: Undo bulk restores recipes back to their original positions
      when(() => mockRecipeService.optimisticRemoveWithIndex('r1'))
          .thenReturn(0);
      when(() => mockRecipeService.optimisticRemoveWithIndex('r2'))
          .thenReturn(1);

      fakeAsync((async) {
        manager.deleteSelected({'r1', 'r2'});
        invalidateCacheCalls.clear();
        notifyParentCalls.clear();

        manager.undoBulkDelete();

        expect(manager.hasPendingDeletes, false);
        verify(() => mockRecipeService.optimisticRestoreAt(
              any(that: isA<Recipe>()),
              any(),
            )).called(2);
        expect(invalidateCacheCalls.length, 1);
        expect(notifyParentCalls.length, 1);

        // Timers should be cancelled
        async.elapse(const Duration(seconds: 10));
        verifyNever(() => mockRecipeService.deleteRecipe(any()));
      });
    });

    test('should do nothing when no bulk batch exists', () {
      fakeAsync((async) {
        manager.undoBulkDelete();

        expect(invalidateCacheCalls, isEmpty);
      });
    });
  });

  group('RecipeDeleteManager - Cancel All', () {
    test('should cancel all pending timers and restore all recipes', () {
      // Behavior: Navigating away cancels all pending deletions
      when(() => mockRecipeService.optimisticRemoveWithIndex('r1'))
          .thenReturn(0);
      when(() => mockRecipeService.optimisticRemoveWithIndex('r2'))
          .thenReturn(1);

      fakeAsync((async) {
        manager.deleteRecipe('r1');
        manager.deleteRecipe('r2');

        manager.cancelAll();

        expect(manager.hasPendingDeletes, false);
        verify(() => mockRecipeService.optimisticRestoreAt(
              any(that: isA<Recipe>()),
              any(),
            )).called(2);

        // No commits after cancel
        async.elapse(const Duration(seconds: 10));
        verifyNever(() => mockRecipeService.deleteRecipe(any()));
      });
    });
  });

  group('RecipeDeleteManager - Dispose', () {
    test('should cancel all pending deletes on dispose', () {
      when(() => mockRecipeService.optimisticRemoveWithIndex('r1'))
          .thenReturn(0);

      fakeAsync((async) {
        manager.deleteRecipe('r1');

        manager.dispose();

        expect(manager.hasPendingDeletes, false);
        verify(() => mockRecipeService.optimisticRestoreAt(
              any(that: isA<Recipe>()),
              any(),
            )).called(1);

        // Timer was cancelled — no commit
        async.elapse(const Duration(seconds: 10));
        verifyNever(() => mockRecipeService.deleteRecipe(any()));
      });
    });
  });

  group('RecipeDeleteManager - Error Handling', () {
    test('should restore recipe and call onError when backend delete fails',
        () {
      // Behavior: If Firestore delete fails, the recipe reappears and user sees error
      when(() => mockRecipeService.optimisticRemoveWithIndex('r1'))
          .thenReturn(0);
      when(() => mockRecipeService.deleteRecipe('r1'))
          .thenThrow(Exception('Network error'));

      fakeAsync((async) {
        manager.deleteRecipe('r1');
        invalidateCacheCalls.clear();
        notifyParentCalls.clear();

        // Trigger the timer commit
        async.elapse(const Duration(seconds: 5));
        // Allow the future to complete
        async.flushMicrotasks();

        verify(() => mockRecipeService.optimisticRestoreAt(
              any(that: isA<Recipe>()),
              0,
            )).called(1);
        expect(errorCalls, ['r1']);
        expect(invalidateCacheCalls.length, 1);
        expect(notifyParentCalls.length, 1);
      });
    });
  });
}
