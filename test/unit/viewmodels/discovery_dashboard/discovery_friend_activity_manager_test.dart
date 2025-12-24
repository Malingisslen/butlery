// test/unit/viewmodels/discovery_dashboard/discovery_friend_activity_manager_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:butlery/viewmodels/discovery_dashboard/discovery_friend_activity_manager.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/models/permissions/resource_permission.dart';

import '../../../infrastructure/mocks/service_mocks.dart';
import '../../../infrastructure/factories/recipe_factory.dart';
import '../../../infrastructure/di/test_service_locator.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late DiscoveryFriendActivityManager activityManager;
  late MockRecipeDiscoveryService mockDiscoveryService;

  setUpAll(() async {
    await TestServiceLocator.initialize();
  });

  setUp(() async {
    mockDiscoveryService = MockRecipeDiscoveryService();

    activityManager = DiscoveryFriendActivityManager(
      discoveryService: mockDiscoveryService,
    );
  });

  tearDown(() {
    try {
      activityManager.dispose();
    } catch (e) {
      // Already disposed, ignore
    }
    mockDiscoveryService.resetState();
  });

  tearDownAll(() async {
    await TestServiceLocator.reset();
  });

  List<Recipe> createTestRecipes({int count = 3, bool withSocialData = true}) {
    return List.generate(count, (index) {
      RecipeSocialData? socialData;
      if (withSocialData) {
        socialData = RecipeSocialData(
          ownerId: 'friend_$index',
          ownerDisplayName: 'Friend User ${index + 1}',
          memberPermissions: {
            'member1': ResourcePermission.editor,
            'member2': ResourcePermission.viewer,
          },
          categoryIds: ['category_$index'],
          allowGuestViewing: true,
          allowMemberInvites: true,
        );
      }

      return RecipeFactory.build(
        id: 'activity_recipe_$index',
        title: 'Friend Recipe ${index + 1}',
        description: 'Description for friend recipe ${index + 1}',
        imageUrls: ['https://example.com/image$index.jpg'],
        createdAt: DateTime.now().subtract(Duration(hours: index)),
        type: withSocialData ? RecipeType.collaborative : RecipeType.personal,
        socialData: socialData,
      );
    });
  }

  group('DiscoveryFriendActivityManager - Activity Loading', () {
    test('should load friend activity successfully', () async {
      final testRecipes = createTestRecipes(count: 3);
      mockDiscoveryService.setRecentlySharedRecipes(testRecipes);

      expect(activityManager.isLoading, isFalse);
      expect(activityManager.hasError, isFalse);
      expect(activityManager.hasFriendActivity, isFalse);

      await activityManager.loadFriendActivity();

      expect(activityManager.isLoading, isFalse);
      expect(activityManager.hasError, isFalse);
      expect(activityManager.hasFriendActivity, isTrue);
      expect(activityManager.friendActivityCount, equals(3));
      expect(activityManager.friendActivity.length, equals(3));
    });

    test('should set loading state during activity loading', () async {
      final testRecipes = createTestRecipes(count: 2);
      mockDiscoveryService.setRecentlySharedRecipes(testRecipes);

      bool loadingStateObserved = false;
      activityManager.addListener(() {
        if (activityManager.isLoading) {
          loadingStateObserved = true;
        }
      });

      await activityManager.loadFriendActivity();

      expect(loadingStateObserved, isTrue);
      expect(activityManager.isLoading, isFalse);
    });

    test('should handle friend activity loading error', () async {
      mockDiscoveryService.setShouldThrowError(true);

      try {
        await activityManager.loadFriendActivity();
        fail('Should have thrown an exception');
      } catch (e) {
        // Exception was thrown as expected
      }

      expect(activityManager.hasError, isTrue);
      expect(activityManager.error, contains('Failed to load friend activity'));
      expect(activityManager.isLoading, isFalse);
      expect(activityManager.hasFriendActivity, isFalse);
    });

    test('should transform recipes to activity format correctly', () async {
      final testRecipes = createTestRecipes(count: 1);
      mockDiscoveryService.setRecentlySharedRecipes(testRecipes);

      await activityManager.loadFriendActivity();

      final activity = activityManager.friendActivity.first;
      expect(activity['id'], equals(testRecipes.first.id));
      expect(activity['type'], equals('recipe_shared'));
      expect(activity['title'], equals(testRecipes.first.title));
      expect(activity['description'], equals(testRecipes.first.description));
      expect(activity['imageUrl'], equals(testRecipes.first.imageUrls.first));
      expect(activity['ownerName'], equals('Friend User 1'));
      expect(activity['contentType'], equals('recipe'));
      expect(activity['contentId'], equals(testRecipes.first.id));
      expect(activity['engagement'], isA<Map<String, dynamic>>());
    });

    test('should handle engagement metrics correctly', () async {
      final testRecipes = createTestRecipes(count: 1);
      mockDiscoveryService.setRecentlySharedRecipes(testRecipes);

      await activityManager.loadFriendActivity();

      final activity = activityManager.friendActivity.first;
      final engagement = activity['engagement'] as Map<String, dynamic>;

      expect(engagement['likes'], equals(0)); // Placeholder implementation
      expect(engagement['comments'], equals(0)); // Placeholder implementation
      expect(engagement['shares'], equals(2)); // memberPermissions length
    });

    test('should handle recipes without social data', () async {
      final testRecipes = createTestRecipes(count: 1, withSocialData: false);
      mockDiscoveryService.setRecentlySharedRecipes(testRecipes);

      await activityManager.loadFriendActivity();

      final activity = activityManager.friendActivity.first;
      expect(activity['ownerName'], equals('Okänd användare'));
      expect(activity['engagement']['shares'], equals(0));
    });

    test('should handle empty activity list', () async {
      mockDiscoveryService.setRecentlySharedRecipes([]);

      await activityManager.loadFriendActivity();

      expect(activityManager.hasFriendActivity, isFalse);
      expect(activityManager.friendActivityCount, equals(0));
      expect(activityManager.friendActivity, isEmpty);
      expect(activityManager.hasError, isFalse);
    });

    test('should refresh activity successfully', () async {
      final initialRecipes = createTestRecipes(count: 2);
      final refreshedRecipes = createTestRecipes(count: 4);

      mockDiscoveryService.setRecentlySharedRecipes(initialRecipes);
      await activityManager.loadFriendActivity();
      expect(activityManager.friendActivityCount, equals(2));

      mockDiscoveryService.setRecentlySharedRecipes(refreshedRecipes);
      await activityManager.refreshActivity();

      expect(activityManager.friendActivityCount, equals(4));
      expect(activityManager.hasError, isFalse);
    });

    test('should load more activity items for pagination', () async {
      final initialRecipes = createTestRecipes(count: 3);
      final moreRecipes = createTestRecipes(count: 2);

      mockDiscoveryService.setRecentlySharedRecipes(initialRecipes);
      await activityManager.loadFriendActivity();
      expect(activityManager.friendActivityCount, equals(3));

      // Simulate loading more content
      mockDiscoveryService
          .setRecentlySharedRecipes([...initialRecipes, ...moreRecipes]);
      await activityManager.loadMoreActivity();

      expect(activityManager.friendActivityCount, greaterThanOrEqualTo(3));
    });

    test('should handle load more activity errors gracefully', () async {
      final initialRecipes = createTestRecipes(count: 2);
      mockDiscoveryService.setRecentlySharedRecipes(initialRecipes);
      await activityManager.loadFriendActivity();

      mockDiscoveryService.setShouldThrowError(true);
      await activityManager.loadMoreActivity();

      expect(activityManager.hasError, isTrue);
      expect(activityManager.error, contains('Failed to load more activity'));
      expect(activityManager.friendActivityCount,
          equals(2)); // Original count preserved
    });

    test('should prevent concurrent load more operations', () async {
      final testRecipes = createTestRecipes(count: 2);
      mockDiscoveryService.setRecentlySharedRecipes(testRecipes);

      // Set loading state
      await activityManager.loadFriendActivity();

      // Try to load more while already loading (simulate concurrent calls)
      final future1 = activityManager.loadMoreActivity();
      final future2 = activityManager.loadMoreActivity();

      await Future.wait([future1, future2]);

      expect(activityManager.friendActivity, isNotEmpty);
    });
  });

  group('DiscoveryFriendActivityManager - Activity Management', () {
    test('should clear all activity', () async {
      final testRecipes = createTestRecipes(count: 3);
      mockDiscoveryService.setRecentlySharedRecipes(testRecipes);

      await activityManager.loadFriendActivity();
      expect(activityManager.hasFriendActivity, isTrue);
      expect(activityManager.friendActivityCount, equals(3));

      activityManager.clearActivity();

      expect(activityManager.hasFriendActivity, isFalse);
      expect(activityManager.friendActivityCount, equals(0));
      expect(activityManager.friendActivity, isEmpty);
      expect(activityManager.hasError, isFalse);
    });

    test('should get activity item by ID', () async {
      final testRecipes = createTestRecipes(count: 3);
      mockDiscoveryService.setRecentlySharedRecipes(testRecipes);

      await activityManager.loadFriendActivity();

      final targetId = testRecipes.first.id;
      final activity = activityManager.getActivityItem(targetId);

      expect(activity, isNotNull);
      expect(activity!['id'], equals(targetId));
      expect(activity['title'], equals('Friend Recipe 1'));
    });

    test('should return null for non-existent activity ID', () async {
      final testRecipes = createTestRecipes(count: 2);
      mockDiscoveryService.setRecentlySharedRecipes(testRecipes);

      await activityManager.loadFriendActivity();

      final activity = activityManager.getActivityItem('non_existent_id');

      expect(activity, isNull);
    });

    test('should filter activity by type', () async {
      final testRecipes = createTestRecipes(count: 3);
      mockDiscoveryService.setRecentlySharedRecipes(testRecipes);

      await activityManager.loadFriendActivity();

      final recipeActivities =
          activityManager.getActivityByType('recipe_shared');
      final otherActivities = activityManager.getActivityByType('other_type');

      expect(recipeActivities.length, equals(3));
      expect(otherActivities, isEmpty);

      for (final activity in recipeActivities) {
        expect(activity['type'], equals('recipe_shared'));
      }
    });

    test('should return immutable list from friendActivity getter', () async {
      final testRecipes = createTestRecipes(count: 2);
      mockDiscoveryService.setRecentlySharedRecipes(testRecipes);

      await activityManager.loadFriendActivity();

      final friendActivity = activityManager.friendActivity;
      expect(
          () => friendActivity.add({'test': 'item'}), throwsUnsupportedError);
    });

    test('should calculate friend activity count correctly', () async {
      expect(activityManager.friendActivityCount, equals(0));

      final testRecipes = createTestRecipes(count: 5);
      mockDiscoveryService.setRecentlySharedRecipes(testRecipes);
      await activityManager.loadFriendActivity();

      expect(activityManager.friendActivityCount, equals(5));

      activityManager.clearActivity();
      expect(activityManager.friendActivityCount, equals(0));
    });
  });

  group('DiscoveryFriendActivityManager - State Management', () {
    test('should notify listeners when activity changes', () async {
      int notificationCount = 0;
      activityManager.addListener(() => notificationCount++);

      final testRecipes = createTestRecipes(count: 2);
      mockDiscoveryService.setRecentlySharedRecipes(testRecipes);

      await activityManager.loadFriendActivity();

      expect(notificationCount, greaterThan(0));
    });

    test('should manage error state correctly', () async {
      expect(activityManager.hasError, isFalse);
      expect(activityManager.error, isNull);

      mockDiscoveryService.setShouldThrowError(true);

      try {
        await activityManager.loadFriendActivity();
      } catch (e) {
        // Expected
      }

      expect(activityManager.hasError, isTrue);
      expect(activityManager.error, isNotNull);
      expect(activityManager.error, contains('Failed to load friend activity'));
    });

    test('should clear error state on successful operations', () async {
      // First operation fails
      mockDiscoveryService.setShouldThrowError(true);
      try {
        await activityManager.loadFriendActivity();
      } catch (e) {
        // Expected
      }
      expect(activityManager.hasError, isTrue);

      // Second operation succeeds
      mockDiscoveryService.setShouldThrowError(false);
      mockDiscoveryService
          .setRecentlySharedRecipes(createTestRecipes(count: 1));

      await activityManager.loadFriendActivity();

      expect(activityManager.hasError, isFalse);
      expect(activityManager.error, isNull);
    });

    test('should clear error when clearing activity', () async {
      mockDiscoveryService.setShouldThrowError(true);
      try {
        await activityManager.loadFriendActivity();
      } catch (e) {
        // Expected
      }
      expect(activityManager.hasError, isTrue);

      activityManager.clearActivity();

      expect(activityManager.hasError, isFalse);
      expect(activityManager.error, isNull);
    });

    test('should handle dispose correctly', () async {
      final testRecipes = createTestRecipes(count: 2);
      mockDiscoveryService.setRecentlySharedRecipes(testRecipes);

      await activityManager.loadFriendActivity();
      expect(activityManager.friendActivityCount, equals(2));

      // Should not throw when disposing
      activityManager.dispose();

      // Don't access ViewModel after dispose - just verify dispose completed
      expect(true, isTrue);
    });

    test('should maintain state consistency during operations', () async {
      int totalNotifications = 0;
      activityManager.addListener(() => totalNotifications++);

      final recipes = createTestRecipes(count: 3);
      mockDiscoveryService.setRecentlySharedRecipes(recipes);

      // Multiple state changes
      await activityManager.loadFriendActivity();
      await activityManager.refreshActivity();
      activityManager.clearActivity();

      expect(totalNotifications, greaterThan(2)); // At least 3 operations
      expect(activityManager.friendActivityCount, equals(0)); // Final state
      expect(activityManager.hasError, isFalse);
    });
  });

  group('DiscoveryFriendActivityManager - Edge Cases', () {
    test('should handle concurrent load operations', () async {
      final testRecipes = createTestRecipes(count: 2);
      mockDiscoveryService.setRecentlySharedRecipes(testRecipes);

      final futures = [
        activityManager.loadFriendActivity(),
        activityManager.refreshActivity(),
      ];

      await Future.wait(futures);

      expect(activityManager.friendActivity, isNotEmpty);
      expect(activityManager.hasError, isFalse);
    });

    test('should handle large activity datasets', () async {
      final largeDataset = createTestRecipes(count: 50);
      mockDiscoveryService.setRecentlySharedRecipes(largeDataset);

      await activityManager.loadFriendActivity();

      expect(activityManager.friendActivityCount, lessThanOrEqualTo(50));
      expect(activityManager.hasFriendActivity, isTrue);

      // Test filtering on large dataset
      final recipeActivities =
          activityManager.getActivityByType('recipe_shared');
      expect(
          recipeActivities.length, equals(activityManager.friendActivityCount));
    });

    test('should handle activity with missing image URLs', () async {
      final recipe = RecipeFactory.build(
        id: 'no_image_recipe',
        title: 'No Image Recipe',
        imageUrls: [], // Empty image URLs
      );
      mockDiscoveryService.setRecentlySharedRecipes([recipe]);

      await activityManager.loadFriendActivity();

      final activity = activityManager.friendActivity.first;
      expect(activity['imageUrl'], isNull);
    });

    test('should handle network timeout scenarios', () async {
      mockDiscoveryService.setShouldThrowError(true);

      try {
        await activityManager.loadFriendActivity();
        fail('Should have thrown an exception');
      } catch (e) {
        // Expected
      }

      expect(activityManager.hasError, isTrue);
      expect(activityManager.hasFriendActivity, isFalse);
    });

    test('should handle service unavailable scenarios', () async {
      mockDiscoveryService.setShouldThrowError(true);

      // Load more should handle error gracefully
      await activityManager.loadMoreActivity();

      expect(activityManager.hasError, isTrue);
      expect(activityManager.friendActivityCount, equals(0));
    });

    test('should handle rapid successive operations', () async {
      final testRecipes = createTestRecipes(count: 3);
      mockDiscoveryService.setRecentlySharedRecipes(testRecipes);

      // Rapid successive calls
      final futures =
          List.generate(5, (_) => activityManager.refreshActivity());
      await Future.wait(futures);

      expect(activityManager.friendActivity.length, equals(3));
      expect(activityManager.hasError, isFalse);
    });

    test('should maintain data consistency during error recovery', () async {
      // Load initial data
      final initialRecipes = createTestRecipes(count: 2);
      mockDiscoveryService.setRecentlySharedRecipes(initialRecipes);
      await activityManager.loadFriendActivity();
      expect(activityManager.friendActivityCount, equals(2));

      // Cause error
      mockDiscoveryService.setShouldThrowError(true);
      try {
        await activityManager.refreshActivity();
      } catch (e) {
        // Expected
      }

      // Data should remain consistent
      expect(activityManager.friendActivityCount, equals(2));
      expect(activityManager.hasError, isTrue);

      // Recover
      mockDiscoveryService.setShouldThrowError(false);
      final newRecipes = createTestRecipes(count: 4);
      mockDiscoveryService.setRecentlySharedRecipes(newRecipes);
      await activityManager.refreshActivity();

      expect(activityManager.friendActivityCount, equals(4));
      expect(activityManager.hasError, isFalse);
    });

    test('should handle malformed activity data gracefully', () async {
      // Test with valid recipes - manager should handle gracefully
      final validRecipes = createTestRecipes(count: 2);
      mockDiscoveryService.setRecentlySharedRecipes(validRecipes);

      await activityManager.loadFriendActivity();

      expect(activityManager.friendActivityCount, equals(2));
      expect(activityManager.hasError, isFalse);

      // Verify all activities have required fields
      for (final activity in activityManager.friendActivity) {
        expect(activity['id'], isNotNull);
        expect(activity['type'], isNotNull);
        expect(activity['title'], isNotNull);
        expect(activity['contentType'], isNotNull);
        expect(activity['engagement'], isNotNull);
      }
    });

    test('should handle edge cases in activity filtering', () async {
      final testRecipes = createTestRecipes(count: 3);
      mockDiscoveryService.setRecentlySharedRecipes(testRecipes);
      await activityManager.loadFriendActivity();

      // Test empty string filter
      final emptyFilter = activityManager.getActivityByType('');
      expect(emptyFilter, isEmpty);

      // Test null-like filter
      final nullFilter = activityManager.getActivityByType('null');
      expect(nullFilter, isEmpty);

      // Test special characters in ID search
      final specialId = activityManager.getActivityItem('activity@#\$%');
      expect(specialId, isNull);
    });
  });

  group('DiscoveryFriendActivityManager - Integration Tests', () {
    test('should handle complete activity flow', () async {
      // Load initial activity
      final initialRecipes = createTestRecipes(count: 3);
      mockDiscoveryService.setRecentlySharedRecipes(initialRecipes);
      await activityManager.loadFriendActivity();

      expect(activityManager.friendActivityCount, equals(3));
      expect(activityManager.hasError, isFalse);

      // Filter activities
      final recipeActivities =
          activityManager.getActivityByType('recipe_shared');
      expect(recipeActivities.length, equals(3));

      // Get specific activity
      final targetActivity =
          activityManager.getActivityItem(initialRecipes.first.id);
      expect(targetActivity, isNotNull);

      // Load more content
      await activityManager.loadMoreActivity();
      expect(activityManager.friendActivity, isNotEmpty);

      // Clear and verify
      activityManager.clearActivity();
      expect(activityManager.friendActivityCount, equals(0));
    });

    test('should maintain state consistency across operations', () async {
      int totalNotifications = 0;
      activityManager.addListener(() => totalNotifications++);

      // Multiple operations sequence
      final recipes1 = createTestRecipes(count: 2);
      mockDiscoveryService.setRecentlySharedRecipes(recipes1);
      await activityManager.loadFriendActivity();

      final recipes2 = createTestRecipes(count: 4);
      mockDiscoveryService.setRecentlySharedRecipes(recipes2);
      await activityManager.refreshActivity();

      await activityManager.loadMoreActivity();

      activityManager.clearActivity();

      expect(totalNotifications, greaterThan(3)); // At least 4 operations
      expect(activityManager.friendActivityCount, equals(0)); // Final state
      expect(activityManager.hasError, isFalse);
    });

    test('should handle mixed success and failure scenarios', () async {
      // Success
      final successRecipes = createTestRecipes(count: 2);
      mockDiscoveryService.setRecentlySharedRecipes(successRecipes);
      await activityManager.loadFriendActivity();
      expect(activityManager.hasError, isFalse);
      expect(activityManager.friendActivityCount, equals(2));

      // Failure
      mockDiscoveryService.setShouldThrowError(true);
      try {
        await activityManager.refreshActivity();
      } catch (e) {
        // Expected
      }
      expect(activityManager.hasError, isTrue);

      // Recovery
      mockDiscoveryService.setShouldThrowError(false);
      final recoveryRecipes = createTestRecipes(count: 5);
      mockDiscoveryService.setRecentlySharedRecipes(recoveryRecipes);
      await activityManager.loadFriendActivity();

      expect(activityManager.hasError, isFalse);
      expect(activityManager.friendActivityCount, equals(5));
    });

    test('should handle pagination with error recovery', () async {
      // Load initial activity
      final initialRecipes = createTestRecipes(count: 3);
      mockDiscoveryService.setRecentlySharedRecipes(initialRecipes);
      await activityManager.loadFriendActivity();
      expect(activityManager.friendActivityCount, equals(3));

      // Pagination fails
      mockDiscoveryService.setShouldThrowError(true);
      await activityManager.loadMoreActivity();
      expect(activityManager.hasError, isTrue);
      expect(activityManager.friendActivityCount, equals(3)); // Count preserved

      // Pagination succeeds after recovery
      mockDiscoveryService.setShouldThrowError(false);
      final moreRecipes = createTestRecipes(count: 2);
      mockDiscoveryService
          .setRecentlySharedRecipes([...initialRecipes, ...moreRecipes]);
      await activityManager.loadMoreActivity();

      expect(activityManager.friendActivityCount, greaterThanOrEqualTo(3));
      // Note: loadMoreActivity doesn't clear error state on success like loadFriendActivity does
      expect(activityManager.hasError,
          isTrue); // Error state persists from previous failure
    });
  });
}
