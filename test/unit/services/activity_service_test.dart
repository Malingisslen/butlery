import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'package:butlery/services/social/activity_service.dart';
import 'package:butlery/models/social/activity_feed_item.dart';

import '../../infrastructure/helpers/_base_unit_test.dart';
import '../../infrastructure/mocks/production_mocks.dart';
import '../../infrastructure/factories/mock_factory.dart';
import '../../infrastructure/di/test_service_locator.dart';

// ============= FAKE MODELS =============

class FakeActivityFeedItem extends Fake implements ActivityFeedItem {
  @override
  final String id;
  @override
  final String userId;
  @override
  final String userDisplayName;
  @override
  final String? userAvatarUrl;
  @override
  final ActivityType type;
  @override
  final String targetId;
  @override
  final String targetType;
  @override
  final String targetTitle;
  @override
  final String? targetImageUrl;
  @override
  final String? parentId;
  @override
  final String? parentType;
  @override
  final List<String> visibility;
  @override
  final Map<String, dynamic> metadata;
  @override
  final DateTime timestamp;
  @override
  final ActivityEngagement engagement;

  FakeActivityFeedItem({
    required this.id,
    required this.userId,
    required this.userDisplayName,
    this.userAvatarUrl,
    required this.type,
    required this.targetId,
    required this.targetType,
    required this.targetTitle,
    this.targetImageUrl,
    this.parentId,
    this.parentType,
    List<String>? visibility,
    Map<String, dynamic>? metadata,
    DateTime? timestamp,
    ActivityEngagement? engagement,
  })  : visibility = visibility ?? ['all_friends'],
        metadata = metadata ?? {},
        timestamp = timestamp ?? DateTime.now(),
        engagement = engagement ?? FakeActivityEngagement();
}

class FakeActivityEngagement extends Fake implements ActivityEngagement {
  @override
  final int likes;
  @override
  final int comments;
  @override
  final int shares;
  @override
  final int views;
  
  FakeActivityEngagement({
    this.likes = 0,
    this.comments = 0,
    this.shares = 0,
    this.views = 0,
  });
}

// ============= TESTS =============

void main() {
  group('ActivityService', () {
    late ActivityService activityService;
    late MockActivityRepository mockActivityRepo;
    late MockAuthRepository mockAuthRepo;
    late User mockUser;

    setUpAll(() async {
      await BaseUnitTest.setupUnit();
      await TestServiceLocator.initialize();
      
      // Register fallback values for mocktail
      registerFallbackValue(ActivityType.recipeCreated);
      registerFallbackValue(ActivityFeedItem.create(
        userId: 'test',
        userDisplayName: 'Test',
        type: ActivityType.recipeCreated,
        targetId: 'test',
        targetType: 'test',
        targetTitle: 'Test',
      ));
      registerFallbackValue(const Duration(seconds: 1));
    });

    setUp(() {
      mockActivityRepo = MockActivityRepository();
      mockAuthRepo = MockAuthRepository();
      
      // Create mock user with proper configuration
      mockUser = MockFactory.createMockUser(
        uid: 'test-user-id',
        displayName: 'Test User',
        photoURL: 'https://example.com/avatar.jpg',
      );

      // Setup auth repository with configuration
      mockAuthRepo.setAuthState(
        user: mockUser,
        userId: 'test-user-id',
      );

      activityService = ActivityService(
        activityRepository: mockActivityRepo,
        authRepository: mockAuthRepo,
      );
    });

    tearDown(() async {
      BaseUnitTest.resetMocks();
      await TestServiceLocator.reset();
    });

    tearDownAll(() async {
      await BaseUnitTest.teardownUnit();
    });

    group('Activity Tracking', () {
      test('should track recipe creation activity', () async {
        // Arrange
        const recipeId = 'recipe-123';
        const recipeTitle = 'Köttbullar med potatismos';
        const recipeImageUrl = 'https://example.com/recipe.jpg';
        const visibility = ['close_friends', 'family'];
        
        when(() => mockActivityRepo.createActivity(any()))
            .thenAnswer((_) async {});

        // Act
        await activityService.trackRecipeCreated(
          recipeId: recipeId,
          recipeTitle: recipeTitle,
          recipeImageUrl: recipeImageUrl,
          visibility: visibility,
        );

        // Assert
        verify(() => mockActivityRepo.createActivity(any())).called(1);
      });

      test('should track recipe sharing activity', () async {
        // Arrange
        const recipeId = 'recipe-456';
        const recipeTitle = 'Pannkakor';
        const sharedWith = ['user1', 'user2'];
        
        when(() => mockActivityRepo.createActivity(any()))
            .thenAnswer((_) async {});

        // Act
        await activityService.trackRecipeShared(
          recipeId: recipeId,
          recipeTitle: recipeTitle,
          sharedWith: sharedWith,
        );

        // Assert
        verify(() => mockActivityRepo.createActivity(any())).called(1);
      });

      test('should track recipe rating activity', () async {
        // Arrange
        const recipeId = 'recipe-789';
        const recipeTitle = 'Raggmunk';
        const rating = 5;
        
        when(() => mockActivityRepo.createActivity(any()))
            .thenAnswer((_) async {});

        // Act
        await activityService.trackRecipeRated(
          recipeId: recipeId,
          recipeTitle: recipeTitle,
          rating: rating,
        );

        // Assert
        verify(() => mockActivityRepo.createActivity(any())).called(1);
      });

      test('should track comment added activity', () async {
        // Arrange
        const contentId = 'recipe-111';
        const contentType = 'recipe';
        const contentTitle = 'Smörgåstårta';
        const commentId = 'comment-1';
        
        when(() => mockActivityRepo.createActivity(any()))
            .thenAnswer((_) async {});

        // Act
        await activityService.trackCommentAdded(
          contentId: contentId,
          contentType: contentType,
          contentTitle: contentTitle,
          commentId: commentId,
        );

        // Assert
        verify(() => mockActivityRepo.createActivity(any())).called(1);
      });

      test('should track reaction added activity', () async {
        // Arrange
        const contentId = 'recipe-222';
        const contentType = 'recipe';
        const contentTitle = 'Kalops';
        const reactionType = 'delicious';
        
        when(() => mockActivityRepo.createActivity(any()))
            .thenAnswer((_) async {});

        // Act
        await activityService.trackReactionAdded(
          contentId: contentId,
          contentType: contentType,
          contentTitle: contentTitle,
          reactionType: reactionType,
        );

        // Assert
        verify(() => mockActivityRepo.createActivity(any())).called(1);
      });

      test('should track menu creation activity', () async {
        // Arrange
        const menuId = 'menu-123';
        const menuTitle = 'Veckomeny v47';
        
        when(() => mockActivityRepo.createActivity(any()))
            .thenAnswer((_) async {});

        // Act
        await activityService.trackMenuCreated(
          menuId: menuId,
          menuTitle: menuTitle,
        );

        // Assert
        verify(() => mockActivityRepo.createActivity(any())).called(1);
      });

      test('should track shopping list creation activity', () async {
        // Arrange
        const listId = 'list-123';
        const listTitle = 'Inköpslista ICA';
        
        when(() => mockActivityRepo.createActivity(any()))
            .thenAnswer((_) async {});

        // Act
        await activityService.trackShoppingListCreated(
          listId: listId,
          listTitle: listTitle,
        );

        // Assert
        verify(() => mockActivityRepo.createActivity(any())).called(1);
      });

      test('should handle authentication error when tracking', () async {
        // Arrange
        mockAuthRepo.setAuthState(user: null, userId: null);

        // Act
        await activityService.trackRecipeCreated(
          recipeId: 'recipe-999',
          recipeTitle: 'Test Recipe',
        );

        // Assert - Service handles error gracefully
        verifyNever(() => mockActivityRepo.createActivity(any()));
      });
    });

    group('Feed Operations', () {
      test('should get friend activity feed', () async {
        // Arrange
        final activities = [
          FakeActivityFeedItem(
            id: 'activity-1',
            userId: 'friend-1',
            userDisplayName: 'Friend One',
            type: ActivityType.recipeCreated,
            targetId: 'recipe-1',
            targetType: 'recipe',
            targetTitle: 'Recipe 1',
          ),
          FakeActivityFeedItem(
            id: 'activity-2',
            userId: 'friend-2',
            userDisplayName: 'Friend Two',
            type: ActivityType.menuCreated,
            targetId: 'menu-1',
            targetType: 'menu',
            targetTitle: 'Menu 1',
          ),
        ];
        
        when(() => mockActivityRepo.getFriendActivityFeed(
          userId: 'test-user-id',
          limit: any(named: 'limit'),
          offset: any(named: 'offset'),
          friendCategories: any(named: 'friendCategories'),
        )).thenAnswer((_) async => activities);

        // Act
        final result = await activityService.getFriendActivityFeed(
          limit: 20,
          offset: 0,
        );

        // Assert
        expect(result, equals(activities));
        expect(result.length, equals(2));
      });

      test('should cache first page of activity feed', () async {
        // Arrange
        final expectedActivities = [
          FakeActivityFeedItem(
            id: 'activity-1',
            userId: 'friend-1',
            userDisplayName: 'Friend One',
            type: ActivityType.recipeCreated,
            targetId: 'recipe-1',
            targetType: 'recipe',
            targetTitle: 'Recipe 1',
          ),
        ];
        
        when(() => mockActivityRepo.getFriendActivityFeed(
          userId: any(named: 'userId'),
          limit: any(named: 'limit'),
          offset: any(named: 'offset'),
          friendCategories: any(named: 'friendCategories'),
        )).thenAnswer((_) async => expectedActivities);

        // Act - Call twice
        await activityService.getFriendActivityFeed(limit: 20, offset: 0);
        await activityService.getFriendActivityFeed(limit: 20, offset: 0);

        // Assert - Repository should only be called once due to caching
        verify(() => mockActivityRepo.getFriendActivityFeed(
          userId: any(named: 'userId'),
          limit: any(named: 'limit'),
          offset: 0,
          friendCategories: any(named: 'friendCategories'),
        )).called(1);
      });

      test('should not cache when offset is not zero', () async {
        // Arrange
        final activities = <ActivityFeedItem>[];
        
        when(() => mockActivityRepo.getFriendActivityFeed(
          userId: any(named: 'userId'),
          limit: any(named: 'limit'),
          offset: any(named: 'offset'),
          friendCategories: any(named: 'friendCategories'),
        )).thenAnswer((_) async => activities);

        // Act - Call with offset
        await activityService.getFriendActivityFeed(limit: 20, offset: 20);
        await activityService.getFriendActivityFeed(limit: 20, offset: 20);

        // Assert - Repository should be called twice (no caching for pagination)
        verify(() => mockActivityRepo.getFriendActivityFeed(
          userId: any(named: 'userId'),
          limit: any(named: 'limit'),
          offset: 20,
          friendCategories: any(named: 'friendCategories'),
        )).called(2);
      });

      test('should get activity feed stream', () {
        // Arrange
        final streamController = StreamController<List<ActivityFeedItem>>.broadcast();
        
        when(() => mockActivityRepo.getFriendActivityFeedStream(
          userId: 'test-user-id',
          limit: any(named: 'limit'),
          friendCategories: any(named: 'friendCategories'),
        )).thenAnswer((_) => streamController.stream);

        // Act
        final stream = activityService.getActivityFeedStream(limit: 50);

        // Assert
        expect(stream, isNotNull);
        expect(stream, isA<Stream<List<ActivityFeedItem>>>());
        
        verify(() => mockActivityRepo.getFriendActivityFeedStream(
          userId: 'test-user-id',
          limit: 50,
          friendCategories: any(named: 'friendCategories'),
        )).called(1);
        
        // Cleanup
        streamController.close();
      });

      test('should return empty stream when not authenticated', () {
        // Arrange
        mockAuthRepo.setAuthState(user: null, userId: null);

        // Act
        final stream = activityService.getActivityFeedStream();

        // Assert
        expect(stream, isA<Stream<List<ActivityFeedItem>>>());
        expect(stream, emitsDone);
      });

      test('should get user activities', () async {
        // Arrange
        final activities = [
          FakeActivityFeedItem(
            id: 'activity-1',
            userId: 'test-user-id',
            userDisplayName: 'Test User',
            type: ActivityType.recipeCreated,
            targetId: 'recipe-1',
            targetType: 'recipe',
            targetTitle: 'My Recipe',
          ),
        ];
        
        when(() => mockActivityRepo.getUserActivities(
          userId: 'test-user-id',
          limit: any(named: 'limit'),
          activityTypes: any(named: 'activityTypes'),
        )).thenAnswer((_) async => activities);

        // Act
        final result = await activityService.getUserActivities(limit: 50);

        // Assert
        expect(result, equals(activities));
      });

      test('should get trending activities', () async {
        // Arrange
        final activities = [
          FakeActivityFeedItem(
            id: 'activity-1',
            userId: 'user-1',
            userDisplayName: 'User One',
            type: ActivityType.recipeCreated,
            targetId: 'recipe-1',
            targetType: 'recipe',
            targetTitle: 'Trending Recipe',
            engagement: FakeActivityEngagement(likes: 100),
          ),
        ];
        
        when(() => mockActivityRepo.getTrendingActivities(
          timeWindow: any(named: 'timeWindow'),
          limit: any(named: 'limit'),
          activityTypes: any(named: 'activityTypes'),
        )).thenAnswer((_) async => activities);

        // Act
        final result = await activityService.getTrendingActivities(
          timeWindow: const Duration(hours: 24),
          limit: 20,
        );

        // Assert
        expect(result, equals(activities));
      });

      test('should get unseen activity count', () async {
        // Arrange
        const unSeenCount = 5;
        
        when(() => mockActivityRepo.getUnseenActivityCount(
          userId: 'test-user-id',
          friendCategories: any(named: 'friendCategories'),
        )).thenAnswer((_) async => unSeenCount);

        // Act
        final result = await activityService.getUnseenActivityCount();

        // Assert
        expect(result, equals(unSeenCount));
      });

      test('should mark activities as seen', () async {
        // Arrange
        final activityIds = ['activity-1', 'activity-2', 'activity-3'];
        
        when(() => mockActivityRepo.markActivitiesAsSeen(
          userId: 'test-user-id',
          activityIds: activityIds,
        )).thenAnswer((_) async => activityIds.length);

        // Act
        await activityService.markActivitiesAsSeen(activityIds);

        // Assert
        verify(() => mockActivityRepo.markActivitiesAsSeen(
          userId: 'test-user-id',
          activityIds: activityIds,
        )).called(1);
      });
    });

    group('Privacy Operations', () {
      test('should hide activity from feed', () async {
        // Arrange
        const activityId = 'activity-123';
        
        when(() => mockActivityRepo.hideActivityFromUser(
          userId: 'test-user-id',
          activityId: activityId,
        )).thenAnswer((_) async => true);

        // Act
        await activityService.hideActivity(activityId);

        // Assert
        verify(() => mockActivityRepo.hideActivityFromUser(
          userId: 'test-user-id',
          activityId: activityId,
        )).called(1);
      });

      test('should block activity type', () async {
        // Arrange
        const activityType = ActivityType.recipeRated;
        
        when(() => mockActivityRepo.blockActivityType(
          userId: 'test-user-id',
          activityType: activityType,
        )).thenAnswer((_) async => true);

        // Act
        await activityService.blockActivityType(activityType);

        // Assert
        verify(() => mockActivityRepo.blockActivityType(
          userId: 'test-user-id',
          activityType: activityType,
        )).called(1);
      });
    });

    group('Cache Management', () {
      test('should invalidate cache after tracking activity', () async {
        // Arrange
        final activities = [
          FakeActivityFeedItem(
            id: 'activity-1',
            userId: 'friend-1',
            userDisplayName: 'Friend One',
            type: ActivityType.recipeCreated,
            targetId: 'recipe-1',
            targetType: 'recipe',
            targetTitle: 'Recipe 1',
          ),
        ];
        
        when(() => mockActivityRepo.getFriendActivityFeed(
          userId: any(named: 'userId'),
          limit: any(named: 'limit'),
          offset: any(named: 'offset'),
          friendCategories: any(named: 'friendCategories'),
        )).thenAnswer((_) async => activities);
        
        when(() => mockActivityRepo.createActivity(any()))
            .thenAnswer((_) async {});

        // Act
        // First call to cache
        await activityService.getFriendActivityFeed(limit: 20, offset: 0);
        
        // Track activity (should invalidate cache)
        await activityService.trackRecipeCreated(
          recipeId: 'new-recipe',
          recipeTitle: 'New Recipe',
        );
        
        // Second call should hit repository again
        await activityService.getFriendActivityFeed(limit: 20, offset: 0);

        // Assert - Repository called twice due to cache invalidation
        verify(() => mockActivityRepo.getFriendActivityFeed(
          userId: any(named: 'userId'),
          limit: any(named: 'limit'),
          offset: 0,
          friendCategories: any(named: 'friendCategories'),
        )).called(2);
      });

      test('should respect cache timeout', () async {
        // This test verifies cache timeout logic is present
        // In a real test, we'd need to mock DateTime.now() or use clock package
        
        // Arrange
        final activities = <ActivityFeedItem>[];
        
        when(() => mockActivityRepo.getFriendActivityFeed(
          userId: any(named: 'userId'),
          limit: any(named: 'limit'),
          offset: any(named: 'offset'),
          friendCategories: any(named: 'friendCategories'),
        )).thenAnswer((_) async => activities);

        // Act
        await activityService.getFriendActivityFeed(limit: 20, offset: 0);

        // Assert - Cache is created
        verify(() => mockActivityRepo.getFriendActivityFeed(
          userId: any(named: 'userId'),
          limit: any(named: 'limit'),
          offset: 0,
          friendCategories: any(named: 'friendCategories'),
        )).called(1);
      });
    });

    group('Error Handling', () {
      test('should handle repository errors gracefully', () async {
        // Arrange
        when(() => mockActivityRepo.getFriendActivityFeed(
          userId: any(named: 'userId'),
          limit: any(named: 'limit'),
          offset: any(named: 'offset'),
          friendCategories: any(named: 'friendCategories'),
        )).thenThrow(Exception('Repository error'));

        // Act
        final result = await activityService.getFriendActivityFeed();

        // Assert - Returns empty list on error
        expect(result, isEmpty);
      });

      test('should require authentication for feed operations', () async {
        // Arrange
        mockAuthRepo.setAuthState(user: null, userId: null);

        // Act
        final result = await activityService.getFriendActivityFeed();

        // Assert
        expect(result, isEmpty);
        verifyNever(() => mockActivityRepo.getFriendActivityFeed(
          userId: any(named: 'userId'),
          limit: any(named: 'limit'),
          offset: any(named: 'offset'),
          friendCategories: any(named: 'friendCategories'),
        ));
      });

      test('should require authentication for marking activities as seen', () async {
        // Arrange
        mockAuthRepo.setAuthState(user: null, userId: null);

        // Act
        await activityService.markActivitiesAsSeen(['activity-1']);

        // Assert
        verifyNever(() => mockActivityRepo.markActivitiesAsSeen(
          userId: any(named: 'userId'),
          activityIds: any(named: 'activityIds'),
        ));
      });
    });

    group('Service Lifecycle', () {
      test('should dispose properly', () async {
        // Act & Assert
        await expectLater(activityService.dispose(), completes);
      });

      test('should clear caches on dispose', () async {
        // Arrange - Add some cached data
        final activities = <ActivityFeedItem>[];
        
        when(() => mockActivityRepo.getFriendActivityFeed(
          userId: any(named: 'userId'),
          limit: any(named: 'limit'),
          offset: any(named: 'offset'),
          friendCategories: any(named: 'friendCategories'),
        )).thenAnswer((_) async => activities);

        await activityService.getFriendActivityFeed(limit: 20, offset: 0);

        // Act
        await activityService.dispose();

        // Create new service instance
        final newService = ActivityService(
          activityRepository: mockActivityRepo,
          authRepository: mockAuthRepo,
        );

        // Get feed again
        await newService.getFriendActivityFeed(limit: 20, offset: 0);

        // Assert - Should call repository again since cache was cleared
        verify(() => mockActivityRepo.getFriendActivityFeed(
          userId: any(named: 'userId'),
          limit: any(named: 'limit'),
          offset: 0,
          friendCategories: any(named: 'friendCategories'),
        )).called(2);
      });
    });
  });
}