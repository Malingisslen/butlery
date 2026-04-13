/// Unit tests for RecipeCacheModule
///
/// Tests cache initialization, CRUD, sync scheduling, auth state,
/// and diagnostics. Uses MockJsonCacheHelper's concrete behavior
/// (not when() stubs) since that mock has @override implementations.
library;

import 'package:flutter_test/flutter_test.dart';
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

    String? currentUserId;
    int notifyListenersCalled = 0;

    setUpAll(() async {
      await BaseUnitTest.setupUnit();
    });

    setUp(() {
      mockCacheHelper = MockJsonCacheHelper();
      fakeFirestore = FirestoreSingleton.instance;

      currentUserId = 'test-user-123';
      notifyListenersCalled = 0;

      testRecipe = RecipeFactory.build(
        id: 'test-recipe-1',
        title: 'Köttbullar',
        createdBy: 'test-user-123',
      );

      module = RecipeCacheModule(
        firestore: fakeFirestore,
        cacheHelper: mockCacheHelper,
        getCurrentUserId: () => currentUserId,
        setError: (error) {},
        notifyListeners: () => notifyListenersCalled++,
      );
    });

    tearDown(() async {
      await module.dispose();
      BaseUnitTest.resetMocks();
      await TestServiceLocator.reset();
    });

    tearDownAll(() async {
      await BaseUnitTest.teardownUnit();
    });

    group('Cache Operations', () {
      test('should save and load recipe from cache', () async {
        await module.saveRecipeToCache(testRecipe);

        final loaded = await module.loadRecipeFromCache('test-recipe-1');
        expect(loaded, isNotNull);
        expect(loaded!.id, equals('test-recipe-1'));
        expect(loaded.title, equals('Köttbullar'));
      });

      test('should return null for missing recipe', () async {
        final loaded = await module.loadRecipeFromCache('nonexistent');
        expect(loaded, isNull);
      });

      test('should remove recipe from cache', () async {
        await module.saveRecipeToCache(testRecipe);
        await module.removeRecipeFromCache('test-recipe-1');

        final loaded = await module.loadRecipeFromCache('test-recipe-1');
        expect(loaded, isNull);
      });

      test('should clear all cached recipes', () async {
        await module.saveRecipeToCache(testRecipe);
        final recipe2 = RecipeFactory.build(id: 'recipe-2', title: 'Pannkakor');
        await module.saveRecipeToCache(recipe2);

        await module.clearCache();

        final count = await module.getCachedRecipeCount();
        expect(count, equals(0));
      });

      test('should count cached recipes', () async {
        await module.saveRecipeToCache(testRecipe);
        final recipe2 = RecipeFactory.build(id: 'recipe-2', title: 'Pannkakor');
        await module.saveRecipeToCache(recipe2);

        final count = await module.getCachedRecipeCount();
        expect(count, equals(2));
      });
    });

    group('Cache Initialization', () {
      test('should initialize and load cached recipes', () async {
        // Pre-populate cache via the mock's concrete saveJson
        mockCacheHelper.setCacheState(
          cache: {
            'test-recipe-1': testRecipe.toJson(),
          },
        );

        final recipes = await module.initializeCache();
        expect(recipes, isA<List<Recipe>>());
      });

      test('should return empty list when cache is empty', () async {
        final recipes = await module.initializeCache();
        expect(recipes, isEmpty);
      });
    });

    group('Firebase Synchronization', () {
      test('should start Firebase sync for authenticated user', () async {
        await module.startFirebaseSync();
        // Should complete without error
      });

      test('should not start sync when user not authenticated', () async {
        currentUserId = null;
        await module.startFirebaseSync();
        expect(module.isSyncing, isFalse);
      });

      test('should stop Firebase sync', () async {
        await module.startFirebaseSync();
        await module.stopFirebaseSync();
        expect(module.isSyncing, isFalse);
      });

      test('should not start sync when no Firestore instance', () async {
        final noFirestoreModule = RecipeCacheModule(
          firestore: null,
          cacheHelper: mockCacheHelper,
          getCurrentUserId: () => currentUserId,
          setError: (error) {},
          notifyListeners: () {},
        );

        await noFirestoreModule.startFirebaseSync();
        expect(noFirestoreModule.isSyncing, isFalse);
        await noFirestoreModule.dispose();
      });
    });

    group('Debounced Sync Operations', () {
      test('should schedule recipe for sync', () {
        module.scheduleSyncForRecipe('recipe-1');
        expect(module.hasPendingSync, isTrue);
        expect(module.pendingSyncCount, equals(1));
      });

      test('should batch multiple sync requests', () {
        module.scheduleSyncForRecipe('recipe-1');
        module.scheduleSyncForRecipe('recipe-2');
        module.scheduleSyncForRecipe('recipe-3');
        expect(module.pendingSyncCount, equals(3));
      });

      test('should deduplicate sync requests for same recipe', () {
        module.scheduleSyncForRecipe('recipe-1');
        module.scheduleSyncForRecipe('recipe-1');
        module.scheduleSyncForRecipe('recipe-1');
        expect(module.pendingSyncCount, equals(1));
      });
    });

    group('Auth State Handling', () {
      test('should handle user login', () {
        module.onAuthStateChanged('new-user-456');
        // Should complete without error
      });

      test('should handle user logout and clear cache', () {
        module.onAuthStateChanged(null);
        // Should clear cache and stop sync without error
      });
    });

    group('Status and Diagnostics', () {
      test('should get sync status map', () {
        final status = module.getSyncStatus();
        expect(status, isA<Map<String, dynamic>>());
        expect(status.containsKey('subscriptionCount'), isTrue);
        expect(status.containsKey('isSyncing'), isTrue);
      });

      test('should report not syncing initially', () {
        expect(module.isSyncing, isFalse);
      });

      test('should report no pending writes initially', () {
        expect(module.hasPendingWrites, isFalse);
      });

      test('should report not from cache initially', () {
        expect(module.isFromCache, isFalse);
      });

      test('should get cache statistics', () async {
        final stats = await module.getCacheStatistics();
        expect(stats, isA<Map<String, dynamic>>());
        expect(stats.containsKey('is_syncing'), isTrue);
      });
    });

    group('Dispose', () {
      test('should dispose without error', () async {
        module.scheduleSyncForRecipe('recipe-1');
        await module.startFirebaseSync();
        await module.dispose();
        // Should complete without error
      });
    });
  });
}
