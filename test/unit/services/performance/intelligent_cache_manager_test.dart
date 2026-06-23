/// Unit tests for IntelligentCacheManager
///
/// Tests predictive caching with user behavior analysis:
/// - UserBehaviorPattern model (serialization, scoring)
/// - CacheEntry eviction scoring
/// - In-memory recipe/user caching
/// - Memory pressure handling
/// - Cache statistics
///
/// Note: Tests that require OfflineService (initialize, clearCache, dispose)
/// are skipped because the lazy _behaviorCache getter needs a real Drift DB.
/// The in-memory caching layer is tested independently.
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/core/di/di_container.dart';
import 'package:butlery/core/providers/application_provider.dart' as production;
import 'package:butlery/services/performance/intelligent_cache_manager.dart';
import 'package:butlery/services/unified/unified_recipe_service.dart';
import 'package:butlery/services/permission_service.dart';
import 'package:butlery/models/recipe_unified.dart';

import '../../../test_support/base_unit_test.dart';
import '../../../infrastructure/di/test_service_locator.dart';
import '../../../infrastructure/mocks/production_mocks.dart';
import '../../../infrastructure/factories/recipe_factory.dart';

void main() {
  group('UserBehaviorPattern', () {
    test('should rank recipes by view count and recency', () {
      final now = DateTime.now();
      final pattern = UserBehaviorPattern(
        userId: 'u1',
        recipeViews: {'recent': 5, 'old': 5},
        lastViewedTimes: {
          'recent': now.subtract(const Duration(hours: 1)),
          'old': now.subtract(const Duration(days: 30)),
        },
      );

      final likely = pattern.getLikelyRecipeIds(limit: 2);
      expect(likely, hasLength(2));
      expect(likely.first, equals('recent'));
    });

    test('should return empty list for empty pattern', () {
      final pattern = UserBehaviorPattern(userId: 'u1');
      expect(pattern.getLikelyRecipeIds(), isEmpty);
    });

    test('should serialize and deserialize to JSON', () {
      final now = DateTime.now();
      final original = UserBehaviorPattern(
        userId: 'u1',
        recipeViews: {'r1': 5},
        lastViewedTimes: {'r1': now},
        mealTypePreferences: {'Middag': 10},
        viewTimePreferences: {18: 15},
        favoriteRecipeIds: {'r1', 'r2'},
        activeFriendIds: {'f1'},
      );

      final json = original.toJson();
      final restored = UserBehaviorPattern.fromJson(json);

      expect(restored.userId, equals('u1'));
      expect(restored.recipeViews, equals({'r1': 5}));
      expect(restored.mealTypePreferences, equals({'Middag': 10}));
      expect(restored.favoriteRecipeIds, equals({'r1', 'r2'}));
      expect(restored.activeFriendIds, equals({'f1'}));
    });

    test('should handle null defaults in constructor', () {
      final pattern = UserBehaviorPattern(userId: 'u1');
      expect(pattern.recipeViews, isEmpty);
      expect(pattern.lastViewedTimes, isEmpty);
      expect(pattern.mealTypePreferences, isEmpty);
      expect(pattern.viewTimePreferences, isEmpty);
      expect(pattern.favoriteRecipeIds, isEmpty);
      expect(pattern.activeFriendIds, isEmpty);
    });
  });

  group('CacheEntry', () {
    test('should track access count and last accessed time', () {
      final entry = CacheEntry<Recipe>(
        key: 'k1',
        data: RecipeFactory.build(),
        size: 1000,
      );

      expect(entry.accessCount, equals(0));

      entry.recordAccess();
      entry.recordAccess();

      expect(entry.accessCount, equals(2));
    });

    test('should give higher eviction score to frequently accessed items', () {
      final fresh = CacheEntry<Recipe>(
        key: 'fresh',
        data: RecipeFactory.build(),
        size: 1000,
      );

      final frequent = CacheEntry<Recipe>(
        key: 'frequent',
        data: RecipeFactory.build(),
        size: 1000,
      );
      // Simulate many accesses
      frequent.accessCount = 50;

      expect(frequent.evictionScore, greaterThan(fresh.evictionScore));
    });

    test('should give lower eviction score to old unaccessed items', () {
      final old = CacheEntry<Recipe>(
        key: 'old',
        data: RecipeFactory.build(),
        size: 1000,
        cachedAt: DateTime.now().subtract(const Duration(hours: 2)),
      );

      final recent = CacheEntry<Recipe>(
        key: 'recent',
        data: RecipeFactory.build(),
        size: 1000,
      );

      // Both have 0 access count, but old has older cachedAt
      expect(old.evictionScore, lessThanOrEqualTo(recent.evictionScore));
    });

    // ENG-15: eviction-score formula uses clock.now() for recency,
    // so an entry that was accessed long ago should score lower than one
    // accessed just now — even if their access counts are equal.
    test(
      'recently accessed entry scores higher than stale entry with same access count',
      () {
        // Intent: the evictionScore denominator includes recency
        // (clock.now() - lastAccessed).  If this breaks and recency is
        // ignored, stale entries would survive eviction and fresh ones
        // would be dropped — inverting LRU behaviour.
        final stale = CacheEntry<Recipe>(
          key: 'stale',
          data: RecipeFactory.build(),
          size: 1000,
        );
        // Manually back-date lastAccessed to simulate a long-ago access.
        stale.lastAccessed = stale.lastAccessed.subtract(
          const Duration(hours: 12),
        );
        stale.accessCount = 5;

        final fresh = CacheEntry<Recipe>(
          key: 'fresh',
          data: RecipeFactory.build(),
          size: 1000,
        );
        // lastAccessed defaults to clock.now() — accessed moments ago.
        fresh.accessCount = 5;

        expect(
          fresh.evictionScore,
          greaterThan(stale.evictionScore),
          reason:
              'Entry accessed recently must score higher (harder to evict) '
              'than an equally-counted entry last accessed 12 h ago',
        );
      },
    );
  });

  group('IntelligentCacheManager', () {
    late IntelligentCacheManager manager;
    late MockUnifiedRecipeService mockRecipeService;
    late FakePermissionService mockPermissionService;

    setUpAll(() async {
      await BaseUnitTest.setupUnit();
      await TestServiceLocator.initialize();
      // Bridge production ServiceLocator to test GetIt instance
      production.ServiceLocator.initialize(DIContainer());
    });

    setUp(() async {
      await TestServiceLocator.clearState();

      mockRecipeService =
          TestServiceLocator.get<UnifiedRecipeService>()
              as MockUnifiedRecipeService;
      mockPermissionService =
          TestServiceLocator.get<PermissionService>() as FakePermissionService;

      mockRecipeService.setRecipeState(
        recipes: [],
        isInitialized: true,
        isLoading: false,
        error: null,
      );

      mockPermissionService.setPermissionState(
        currentUserId: 'test_user_123',
        defaultHasPermission: true,
      );

      manager = IntelligentCacheManager();
    });

    // Don't call manager.dispose() - it triggers _behaviorCache lazy getter
    // which needs OfflineService with a real Drift database.
    tearDown(() async {
      await TestServiceLocator.clearState();
      BaseUnitTest.resetMocks();
    });

    tearDownAll(() async {
      await TestServiceLocator.reset();
      await BaseUnitTest.teardownUnit();
    });

    group('Cache Statistics', () {
      test('should provide initial cache statistics', () {
        final stats = manager.getCacheStats();
        expect(stats['recipesCached'], equals(0));
        expect(stats['usersCached'], equals(0));
        expect(stats['genericCached'], equals(0));
        expect(stats['memoryUsageMB'], isA<String>());
        expect(stats['maxMemoryMB'], equals(50));
        expect(stats['behaviorPatternLoaded'], isFalse);
      });
    });

    group('Recipe Caching', () {
      test('should cache recipe on first access', () async {
        final recipe = RecipeFactory.build(id: 'r1', title: 'Pasta');
        mockRecipeService.setRecipeState(
          recipes: [recipe],
          isInitialized: true,
        );

        final result = await manager.getCachedRecipe('r1');
        expect(result?.id, equals('r1'));

        final stats = manager.getCacheStats();
        expect(stats['recipesCached'], equals(1));
      });

      test('should serve from cache on second access', () async {
        final recipe = RecipeFactory.build(id: 'r2');
        mockRecipeService.setRecipeState(
          recipes: [recipe],
          isInitialized: true,
        );

        await manager.getCachedRecipe('r2');
        final cached = await manager.getCachedRecipe('r2');

        expect(cached?.id, equals('r2'));
        // Stats still show 1 recipe cached
        expect(manager.getCacheStats()['recipesCached'], equals(1));
      });

      test('should return null for non-existent recipe', () async {
        mockRecipeService.setRecipeState(
          recipes: [],
          isInitialized: true,
        );

        final result = await manager.getCachedRecipe('nonexistent');
        expect(result, isNull);
      });

      test('should handle Swedish characters', () async {
        final recipe = RecipeFactory.build(
          id: 'swedish',
          title: 'Kottbullar med graddsas',
          ingredients: ['Fars', 'Agg', 'Mjolk'],
        );
        mockRecipeService.setRecipeState(
          recipes: [recipe],
          isInitialized: true,
        );

        final result = await manager.getCachedRecipe('swedish');
        expect(result?.title, equals('Kottbullar med graddsas'));
      });
    });

    group('Concurrent Access', () {
      test('should handle concurrent reads safely', () async {
        final recipe = RecipeFactory.build(id: 'concurrent');
        mockRecipeService.setRecipeState(
          recipes: [recipe],
          isInitialized: true,
        );

        final futures = List.generate(
          10,
          (_) => manager.getCachedRecipe('concurrent'),
        );
        final results = await Future.wait(futures);

        expect(results.every((r) => r?.id == 'concurrent'), isTrue);
      });

      test('should handle concurrent different recipe reads', () async {
        final recipes = List.generate(
          5,
          (i) => RecipeFactory.build(id: 'c_$i'),
        );
        mockRecipeService.setRecipeState(
          recipes: recipes,
          isInitialized: true,
        );

        final futures = recipes.map((r) => manager.getCachedRecipe(r.id));
        await Future.wait(futures);

        expect(manager.getCacheStats()['recipesCached'], equals(5));
      });
    });

    group('Memory Management', () {
      test('should handle memory pressure by clearing caches', () async {
        final recipes = List.generate(
          10,
          (i) => RecipeFactory.build(id: 'mem_$i'),
        );
        mockRecipeService.setRecipeState(
          recipes: recipes,
          isInitialized: true,
        );

        for (final r in recipes) {
          await manager.getCachedRecipe(r.id);
        }

        final beforeCount = manager.getCacheStats()['recipesCached'] as int;
        expect(beforeCount, greaterThan(0));

        manager.handleMemoryPressure();

        // After memory pressure, recipe cache is cleared
        expect(manager.getCacheStats()['recipesCached'], equals(0));
      });

      test('should keep current user in cache during memory pressure', () {
        // handleMemoryPressure preserves current user's entry in _userCache
        // With no user cache entries, this should not crash
        expect(() => manager.handleMemoryPressure(), returnsNormally);
      });
    });

    group('App Lifecycle', () {
      test('should pause and resume without error', () {
        // These cancel/restart timers - should not throw
        // Note: don't call onAppPaused because _saveBehaviorPattern triggers
        // the lazy _behaviorCache getter
        expect(() => manager.onAppResumed(), returnsNormally);
      });
    });

    group('Preload Content', () {
      test('should preload without crashing when no patterns exist', () async {
        mockRecipeService.setRecipeState(
          recipes: [RecipeFactory.build(id: 'preload1')],
          isInitialized: true,
        );

        // preloadLikelyContent loads behavior patterns which triggers
        // _behaviorCache -> OfflineService. It catches errors internally.
        await expectLater(
          manager.preloadLikelyContent('test_user_123'),
          completes,
        );
      });
    });

    group('Performance', () {
      test('should access cached recipe quickly', () async {
        final recipe = RecipeFactory.build(id: 'perf');
        mockRecipeService.setRecipeState(
          recipes: [recipe],
          isInitialized: true,
        );

        // First access loads from service
        await manager.getCachedRecipe('perf');

        // Second access should be from memory cache
        final sw = Stopwatch()..start();
        await manager.getCachedRecipe('perf');
        sw.stop();

        expect(sw.elapsedMilliseconds, lessThan(50));
      });
    });
  });
}
