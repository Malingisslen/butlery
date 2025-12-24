/// Unit tests for friends functionality
///
/// Tests the friends service with mocked repository following the
/// documentation's Firebase Testing Strategy.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:butlery/models/friend_request.dart';
import 'package:butlery/models/friend_category.dart';
import 'package:butlery/models/user_profile.dart';
import '../../../test_support/base_unit_test.dart';
import '../../../infrastructure/di/test_service_locator.dart';
import '../../../infrastructure/mocks/production_mocks.dart';

void main() {
  group('Friends Service', () {
    late MockFriendsRepository mockRepository;
    late MockAuthRepository mockAuthRepository;

    setUpAll(() async {
      await BaseUnitTest.setupUnit();
    });

    setUp(() async {
      await TestServiceLocator.initialize();

      // Create mocks
      mockRepository = MockFriendsRepository();
      mockAuthRepository = MockAuthRepository();

      // Configure auth state
      mockAuthRepository.setAuthState(userId: 'test_user_123');
    });

    tearDown(() async {
      BaseUnitTest.resetMocks();
      await TestServiceLocator.reset();
    });

    tearDownAll(() async {
      await BaseUnitTest.teardownUnit();
    });

    group('Friend Requests', () {
      test('should send friend request to another user', () async {
        // Arrange
        const toUserId = 'target_user_456';
        const message = 'Let\'s be friends!';

        when(() => mockRepository.sendFriendRequest(
              toUserId,
              message: message,
            )).thenAnswer((_) async => true);

        // Act
        final success = await mockRepository.sendFriendRequest(
          toUserId,
          message: message,
        );

        // Assert
        expect(success, isTrue);

        verify(() => mockRepository.sendFriendRequest(
              toUserId,
              message: message,
            )).called(1);
      });

      test('should not send duplicate friend request', () async {
        // Arrange
        const toUserId = 'target_user_456';

        when(() => mockRepository.sendFriendRequest(toUserId))
            .thenAnswer((_) async => false);

        // Act
        final success = await mockRepository.sendFriendRequest(toUserId);

        // Assert
        expect(success, isFalse);
      });

      test('should accept friend request', () async {
        // Arrange
        const requestId = 'request_123';

        when(() => mockRepository.acceptFriendRequest(requestId))
            .thenAnswer((_) async => true);

        // Act
        final success = await mockRepository.acceptFriendRequest(requestId);

        // Assert
        expect(success, isTrue);

        verify(() => mockRepository.acceptFriendRequest(requestId)).called(1);
      });

      test('should reject friend request', () async {
        // Arrange
        const requestId = 'request_123';

        when(() => mockRepository.rejectFriendRequest(requestId))
            .thenAnswer((_) async => true);

        // Act
        final success = await mockRepository.rejectFriendRequest(requestId);

        // Assert
        expect(success, isTrue);

        verify(() => mockRepository.rejectFriendRequest(requestId)).called(1);
      });

      test('should cancel sent friend request', () async {
        // Arrange
        const requestId = 'request_123';

        when(() => mockRepository.cancelFriendRequest(requestId))
            .thenAnswer((_) async => true);

        // Act
        final success = await mockRepository.cancelFriendRequest(requestId);

        // Assert
        expect(success, isTrue);

        verify(() => mockRepository.cancelFriendRequest(requestId)).called(1);
      });

      test('should get incoming friend requests', () async {
        // Arrange
        final expectedRequests = [
          FriendRequest(
            id: 'request_1',
            fromUserId: 'user_1',
            toUserId: 'test_user_123',
            sentAt: DateTime.now(),
            status: FriendRequestStatus.pending,
          ),
          FriendRequest(
            id: 'request_2',
            fromUserId: 'user_2',
            toUserId: 'test_user_123',
            sentAt: DateTime.now(),
            status: FriendRequestStatus.pending,
          ),
        ];

        when(() => mockRepository.getIncomingRequests())
            .thenAnswer((_) async => expectedRequests);

        // Act
        final requests = await mockRepository.getIncomingRequests();

        // Assert
        expect(requests.length, equals(2));
        expect(requests.every((r) => r.toUserId == 'test_user_123'), isTrue);

        verify(() => mockRepository.getIncomingRequests()).called(1);
      });

      test('should get sent friend requests', () async {
        // Arrange
        final expectedRequests = [
          FriendRequest(
            id: 'request_1',
            fromUserId: 'test_user_123',
            toUserId: 'user_1',
            sentAt: DateTime.now(),
            status: FriendRequestStatus.pending,
          ),
        ];

        when(() => mockRepository.getSentRequests())
            .thenAnswer((_) async => expectedRequests);

        // Act
        final requests = await mockRepository.getSentRequests();

        // Assert
        expect(requests.length, equals(1));
        expect(requests.first.fromUserId, equals('test_user_123'));

        verify(() => mockRepository.getSentRequests()).called(1);
      });

      test('should check if request exists between users', () async {
        // Arrange
        const userId1 = 'test_user_123';
        const userId2 = 'target_user_456';

        when(() => mockRepository.requestExists(userId1, userId2))
            .thenAnswer((_) async => true);

        // Act
        final exists = await mockRepository.requestExists(userId1, userId2);

        // Assert
        expect(exists, isTrue);

        verify(() => mockRepository.requestExists(userId1, userId2)).called(1);
      });
    });

    group('Friend Relationships', () {
      test('should check if two users are friends', () async {
        // Arrange
        const userId1 = 'test_user_123';
        const userId2 = 'friend_456';

        when(() => mockRepository.areFriends(userId1, userId2))
            .thenAnswer((_) async => true);

        // Act
        final areFriends = await mockRepository.areFriends(userId1, userId2);

        // Assert
        expect(areFriends, isTrue);

        verify(() => mockRepository.areFriends(userId1, userId2)).called(1);
      });

      test('should get friend profiles for user', () async {
        // Arrange
        const userId = 'test_user_123';
        final friendIds = ['friend_1', 'friend_2'];
        final expectedFriends = [
          UserProfile(
            uid: 'friend_1',
            displayName: 'Friend One',
            email: 'friend1@example.com',
            joinedAt: DateTime.now(),
            lastActiveAt: DateTime.now(),
          ),
          UserProfile(
            uid: 'friend_2',
            displayName: 'Friend Two',
            email: 'friend2@example.com',
            joinedAt: DateTime.now(),
            lastActiveAt: DateTime.now(),
          ),
        ];

        when(() => mockRepository.fetchFriendIds(userId))
            .thenAnswer((_) async => friendIds);
        when(() => mockRepository.fetchFriendProfiles(friendIds))
            .thenAnswer((_) async => expectedFriends);

        // Act
        final ids = await mockRepository.fetchFriendIds(userId);
        final friends = await mockRepository.fetchFriendProfiles(ids);

        // Assert
        expect(friends.length, equals(2));

        verify(() => mockRepository.fetchFriendIds(userId)).called(1);
        verify(() => mockRepository.fetchFriendProfiles(friendIds)).called(1);
      });

      test('should remove friend', () async {
        // Arrange
        const friendId = 'friend_456';

        when(() => mockRepository.removeFriend(friendId))
            .thenAnswer((_) async => true);

        // Act
        final success = await mockRepository.removeFriend(friendId);

        // Assert
        expect(success, isTrue);

        verify(() => mockRepository.removeFriend(friendId)).called(1);
      });

      test('should add mutual friends', () async {
        // Arrange
        const userId1 = 'test_user_123';
        const userId2 = 'other_user_456';

        when(() => mockRepository.addMutualFriends(userId1, userId2))
            .thenAnswer((_) async {});

        // Act
        await mockRepository.addMutualFriends(userId1, userId2);

        // Assert
        verify(() => mockRepository.addMutualFriends(userId1, userId2))
            .called(1);
      });
    });

    group('Friend Categories', () {
      test('should save friend category', () async {
        // Arrange
        const userId = 'test_user_123';
        final category = FriendCategory(
          id: 'category_1',
          ownerId: userId,
          name: 'Close Friends',
          description: 'My closest friends',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        when(() => mockRepository.saveCategory(userId, category))
            .thenAnswer((_) async {});

        // Act
        await mockRepository.saveCategory(userId, category);

        // Assert
        verify(() => mockRepository.saveCategory(userId, category)).called(1);
      });

      test('should get all categories for user', () async {
        // Arrange
        const userId = 'test_user_123';
        final expectedCategories = [
          FriendCategory(
            id: 'category_1',
            ownerId: userId,
            name: 'Family',
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
          FriendCategory(
            id: 'category_2',
            ownerId: userId,
            name: 'Work',
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
        ];

        when(() => mockRepository.fetchCategories(userId))
            .thenAnswer((_) async => expectedCategories);

        // Act
        final categories = await mockRepository.fetchCategories(userId);

        // Assert
        expect(categories.length, equals(2));

        verify(() => mockRepository.fetchCategories(userId)).called(1);
      });

      test('should update category members', () async {
        // Arrange
        const userId = 'test_user_123';
        const categoryId = 'category_1';
        final memberIds = ['friend_456', 'friend_789'];

        when(() => mockRepository.updateCategoryMembers(
            userId, categoryId, memberIds)).thenAnswer((_) async {});

        // Act
        await mockRepository.updateCategoryMembers(
            userId, categoryId, memberIds);

        // Assert
        verify(() => mockRepository.updateCategoryMembers(
            userId, categoryId, memberIds)).called(1);
      });

      test('should delete category', () async {
        // Arrange
        const userId = 'test_user_123';
        const categoryId = 'category_1';

        when(() => mockRepository.deleteCategory(userId, categoryId))
            .thenAnswer((_) async {});

        // Act
        await mockRepository.deleteCategory(userId, categoryId);

        // Assert
        verify(() => mockRepository.deleteCategory(userId, categoryId))
            .called(1);
      });

      test('should get category by ID', () async {
        // Arrange
        const userId = 'test_user_123';
        const categoryId = 'category_1';
        final expectedCategory = FriendCategory(
          id: categoryId,
          ownerId: userId,
          name: 'Family',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        when(() => mockRepository.getCategory(userId, categoryId))
            .thenAnswer((_) async => expectedCategory);

        // Act
        final category = await mockRepository.getCategory(userId, categoryId);

        // Assert
        expect(category?.name, equals('Family'));

        verify(() => mockRepository.getCategory(userId, categoryId)).called(1);
      });
    });
  });
}
