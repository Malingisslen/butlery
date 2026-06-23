/// Unit tests for DebouncedSyncOperations
///
/// Tests debounced sync module including scheduling, batch processing,
/// queue management, and error handling.
library;

import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:get_it/get_it.dart';
import 'package:butlery/services/unified/modules/debounced_sync_operations.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/repositories/interfaces/recipe_repository.dart';
import '../../../../test_support/base_unit_test.dart';
import '../../../../infrastructure/di/test_service_locator.dart';
import '../../../../infrastructure/mocks/production_mocks.dart';
import '../../../../infrastructure/builders/recipe_builder.dart';

void main() {
  group('DebouncedSyncOperations', () {
    late MockRecipeRepository mockRecipeRepository;
    late Recipe testRecipe;
    late Recipe collaborativeRecipe;
    late Set<String> pendingSyncIds;
    late Timer? syncTimer;

    setUpAll(() async {
      await BaseUnitTest.setupUnit();
    });

    setUp(() async {
      await TestServiceLocator.initialize();

      // Create mock dependencies
      mockRecipeRepository = MockRecipeRepository();

      // Register mock repository with GetIt for the service to use
      // First unregister if already registered
      if (GetIt.instance.isRegistered<RecipeRepository>()) {
        GetIt.instance.unregister<RecipeRepository>();
      }
      GetIt.instance.registerSingleton<RecipeRepository>(mockRecipeRepository);

      // Create test data
      testRecipe = RecipeBuilder()
          .withId('recipe_1')
          .withTitle('Test Recipe')
          .withCreatedBy('user_123')
          .build();

      collaborativeRecipe = RecipeBuilder()
          .withId('collab_recipe')
          .withTitle('Collaborative Recipe')
          .withCreatedBy('user_456')
          .asCollaborative()
          .build();

      pendingSyncIds = {};
      syncTimer = null;

      // Setup mock repository behavior
      when(
        () => mockRecipeRepository.update(any()),
      ).thenAnswer((_) async => {});
    });

    tearDown(() async {
      syncTimer?.cancel();
      syncTimer = null;
      pendingSyncIds.clear();

      // Unregister GetIt instance
      if (GetIt.instance.isRegistered<RecipeRepository>()) {
        GetIt.instance.unregister<RecipeRepository>();
      }

      BaseUnitTest.resetMocks();
      await TestServiceLocator.reset();
    });

    tearDownAll(() async {
      await BaseUnitTest.teardownUnit();
    });

    group('Debounced Sync Scheduling', () {
      test('should schedule recipe for sync', () async {
        // Arrange
        var syncPendingCalled = false;

        // Act
        DebouncedSyncOperations.scheduleSyncForRecipe(
          recipeId: 'recipe_1',
          pendingSyncIds: pendingSyncIds,
          getSyncTimer: () => syncTimer,
          setSyncTimer: (timer) => syncTimer = timer,
          syncDebounce: const Duration(milliseconds: 100),
          onSyncPending: () => syncPendingCalled = true,
        );

        // Assert
        expect(pendingSyncIds.contains('recipe_1'), isTrue);
        expect(syncTimer, isNotNull);
        expect(syncTimer!.isActive, isTrue);

        // Wait for debounce
        await Future.delayed(const Duration(milliseconds: 150));
        expect(syncPendingCalled, isTrue);
      });

      test('should cancel previous timer when scheduling new sync', () async {
        // Arrange
        var syncCallCount = 0;

        // Act - Schedule first sync
        DebouncedSyncOperations.scheduleSyncForRecipe(
          recipeId: 'recipe_1',
          pendingSyncIds: pendingSyncIds,
          getSyncTimer: () => syncTimer,
          setSyncTimer: (timer) => syncTimer = timer,
          syncDebounce: const Duration(milliseconds: 100),
          onSyncPending: () => syncCallCount++,
        );

        final firstTimer = syncTimer;

        // Schedule second sync before first completes
        await Future.delayed(const Duration(milliseconds: 50));
        DebouncedSyncOperations.scheduleSyncForRecipe(
          recipeId: 'recipe_2',
          pendingSyncIds: pendingSyncIds,
          getSyncTimer: () => syncTimer,
          setSyncTimer: (timer) => syncTimer = timer,
          syncDebounce: const Duration(milliseconds: 100),
          onSyncPending: () => syncCallCount++,
        );

        // Assert
        expect(
          firstTimer!.isActive,
          isFalse,
        ); // First timer should be cancelled
        expect(syncTimer!.isActive, isTrue); // New timer should be active
        expect(pendingSyncIds.length, equals(2));

        // Wait for debounce
        await Future.delayed(const Duration(milliseconds: 150));
        expect(syncCallCount, equals(1)); // Should only be called once
      });

      test('should accumulate multiple recipes in pending sync', () async {
        // Arrange
        var syncPendingCalled = false;

        // Act - Schedule multiple syncs
        for (int i = 0; i < 5; i++) {
          DebouncedSyncOperations.scheduleSyncForRecipe(
            recipeId: 'recipe_$i',
            pendingSyncIds: pendingSyncIds,
            getSyncTimer: () => syncTimer,
            setSyncTimer: (timer) => syncTimer = timer,
            syncDebounce: const Duration(milliseconds: 100),
            onSyncPending: () => syncPendingCalled = true,
          );
          await Future.delayed(const Duration(milliseconds: 20));
        }

        // Assert
        expect(pendingSyncIds.length, equals(5));
        expect(
          pendingSyncIds,
          containsAll([
            'recipe_0',
            'recipe_1',
            'recipe_2',
            'recipe_3',
            'recipe_4',
          ]),
        );

        // Wait for final debounce
        await Future.delayed(const Duration(milliseconds: 150));
        expect(syncPendingCalled, isTrue);
      });
    });

    group('Sync Pending Recipes', () {
      test('should sync all pending recipes', () async {
        // Arrange
        pendingSyncIds.addAll(['recipe_1', 'recipe_2']);
        Future<Recipe?> recipeLoader(String id) async {
          if (id == 'recipe_1') return testRecipe;
          if (id == 'recipe_2') {
            return RecipeBuilder()
                .withId('recipe_2')
                .withTitle('Recipe 2')
                .withCreatedBy('user_123')
                .build();
          }
          return null;
        }

        // Act
        await DebouncedSyncOperations.syncPendingRecipes(
          pendingSyncIds: pendingSyncIds,
          recipeLoader: recipeLoader,
          currentUserId: 'user_123',
        );

        // Assert
        expect(pendingSyncIds.isEmpty, isTrue);
        verify(() => mockRecipeRepository.update(any())).called(2);
      });

      test('should handle null current user', () async {
        // Arrange
        pendingSyncIds.add('recipe_1');
        Future<Recipe?> recipeLoader(String id) async => testRecipe;

        // Act
        await DebouncedSyncOperations.syncPendingRecipes(
          pendingSyncIds: pendingSyncIds,
          recipeLoader: recipeLoader,
          currentUserId: null,
        );

        // Assert
        expect(
          pendingSyncIds.contains('recipe_1'),
          isTrue,
        ); // Should not be cleared
        verifyNever(() => mockRecipeRepository.update(any()));
      });

      test('should re-add failed syncs to pending', () async {
        // Arrange
        pendingSyncIds.add('recipe_1');
        when(
          () => mockRecipeRepository.update(any()),
        ).thenThrow(Exception('Sync failed'));
        Future<Recipe?> recipeLoader(String id) async => testRecipe;

        // Act
        await DebouncedSyncOperations.syncPendingRecipes(
          pendingSyncIds: pendingSyncIds,
          recipeLoader: recipeLoader,
          currentUserId: 'user_123',
        );

        // Assert
        expect(pendingSyncIds.contains('recipe_1'), isTrue);
      });

      test('should handle missing recipes', () async {
        // Arrange
        pendingSyncIds.add('non_existent');
        Future<Recipe?> recipeLoader(String id) async => null;

        // Act
        await DebouncedSyncOperations.syncPendingRecipes(
          pendingSyncIds: pendingSyncIds,
          recipeLoader: recipeLoader,
          currentUserId: 'user_123',
        );

        // Assert
        expect(pendingSyncIds.isEmpty, isTrue);
        verifyNever(() => mockRecipeRepository.update(any()));
      });
    });

    group('Batch Sync Operations', () {
      test('should sync multiple recipes immediately', () async {
        // Arrange
        final recipeIds = ['recipe_1', 'recipe_2'];
        Future<Recipe?> recipeLoader(String id) async {
          if (id == 'recipe_1') return testRecipe;
          if (id == 'recipe_2') {
            return RecipeBuilder()
                .withId('recipe_2')
                .withTitle('Recipe 2')
                .withCreatedBy('user_123')
                .build();
          }
          return null;
        }

        // Act
        await DebouncedSyncOperations.syncMultipleRecipesImmediately(
          recipeIds: recipeIds,
          recipeLoader: recipeLoader,
          currentUserId: 'user_123',
        );

        // Assert
        verify(() => mockRecipeRepository.update(any())).called(2);
      });

      test('should handle empty recipe list', () async {
        // Arrange
        Future<Recipe?> recipeLoader(String id) async => testRecipe;

        // Act
        await DebouncedSyncOperations.syncMultipleRecipesImmediately(
          recipeIds: [],
          recipeLoader: recipeLoader,
          currentUserId: 'user_123',
        );

        // Assert
        verifyNever(() => mockRecipeRepository.update(any()));
      });

      test('should handle sync errors in batch', () async {
        // Arrange
        final recipeIds = ['recipe_1'];
        when(
          () => mockRecipeRepository.update(any()),
        ).thenThrow(Exception('Sync failed'));
        Future<Recipe?> recipeLoader(String id) async => testRecipe;

        // Act & Assert
        expect(
          () => DebouncedSyncOperations.syncMultipleRecipesImmediately(
            recipeIds: recipeIds,
            recipeLoader: recipeLoader,
            currentUserId: 'user_123',
          ),
          throwsException,
        );
      });
    });

    group('Force Sync', () {
      test('should force sync single recipe', () async {
        // Arrange
        Future<Recipe?> recipeLoader(String id) async => testRecipe;

        // Act
        await DebouncedSyncOperations.forceSyncRecipe(
          recipeId: 'recipe_1',
          recipeLoader: recipeLoader,
          currentUserId: 'user_123',
        );

        // Assert
        verify(() => mockRecipeRepository.update(any())).called(1);
      });

      test('should handle null user in force sync', () async {
        // Arrange
        Future<Recipe?> recipeLoader(String id) async => testRecipe;

        // Act
        await DebouncedSyncOperations.forceSyncRecipe(
          recipeId: 'recipe_1',
          recipeLoader: recipeLoader,
          currentUserId: null,
        );

        // Assert
        verifyNever(() => mockRecipeRepository.update(any()));
      });

      test('should handle collaborative recipe sync', () async {
        // Arrange
        Future<Recipe?> recipeLoader(String id) async => collaborativeRecipe;

        // Act
        await DebouncedSyncOperations.forceSyncRecipe(
          recipeId: 'collab_recipe',
          recipeLoader: recipeLoader,
          currentUserId: 'user_123',
        );

        // Assert — collaborative recipes now sync through the same repository
        // until the dedicated collaborative repo is wired in (see
        // _syncCollaborativeRecipe in debounced_sync_operations.dart).
        verify(() => mockRecipeRepository.update(any())).called(1);
      });
    });

    group('Sync Queue Management', () {
      test('should get pending sync status', () {
        // Arrange
        pendingSyncIds.addAll(['recipe_1', 'recipe_2']);

        // Act
        final status = DebouncedSyncOperations.getPendingSyncStatus(
          pendingSyncIds,
        );

        // Assert
        expect(status['pendingCount'], equals(2));
        expect(
          status['pendingRecipeIds'],
          containsAll(['recipe_1', 'recipe_2']),
        );
        expect(status['hasPendingSync'], isTrue);
      });

      test('should clear pending syncs', () {
        // Arrange
        pendingSyncIds.addAll(['recipe_1', 'recipe_2']);

        // Act
        DebouncedSyncOperations.clearPendingSync(pendingSyncIds);

        // Assert
        expect(pendingSyncIds.isEmpty, isTrue);
      });

      test('should remove specific recipe from pending', () {
        // Arrange
        pendingSyncIds.addAll(['recipe_1', 'recipe_2']);

        // Act
        DebouncedSyncOperations.removePendingSync(
          recipeId: 'recipe_1',
          pendingSyncIds: pendingSyncIds,
        );

        // Assert
        expect(pendingSyncIds.contains('recipe_1'), isFalse);
        expect(pendingSyncIds.contains('recipe_2'), isTrue);
      });

      test('should add recipe to pending sync queue', () {
        // Arrange
        expect(pendingSyncIds.isEmpty, isTrue);

        // Act
        DebouncedSyncOperations.addPendingSync(
          recipeId: 'recipe_1',
          pendingSyncIds: pendingSyncIds,
        );

        // Assert
        expect(pendingSyncIds.contains('recipe_1'), isTrue);
      });
    });

    group('Sync Optimization', () {
      test('should determine if recipe needs sync', () {
        // Arrange
        final recentRecipe = RecipeBuilder()
          ..updatedAt = DateTime.now().subtract(const Duration(minutes: 5));
        final oldRecipe = RecipeBuilder()
          ..updatedAt = DateTime.now().subtract(const Duration(hours: 2));

        // Act & Assert
        expect(
          DebouncedSyncOperations.shouldSyncRecipe(
            recipe: recentRecipe.build(),
            minSyncInterval: const Duration(minutes: 10),
          ),
          isTrue,
        );

        expect(
          DebouncedSyncOperations.shouldSyncRecipe(
            recipe: oldRecipe.build(),
            minSyncInterval: const Duration(minutes: 10),
          ),
          isFalse,
        );
      });

      test('should get urgent sync recipes', () {
        // Arrange
        pendingSyncIds.addAll(['recipe_1', 'recipe_2']);
        Future<Recipe?> recipeLoader(String id) async => testRecipe;

        // Act
        final urgentRecipes = DebouncedSyncOperations.getUrgentSyncRecipes(
          pendingSyncIds: pendingSyncIds,
          recipeLoader: recipeLoader,
          urgentThreshold: const Duration(minutes: 5),
        );

        // Assert
        expect(urgentRecipes, containsAll(['recipe_1', 'recipe_2']));
      });
    });

    group('Error Handling', () {
      test('should handle sync error with retry logic', () async {
        // Arrange
        Future<Recipe?> recipeLoader(String id) async => testRecipe;

        // Act
        await DebouncedSyncOperations.handleSyncError(
          recipeId: 'recipe_1',
          error: 'network timeout',
          pendingSyncIds: pendingSyncIds,
          maxRetries: 3,
          recipeLoader: recipeLoader,
          currentUserId: 'user_123',
        );

        // Assert
        expect(pendingSyncIds.contains('recipe_1'), isTrue);
      });

      test('should handle non-network errors', () async {
        // Arrange
        Future<Recipe?> recipeLoader(String id) async => testRecipe;

        // Act
        await DebouncedSyncOperations.handleSyncError(
          recipeId: 'recipe_1',
          error: 'validation error',
          pendingSyncIds: pendingSyncIds,
          maxRetries: 3,
          recipeLoader: recipeLoader,
          currentUserId: 'user_123',
        );

        // Assert
        expect(pendingSyncIds.contains('recipe_1'), isTrue);
      });

      test('should retry failed syncs', () async {
        // Arrange
        final failedSyncIds = {'recipe_1', 'recipe_2'};
        var syncAttempts = 0;

        when(() => mockRecipeRepository.update(any())).thenAnswer((_) async {
          syncAttempts++;
          if (syncAttempts == 1) {
            throw Exception('First attempt failed');
          }
        });

        Future<Recipe?> recipeLoader(String id) async => testRecipe;

        // Act
        await DebouncedSyncOperations.retryFailedSyncs(
          failedSyncIds: failedSyncIds,
          recipeLoader: recipeLoader,
          currentUserId: 'user_123',
        );

        // Assert
        expect(failedSyncIds.length, equals(1)); // One recipe failed again
      });

      test('should handle null user in retry', () async {
        // Arrange
        final failedSyncIds = {'recipe_1'};
        Future<Recipe?> recipeLoader(String id) async => testRecipe;

        // Act
        await DebouncedSyncOperations.retryFailedSyncs(
          failedSyncIds: failedSyncIds,
          recipeLoader: recipeLoader,
          currentUserId: null,
        );

        // Assert
        expect(failedSyncIds.contains('recipe_1'), isTrue);
        verifyNever(() => mockRecipeRepository.update(any()));
      });
    });

    group('Swedish Language Support', () {
      test('should handle Swedish characters in recipe sync', () async {
        // Arrange
        final swedishRecipe = RecipeBuilder()
            .withId('swedish_recipe')
            .withTitle('Köttbullar med gräddsås')
            .withDescription('Äkta svenska köttbullar från Småland')
            .withIngredients(['Nötfärs', 'Ägg', 'Mjölk', 'Lök'])
            .withCreatedBy('user_123')
            .build();

        Future<Recipe?> recipeLoader(String id) async => swedishRecipe;

        // Act
        await DebouncedSyncOperations.forceSyncRecipe(
          recipeId: 'swedish_recipe',
          recipeLoader: recipeLoader,
          currentUserId: 'user_123',
        );

        // Assert
        verify(() => mockRecipeRepository.update(any())).called(1);
      });
    });

    group('Concurrent Operations', () {
      test('should handle concurrent sync scheduling safely', () async {
        // Arrange
        var syncCount = 0;

        // Act - Schedule multiple syncs concurrently
        final futures = List.generate(
          10,
          (i) => Future(() {
            DebouncedSyncOperations.scheduleSyncForRecipe(
              recipeId: 'concurrent_$i',
              pendingSyncIds: pendingSyncIds,
              getSyncTimer: () => syncTimer,
              setSyncTimer: (timer) => syncTimer = timer,
              syncDebounce: const Duration(milliseconds: 100),
              onSyncPending: () => syncCount++,
            );
          }),
        );

        await Future.wait(futures);

        // Assert - All recipes should be queued
        expect(pendingSyncIds.length, equals(10));
        for (int i = 0; i < 10; i++) {
          expect(pendingSyncIds.contains('concurrent_$i'), isTrue);
        }

        // Wait for debounce
        await Future.delayed(const Duration(milliseconds: 150));
        expect(syncCount, equals(1)); // Should only trigger once
      });
    });

    group('Disposal and Cleanup', () {
      test('should clean up resources on disposal', () {
        // Arrange
        DebouncedSyncOperations.scheduleSyncForRecipe(
          recipeId: 'cleanup_test',
          pendingSyncIds: pendingSyncIds,
          getSyncTimer: () => syncTimer,
          setSyncTimer: (timer) => syncTimer = timer,
          syncDebounce: const Duration(milliseconds: 1000),
          onSyncPending: () {},
        );

        expect(syncTimer?.isActive, isTrue);
        expect(pendingSyncIds.isNotEmpty, isTrue);

        // Act - Clean up resources manually since it's a static class
        syncTimer?.cancel();
        DebouncedSyncOperations.clearPendingSync(pendingSyncIds);

        // Assert
        expect(syncTimer?.isActive, isFalse);
        expect(pendingSyncIds.isEmpty, isTrue);
      });
    });

    group('Performance', () {
      test('should handle large batch sync efficiently', () async {
        // Arrange
        final largeRecipeIds = List.generate(100, (i) => 'large_batch_$i');
        final recipes = <String, Recipe>{};

        for (int i = 0; i < 100; i++) {
          recipes['large_batch_$i'] = RecipeBuilder()
              .withId('large_batch_$i')
              .withTitle('Recipe $i')
              .withCreatedBy('user_123')
              .build();
        }

        Future<Recipe?> recipeLoader(String id) async => recipes[id];

        // Act
        final stopwatch = Stopwatch()..start();
        await DebouncedSyncOperations.syncMultipleRecipesImmediately(
          recipeIds: largeRecipeIds,
          recipeLoader: recipeLoader,
          currentUserId: 'user_123',
        );
        stopwatch.stop();

        // Assert
        verify(() => mockRecipeRepository.update(any())).called(100);
        expect(
          stopwatch.elapsedMilliseconds,
          lessThan(5000),
        ); // Should complete within 5 seconds
      });
    });
  });
}
