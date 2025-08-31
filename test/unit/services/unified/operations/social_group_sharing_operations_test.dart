import 'package:flutter_test/flutter_test.dart';
import 'package:butlery/services/unified/operations/social_group_sharing_operations.dart';
import 'package:butlery/models/friend_category.dart';
import 'package:butlery/models/shared_content.dart';
import 'package:butlery/models/user_profile.dart';
import 'package:butlery/repositories/interfaces/social_sharing_repository.dart';
import 'package:mocktail/mocktail.dart';
import 'package:get_it/get_it.dart';

import '../../../../test_support/base_unit_test.dart';
import '../../../../infrastructure/di/test_service_locator.dart';
import '../../../../infrastructure/builders/user_builder.dart';
import '../../../../infrastructure/mocks/production_mocks.dart';

void main() {
  group('SocialGroupSharingOperations', () {
    late SocialGroupSharingOperations operations;
    late MockUnifiedFriendsService mockParentService;
    late MockSocialSharingRepository mockSharingRepository;
    late List<FriendCategory> testCategories;
    late List<UserProfile> testFriends;
    late SharedContent testContent;

    setUpAll(() async {
      await BaseUnitTest.setupUnit();
      registerFallbackValue(SharedContent(
        id: 'test',
        contentType: 'recipe',
        contentId: 'test',
        ownerId: 'test',
        sharedAt: DateTime.now(),
        sharedWithUserIds: [],
        sharedWithGroupIds: [],
        metadata: {},
        permissions: SharingPermissions(),
      ));
      registerFallbackValue(FriendCategory(
        id: 'test',
        name: 'Test',
        ownerId: 'test',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ));
    });

    setUp(() async {
      await TestServiceLocator.initialize();

      // Create test data
      testFriends = [
        UserBuilder().withId('friend-1').withName('Anna Andersson').build(),
        UserBuilder().withId('friend-2').withName('Erik Eriksson').build(),
        UserBuilder().withId('friend-3').withName('Maria Nilsson').build(),
      ];

      testCategories = [
        FriendCategory(
          id: 'family-group',
          name: 'Family',
          description: 'Family members',
          ownerId: 'test-user-123',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          friendUserIds: ['friend-1', 'friend-2'],
          emoji: '👨‍👩‍👧‍👦',
        ),
        FriendCategory(
          id: 'cooking-club',
          name: 'Cooking Club',
          description: 'Cooking enthusiasts',
          ownerId: 'test-user-123',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          friendUserIds: ['friend-2', 'friend-3'],
          emoji: '👨‍🍳',
        ),
        FriendCategory(
          id: 'empty-group',
          name: 'Empty Group',
          description: 'No members yet',
          ownerId: 'test-user-123',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          friendUserIds: [],
          emoji: '📭',
        ),
      ];

      testContent = SharedContent(
        id: 'content-123',
        contentType: 'recipe',
        contentId: 'recipe-456',
        ownerId: 'test-user-123',
        sharedAt: DateTime.now(),
        sharedWithUserIds: [],
        sharedWithGroupIds: [],
        metadata: {
          'title': 'Swedish Meatballs',
          'description': 'Traditional Swedish recipe',
          'imageUrl': 'https://example.com/meatballs.jpg',
        },
        permissions: SharingPermissions(),
      );

      // Create mock parent service
      mockParentService = MockUnifiedFriendsService();
      mockParentService.setFriendsState(
        currentUserId: 'test-user-123',
        currentUserDisplayName: 'Test User',
        categoriesList: testCategories,
        friends: testFriends,
      );

      // Create mock sharing repository
      mockSharingRepository = MockSocialSharingRepository();

      // Register mock repository with GetIt
      final getIt = GetIt.instance;
      if (getIt.isRegistered<SocialSharingRepository>()) {
        getIt.unregister<SocialSharingRepository>();
      }
      getIt.registerSingleton<SocialSharingRepository>(mockSharingRepository);

      // Create operations instance
      operations = SocialGroupSharingOperations(mockParentService);
    });

    tearDown(() async {
      // Unregister mock from GetIt
      final getIt = GetIt.instance;
      if (getIt.isRegistered<SocialSharingRepository>()) {
        getIt.unregister<SocialSharingRepository>();
      }
      BaseUnitTest.resetMocks();
      await TestServiceLocator.reset();
    });

    tearDownAll(() async {
      await BaseUnitTest.teardownUnit();
    });

    group('Group Content Sharing', () {
      test('should share content to group successfully', () async {
        // Act
        final result = await operations.shareContentToGroup(
          groupId: 'family-group',
          content: testContent,
        );

        // Assert
        expect(result, isTrue);
        expect(mockSharingRepository.sharedContent.length, equals(1));

        final shared = mockSharingRepository.sharedContent.first;
        expect(shared['groupId'], equals('family-group'));
        expect(shared['content'], equals(testContent));
      });

      test('should fail when group does not exist', () async {
        // Act
        final result = await operations.shareContentToGroup(
          groupId: 'non-existent-group',
          content: testContent,
        );

        // Assert
        expect(result, isFalse);
        expect(mockSharingRepository.sharedContent.length, equals(0));
      });

      test('should fail when user does not own content', () async {
        // Arrange
        final otherContent = SharedContent(
          id: 'other-content',
          contentType: 'recipe',
          contentId: 'other-recipe',
          ownerId: 'other-user', // Different owner
          sharedAt: DateTime.now(),
          sharedWithUserIds: [],
          sharedWithGroupIds: [],
          metadata: {
            'title': 'Other Recipe',
            'description': 'Not mine',
            'imageUrl': '',
          },
          permissions: SharingPermissions(),
        );

        // Act
        final result = await operations.shareContentToGroup(
          groupId: 'family-group',
          content: otherContent,
        );

        // Assert
        expect(result, isFalse);
        expect(mockSharingRepository.sharedContent.length, equals(0));
      });

      test('should share content to multiple groups', () async {
        // Act
        final result = await operations.shareContentToGroups(
          groupIds: ['family-group', 'cooking-club'],
          content: testContent,
        );

        // Assert
        expect(result, isTrue);
        expect(mockSharingRepository.sharedContent.length, equals(2));

        final groupIds = mockSharingRepository.sharedContent
            .map((s) => s['groupId'] as String)
            .toList();
        expect(groupIds, containsAll(['family-group', 'cooking-club']));
      });

      test('should handle partial failure in multiple group sharing', () async {
        // Act
        final result = await operations.shareContentToGroups(
          groupIds: ['family-group', 'non-existent-group', 'cooking-club'],
          content: testContent,
        );

        // Assert
        expect(result, isFalse); // Overall failure due to one failed
        expect(mockSharingRepository.sharedContent.length,
            equals(2)); // But two succeeded
      });
    });

    group('Group Member Resolution', () {
      test('should resolve group members', () {
        // Act
        final memberIds = operations.resolveGroupMembers('family-group');

        // Assert
        expect(memberIds.length, equals(2));
        expect(memberIds, containsAll(['friend-1', 'friend-2']));
      });

      test('should return empty list for non-existent group', () {
        // Act
        final memberIds = operations.resolveGroupMembers('non-existent');

        // Assert
        expect(memberIds, isEmpty);
      });

      test('should resolve group member profiles', () {
        // Act
        final profiles = operations.resolveGroupMemberProfiles('family-group');

        // Assert
        expect(profiles.length, equals(2));
        expect(
            profiles.map((p) => p.uid), containsAll(['friend-1', 'friend-2']));
        expect(profiles.first.displayName, equals('Anna Andersson'));
      });

      test('should resolve multiple groups to unique member IDs', () {
        // Act
        final memberIds = operations.resolveMultipleGroupMembers(
          ['family-group', 'cooking-club'],
        );

        // Assert
        // friend-1 is in family, friend-2 is in both, friend-3 is in cooking
        expect(memberIds.length, equals(3));
        expect(memberIds, containsAll(['friend-1', 'friend-2', 'friend-3']));
      });

      test('should handle empty group in member resolution', () {
        // Act
        final memberIds = operations.resolveGroupMembers('empty-group');

        // Assert
        expect(memberIds, isEmpty);
      });
    });

    group('Group Sharing Validation', () {
      test('should validate owner can share to group', () {
        // Act
        final canShare = operations.canShareToGroup(
          'family-group',
          'test-user-123',
        );

        // Assert
        expect(canShare, isTrue);
      });

      test('should validate member can share to group', () {
        // Arrange - Add current user as member
        testCategories.first.friendUserIds.add('test-user-123');

        // Act
        final canShare = operations.canShareToGroup(
          'family-group',
          'test-user-123',
        );

        // Assert
        expect(canShare, isTrue);
      });

      test('should reject non-member sharing to group', () {
        // Act
        final canShare = operations.canShareToGroup(
          'family-group',
          'stranger-123',
        );

        // Assert
        expect(canShare, isFalse);
      });

      test('should validate sharing to multiple groups', () {
        // Act
        final canShare = operations.canShareToGroups(
          ['family-group', 'cooking-club'],
          'test-user-123',
        );

        // Assert
        expect(canShare, isTrue);
      });

      test('should reject if cannot share to any group', () {
        // Act
        final canShare = operations.canShareToGroups(
          ['family-group', 'cooking-club'],
          'stranger-123',
        );

        // Assert
        expect(canShare, isFalse);
      });

      test('should check group accessibility', () {
        // Act & Assert
        expect(operations.isGroupAccessible('family-group'), isTrue);
        expect(operations.isGroupAccessible('non-existent'), isFalse);
      });
    });

    group('Group Sharing Statistics', () {
      test('should get group sharing stats', () {
        // Act
        final stats = operations.getGroupSharingStats('family-group');

        // Assert
        expect(stats['groupName'], equals('Family'));
        expect(stats['memberCount'], equals(2));
        expect(stats['groupEmoji'], equals('👨‍👩‍👧‍👦'));
        expect(stats['isOwner'], isTrue);
        expect(stats['createdAt'], isNotNull);
      });

      test('should handle stats for non-existent group', () {
        // Act
        final stats = operations.getGroupSharingStats('non-existent');

        // Assert
        expect(stats['groupName'], equals('Unknown'));
        expect(stats['memberCount'], equals(0));
        expect(stats['contentSharedToGroup'], equals(0));
      });

      test('should get multiple group sharing stats', () {
        // Act
        final stats = operations.getMultipleGroupSharingStats(
          ['family-group', 'cooking-club'],
        );

        // Assert
        expect(stats.length, equals(2));
        expect(stats['family-group']?['groupName'], equals('Family'));
        expect(stats['cooking-club']?['groupName'], equals('Cooking Club'));
        expect(stats['cooking-club']?['memberCount'], equals(2));
      });
    });

    group('Group Content Discovery', () {
      test('should get content shared to group', () async {
        // Act
        final content =
            await operations.getContentSharedToGroup('family-group');

        // Assert
        // Currently returns empty list as implementation is pending
        expect(content, isEmpty);
      });

      test('should get groups with shared content', () async {
        // Act
        final groups =
            await operations.getGroupsWithSharedContent('test-user-123');

        // Assert
        // Currently returns empty list as implementation is pending
        expect(groups, isEmpty);
      });
    });

    group('Helper Methods', () {
      test('should get group by ID', () {
        // Act
        final group = operations.getGroupById('family-group');

        // Assert
        expect(group, isNotNull);
        expect(group!.name, equals('Family'));
        expect(group.id, equals('family-group'));
      });

      test('should return null for non-existent group', () {
        // Act
        final group = operations.getGroupById('non-existent');

        // Assert
        expect(group, isNull);
      });

      test('should get available groups for sharing', () {
        // Act
        final groups = operations.getAvailableGroupsForSharing();

        // Assert
        expect(groups.length, equals(3));
        expect(groups.map((g) => g.id),
            containsAll(['family-group', 'cooking-club', 'empty-group']));
      });

      test('should filter groups based on membership', () {
        // Arrange - Add current user as member to only one group
        testCategories[0].friendUserIds.add('test-user-123');
        mockParentService.setFriendsState(categoriesList: testCategories);

        // Act
        final groups = operations.getAvailableGroupsForSharing();

        // Assert
        // All groups are owned by current user in test data
        expect(groups.length, equals(3));
      });
    });
  });
}
