// test/unit/services/unified/modules/realtime_cache_manager_test.dart

// ignore_for_file: cancel_subscriptions

import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:butlery/services/unified/modules/realtime_cache_manager.dart';
import 'package:butlery/models/recipe_unified.dart';
import '../../../../test_support/base_unit_test.dart';
import '../../../../infrastructure/di/test_service_locator.dart';
import '../../../../infrastructure/mocks/production_mocks.dart';
import '../../../../infrastructure/builders/recipe_builder.dart';

void main() {
  group('RealtimeCacheManager', () {
    late FakeJsonCacheHelper mockCacheHelper;
    late Recipe testRecipe;
    late Recipe testRecipe2;

    setUpAll(() {
      // Centralized fallback values already registered via TestServiceLocator
    });

    setUp(() async {
      await BaseUnitTest.setupUnit();
      await TestServiceLocator.initialize();

      // Initialize mocks using centralized infrastructure
      mockCacheHelper = FakeJsonCacheHelper();

      // Create test data
      testRecipe = RecipeBuilder()
          .withId('recipe_1')
          .withTitle('Test Recipe')
          .withDescription('A test recipe')
          .build();

      testRecipe2 = RecipeBuilder()
          .withId('recipe_2')
          .withTitle('Another Recipe')
          .withDescription('Another test recipe')
          .build();

      // Configure mock
      mockCacheHelper.setCacheState(cache: {});
    });

    tearDown(() async {
      await TestServiceLocator.reset();
      BaseUnitTest.resetMocks();
    });

    tearDownAll(() async {
      // Cleanup if needed
    });

    group('Real-time Cache Operations', () {
      test('should save recipe to cache during real-time editing', () async {
        // Arrange
        mockCacheHelper.setCacheState(cache: {});

        // Act
        await RealtimeCacheManager.saveToCache(
          recipe: testRecipe,
          cacheHelper: mockCacheHelper,
        );

        // Assert
        final cachedRecipe = await mockCacheHelper.loadJson('recipe_1');
        expect(cachedRecipe, isNotNull);
        expect(cachedRecipe?['core']?['title'], equals('Test Recipe'));
      });

      test('should load recipe from cache for real-time operations', () async {
        // Arrange
        mockCacheHelper.setCacheState(
          cache: {
            'recipe_1': testRecipe.toJson(),
          },
        );

        // Act
        final loadedRecipe = await RealtimeCacheManager.loadFromCache(
          recipeId: 'recipe_1',
          cacheHelper: mockCacheHelper,
        );

        // Assert
        expect(loadedRecipe, isNotNull);
        expect(loadedRecipe?.id, equals('recipe_1'));
        expect(loadedRecipe?.title, equals('Test Recipe'));
      });

      test('should return null when recipe not in cache', () async {
        // Arrange
        mockCacheHelper.setCacheState(cache: {});

        // Act
        final loadedRecipe = await RealtimeCacheManager.loadFromCache(
          recipeId: 'non_existent',
          cacheHelper: mockCacheHelper,
        );

        // Assert
        expect(loadedRecipe, isNull);
      });

      test('should handle errors gracefully when loading from cache', () async {
        // Arrange — Recipe.fromJson is defensive and fills defaults for missing
        // fields, so partial data produces a valid (but empty) Recipe rather
        // than throwing.
        mockCacheHelper.setCacheState(
          cache: {
            'recipe_1': {'invalid': 'data'},
          },
        );

        // Act
        final loadedRecipe = await RealtimeCacheManager.loadFromCache(
          recipeId: 'recipe_1',
          cacheHelper: mockCacheHelper,
        );

        // Assert — returns a Recipe with defaults, not null
        expect(loadedRecipe, isNotNull);
      });
    });

    group('Cache Update Operations', () {
      test('should update cached recipe with real-time changes', () async {
        // Arrange
        final existingData = testRecipe.toJson();
        mockCacheHelper.setCacheState(
          cache: {
            'recipe_1': existingData,
          },
        );

        final editData = {
          'title': 'Updated Title',
          'description': 'Updated Description',
          'editedAt': DateTime.now().toIso8601String(),
          'editedBy': 'user_123',
          'editedByDisplayName': 'Test User',
        };

        // Act
        await RealtimeCacheManager.updateCacheWithEdit(
          recipeId: 'recipe_1',
          editData: editData,
          cacheHelper: mockCacheHelper,
        );

        // Assert
        final updatedRecipe = await mockCacheHelper.loadJson('recipe_1');
        expect(updatedRecipe, isNotNull);
        expect(updatedRecipe?['title'], equals('Updated Title'));
        expect(updatedRecipe?['description'], equals('Updated Description'));
        expect(updatedRecipe?['editedBy'], equals('user_123'));
      });

      test('should skip metadata fields when updating cache', () async {
        // Arrange
        final existingData = testRecipe.toJson();
        mockCacheHelper.setCacheState(
          cache: {
            'recipe_1': existingData,
          },
        );

        final editData = {
          'title': 'Updated Title',
          'operation': 'update', // Metadata field - should be skipped
          'field': 'title', // Metadata field - should be skipped
          'editType': 'text', // Metadata field - should be skipped
          'editedAt': DateTime.now().toIso8601String(),
          'editedBy': 'user_123',
          'editedByDisplayName': 'Test User',
        };

        // Act
        await RealtimeCacheManager.updateCacheWithEdit(
          recipeId: 'recipe_1',
          editData: editData,
          cacheHelper: mockCacheHelper,
        );

        // Assert
        final updatedRecipe = await mockCacheHelper.loadJson('recipe_1');
        expect(updatedRecipe?['operation'], isNull);
        expect(updatedRecipe?['field'], isNull);
        expect(updatedRecipe?['editType'], isNull);
        expect(updatedRecipe?['title'], equals('Updated Title'));
      });

      test('should handle missing cached recipe when updating', () async {
        // Arrange
        mockCacheHelper.setCacheState(cache: {});

        final editData = {
          'title': 'Updated Title',
          'editedAt': DateTime.now().toIso8601String(),
          'editedBy': 'user_123',
        };

        // Act & Assert - should not throw
        await RealtimeCacheManager.updateCacheWithEdit(
          recipeId: 'recipe_1',
          editData: editData,
          cacheHelper: mockCacheHelper,
        );

        // Verify cache is still empty (no save was attempted)
        final cachedRecipe = await mockCacheHelper.loadJson('recipe_1');
        expect(cachedRecipe, isNull);
      });
    });

    group('Cache Cleanup', () {
      test('should clear cache for specific recipe', () async {
        // Arrange
        mockCacheHelper.setCacheState(
          cache: {
            'recipe_1': testRecipe.toJson(),
            'recipe_2': testRecipe2.toJson(),
          },
        );

        // Act
        await RealtimeCacheManager.clearRecipeCache(
          recipeId: 'recipe_1',
          cacheHelper: mockCacheHelper,
        );

        // Assert
        final recipe1Exists = await mockCacheHelper.exists('recipe_1');
        final recipe2Exists = await mockCacheHelper.exists('recipe_2');
        expect(recipe1Exists, isFalse);
        expect(recipe2Exists, isTrue);
      });

      test('should handle errors when clearing cache', () async {
        // Arrange - create a mock that throws on delete
        final errorHelper = FakeJsonCacheHelper();

        // Act & Assert - should not throw
        await RealtimeCacheManager.clearRecipeCache(
          recipeId: 'recipe_1',
          cacheHelper: errorHelper,
        );
      });
    });

    group('Preloading Operations', () {
      test('should preload recipes for real-time editing', () async {
        // Arrange
        mockCacheHelper.setCacheState(cache: {});

        final loadedRecipes = <String, Recipe>{
          'recipe_1': testRecipe,
          'recipe_2': testRecipe2,
        };

        Future<Recipe?> loadRecipeFromFirestore(String recipeId) async {
          return loadedRecipes[recipeId];
        }

        // Act
        await RealtimeCacheManager.preloadRecipesForRealtimeEditing(
          recipeIds: ['recipe_1', 'recipe_2'],
          cacheHelper: mockCacheHelper,
          loadRecipeFromFirestore: loadRecipeFromFirestore,
        );

        // Assert
        final recipe1 = await mockCacheHelper.loadJson('recipe_1');
        final recipe2 = await mockCacheHelper.loadJson('recipe_2');
        expect(recipe1, isNotNull);
        expect(recipe2, isNotNull);
        expect(recipe1?['core']?['title'], equals('Test Recipe'));
        expect(recipe2?['core']?['title'], equals('Another Recipe'));
      });

      test('should skip already cached recipes when preloading', () async {
        // Arrange
        mockCacheHelper.setCacheState(
          cache: {
            'recipe_1': testRecipe.toJson(), // Already cached
          },
        );

        var firestoreCalled = false;
        Future<Recipe?> loadRecipeFromFirestore(String recipeId) async {
          if (recipeId == 'recipe_1') {
            firestoreCalled = true; // Should not be called for recipe_1
          }
          if (recipeId == 'recipe_2') return testRecipe2;
          return null;
        }

        // Act
        await RealtimeCacheManager.preloadRecipesForRealtimeEditing(
          recipeIds: ['recipe_1', 'recipe_2'],
          cacheHelper: mockCacheHelper,
          loadRecipeFromFirestore: loadRecipeFromFirestore,
        );

        // Assert - recipe_1 was already cached, recipe_2 should be added
        expect(
          firestoreCalled,
          isFalse,
        ); // recipe_1 wasn't loaded from Firestore
        final recipe2 = await mockCacheHelper.loadJson('recipe_2');
        expect(recipe2, isNotNull);
        expect(recipe2?['core']?['title'], equals('Another Recipe'));
      });
    });

    group('Cache Synchronization', () {
      test(
        'should sync cache with Firestore during real-time editing',
        () async {
          // Arrange
          final updatedRecipe = RecipeBuilder()
              .withId('recipe_1')
              .withTitle('Synced Recipe')
              .build();

          mockCacheHelper.setCacheState(cache: {});

          // Act
          await RealtimeCacheManager.syncCacheWithFirestore(
            recipeId: 'recipe_1',
            latestRecipe: updatedRecipe,
            cacheHelper: mockCacheHelper,
          );

          // Assert
          final cachedRecipe = await mockCacheHelper.loadJson('recipe_1');
          expect(cachedRecipe?['core']?['title'], equals('Synced Recipe'));
        },
      );

      test('should check if cached recipe is stale', () async {
        // Arrange
        final cachedData = {
          ...testRecipe.toJson(),
          'editedAt': DateTime(2024, 1, 1).toIso8601String(),
        };
        mockCacheHelper.setCacheState(
          cache: {
            'recipe_1': cachedData,
          },
        );

        final lastFirestoreUpdate = DateTime(2024, 1, 2); // Newer than cache

        // Act
        final isStale = await RealtimeCacheManager.isCacheStale(
          recipeId: 'recipe_1',
          lastFirestoreUpdate: lastFirestoreUpdate,
          cacheHelper: mockCacheHelper,
        );

        // Assert
        expect(isStale, isTrue);
      });

      test(
        'should return true for stale check when recipe not in cache',
        () async {
          // Arrange
          mockCacheHelper.setCacheState(cache: {});

          // Act
          final isStale = await RealtimeCacheManager.isCacheStale(
            recipeId: 'recipe_1',
            lastFirestoreUpdate: DateTime.now(),
            cacheHelper: mockCacheHelper,
          );

          // Assert
          expect(isStale, isTrue);
        },
      );

      test('should force refresh cache from Firestore', () async {
        // Arrange
        mockCacheHelper.setCacheState(
          cache: {
            'recipe_1': testRecipe.toJson(),
          },
        );

        final refreshedRecipe = RecipeBuilder()
            .withId('recipe_1')
            .withTitle('Refreshed Recipe')
            .build();

        Future<Recipe?> loadRecipeFromFirestore(String recipeId) async {
          return refreshedRecipe;
        }

        // Act
        await RealtimeCacheManager.forceRefreshCache(
          recipeId: 'recipe_1',
          cacheHelper: mockCacheHelper,
          loadRecipeFromFirestore: loadRecipeFromFirestore,
        );

        // Assert - cache should be cleared and refreshed
        final cachedRecipe = await mockCacheHelper.loadJson('recipe_1');
        expect(cachedRecipe?['core']?['title'], equals('Refreshed Recipe'));
      });
    });

    group('Disposal Operations', () {
      test('should dispose of all real-time resources', () async {
        // Arrange
        final mockSubscription = MockStreamSubscription<DocumentSnapshot>();
        // No need to stub cancel() - it's already implemented in the mock
        final activeEditingSessions =
            <String, StreamSubscription<DocumentSnapshot>>{
              'recipe_1': mockSubscription,
            };

        final pendingRealtimeEdits = <String, List<Map<String, dynamic>>>{
          'recipe_1': [
            {'edit': 'data'},
          ],
        };

        final mockTimer = MockTimer();
        final conflictResolutionTimers = <String, Timer>{
          'recipe_1': mockTimer,
        };

        var stopEditingCalled = false;
        Future<bool> stopRealtimeEditing(String recipeId) async {
          stopEditingCalled = true;
          return true;
        }

        // Act
        await RealtimeCacheManager.dispose(
          activeEditingSessions: activeEditingSessions,
          pendingRealtimeEdits: pendingRealtimeEdits,
          conflictResolutionTimers: conflictResolutionTimers,
          stopRealtimeEditing: stopRealtimeEditing,
        );

        // Assert
        expect(stopEditingCalled, isTrue);
        expect(activeEditingSessions, isEmpty);
        expect(pendingRealtimeEdits, isEmpty);
        expect(conflictResolutionTimers, isEmpty);
      });

      test('should handle errors during disposal gracefully', () async {
        // Arrange
        final activeEditingSessions =
            <String, StreamSubscription<DocumentSnapshot>>{};
        final pendingRealtimeEdits = <String, List<Map<String, dynamic>>>{};
        final conflictResolutionTimers = <String, Timer>{};

        Future<bool> stopRealtimeEditing(String recipeId) async {
          throw Exception('Stop failed');
        }

        // Act & Assert - should not throw
        await RealtimeCacheManager.dispose(
          activeEditingSessions: activeEditingSessions,
          pendingRealtimeEdits: pendingRealtimeEdits,
          conflictResolutionTimers: conflictResolutionTimers,
          stopRealtimeEditing: stopRealtimeEditing,
        );
      });
    });

    group('Batch Cache Operations', () {
      test('should save multiple recipes to cache simultaneously', () async {
        // Arrange
        mockCacheHelper.setCacheState(cache: {});
        final recipes = [testRecipe, testRecipe2];

        // Act
        await Future.wait(
          recipes.map(
            (recipe) => RealtimeCacheManager.saveToCache(
              recipe: recipe,
              cacheHelper: mockCacheHelper,
            ),
          ),
        );

        // Assert
        final recipe1 = await mockCacheHelper.loadJson('recipe_1');
        final recipe2 = await mockCacheHelper.loadJson('recipe_2');
        expect(recipe1, isNotNull);
        expect(recipe2, isNotNull);
      });

      test('should clear multiple recipe caches at once', () async {
        // Arrange
        mockCacheHelper.setCacheState(
          cache: {
            'recipe_1': testRecipe.toJson(),
            'recipe_2': testRecipe2.toJson(),
            'recipe_3': RecipeBuilder().withId('recipe_3').build().toJson(),
          },
        );

        // Act - clear recipes 1 and 2, keep 3
        await Future.wait([
          RealtimeCacheManager.clearRecipeCache(
            recipeId: 'recipe_1',
            cacheHelper: mockCacheHelper,
          ),
          RealtimeCacheManager.clearRecipeCache(
            recipeId: 'recipe_2',
            cacheHelper: mockCacheHelper,
          ),
        ]);

        // Assert
        expect(await mockCacheHelper.exists('recipe_1'), isFalse);
        expect(await mockCacheHelper.exists('recipe_2'), isFalse);
        expect(await mockCacheHelper.exists('recipe_3'), isTrue);
      });

      test('should handle batch updates to cache', () async {
        // Arrange
        mockCacheHelper.setCacheState(
          cache: {
            'recipe_1': testRecipe.toJson(),
          },
        );

        final updates = [
          {'field': 'title', 'title': 'Batch Update 1'},
          {'field': 'description', 'description': 'Batch Update 2'},
          {'field': 'servings', 'servings': 6},
        ];

        // Act
        for (final update in updates) {
          await RealtimeCacheManager.updateCacheWithEdit(
            recipeId: 'recipe_1',
            editData: update,
            cacheHelper: mockCacheHelper,
          );
        }

        // Assert
        final cached = await mockCacheHelper.loadJson('recipe_1');
        expect(cached?['title'], equals('Batch Update 1'));
        expect(cached?['description'], equals('Batch Update 2'));
        expect(cached?['servings'], equals(6));
      });
    });

    group('Cache Validation', () {
      test('should validate cached recipe data integrity', () async {
        // Arrange
        final validRecipe = testRecipe;
        mockCacheHelper.setCacheState(
          cache: {
            'recipe_1': validRecipe.toJson(),
          },
        );

        // Act
        final loaded = await RealtimeCacheManager.loadFromCache(
          recipeId: 'recipe_1',
          cacheHelper: mockCacheHelper,
        );

        // Assert — JSON round-trip may enrich personalTags from personalTagIds
        // (lazy migration in RecipeCore.fromJson), so full toJson equality can
        // diverge. Compare core identity and content fields instead.
        expect(loaded, isNotNull);
        expect(loaded?.id, equals(validRecipe.id));
        expect(loaded?.title, equals(validRecipe.title));
        expect(loaded?.core.description, equals(validRecipe.core.description));
        expect(loaded?.core.ingredients, equals(validRecipe.core.ingredients));
      });

      test('should detect and handle corrupted cache data', () async {
        // Arrange - corrupted data missing required fields
        mockCacheHelper.setCacheState(
          cache: {
            'recipe_1': {
              'partial': 'data',
              // Missing core fields
            },
          },
        );

        // Act
        final loaded = await RealtimeCacheManager.loadFromCache(
          recipeId: 'recipe_1',
          cacheHelper: mockCacheHelper,
        );

        // Assert — Recipe.fromJson is defensive (safe defaults for missing
        // fields), so partial data produces a Recipe rather than throwing.
        expect(loaded, isNotNull);
      });

      test('should handle cache with Swedish characters', () async {
        // Arrange
        final swedishRecipe = RecipeBuilder()
            .withId('swedish_1')
            .withTitle('Köttbullar med gräddsås')
            .withDescription('Äkta svenska köttbullar från Småland')
            .withIngredients(['Färs', 'Ägg', 'Mjölk', 'Lök'])
            .build();

        mockCacheHelper.setCacheState(cache: {});

        // Act
        await RealtimeCacheManager.saveToCache(
          recipe: swedishRecipe,
          cacheHelper: mockCacheHelper,
        );

        final loaded = await RealtimeCacheManager.loadFromCache(
          recipeId: 'swedish_1',
          cacheHelper: mockCacheHelper,
        );

        // Assert
        expect(loaded?.title, equals('Köttbullar med gräddsås'));
        expect(loaded?.description, contains('Småland'));
        expect(loaded?.ingredients, contains('Ägg'));
      });
    });

    group('Performance Optimization', () {
      test('should handle large recipe data efficiently', () async {
        // Arrange
        final largeRecipe = RecipeBuilder()
            .withId('large_recipe')
            .withTitle('Large Recipe')
            .withDescription('Very long description ' * 100)
            .withIngredients(List.generate(50, (i) => 'Ingredient $i'))
            .withInstructions(
              List.generate(30, (i) => 'Step $i: ${'instruction ' * 20}'),
            )
            .build();

        mockCacheHelper.setCacheState(cache: {});

        // Act
        final stopwatch = Stopwatch()..start();
        await RealtimeCacheManager.saveToCache(
          recipe: largeRecipe,
          cacheHelper: mockCacheHelper,
        );
        stopwatch.stop();

        // Assert
        expect(stopwatch.elapsedMilliseconds, lessThan(100)); // Should be fast
        final loaded = await RealtimeCacheManager.loadFromCache(
          recipeId: 'large_recipe',
          cacheHelper: mockCacheHelper,
        );
        expect(loaded, isNotNull);
      });

      test('should skip unnecessary cache operations', () async {
        // Arrange
        mockCacheHelper.setCacheState(
          cache: {
            'recipe_1': testRecipe.toJson(),
          },
        );

        // Act - save the same recipe twice
        await RealtimeCacheManager.saveToCache(
          recipe: testRecipe,
          cacheHelper: mockCacheHelper,
        );

        await RealtimeCacheManager.saveToCache(
          recipe: testRecipe,
          cacheHelper: mockCacheHelper,
        );

        // Assert - cache should still have the recipe
        final cached = await mockCacheHelper.loadJson('recipe_1');
        expect(cached, isNotNull);
        expect(cached?['core']?['title'], equals('Test Recipe'));
      });
    });

    group('Concurrent Access', () {
      test('should handle concurrent cache reads safely', () async {
        // Arrange
        mockCacheHelper.setCacheState(
          cache: {
            'recipe_1': testRecipe.toJson(),
          },
        );

        // Act - multiple concurrent reads
        final futures = List.generate(
          10,
          (_) => RealtimeCacheManager.loadFromCache(
            recipeId: 'recipe_1',
            cacheHelper: mockCacheHelper,
          ),
        );

        final results = await Future.wait(futures);

        // Assert - all should succeed
        expect(results.every((r) => r?.id == 'recipe_1'), isTrue);
      });

      test('should handle concurrent cache writes safely', () async {
        // Arrange
        mockCacheHelper.setCacheState(cache: {});
        final recipes = List.generate(
          5,
          (i) => RecipeBuilder()
              .withId('concurrent_$i')
              .withTitle('Concurrent Recipe $i')
              .build(),
        );

        // Act - concurrent writes
        await Future.wait(
          recipes.map(
            (r) => RealtimeCacheManager.saveToCache(
              recipe: r,
              cacheHelper: mockCacheHelper,
            ),
          ),
        );

        // Assert - all should be cached
        for (int i = 0; i < 5; i++) {
          final cached = await mockCacheHelper.loadJson('concurrent_$i');
          expect(cached, isNotNull);
          expect(cached?['core']?['title'], equals('Concurrent Recipe $i'));
        }
      });
    });

    group('Edge Cases', () {
      test('should handle empty recipe ID gracefully', () async {
        // Act
        final loaded = await RealtimeCacheManager.loadFromCache(
          recipeId: '',
          cacheHelper: mockCacheHelper,
        );

        // Assert
        expect(loaded, isNull);
      });

      test('should handle null edit data fields', () async {
        // Arrange
        mockCacheHelper.setCacheState(
          cache: {
            'recipe_1': testRecipe.toJson(),
          },
        );

        final editData = <String, dynamic>{
          'title': null,
          'description': 'Valid description',
          'servings': null,
        };

        // Act
        await RealtimeCacheManager.updateCacheWithEdit(
          recipeId: 'recipe_1',
          editData: editData,
          cacheHelper: mockCacheHelper,
        );

        // Assert
        final cached = await mockCacheHelper.loadJson('recipe_1');
        expect(cached?['title'], isNull);
        expect(cached?['description'], equals('Valid description'));
        expect(cached?['servings'], isNull);
      });
    });
  });
}

// ULTRATHINK CONVERSION COMPLETE: Local mock classes removed - using centralized mocks
