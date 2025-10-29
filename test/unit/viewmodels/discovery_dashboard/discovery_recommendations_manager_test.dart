// test/unit/viewmodels/discovery_dashboard/discovery_recommendations_manager_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:butlery/viewmodels/discovery_dashboard/discovery_recommendations_manager.dart';
import 'package:butlery/models/recommendation.dart';
import 'package:butlery/services/permission_service.dart';

import '../../../infrastructure/mocks/service_mocks.dart';
import '../../../infrastructure/mocks/production_mocks.dart';
import '../../../infrastructure/di/test_service_locator.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late DiscoveryRecommendationsManager recommendationsManager;
  late MockRecommendationService mockRecommendationService;
  late MockPermissionService mockPermissionService;

  setUpAll(() async {
    await TestServiceLocator.initialize();
    
    // Register fallback values for mocktail
    registerFallbackValue(RecommendationType.similarToShared);
    registerFallbackValue(FeedbackType.like);
  });

  setUp(() async {
    mockRecommendationService = MockRecommendationService();
    
    // Get the permission service from TestServiceLocator (it's already configured)
    mockPermissionService = TestServiceLocator.get<PermissionService>() as MockPermissionService;

    recommendationsManager = DiscoveryRecommendationsManager(
      recommendationService: mockRecommendationService,
    );

    // TestServiceLocator already provides user ID 'test-user-123', but let's ensure it's set correctly
    mockPermissionService.setPermissionState(currentUserId: 'test_user_123');
  });

  tearDown(() {
    try {
      recommendationsManager.dispose();
    } catch (e) {
      // Already disposed, ignore
    }
    mockRecommendationService.resetState();
    mockPermissionService.reset();
  });

  tearDownAll(() async {
    await TestServiceLocator.reset();
  });

  List<Recommendation> createTestRecommendations({int count = 3}) {
    return List.generate(count, (index) {
      return Recommendation(
        id: 'rec_$index',
        contentId: 'content_$index',
        contentType: 'recipe',
        title: 'Recommendation ${index + 1}',
        description: 'Description for recommendation ${index + 1}',
        reason: 'Based on your cooking history',
        type: RecommendationType.values[index % RecommendationType.values.length],
        score: 0.8 - (index * 0.1),
        imageUrl: 'https://example.com/image$index.jpg',
        metadata: {'category': 'italian', 'difficulty': 'easy'},
        createdAt: DateTime.now().subtract(Duration(hours: index)),
        isDismissed: false,
        isLiked: false,
      );
    });
  }

  group('DiscoveryRecommendationsManager - Recommendations Loading', () {
    test('should load personalized recommendations successfully', () async {
      final testRecommendations = createTestRecommendations(count: 5);
      mockRecommendationService.setRecommendations(testRecommendations);

      expect(recommendationsManager.isLoading, isFalse);
      expect(recommendationsManager.hasError, isFalse);
      expect(recommendationsManager.hasRecommendations, isFalse);

      await recommendationsManager.loadPersonalizedRecommendations();

      expect(recommendationsManager.isLoading, isFalse);
      expect(recommendationsManager.hasError, isFalse);
      expect(recommendationsManager.hasRecommendations, isTrue);
      expect(recommendationsManager.recommendationsCount, equals(5));
      expect(recommendationsManager.personalizedRecommendations.length, equals(5));
    });

    test('should set loading state during recommendations loading', () async {
      final testRecommendations = createTestRecommendations(count: 2);
      mockRecommendationService.setRecommendations(testRecommendations);

      bool loadingStateObserved = false;
      recommendationsManager.addListener(() {
        if (recommendationsManager.isLoading) {
          loadingStateObserved = true;
        }
      });

      await recommendationsManager.loadPersonalizedRecommendations();

      expect(loadingStateObserved, isTrue);
      expect(recommendationsManager.isLoading, isFalse);
    });

    test('should handle recommendations loading error', () async {
      mockRecommendationService.setShouldThrowError(true);

      try {
        await recommendationsManager.loadPersonalizedRecommendations();
        fail('Should have thrown an exception');
      } catch (e) {
        // Exception was thrown as expected
      }

      expect(recommendationsManager.hasError, isTrue);
      expect(recommendationsManager.error, contains('Failed to load recommendations'));
      expect(recommendationsManager.isLoading, isFalse);
      expect(recommendationsManager.hasRecommendations, isFalse);
      expect(recommendationsManager.personalizedRecommendations, isEmpty);
    });

    test('should handle missing user ID gracefully', () async {
      mockPermissionService.setPermissionState(currentUserId: null);

      await recommendationsManager.loadPersonalizedRecommendations();

      expect(recommendationsManager.hasError, isFalse);
      expect(recommendationsManager.hasRecommendations, isFalse);
      expect(recommendationsManager.personalizedRecommendations, isEmpty);
    });

    test('should transform recommendations to map format correctly', () async {
      final testRecommendations = createTestRecommendations(count: 1);
      mockRecommendationService.setRecommendations(testRecommendations);

      await recommendationsManager.loadPersonalizedRecommendations();

      final recommendation = recommendationsManager.personalizedRecommendations.first;
      final original = testRecommendations.first;

      expect(recommendation['id'], equals(original.id));
      expect(recommendation['type'], equals(original.type.toString().split('.').last));
      expect(recommendation['title'], equals(original.title));
      expect(recommendation['description'], equals(original.description));
      expect(recommendation['imageUrl'], equals(original.imageUrl));
      expect(recommendation['reason'], equals(original.reason));
      expect(recommendation['contentType'], equals(original.contentType));
      expect(recommendation['contentId'], equals(original.contentId));
      expect(recommendation['score'], equals(original.score));
      expect(recommendation['isDismissed'], equals(original.isDismissed));
      expect(recommendation['isLiked'], equals(original.isLiked));
      expect(recommendation['metadata'], equals(original.metadata));
    });

    test('should refresh recommendations successfully', () async {
      final initialRecommendations = createTestRecommendations(count: 2);
      final refreshedRecommendations = createTestRecommendations(count: 4);
      
      mockRecommendationService.setRecommendations(initialRecommendations);
      await recommendationsManager.loadPersonalizedRecommendations();
      expect(recommendationsManager.recommendationsCount, equals(2));

      mockRecommendationService.setRecommendations(refreshedRecommendations);
      await recommendationsManager.refreshRecommendations();
      
      expect(recommendationsManager.recommendationsCount, equals(4));
      expect(recommendationsManager.hasError, isFalse);
    });

    test('should load more recommendations for pagination', () async {
      final initialRecommendations = createTestRecommendations(count: 3);
      mockRecommendationService.setRecommendations(initialRecommendations);
      await recommendationsManager.loadPersonalizedRecommendations();
      expect(recommendationsManager.recommendationsCount, equals(3));

      // Simulate loading more content
      final moreRecommendations = createTestRecommendations(count: 2);
      mockRecommendationService.setRecommendations([...initialRecommendations, ...moreRecommendations]);
      await recommendationsManager.loadMoreRecommendations();

      expect(recommendationsManager.recommendationsCount, greaterThanOrEqualTo(3));
    });

    test('should handle load more recommendations errors', () async {
      mockRecommendationService.setShouldThrowError(true);

      await recommendationsManager.loadMoreRecommendations();

      expect(recommendationsManager.hasError, isTrue);
      expect(recommendationsManager.error, contains('Failed to load more recommendations'));
    });

    test('should handle missing user ID in load more recommendations', () async {
      mockPermissionService.setPermissionState(currentUserId: null);

      await recommendationsManager.loadMoreRecommendations();

      expect(recommendationsManager.hasError, isFalse);
      expect(recommendationsManager.recommendationsCount, equals(0));
    });

    test('should clear all recommendations', () async {
      final testRecommendations = createTestRecommendations(count: 3);
      mockRecommendationService.setRecommendations(testRecommendations);
      
      await recommendationsManager.loadPersonalizedRecommendations();
      expect(recommendationsManager.hasRecommendations, isTrue);
      expect(recommendationsManager.recommendationsCount, equals(3));

      recommendationsManager.clearRecommendations();

      expect(recommendationsManager.hasRecommendations, isFalse);
      expect(recommendationsManager.recommendationsCount, equals(0));
      expect(recommendationsManager.personalizedRecommendations, isEmpty);
      expect(recommendationsManager.hasError, isFalse);
    });
  });

  group('DiscoveryRecommendationsManager - Feedback System', () {
    test('should provide like feedback successfully', () async {
      final testRecommendations = createTestRecommendations(count: 1);
      mockRecommendationService.setRecommendations(testRecommendations);
      await recommendationsManager.loadPersonalizedRecommendations();

      final recommendationId = testRecommendations.first.id;
      await recommendationsManager.likeRecommendation(recommendationId);

      final recommendation = recommendationsManager.getRecommendation(recommendationId);
      expect(recommendation!['isLiked'], isTrue);
      expect(recommendation['isDismissed'], isFalse);
    });

    test('should provide dismiss feedback successfully', () async {
      final testRecommendations = createTestRecommendations(count: 1);
      mockRecommendationService.setRecommendations(testRecommendations);
      await recommendationsManager.loadPersonalizedRecommendations();

      final recommendationId = testRecommendations.first.id;
      await recommendationsManager.dismissRecommendation(recommendationId);

      final recommendation = recommendationsManager.getRecommendation(recommendationId);
      expect(recommendation!['isDismissed'], isTrue);
      expect(recommendation['isLiked'], isFalse);
    });

    test('should provide general feedback successfully', () async {
      final testRecommendations = createTestRecommendations(count: 1);
      mockRecommendationService.setRecommendations(testRecommendations);
      await recommendationsManager.loadPersonalizedRecommendations();

      final recommendationId = testRecommendations.first.id;
      await recommendationsManager.provideRecommendationFeedback(
        recommendationId, 
        FeedbackType.save
      );

      final recommendation = recommendationsManager.getRecommendation(recommendationId);
      expect(recommendation!['isSaved'], isTrue);
      expect(recommendation['isDismissed'], isFalse);
    });

    test('should handle feedback errors', () async {
      final testRecommendations = createTestRecommendations(count: 1);
      mockRecommendationService.setRecommendations(testRecommendations);
      await recommendationsManager.loadPersonalizedRecommendations();

      final recommendationId = testRecommendations.first.id;
      mockRecommendationService.setFeedbackResult(recommendationId, false);

      await recommendationsManager.likeRecommendation(recommendationId);

      expect(recommendationsManager.hasError, isTrue);
      expect(recommendationsManager.error, contains('Failed to provide feedback'));
    });

    test('should handle feedback for non-existent recommendation', () async {
      const nonExistentId = 'non_existent_rec';

      await recommendationsManager.likeRecommendation(nonExistentId);

      // Service call succeeds, but no local recommendation to update
      expect(recommendationsManager.hasError, isFalse);
    });

    test('should undo recommendation dismissal successfully', () async {
      final testRecommendations = createTestRecommendations(count: 1);
      testRecommendations.first.isDismissed = true; // Pre-dismissed
      mockRecommendationService.setRecommendations(testRecommendations);
      await recommendationsManager.loadPersonalizedRecommendations();

      final recommendationId = testRecommendations.first.id;
      await recommendationsManager.undoRecommendationDismissal(recommendationId);

      final recommendation = recommendationsManager.getRecommendation(recommendationId);
      expect(recommendation!['isDismissed'], isFalse);
    });

    test('should handle undo dismissal errors', () async {
      mockRecommendationService.setShouldThrowError(true);

      await recommendationsManager.undoRecommendationDismissal('rec_1');

      expect(recommendationsManager.hasError, isTrue);
      expect(recommendationsManager.error, contains('Failed to undo dismissal'));
    });

    test('should handle different feedback types correctly', () async {
      final testRecommendations = createTestRecommendations(count: 1);
      mockRecommendationService.setRecommendations(testRecommendations);
      await recommendationsManager.loadPersonalizedRecommendations();

      final recommendationId = testRecommendations.first.id;

      // Test not interested feedback
      await recommendationsManager.provideRecommendationFeedback(
        recommendationId, 
        FeedbackType.notInterested
      );

      var recommendation = recommendationsManager.getRecommendation(recommendationId);
      expect(recommendation!['isDismissed'], isTrue);
      expect(recommendation['isLiked'], isFalse);

      // Test like feedback (should undo dismissal)
      await recommendationsManager.provideRecommendationFeedback(
        recommendationId, 
        FeedbackType.like
      );

      recommendation = recommendationsManager.getRecommendation(recommendationId);
      expect(recommendation!['isLiked'], isTrue);
      expect(recommendation['isDismissed'], isFalse);
    });
  });

  group('DiscoveryRecommendationsManager - Filtering and Retrieval', () {
    test('should get recommendation by ID', () async {
      final testRecommendations = createTestRecommendations(count: 3);
      mockRecommendationService.setRecommendations(testRecommendations);
      
      await recommendationsManager.loadPersonalizedRecommendations();

      final targetId = testRecommendations.first.id;
      final recommendation = recommendationsManager.getRecommendation(targetId);

      expect(recommendation, isNotNull);
      expect(recommendation!['id'], equals(targetId));
      expect(recommendation['title'], equals('Recommendation 1'));
    });

    test('should return null for non-existent recommendation ID', () async {
      final testRecommendations = createTestRecommendations(count: 2);
      mockRecommendationService.setRecommendations(testRecommendations);
      
      await recommendationsManager.loadPersonalizedRecommendations();

      final recommendation = recommendationsManager.getRecommendation('non_existent_id');

      expect(recommendation, isNull);
    });

    test('should filter recommendations by type', () async {
      final testRecommendations = [
        Recommendation(
          id: 'rec_1',
          contentId: 'content_1',
          contentType: 'recipe',
          title: 'Recipe Recommendation',
          description: 'Description 1',
          reason: 'Reason 1',
          type: RecommendationType.similarToShared,
          score: 0.9,
        ),
        Recommendation(
          id: 'rec_2',
          contentId: 'content_2',
          contentType: 'menu',
          title: 'Menu Recommendation',
          description: 'Description 2',
          reason: 'Reason 2',
          type: RecommendationType.trendingForYou,
          score: 0.8,
        ),
      ];
      mockRecommendationService.setRecommendations(testRecommendations);
      
      await recommendationsManager.loadPersonalizedRecommendations();

      final similarRecommendations = recommendationsManager.getRecommendationsByType('similarToShared');
      final trendingRecommendations = recommendationsManager.getRecommendationsByType('trendingForYou');
      final emptyRecommendations = recommendationsManager.getRecommendationsByType('nonExistentType');

      expect(similarRecommendations.length, equals(1));
      expect(similarRecommendations.first['title'], equals('Recipe Recommendation'));
      expect(trendingRecommendations.length, equals(1));
      expect(trendingRecommendations.first['title'], equals('Menu Recommendation'));
      expect(emptyRecommendations, isEmpty);
    });

    test('should filter recommendations by content type', () async {
      final testRecommendations = [
        Recommendation(
          id: 'rec_1',
          contentId: 'content_1',
          contentType: 'recipe',
          title: 'Recipe Content',
          description: 'Description 1',
          reason: 'Reason 1',
          type: RecommendationType.similarToShared,
          score: 0.9,
        ),
        Recommendation(
          id: 'rec_2',
          contentId: 'content_2',
          contentType: 'menu',
          title: 'Menu Content',
          description: 'Description 2',
          reason: 'Reason 2',
          type: RecommendationType.trendingForYou,
          score: 0.8,
        ),
      ];
      mockRecommendationService.setRecommendations(testRecommendations);
      
      await recommendationsManager.loadPersonalizedRecommendations();

      final recipeRecommendations = recommendationsManager.getRecommendationsByContentType('recipe');
      final menuRecommendations = recommendationsManager.getRecommendationsByContentType('menu');

      expect(recipeRecommendations.length, equals(1));
      expect(recipeRecommendations.first['title'], equals('Recipe Content'));
      expect(menuRecommendations.length, equals(1));
      expect(menuRecommendations.first['title'], equals('Menu Content'));
    });

    test('should get active (non-dismissed) recommendations', () async {
      final testRecommendations = createTestRecommendations(count: 3);
      testRecommendations[1].isDismissed = true; // Dismiss second recommendation
      mockRecommendationService.setRecommendations(testRecommendations);
      
      await recommendationsManager.loadPersonalizedRecommendations();

      final activeRecommendations = recommendationsManager.activeRecommendations;

      expect(activeRecommendations.length, equals(2));
      expect(activeRecommendations.every((rec) => rec['isDismissed'] != true), isTrue);
    });

    test('should get liked recommendations', () async {
      final testRecommendations = createTestRecommendations(count: 3);
      testRecommendations[0].isLiked = true; // Like first recommendation
      testRecommendations[2].isLiked = true; // Like third recommendation
      mockRecommendationService.setRecommendations(testRecommendations);
      
      await recommendationsManager.loadPersonalizedRecommendations();

      final likedRecommendations = recommendationsManager.likedRecommendations;

      expect(likedRecommendations.length, equals(2));
      expect(likedRecommendations.every((rec) => rec['isLiked'] == true), isTrue);
    });

    test('should return immutable list from personalizedRecommendations getter', () async {
      final testRecommendations = createTestRecommendations(count: 2);
      mockRecommendationService.setRecommendations(testRecommendations);
      
      await recommendationsManager.loadPersonalizedRecommendations();

      final recommendations = recommendationsManager.personalizedRecommendations;
      expect(() => recommendations.add({'test': 'item'}), throwsUnsupportedError);
    });
  });

  group('DiscoveryRecommendationsManager - State Management', () {
    test('should notify listeners when recommendations change', () async {
      int notificationCount = 0;
      recommendationsManager.addListener(() => notificationCount++);

      final testRecommendations = createTestRecommendations(count: 2);
      mockRecommendationService.setRecommendations(testRecommendations);

      await recommendationsManager.loadPersonalizedRecommendations();

      expect(notificationCount, greaterThan(0));
    });

    test('should manage error state correctly', () async {
      expect(recommendationsManager.hasError, isFalse);
      expect(recommendationsManager.error, isNull);

      mockRecommendationService.setShouldThrowError(true);

      try {
        await recommendationsManager.loadPersonalizedRecommendations();
      } catch (e) {
        // Expected
      }

      expect(recommendationsManager.hasError, isTrue);
      expect(recommendationsManager.error, isNotNull);
      expect(recommendationsManager.error, contains('Failed to load recommendations'));
    });

    test('should clear error state on successful operations', () async {
      // First operation fails
      mockRecommendationService.setShouldThrowError(true);
      try {
        await recommendationsManager.loadPersonalizedRecommendations();
      } catch (e) {
        // Expected
      }
      expect(recommendationsManager.hasError, isTrue);

      // Second operation succeeds
      mockRecommendationService.setShouldThrowError(false);
      mockRecommendationService.setRecommendations(createTestRecommendations(count: 1));
      
      await recommendationsManager.loadPersonalizedRecommendations();
      
      expect(recommendationsManager.hasError, isFalse);
      expect(recommendationsManager.error, isNull);
    });

    test('should clear error when clearing recommendations', () async {
      mockRecommendationService.setShouldThrowError(true);
      try {
        await recommendationsManager.loadPersonalizedRecommendations();
      } catch (e) {
        // Expected
      }
      expect(recommendationsManager.hasError, isTrue);

      recommendationsManager.clearRecommendations();

      expect(recommendationsManager.hasError, isFalse);
      expect(recommendationsManager.error, isNull);
    });

    test('should handle dispose correctly', () async {
      final testRecommendations = createTestRecommendations(count: 2);
      mockRecommendationService.setRecommendations(testRecommendations);
      
      await recommendationsManager.loadPersonalizedRecommendations();
      expect(recommendationsManager.recommendationsCount, equals(2));
      
      // Should not throw when disposing
      recommendationsManager.dispose();
      
      // Don't access ViewModel after dispose - just verify dispose completed
      expect(true, isTrue);
    });

    test('should maintain state consistency during operations', () async {
      int totalNotifications = 0;
      recommendationsManager.addListener(() => totalNotifications++);

      final recommendations = createTestRecommendations(count: 3);
      mockRecommendationService.setRecommendations(recommendations);

      // Multiple state changes
      await recommendationsManager.loadPersonalizedRecommendations();
      await recommendationsManager.likeRecommendation(recommendations.first.id);
      await recommendationsManager.refreshRecommendations();
      recommendationsManager.clearRecommendations();

      expect(totalNotifications, greaterThan(3)); // At least 4 operations
      expect(recommendationsManager.recommendationsCount, equals(0)); // Final state
      expect(recommendationsManager.hasError, isFalse);
    });
  });

  group('DiscoveryRecommendationsManager - Edge Cases', () {
    test('should handle concurrent load operations', () async {
      final testRecommendations = createTestRecommendations(count: 2);
      mockRecommendationService.setRecommendations(testRecommendations);

      final futures = [
        recommendationsManager.loadPersonalizedRecommendations(),
        recommendationsManager.refreshRecommendations(),
      ];

      await Future.wait(futures);

      expect(recommendationsManager.personalizedRecommendations, isNotEmpty);
      expect(recommendationsManager.hasError, isFalse);
    });

    test('should handle large recommendation datasets', () async {
      final largeDataset = createTestRecommendations(count: 50);
      mockRecommendationService.setRecommendations(largeDataset);

      await recommendationsManager.loadPersonalizedRecommendations();

      expect(recommendationsManager.recommendationsCount, lessThanOrEqualTo(50));
      expect(recommendationsManager.hasRecommendations, isTrue);
      
      // Test filtering on large dataset
      final activeRecommendations = recommendationsManager.activeRecommendations;
      expect(activeRecommendations.length, equals(recommendationsManager.recommendationsCount));
    });

    test('should handle recommendations with missing optional fields', () async {
      final recommendation = Recommendation(
        id: 'minimal_rec',
        contentId: 'minimal_content',
        contentType: 'recipe',
        title: 'Minimal Recommendation',
        description: 'Minimal description',
        reason: 'Minimal reason',
        type: RecommendationType.similarToShared,
        score: 0.5,
        // No imageUrl, metadata, etc.
      );
      mockRecommendationService.setRecommendations([recommendation]);

      await recommendationsManager.loadPersonalizedRecommendations();

      final rec = recommendationsManager.personalizedRecommendations.first;
      expect(rec['imageUrl'], isNull);
      expect(rec['metadata'], isNull);
      expect(rec['id'], equals('minimal_rec'));
    });

    test('should handle network timeout scenarios', () async {
      mockRecommendationService.setShouldThrowError(true);

      try {
        await recommendationsManager.loadPersonalizedRecommendations();
        fail('Should have thrown an exception');
      } catch (e) {
        // Expected
      }

      expect(recommendationsManager.hasError, isTrue);
      expect(recommendationsManager.hasRecommendations, isFalse);
    });

    test('should handle rapid successive operations', () async {
      final testRecommendations = createTestRecommendations(count: 3);
      mockRecommendationService.setRecommendations(testRecommendations);

      // Rapid successive calls
      final futures = List.generate(5, (_) => recommendationsManager.refreshRecommendations());
      await Future.wait(futures);

      expect(recommendationsManager.personalizedRecommendations.length, equals(3));
      expect(recommendationsManager.hasError, isFalse);
    });

    test('should maintain data consistency during error recovery', () async {
      // Load initial data
      final initialRecommendations = createTestRecommendations(count: 2);
      mockRecommendationService.setRecommendations(initialRecommendations);
      await recommendationsManager.loadPersonalizedRecommendations();
      expect(recommendationsManager.recommendationsCount, equals(2));

      // Cause error
      mockRecommendationService.setShouldThrowError(true);
      try {
        await recommendationsManager.refreshRecommendations();
      } catch (e) {
        // Expected
      }
      
      // Data should be cleared on error
      expect(recommendationsManager.recommendationsCount, equals(0));
      expect(recommendationsManager.hasError, isTrue);

      // Recover
      mockRecommendationService.setShouldThrowError(false);
      final newRecommendations = createTestRecommendations(count: 4);
      mockRecommendationService.setRecommendations(newRecommendations);
      await recommendationsManager.refreshRecommendations();

      expect(recommendationsManager.recommendationsCount, equals(4));
      expect(recommendationsManager.hasError, isFalse);
    });

    test('should handle edge cases in filtering', () async {
      final testRecommendations = createTestRecommendations(count: 3);
      mockRecommendationService.setRecommendations(testRecommendations);
      await recommendationsManager.loadPersonalizedRecommendations();

      // Test empty string filters
      final emptyTypeFilter = recommendationsManager.getRecommendationsByType('');
      expect(emptyTypeFilter, isEmpty);

      final emptyContentFilter = recommendationsManager.getRecommendationsByContentType('');
      expect(emptyContentFilter, isEmpty);

      // Test null-like filters
      final nullTypeFilter = recommendationsManager.getRecommendationsByType('null');
      expect(nullTypeFilter, isEmpty);

      // Test special characters in ID search
      final specialId = recommendationsManager.getRecommendation('rec@#\$%');
      expect(specialId, isNull);
    });

    test('should handle feedback state updates correctly', () async {
      final testRecommendations = createTestRecommendations(count: 3);
      mockRecommendationService.setRecommendations(testRecommendations);
      await recommendationsManager.loadPersonalizedRecommendations();

      final recommendationId = testRecommendations.first.id;

      // Like -> Dismiss -> Undo sequence
      await recommendationsManager.likeRecommendation(recommendationId);
      var rec = recommendationsManager.getRecommendation(recommendationId);
      expect(rec!['isLiked'], isTrue);
      expect(rec['isDismissed'], isFalse);

      await recommendationsManager.dismissRecommendation(recommendationId);
      rec = recommendationsManager.getRecommendation(recommendationId);
      expect(rec!['isDismissed'], isTrue);
      expect(rec['isLiked'], isFalse);

      await recommendationsManager.undoRecommendationDismissal(recommendationId);
      rec = recommendationsManager.getRecommendation(recommendationId);
      expect(rec!['isDismissed'], isFalse);
      // isLiked state should remain false after undo
    });
  });

  group('DiscoveryRecommendationsManager - Integration Tests', () {
    test('should handle complete recommendation flow', () async {
      // Load recommendations
      final testRecommendations = createTestRecommendations(count: 5);
      mockRecommendationService.setRecommendations(testRecommendations);
      await recommendationsManager.loadPersonalizedRecommendations();

      expect(recommendationsManager.recommendationsCount, equals(5));
      expect(recommendationsManager.hasError, isFalse);

      // Filter recommendations
      final activeRecommendations = recommendationsManager.activeRecommendations;
      expect(activeRecommendations.length, equals(5));

      // Provide feedback
      final recommendationId = testRecommendations.first.id;
      await recommendationsManager.likeRecommendation(recommendationId);

      final likedRecommendations = recommendationsManager.likedRecommendations;
      expect(likedRecommendations.length, equals(1));

      // Load more recommendations
      await recommendationsManager.loadMoreRecommendations();
      expect(recommendationsManager.recommendationsCount, greaterThanOrEqualTo(5));

      // Clear recommendations
      recommendationsManager.clearRecommendations();
      expect(recommendationsManager.recommendationsCount, equals(0));
    });

    test('should maintain state consistency across operations', () async {
      int totalNotifications = 0;
      recommendationsManager.addListener(() => totalNotifications++);

      // Complex operation sequence
      final recs1 = createTestRecommendations(count: 3);
      mockRecommendationService.setRecommendations(recs1);
      await recommendationsManager.loadPersonalizedRecommendations();

      await recommendationsManager.likeRecommendation(recs1.first.id);
      await recommendationsManager.dismissRecommendation(recs1[1].id);

      final recs2 = createTestRecommendations(count: 5);
      mockRecommendationService.setRecommendations(recs2);
      await recommendationsManager.refreshRecommendations();

      await recommendationsManager.loadMoreRecommendations();
      recommendationsManager.clearRecommendations();

      expect(totalNotifications, greaterThan(5)); // Multiple operations
      expect(recommendationsManager.recommendationsCount, equals(0)); // Final state
      expect(recommendationsManager.hasError, isFalse);
    });

    test('should handle mixed success and failure scenarios', () async {
      // Success
      final successRecommendations = createTestRecommendations(count: 2);
      mockRecommendationService.setRecommendations(successRecommendations);
      await recommendationsManager.loadPersonalizedRecommendations();
      expect(recommendationsManager.hasError, isFalse);
      expect(recommendationsManager.recommendationsCount, equals(2));

      // Feedback failure
      final recommendationId = successRecommendations.first.id;
      mockRecommendationService.setFeedbackResult(recommendationId, false);
      await recommendationsManager.likeRecommendation(recommendationId);
      expect(recommendationsManager.hasError, isTrue);

      // Recovery
      mockRecommendationService.setShouldThrowError(false);
      mockRecommendationService.setFeedbackResult(recommendationId, true);
      final recoveryRecommendations = createTestRecommendations(count: 4);
      mockRecommendationService.setRecommendations(recoveryRecommendations);
      await recommendationsManager.loadPersonalizedRecommendations();
      
      expect(recommendationsManager.hasError, isFalse);
      expect(recommendationsManager.recommendationsCount, equals(4));
    });

    test('should handle complex filtering scenarios', () async {
      final mixedRecommendations = [
        Recommendation(
          id: 'recipe_liked',
          contentId: 'recipe_1',
          contentType: 'recipe',
          title: 'Liked Recipe',
          description: 'Description',
          reason: 'Reason',
          type: RecommendationType.similarToShared,
          score: 0.9,
          isLiked: true,
        ),
        Recommendation(
          id: 'menu_dismissed',
          contentId: 'menu_1',
          contentType: 'menu',
          title: 'Dismissed Menu',
          description: 'Description',
          reason: 'Reason',
          type: RecommendationType.trendingForYou,
          score: 0.8,
          isDismissed: true,
        ),
        Recommendation(
          id: 'recipe_active',
          contentId: 'recipe_2',
          contentType: 'recipe',
          title: 'Active Recipe',
          description: 'Description',
          reason: 'Reason',
          type: RecommendationType.basedOnFriends,
          score: 0.7,
        ),
      ];

      mockRecommendationService.setRecommendations(mixedRecommendations);
      await recommendationsManager.loadPersonalizedRecommendations();

      expect(recommendationsManager.recommendationsCount, equals(3));
      expect(recommendationsManager.activeRecommendations.length, equals(2));
      expect(recommendationsManager.likedRecommendations.length, equals(1));
      expect(recommendationsManager.getRecommendationsByContentType('recipe').length, equals(2));
      expect(recommendationsManager.getRecommendationsByContentType('menu').length, equals(1));
    });
  });
}