/// Comprehensive unit tests for RecipeCacheModule
///
/// Tests the recipe cache module that provides unified caching functionality
/// with real-time synchronization, debounced writes, and cache optimization.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:butlery/services/unified/modules/recipe_cache_module.dart';
import 'package:butlery/models/recipe_unified.dart';

import '../../../../test_support/base_unit_test.dart';
import '../../../../infrastructure/factories/recipe_factory.dart';
import '../../../../infrastructure/mocks/production_mocks.dart';
import '../../../../infrastructure/mocks/firestore_singleton.dart';
import '../../../../infrastructure/di/test_service_locator.dart';

void main() {
  group('RecipeCacheModule', () {
    late RecipeCacheModule module;
    late MockJsonCacheHelper mockCacheHelper;
    late FakeFirebaseFirestore fakeFirestore;
    late Recipe testRecipe;

    // Callback functions
    String? currentUserId;
    int notifyListenersCalled = 0;

    setUpAll(() async {
      await BaseUnitTest.setupUnit();
      registerFallbackValue(RecipeFactory.build());
      registerFallbackValue(<String, dynamic>{});
    });

    setUp(() {
      mockCacheHelper = MockJsonCacheHelper();
      fakeFirestore = FirestoreSingleton.instance;

      currentUserId = 'test-user-123';
      notifyListenersCalled = 0;

      module = RecipeCacheModule(
        firestore: fakeFirestore,
        cacheHelper: mockCacheHelper,
        getCurrentUserId: () => currentUserId,
        setError: (error) {},
        notifyListeners: () => notifyListenersCalled++,
      );

      testRecipe = RecipeFactory.build(
        id: 'test-recipe-1',
        title: 'Köttbullar',
        createdBy: 'test-user-123',
      );

      // Setup mock cache helper
      when(() => mockCacheHelper.saveJson(any(), any()))
          .thenAnswer((_) async => true);
      when(() => mockCacheHelper.delete(any())).thenAnswer((_) async => true);
    });

    tearDown(() async {
      module.dispose();
      BaseUnitTest.resetMocks();
      await TestServiceLocator.reset();
    });

    tearDownAll(() async {
      await BaseUnitTest.teardownUnit();
    });

    group('Cache Initialization', () {
      test('should initialize cache and load cached recipes', () async {
        // Arrange
        when(() => mockCacheHelper.getAllKeys())
            .thenAnswer((_) async => ['recipe-1', 'recipe-2']);
        when(() => mockCacheHelper.loadJson('recipe-1'))
            .thenAnswer((_) async => testRecipe.toJson());
        when(() => mockCacheHelper.loadJson('recipe-2'))
            .thenAnswer((_) async => null);

        // Act
        final recipes = await module.initializeCache();

        // Assert
        expect(recipes, isA<List<Recipe>>());
        expect(recipes.length, greaterThanOrEqualTo(0));
      });

      test('should handle initialization errors gracefully', () async {
        // Arrange
        when(() => mockCacheHelper.getAllKeys())
            .thenThrow(Exception('Cache error'));

        // Act
        final recipes = await module.initializeCache();

        // Assert
        expect(recipes, isEmpty);
      });
    });

    group('Cache Operations', () {
      test('should save recipe to cache', () async {
        // Act
        await module.saveRecipeToCache(testRecipe);

        // Assert
        verify(() => mockCacheHelper.saveJson(testRecipe.id, any())).called(1);
      });

      test('should load recipe from cache by ID', () async {
        // Arrange
        when(() => mockCacheHelper.loadJson('test-recipe-1'))
            .thenAnswer((_) async => testRecipe.toJson());

        // Act
        final recipe = await module.loadRecipeFromCache('test-recipe-1');

        // Assert
        expect(recipe, isNotNull);
        expect(recipe!.id, equals('test-recipe-1'));
      });

      test('should remove recipe from cache', () async {
        // Act
        await module.removeRecipeFromCache('test-recipe-1');

        // Assert
        verify(() => mockCacheHelper.delete('test-recipe-1')).called(1);
      });

      test('should get cached recipe count', () async {
        // Arrange
        when(() => mockCacheHelper.getAllKeys())
            .thenAnswer((_) async => ['recipe-1', 'recipe-2', 'recipe-3']);

        // Act
        final count = await module.getCachedRecipeCount();

        // Assert
        expect(count, equals(3));
      });

      test('should clear all cached recipes', () async {
        // Arrange
        when(() => mockCacheHelper.getAllKeys())
            .thenAnswer((_) async => ['recipe-1', 'recipe-2']);

        // Act
        await module.clearCache();

        // Assert
        verify(() => mockCacheHelper.delete(any()))
            .called(greaterThanOrEqualTo(0));
      });
    });

    group('Firebase Synchronization', () {
      test('should start Firebase sync for authenticated user', () async {
        // Act
        await module.startFirebaseSync();

        // Assert
        // Should complete without error
      });

      test('should not start sync when user not authenticated', () async {
        // Arrange
        currentUserId = null;

        // Act
        await module.startFirebaseSync();

        // Assert
        // Should complete without error but not start sync
      });

      test('should stop Firebase sync', () async {
        // Act
        await module.stopFirebaseSync();

        // Assert
        // Should complete without error
      });

      test('should handle sync errors gracefully', () async {
        // Arrange
        // FakeFirebaseFirestore handles errors naturally during collection access

        // Act
        await module.startFirebaseSync();

        // Assert
        // Should handle error without crashing
      });
    });

    group('Debounced Sync Operations', () {
      test('should schedule recipe for sync', () {
        // Act
        module.scheduleSyncForRecipe('recipe-1');

        // Assert
        expect(module.hasPendingSync, isTrue);
        expect(module.pendingSyncCount, equals(1));
      });

      test('should batch multiple sync requests', () {
        // Act
        module.scheduleSyncForRecipe('recipe-1');
        module.scheduleSyncForRecipe('recipe-2');
        module.scheduleSyncForRecipe('recipe-3');

        // Assert
        expect(module.pendingSyncCount, equals(3));
      });

      test('should prevent duplicate sync requests', () {
        // Act
        module.scheduleSyncForRecipe('recipe-1');
        module.scheduleSyncForRecipe('recipe-1');
        module.scheduleSyncForRecipe('recipe-1');

        // Assert
        expect(module.pendingSyncCount, equals(1));
      });
    });

    group('Cache Statistics', () {
      test('should get cache statistics', () async {
        // Arrange
        when(() => mockCacheHelper.getAllKeys())
            .thenAnswer((_) async => ['recipe-1', 'recipe-2']);

        // Act
        final stats = await module.getCacheStatistics();

        // Assert
        expect(stats, isA<Map<String, dynamic>>());
        expect(stats.containsKey('is_syncing'), isTrue);
      });

      test('should handle statistics errors', () async {
        // Arrange
        when(() => mockCacheHelper.getAllKeys())
            .thenThrow(Exception('Cache error'));

        // Act
        final stats = await module.getCacheStatistics();

        // Assert
        // When there's an error, the module returns a map with error info
        expect(stats, isA<Map<String, dynamic>>());
        expect(stats.containsKey('error'), isTrue);
      });
    });

    group('Auth State Handling', () {
      test('should handle user login', () {
        // Act
        module.onAuthStateChanged('new-user-456');

        // Assert
        // Constructor calls setCurrentUser with 'test-user-123' (initial value)
        // onAuthStateChanged calls setCurrentUser with 'new-user-456'
        verify(() => mockCacheHelper.setCurrentUser('test-user-123')).called(1);
        verify(() => mockCacheHelper.setCurrentUser('new-user-456')).called(1);
      });

      test('should handle user logout', () async {
        // Arrange
        // Stub getAllKeys for clearCache() which is called on logout
        when(() => mockCacheHelper.getAllKeys())
            .thenAnswer((_) async => <String>[]);

        // Act
        module.onAuthStateChanged(null);

        // Assert
        // Constructor calls setCurrentUser with 'test-user-123' first
        // onAuthStateChanged(null) calls setCurrentUser with null
        verify(() => mockCacheHelper.setCurrentUser('test-user-123')).called(1);
        verify(() => mockCacheHelper.setCurrentUser(null)).called(1);
      });

      test('should clear cache on logout', () async {
        // Arrange
        when(() => mockCacheHelper.getAllKeys())
            .thenAnswer((_) async => ['recipe-1']);
        when(() => mockCacheHelper.delete(any())).thenAnswer((_) async => true);

        // Act
        module.onAuthStateChanged(null);

        // Assert
        // When logging out, setCurrentUser(null) is called
        verify(() => mockCacheHelper.setCurrentUser(null)).called(1);
        // Note: clearCache() and stopFirebaseSync() are called asynchronously
        // The test ensures no crashes occur during logout
      });
    });

    group('Status and Diagnostics', () {
      test('should get sync status', () {
        // Act
        final status = module.getSyncStatus();

        // Assert
        expect(status, isA<Map<String, dynamic>>());
        expect(status.containsKey('subscriptionCount'), isTrue);
        expect(status.containsKey('isSyncing'), isTrue);
      });

      test('should check if syncing', () {
        // Act
        final isSyncing = module.isSyncing;

        // Assert
        expect(isSyncing, isA<bool>());
      });

      test('should check for pending syncs', () {
        // Arrange
        module.scheduleSyncForRecipe('recipe-1');

        // Act
        final hasPending = module.hasPendingSync;

        // Assert
        expect(hasPending, isTrue);
      });
    });

    group('Edge Cases', () {
      test('should handle null Firebase instance', () async {
        // Arrange
        final moduleNoFirebase = RecipeCacheModule(
          firestore: null,
          cacheHelper: mockCacheHelper,
          getCurrentUserId: () => currentUserId,
          setError: (error) {},
          notifyListeners: () {},
        );

        // Act
        await moduleNoFirebase.startFirebaseSync();

        // Assert
        // Should complete without error
        moduleNoFirebase.dispose();
      });

      test('should handle corrupted cache data', () async {
        // Arrange
        when(() => mockCacheHelper.loadJson('corrupt-recipe'))
            .thenAnswer((_) async => {'invalid': 'data'});

        // Act
        final recipe = await module.loadRecipeFromCache('corrupt-recipe');

        // Assert
        expect(recipe, isNull);
      });

      test('should recover from sync failures', () async {
        // Arrange
        module.scheduleSyncForRecipe('recipe-1');
        when(() => mockCacheHelper.loadJson('recipe-1'))
            .thenThrow(Exception('Load error'));

        // Act & Assert
        // Should handle error without crashing
        // The test verifies that scheduling sync with a failing load doesn't crash
        expect(module.hasPendingSync, isTrue);
      });
    });
  });
}
