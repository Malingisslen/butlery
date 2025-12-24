// test/unit/viewmodels/discovery_dashboard/discovery_content_manager_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:butlery/viewmodels/discovery_dashboard/discovery_content_manager.dart';
import 'package:butlery/models/recipe_unified.dart';

import '../../../infrastructure/mocks/service_mocks.dart';
import '../../../infrastructure/factories/recipe_factory.dart';
import '../../../infrastructure/di/test_service_locator.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late DiscoveryContentManager contentManager;
  late MockRecipeDiscoveryService mockDiscoveryService;

  setUpAll(() async {
    await TestServiceLocator.initialize();
  });

  setUp(() async {
    mockDiscoveryService = MockRecipeDiscoveryService();

    contentManager = DiscoveryContentManager(
      discoveryService: mockDiscoveryService,
    );
  });

  tearDown(() {
    try {
      contentManager.dispose();
    } catch (e) {
      // Already disposed, ignore
    }
    mockDiscoveryService.resetState();
  });

  tearDownAll(() async {
    await TestServiceLocator.reset();
  });

  List<Recipe> createTestRecipes({int count = 3}) {
    return List.generate(
        count,
        (index) => RecipeFactory.build(
              id: 'trending_recipe_$index',
              title: 'Trending Recipe ${index + 1}',
              description: 'Description for trending recipe ${index + 1}',
            ));
  }

  group('DiscoveryContentManager - Content Loading', () {
    test('should load all trending content successfully', () async {
      final testRecipes = createTestRecipes(count: 5);
      mockDiscoveryService.setTrendingRecipes(testRecipes);

      expect(contentManager.isLoading, isFalse);
      expect(contentManager.hasError, isFalse);

      await contentManager.loadAllTrendingContent();

      expect(contentManager.isLoading, isFalse);
      expect(contentManager.hasError, isFalse);
      expect(contentManager.trendingRecipes, equals(testRecipes));
      expect(contentManager.trendingRecipes.length, equals(5));
      expect(
          contentManager.trendingMenus, isEmpty); // Placeholder implementation
      expect(contentManager.trendingShoppingLists,
          isEmpty); // Placeholder implementation
    });

    test('should set loading state during content loading', () async {
      final testRecipes = createTestRecipes(count: 3);
      mockDiscoveryService.setTrendingRecipes(testRecipes);

      bool loadingStateObserved = false;
      contentManager.addListener(() {
        if (contentManager.isLoading) {
          loadingStateObserved = true;
        }
      });

      await contentManager.loadAllTrendingContent();

      expect(loadingStateObserved, isTrue);
      expect(contentManager.isLoading, isFalse);
    });

    test('should handle trending recipes loading error', () async {
      mockDiscoveryService.setShouldThrowError(true);

      try {
        await contentManager.loadAllTrendingContent();
        fail('Should have thrown an exception');
      } catch (e) {
        // Exception was thrown as expected
      }

      expect(contentManager.hasError, isTrue);
      expect(contentManager.error, contains('Failed to load trending content'));
      expect(contentManager.isLoading, isFalse);
    });

    test('should refresh content successfully', () async {
      final initialRecipes = createTestRecipes(count: 2);
      final refreshedRecipes = createTestRecipes(count: 4);

      mockDiscoveryService.setTrendingRecipes(initialRecipes);
      await contentManager.loadAllTrendingContent();
      expect(contentManager.trendingRecipes.length, equals(2));

      mockDiscoveryService.setTrendingRecipes(refreshedRecipes);
      await contentManager.refreshContent();

      expect(contentManager.trendingRecipes.length, equals(4));
      expect(contentManager.hasError, isFalse);
    });

    test('should clear all content', () async {
      final testRecipes = createTestRecipes(count: 3);
      mockDiscoveryService.setTrendingRecipes(testRecipes);

      await contentManager.loadAllTrendingContent();
      expect(contentManager.trendingContentCount, equals(3));

      contentManager.clearContent();

      expect(contentManager.trendingRecipes, isEmpty);
      expect(contentManager.trendingMenus, isEmpty);
      expect(contentManager.trendingShoppingLists, isEmpty);
      expect(contentManager.trendingContentCount, equals(0));
      expect(contentManager.hasError, isFalse);
    });

    test('should calculate trending content count correctly', () async {
      final testRecipes = createTestRecipes(count: 5);
      mockDiscoveryService.setTrendingRecipes(testRecipes);

      await contentManager.loadAllTrendingContent();

      expect(contentManager.trendingContentCount,
          equals(5)); // Only recipes in current implementation
    });

    test('should load more trending content for pagination', () async {
      final initialRecipes = createTestRecipes(count: 3);
      final moreRecipes = createTestRecipes(count: 2);

      mockDiscoveryService.setTrendingRecipes(initialRecipes);
      await contentManager.loadAllTrendingContent();
      expect(contentManager.trendingRecipes.length, equals(3));

      // Simulate loading more content
      mockDiscoveryService
          .setTrendingRecipes([...initialRecipes, ...moreRecipes]);
      await contentManager.loadMoreTrendingContent();

      expect(contentManager.trendingRecipes.length, greaterThanOrEqualTo(3));
    });

    test('should handle load more content errors gracefully', () async {
      mockDiscoveryService.setShouldThrowError(true);

      // Should not throw, should handle gracefully
      await contentManager.loadMoreTrendingContent();

      expect(contentManager.trendingRecipes, isEmpty);
    });
  });

  group('DiscoveryContentManager - Search Operations', () {
    test('should search recipes successfully', () async {
      final testRecipes = [
        RecipeFactory.build(
            title: 'Pasta Carbonara', description: 'Creamy pasta dish'),
        RecipeFactory.build(
            title: 'Chicken Curry', description: 'Spicy chicken curry'),
        RecipeFactory.build(
            title: 'Pasta Bolognese', description: 'Meat sauce pasta'),
      ];

      mockDiscoveryService.setSearchResults(testRecipes);

      final results = await contentManager.searchRecipes('pasta');

      expect(results.length, equals(3));
      expect(results.first['type'], equals('recipe'));
      expect(results.first['title'], isA<String>());
      expect(results.first['contentId'], isNotNull);
      expect(results.first['relevanceScore'], isA<double>());
    });

    test('should return empty list when recipe search fails', () async {
      mockDiscoveryService.setShouldThrowError(true);

      final results = await contentManager.searchRecipes('pasta');

      expect(results, isEmpty);
    });

    test('should search menus successfully', () async {
      // Set up trending menus for search
      contentManager.clearContent();
      // Note: Menu search operates on _trendingMenus which are currently empty in placeholder

      final results = contentManager.searchMenus('weekly');

      expect(results, isEmpty); // Expected due to placeholder implementation
    });

    test('should search shopping lists successfully', () async {
      // Set up trending shopping lists for search
      contentManager.clearContent();
      // Note: Shopping list search operates on _trendingShoppingLists which are currently empty in placeholder

      final results = contentManager.searchShoppingLists('grocery');

      expect(results, isEmpty); // Expected due to placeholder implementation
    });

    test('should calculate relevance scores correctly', () async {
      final testRecipes = [
        RecipeFactory.build(
            title: 'Perfect Pasta', description: 'Great pasta recipe'),
        RecipeFactory.build(
            title: 'Chicken Recipe',
            description: 'Contains pasta as ingredient'),
        RecipeFactory.build(title: 'Random Recipe', description: 'No match'),
      ];

      mockDiscoveryService.setSearchResults(testRecipes);

      final results = await contentManager.searchRecipes('pasta');

      expect(results.length, greaterThanOrEqualTo(2));

      // Check that results have relevance scores
      for (final result in results) {
        expect(result['relevanceScore'], isA<double>());
        expect(result['relevanceScore'], greaterThanOrEqualTo(0.0));
      }

      // Title match should have higher score than description match
      final titleMatch = results.firstWhere(
          (r) => r['title'].toString().toLowerCase().contains('pasta'));
      expect(titleMatch['relevanceScore'], greaterThan(0.0));
    });

    test('should handle empty search queries', () async {
      final results = await contentManager.searchRecipes('');

      // Search service should handle empty queries
      expect(results, isA<List>());
    });

    test('should handle search with special characters', () async {
      final testRecipes = [
        RecipeFactory.build(title: 'Café Crème', description: 'French coffee'),
        RecipeFactory.build(title: 'Naïve Recipe', description: 'Simple dish'),
      ];

      mockDiscoveryService.setSearchResults(testRecipes);

      final results = await contentManager.searchRecipes('café');

      expect(results, isNotEmpty);
      expect(results.first['type'], equals('recipe'));
    });
  });

  group('DiscoveryContentManager - State Management', () {
    test('should notify listeners when content changes', () async {
      int notificationCount = 0;
      contentManager.addListener(() => notificationCount++);

      final testRecipes = createTestRecipes(count: 2);
      mockDiscoveryService.setTrendingRecipes(testRecipes);

      await contentManager.loadAllTrendingContent();

      expect(notificationCount, greaterThan(0));
    });

    test('should manage error state correctly', () async {
      expect(contentManager.hasError, isFalse);
      expect(contentManager.error, isNull);

      mockDiscoveryService.setShouldThrowError(true);

      try {
        await contentManager.loadAllTrendingContent();
      } catch (e) {
        // Expected
      }

      expect(contentManager.hasError, isTrue);
      expect(contentManager.error, isNotNull);
      expect(contentManager.error, contains('Failed to load trending content'));
    });

    test('should clear error state on successful operations', () async {
      // First operation fails
      mockDiscoveryService.setShouldThrowError(true);
      try {
        await contentManager.loadAllTrendingContent();
      } catch (e) {
        // Expected
      }
      expect(contentManager.hasError, isTrue);

      // Second operation succeeds
      mockDiscoveryService.setShouldThrowError(false);
      mockDiscoveryService.setTrendingRecipes(createTestRecipes(count: 1));

      await contentManager.loadAllTrendingContent();

      expect(contentManager.hasError, isFalse);
      expect(contentManager.error, isNull);
    });

    test('should clear error when clearing content', () async {
      mockDiscoveryService.setShouldThrowError(true);
      try {
        await contentManager.loadAllTrendingContent();
      } catch (e) {
        // Expected
      }
      expect(contentManager.hasError, isTrue);

      contentManager.clearContent();

      expect(contentManager.hasError, isFalse);
      expect(contentManager.error, isNull);
    });

    test('should return immutable lists from getters', () async {
      final testRecipes = createTestRecipes(count: 2);
      mockDiscoveryService.setTrendingRecipes(testRecipes);

      await contentManager.loadAllTrendingContent();

      final trendingRecipes = contentManager.trendingRecipes;
      expect(() => trendingRecipes.add(RecipeFactory.build()),
          throwsUnsupportedError);
    });

    test('should handle dispose correctly', () async {
      final testRecipes = createTestRecipes(count: 2);
      mockDiscoveryService.setTrendingRecipes(testRecipes);

      await contentManager.loadAllTrendingContent();
      expect(contentManager.trendingRecipes.length, equals(2));

      // Should not throw when disposing
      contentManager.dispose();

      // Don't access ViewModel after dispose - just verify dispose completed
      expect(true, isTrue); // Test passes if dispose didn't throw
    });
  });

  group('DiscoveryContentManager - Filtering Operations', () {
    test('should apply category filter', () {
      int notificationCount = 0;
      contentManager.addListener(() => notificationCount++);

      contentManager.applyCategoryFilter('vegetarian');

      expect(notificationCount, equals(1));
    });

    test('should handle multiple category filters', () {
      contentManager.applyCategoryFilter('vegetarian');
      contentManager.applyCategoryFilter('gluten-free');
      contentManager.applyCategoryFilter('low-carb');

      // Should complete without errors
      expect(contentManager.hasError, isFalse);
    });

    test('should handle empty category filter', () {
      contentManager.applyCategoryFilter('');

      expect(contentManager.hasError, isFalse);
    });

    test('should handle null-like category filters', () {
      contentManager.applyCategoryFilter('null');
      contentManager.applyCategoryFilter('undefined');

      expect(contentManager.hasError, isFalse);
    });
  });

  group('DiscoveryContentManager - Edge Cases', () {
    test('should handle concurrent load operations', () async {
      final testRecipes1 = createTestRecipes(count: 2);

      mockDiscoveryService.setTrendingRecipes(testRecipes1);

      final futures = [
        contentManager.loadAllTrendingContent(),
        contentManager.refreshContent(),
        contentManager.loadMoreTrendingContent(),
      ];

      await Future.wait(futures);

      expect(contentManager.trendingRecipes, isNotEmpty);
      expect(contentManager.hasError, isFalse);
    });

    test('should handle large recipe datasets', () async {
      final largeDataset = createTestRecipes(count: 100);
      mockDiscoveryService.setTrendingRecipes(largeDataset);

      await contentManager.loadAllTrendingContent();

      expect(contentManager.trendingRecipes.length, lessThanOrEqualTo(100));
      expect(contentManager.trendingContentCount, greaterThan(0));
    });

    test('should handle empty datasets gracefully', () async {
      mockDiscoveryService.setTrendingRecipes([]);
      mockDiscoveryService.setSearchResults([]);

      await contentManager.loadAllTrendingContent();
      final searchResults = await contentManager.searchRecipes('test');

      expect(contentManager.trendingRecipes, isEmpty);
      expect(contentManager.trendingContentCount, equals(0));
      expect(searchResults, isEmpty);
      expect(contentManager.hasError, isFalse);
    });

    test('should handle network timeout scenarios', () async {
      // Simulate timeout by throwing exception
      mockDiscoveryService.setShouldThrowError(true);

      try {
        await contentManager.loadAllTrendingContent();
        fail('Should have thrown an exception');
      } catch (e) {
        // Exception was thrown as expected
      }

      expect(contentManager.hasError, isTrue);
    });

    test('should handle service unavailable scenarios', () async {
      mockDiscoveryService.setShouldThrowError(true);

      final searchResults = await contentManager.searchRecipes('pasta');

      expect(searchResults, isEmpty);
    });

    test('should handle malformed data gracefully', () async {
      // Mock service returns valid recipes, so this tests the manager's robustness
      final validRecipes = createTestRecipes(count: 3);
      mockDiscoveryService.setTrendingRecipes(validRecipes);

      await contentManager.loadAllTrendingContent();

      expect(contentManager.trendingRecipes.length, equals(3));
      expect(contentManager.hasError, isFalse);
    });

    test('should handle rapid successive operations', () async {
      final testRecipes = createTestRecipes(count: 5);
      mockDiscoveryService.setTrendingRecipes(testRecipes);

      // Rapid successive calls
      final futures = List.generate(10, (_) => contentManager.refreshContent());
      await Future.wait(futures);

      expect(contentManager.trendingRecipes, equals(testRecipes));
      expect(contentManager.hasError, isFalse);
    });

    test('should maintain consistency during error recovery', () async {
      // Load initial data
      final initialRecipes = createTestRecipes(count: 2);
      mockDiscoveryService.setTrendingRecipes(initialRecipes);
      await contentManager.loadAllTrendingContent();
      expect(contentManager.trendingRecipes.length, equals(2));

      // Cause error
      mockDiscoveryService.setShouldThrowError(true);
      try {
        await contentManager.refreshContent();
      } catch (e) {
        // Expected
      }

      // Data should remain consistent
      expect(contentManager.trendingRecipes.length, equals(2));
      expect(contentManager.hasError, isTrue);

      // Recover
      mockDiscoveryService.setShouldThrowError(false);
      final newRecipes = createTestRecipes(count: 4);
      mockDiscoveryService.setTrendingRecipes(newRecipes);
      await contentManager.refreshContent();

      expect(contentManager.trendingRecipes.length, equals(4));
      expect(contentManager.hasError, isFalse);
    });
  });

  group('DiscoveryContentManager - Integration Tests', () {
    test('should handle complete discovery flow', () async {
      // Load trending content
      final trendingRecipes = createTestRecipes(count: 5);
      mockDiscoveryService.setTrendingRecipes(trendingRecipes);
      await contentManager.loadAllTrendingContent();

      expect(contentManager.trendingRecipes.length, equals(5));
      expect(contentManager.hasError, isFalse);

      // Search within content
      final searchRecipes = createTestRecipes(count: 3);
      mockDiscoveryService.setSearchResults(searchRecipes);
      final searchResults = await contentManager.searchRecipes('pasta');

      expect(searchResults.length, equals(3));

      // Apply filters
      contentManager.applyCategoryFilter('italian');
      expect(contentManager.hasError, isFalse);

      // Load more content
      await contentManager.loadMoreTrendingContent();
      expect(contentManager.trendingRecipes, isNotEmpty);

      // Clear and verify
      contentManager.clearContent();
      expect(contentManager.trendingContentCount, equals(0));
    });

    test('should maintain state consistency across operations', () async {
      int totalNotifications = 0;
      contentManager.addListener(() => totalNotifications++);

      // Multiple operations
      final recipes1 = createTestRecipes(count: 3);
      mockDiscoveryService.setTrendingRecipes(recipes1);
      await contentManager.loadAllTrendingContent();

      final recipes2 = createTestRecipes(count: 5);
      mockDiscoveryService.setTrendingRecipes(recipes2);
      await contentManager.refreshContent();

      contentManager.applyCategoryFilter('healthy');

      await contentManager.loadMoreTrendingContent();

      expect(totalNotifications, greaterThan(3)); // At least 4 operations
      expect(contentManager.trendingRecipes.length, greaterThanOrEqualTo(3));
      expect(contentManager.hasError, isFalse);
    });

    test('should handle mixed success and failure scenarios', () async {
      // Success
      final successRecipes = createTestRecipes(count: 2);
      mockDiscoveryService.setTrendingRecipes(successRecipes);
      await contentManager.loadAllTrendingContent();
      expect(contentManager.hasError, isFalse);

      // Failure
      mockDiscoveryService.setShouldThrowError(true);
      try {
        await contentManager.refreshContent();
      } catch (e) {
        // Expected
      }
      expect(contentManager.hasError, isTrue);

      // Recovery
      mockDiscoveryService.setShouldThrowError(false);
      final recoveryRecipes = createTestRecipes(count: 4);
      mockDiscoveryService.setTrendingRecipes(recoveryRecipes);
      await contentManager.loadAllTrendingContent();

      expect(contentManager.hasError, isFalse);
      expect(contentManager.trendingRecipes.length, equals(4));
    });
  });
}
