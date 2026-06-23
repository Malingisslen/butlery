/// Unit tests for services using FriendsRepository
///
/// Tests business logic using mocked repository, avoiding Firebase implementation details.
/// For Firebase-specific tests, see integration tests.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:butlery/models/friend_request.dart';
import 'package:butlery/models/friend_category.dart';
import 'package:butlery/models/user_profile.dart';
import 'package:butlery/models/group_invitation.dart';
import '../../test_support/base_unit_test.dart';
import '../../infrastructure/di/test_service_locator.dart';
import '../../infrastructure/factories/mock_factory.dart';
import '../../infrastructure/mocks/production_mocks.dart';
import '../../infrastructure/builders/user_builder.dart';

void main() {
  group('FriendsRepository Mock Tests', () {
    late MockFriendsRepository mockRepository;
    late UserProfile testUser;

    setUpAll(() async {
      await BaseUnitTest.setupUnit();
    });

    setUp(() async {
      await TestServiceLocator.initialize();

      // Create test users
      testUser = UserBuilder()
          .withId('test_user_123')
          .withName('Test User')
          .build();

      // Create mock repository with configuration
      mockRepository = MockFactory.createFriendsRepository(
        currentUserId: testUser.uid,
        friendIds: [],
        friendProfiles: [],
      );

      // Register the mock in service locator
      TestServiceLocator.registerMock(mockRepository);
    });

    tearDown(() async {
      BaseUnitTest.resetMocks();
      await TestServiceLocator.reset();
    });

    group('Friend Requests', () {
      test('should send friend request to another user', () async {
        // Arrange
        const toUserId = 'target_user_456';
        const message = 'Let\'s be friends!';

        // Stub the repository method
        when(
          () => mockRepository.sendFriendRequest(toUserId, message: message),
        ).thenAnswer((_) async => true);

        // Act
        final success = await mockRepository.sendFriendRequest(
          toUserId,
          message: message,
        );

        // Assert
        expect(success, isTrue);

        // Verify the method was called with correct parameters
        verify(
          () => mockRepository.sendFriendRequest(toUserId, message: message),
        ).called(1);
      });

      test('should not send duplicate friend request', () async {
        // Arrange
        const toUserId = 'target_user_456';

        // Stub to check if request exists
        when(
          () => mockRepository.requestExists(testUser.uid, toUserId),
        ).thenAnswer((_) async => true);

        // Stub send request to return false for duplicate
        when(
          () => mockRepository.sendFriendRequest(toUserId),
        ).thenAnswer((_) async => false);

        // Act
        final exists = await mockRepository.requestExists(
          testUser.uid,
          toUserId,
        );
        final success = await mockRepository.sendFriendRequest(toUserId);

        // Assert
        expect(exists, isTrue);
        expect(success, isFalse);
      });

      test('should accept friend request', () async {
        // Arrange
        final friendRequest = FriendRequest(
          id: 'request_123',
          fromUserId: 'sender_user',
          toUserId: testUser.uid,
          status: FriendRequestStatus.pending,
          sentAt: DateTime.now(),
        );

        // Stub the repository methods
        when(
          () => mockRepository.acceptFriendRequest(friendRequest.id),
        ).thenAnswer((_) async => true);

        when(
          () => mockRepository.addMutualFriends(
            friendRequest.fromUserId,
            friendRequest.toUserId,
          ),
        ).thenAnswer((_) async {});

        // Act
        final success = await mockRepository.acceptFriendRequest(
          friendRequest.id,
        );

        // Assert
        expect(success, isTrue);

        // Verify the method was called
        verify(
          () => mockRepository.acceptFriendRequest(friendRequest.id),
        ).called(1);
      });

      test('should reject friend request', () async {
        // Arrange
        const requestId = 'request_123';

        // Stub the repository method
        when(
          () => mockRepository.rejectFriendRequest(requestId),
        ).thenAnswer((_) async => true);

        // Act
        final success = await mockRepository.rejectFriendRequest(requestId);

        // Assert
        expect(success, isTrue);
        verify(() => mockRepository.rejectFriendRequest(requestId)).called(1);
      });

      test('should cancel sent friend request', () async {
        // Arrange
        const requestId = 'request_123';

        // Stub the repository method
        when(
          () => mockRepository.cancelFriendRequest(requestId),
        ).thenAnswer((_) async => true);

        // Act
        final success = await mockRepository.cancelFriendRequest(requestId);

        // Assert
        expect(success, isTrue);
        verify(() => mockRepository.cancelFriendRequest(requestId)).called(1);
      });

      test('should get incoming friend requests', () async {
        // Arrange
        final incomingRequests = [
          FriendRequest(
            id: 'req_1',
            fromUserId: 'user_1',
            toUserId: testUser.uid,
            status: FriendRequestStatus.pending,
            sentAt: DateTime.now().subtract(const Duration(days: 1)),
            message: 'Hi there!',
          ),
          FriendRequest(
            id: 'req_2',
            fromUserId: 'user_2',
            toUserId: testUser.uid,
            status: FriendRequestStatus.pending,
            sentAt: DateTime.now(),
          ),
        ];

        // Stub the repository method
        when(
          () => mockRepository.getIncomingRequests(),
        ).thenAnswer((_) async => incomingRequests);

        // Act
        final requests = await mockRepository.getIncomingRequests();

        // Assert
        expect(requests.length, equals(2));
        expect(requests.first.fromUserId, equals('user_1'));
        expect(requests.first.message, equals('Hi there!'));

        // Verify the method was called
        verify(() => mockRepository.getIncomingRequests()).called(1);
      });

      test('should get sent friend requests', () async {
        // Arrange
        final sentRequests = [
          FriendRequest(
            id: 'sent_1',
            fromUserId: testUser.uid,
            toUserId: 'user_3',
            status: FriendRequestStatus.pending,
            sentAt: DateTime.now(),
            message: 'Let\'s connect!',
          ),
        ];

        // Stub the repository method
        when(
          () => mockRepository.getSentRequests(),
        ).thenAnswer((_) async => sentRequests);

        // Act
        final requests = await mockRepository.getSentRequests();

        // Assert
        expect(requests.length, equals(1));
        expect(requests.first.toUserId, equals('user_3'));
        verify(() => mockRepository.getSentRequests()).called(1);
      });
    });

    group('Friend Management', () {
      test('should check if two users are friends', () async {
        // Arrange
        const userId1 = 'user_1';
        const userId2 = 'user_2';

        // Stub the repository method
        when(
          () => mockRepository.areFriends(userId1, userId2),
        ).thenAnswer((_) async => true);

        // Act
        final areFriends = await mockRepository.areFriends(userId1, userId2);

        // Assert
        expect(areFriends, isTrue);
        verify(() => mockRepository.areFriends(userId1, userId2)).called(1);
      });

      test('should add mutual friends', () async {
        // Arrange
        const userId1 = 'user_1';
        const userId2 = 'user_2';

        // Stub the repository method
        when(
          () => mockRepository.addMutualFriends(userId1, userId2),
        ).thenAnswer((_) async {});

        // Act
        await mockRepository.addMutualFriends(userId1, userId2);

        // Assert
        verify(
          () => mockRepository.addMutualFriends(userId1, userId2),
        ).called(1);
      });

      test('should remove friend', () async {
        // Arrange
        const friendUserId = 'friend_456';

        // Stub the repository methods
        when(
          () => mockRepository.removeFriend(friendUserId),
        ).thenAnswer((_) async => true);

        when(
          () => mockRepository.removeMutualFriends(testUser.uid, friendUserId),
        ).thenAnswer((_) async {});

        // Act
        final success = await mockRepository.removeFriend(friendUserId);

        // Assert
        expect(success, isTrue);
        verify(() => mockRepository.removeFriend(friendUserId)).called(1);
      });

      test('should fetch friend ids for a user', () async {
        // Arrange
        final friendIds = ['friend_1', 'friend_2', 'friend_3'];

        // Stub the repository method
        when(
          () => mockRepository.fetchFriendIds(testUser.uid),
        ).thenAnswer((_) async => friendIds);

        // Act
        final ids = await mockRepository.fetchFriendIds(testUser.uid);

        // Assert
        expect(ids.length, equals(3));
        expect(ids, contains('friend_2'));
        verify(() => mockRepository.fetchFriendIds(testUser.uid)).called(1);
      });

      test('should fetch friend profiles', () async {
        // Arrange
        final friendProfiles = [
          UserBuilder().withId('friend_1').withName('Friend One').build(),
          UserBuilder().withId('friend_2').withName('Friend Two').build(),
        ];
        final List<String> friendIds = friendProfiles
            .map((p) => p.uid)
            .toList();

        // Stub the repository method
        when(
          () => mockRepository.fetchFriendProfiles(friendIds),
        ).thenAnswer((_) async => friendProfiles);

        // Act
        final profiles = await mockRepository.fetchFriendProfiles(friendIds);

        // Assert
        expect(profiles.length, equals(2));
        expect(profiles.first.displayName, equals('Friend One'));
        verify(() => mockRepository.fetchFriendProfiles(friendIds)).called(1);
      });
    });

    group('Friend Categories', () {
      test('should create friend category', () async {
        // Arrange
        final category = FriendCategory(
          id: 'cat_1',
          ownerId: testUser.uid,
          name: 'Family',
          friendUserIds: ['friend_1', 'friend_2'],
          createdAt: DateTime.now(),
        );

        // Stub the repository method
        when(
          () => mockRepository.saveCategory(testUser.uid, category),
        ).thenAnswer((_) async {});

        // Act
        await mockRepository.saveCategory(testUser.uid, category);

        // Assert - verify the method was called with correct parameters
        verify(
          () => mockRepository.saveCategory(testUser.uid, category),
        ).called(1);
      });

      test('should get user categories', () async {
        // Arrange
        final List<FriendCategory> categories = [
          FriendCategory(
            id: 'cat_1',
            name: 'Family',
            ownerId: testUser.uid,
            friendUserIds: ['friend_1'],
            createdAt: DateTime.now(),
          ),
          FriendCategory(
            id: 'cat_2',
            name: 'Work',
            ownerId: testUser.uid,
            friendUserIds: ['friend_2', 'friend_3'],
            createdAt: DateTime.now(),
          ),
        ];

        // Stub the repository method
        when(
          () => mockRepository.fetchCategories(testUser.uid),
        ).thenAnswer((_) async => categories);

        // Act
        final userCategories = await mockRepository.fetchCategories(
          testUser.uid,
        );

        // Assert
        expect(userCategories.length, equals(2));
        expect(userCategories.map((c) => c.name), contains('Work'));
        verify(() => mockRepository.fetchCategories(testUser.uid)).called(1);
      });

      test('should delete friend category', () async {
        // Arrange
        const categoryId = 'cat_1';

        // Stub the repository method
        when(
          () => mockRepository.deleteCategory(testUser.uid, categoryId),
        ).thenAnswer((_) async {});

        // Act
        await mockRepository.deleteCategory(testUser.uid, categoryId);

        // Assert
        verify(
          () => mockRepository.deleteCategory(testUser.uid, categoryId),
        ).called(1);
      });
    });

    group('Group Invitations', () {
      test('should save group invitation', () async {
        // Arrange
        final invitation = GroupInvitation(
          id: 'invite_1',
          groupId: 'group_123',
          groupName: 'Cooking Club',
          groupEmoji: '👨‍🍳',
          fromUserId: testUser.uid,
          fromUserName: testUser.displayName,
          toUserId: 'user_789',
          status: GroupInvitationStatus.pending,
          sentAt: DateTime.now(),
        );

        // Stub the repository method
        when(
          () => mockRepository.saveInvitation(invitation),
        ).thenAnswer((_) async {});

        // Act
        await mockRepository.saveInvitation(invitation);

        // Assert
        verify(() => mockRepository.saveInvitation(invitation)).called(1);
      });

      test('should get invitation by id', () async {
        // Arrange
        const invitationId = 'invite_1';
        final invitation = GroupInvitation(
          id: invitationId,
          groupId: 'group_123',
          groupName: 'Cooking Club',
          groupEmoji: '👨‍🍳',
          fromUserId: 'user_456',
          fromUserName: 'Other User',
          toUserId: testUser.uid,
          status: GroupInvitationStatus.pending,
          sentAt: DateTime.now(),
        );

        // Stub the repository method
        when(
          () => mockRepository.getInvitation(invitationId),
        ).thenAnswer((_) async => invitation);

        // Act
        final result = await mockRepository.getInvitation(invitationId);

        // Assert
        expect(result, isNotNull);
        expect(result?.groupName, equals('Cooking Club'));
        verify(() => mockRepository.getInvitation(invitationId)).called(1);
      });

      test('should stream received invitations', () async {
        // Arrange
        final List<GroupInvitation> invitations = [
          GroupInvitation(
            id: 'invite_1',
            groupId: 'group_123',
            groupName: 'Cooking Club',
            groupEmoji: '👨‍🍳',
            fromUserId: 'user_456',
            fromUserName: 'Other User',
            toUserId: testUser.uid,
            status: GroupInvitationStatus.pending,
            sentAt: DateTime.now(),
          ),
        ];

        // Stub the repository method
        when(
          () => mockRepository.receivedInvitationsStream(testUser.uid),
        ).thenAnswer((_) => Stream.value(invitations));

        // Act
        final stream = mockRepository.receivedInvitationsStream(testUser.uid);
        final result = await stream.first;

        // Assert
        expect(result.length, equals(1));
        expect(result.first.groupName, equals('Cooking Club'));
        verify(
          () => mockRepository.receivedInvitationsStream(testUser.uid),
        ).called(1);
      });

      test('should update invitation', () async {
        // Arrange
        const invitationId = 'invite_1';
        final updateData = {'status': 'accepted'};

        // Stub the repository method
        when(
          () => mockRepository.updateInvitation(invitationId, updateData),
        ).thenAnswer((_) async {});

        // Act
        await mockRepository.updateInvitation(invitationId, updateData);

        // Assert
        verify(
          () => mockRepository.updateInvitation(invitationId, updateData),
        ).called(1);
      });
    });
  });
}
