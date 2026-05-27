/// Comprehensive unit tests for FriendRelationshipRepository.
///
/// Tests mutual friendship management, friend discovery, relationship queries,
/// and real-time streams.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:butlery/repositories/firebase/friends/friend_relationship_repository.dart';
import 'package:butlery/models/user_profile.dart';
import 'package:butlery/core/utils/timestamp_provider.dart';

import '../../../test_support/base_unit_test.dart';
import '../../../infrastructure/di/test_service_locator.dart';
import '../../../infrastructure/mocks/production_mocks.dart';

void main() {
  group('FriendRelationshipRepository - Mutual Friendships & Discovery', () {
    late FriendRelationshipRepository repository;
    late FakeFirebaseFirestore fakeFirestore;
    late FakeAuthRepository mockAuthRepo;
    late FakeUser mockUser;

    // Test data
    const testUserId = 'user-123';
    const testFriendId = 'friend-456';
    const testOtherUserId = 'other-789';

    setUpAll(() async {
      await BaseUnitTest.setupUnit();
    });

    setUp(() {
      // Create fake Firestore instance
      fakeFirestore = FakeFirebaseFirestore();

      // Create mocks
      mockAuthRepo = FakeAuthRepository();
      mockUser = FakeUser(uid: testUserId, displayName: 'Test User');

      // Setup default auth state
      mockAuthRepo.setAuthState(
        user: mockUser,
        userId: testUserId,
        isAuthenticated: true,
      );

      // Create repository with fake Firestore and test timestamp provider
      repository = FriendRelationshipRepository(
        firestore: fakeFirestore,
        authRepository: mockAuthRepo,
        timestampProvider: const TestTimestampProvider(),
      );
    });

    tearDown(() async {
      BaseUnitTest.resetMocks();
      await TestServiceLocator.reset();
    });

    // ===== HELPER METHODS =====

    Future<void> seedFriendship(String userId, String friendId) async {
      await fakeFirestore
          .collection('users')
          .doc(userId)
          .collection('friends')
          .doc(friendId)
          .set({'addedAt': Timestamp.now()});
    }

    Future<void> seedMutualFriendship(String userId1, String userId2) async {
      await seedFriendship(userId1, userId2);
      await seedFriendship(userId2, userId1);
    }

    Future<void> seedUserProfile(String userId, String displayName) async {
      final profile = UserProfile(
        uid: userId,
        displayName: displayName,
        email: '$userId@example.com',
        joinedAt: DateTime(2025, 1, 1),
        lastActiveAt: DateTime(2025, 1, 1),
      );
      await fakeFirestore
          .collection('public_profiles')
          .doc(userId)
          .set(profile.toFirestore());
    }

    // ===== PERMISSION VALIDATION TESTS =====

    group('Permission Validation', () {
      test('should allow reading any public profile', () async {
        // Arrange
        final profile = UserProfile(
          uid: testFriendId,
          displayName: 'Friend',
          email: 'friend@example.com',
          joinedAt: DateTime.now(),
          lastActiveAt: DateTime.now(),
        );

        // Act
        final hasPermission = await repository.validateReadPermission(
            testUserId, testFriendId, profile);

        // Assert
        expect(hasPermission, isTrue);
      });

      test('should allow updating own profile', () async {
        // Arrange
        final profile = UserProfile(
          uid: testUserId,
          displayName: 'Test User',
          email: 'test@example.com',
          joinedAt: DateTime.now(),
          lastActiveAt: DateTime.now(),
        );

        // Act
        final hasPermission = await repository.validateUpdatePermission(
            testUserId, testUserId, profile);

        // Assert
        expect(hasPermission, isTrue);
      });

      test('should reject updating another user profile', () async {
        // Arrange
        final profile = UserProfile(
          uid: testFriendId,
          displayName: 'Friend',
          email: 'friend@example.com',
          joinedAt: DateTime.now(),
          lastActiveAt: DateTime.now(),
        );

        // Act
        final hasPermission = await repository.validateUpdatePermission(
            testUserId, testFriendId, profile);

        // Assert
        expect(hasPermission, isFalse);
      });
    });

    // ===== FRIENDSHIP OPERATIONS =====

    group('Friendship Operations', () {
      test('should check if users are friends', () async {
        // Arrange
        await seedMutualFriendship(testUserId, testFriendId);

        // Act
        final areFriends =
            await repository.areFriends(testUserId, testFriendId);

        // Assert
        expect(areFriends, isTrue);
      });

      test('should return false if users are not friends', () async {
        // Act
        final areFriends =
            await repository.areFriends(testUserId, testFriendId);

        // Assert
        expect(areFriends, isFalse);
      });

      test('should add mutual friends successfully', () async {
        // Act
        await repository.addMutualFriends(testUserId, testFriendId);

        // Assert - Check both directions
        final areFriends1 =
            await repository.areFriends(testUserId, testFriendId);
        final areFriends2 =
            await repository.areFriends(testFriendId, testUserId);
        expect(areFriends1, isTrue);
        expect(areFriends2, isTrue);
      },
          skip:
              'FieldValue.increment conflicts with TestServiceLocator platform bindings (MethodChannelFieldValue vs MockFieldValuePlatform)');

      test('should remove mutual friends successfully', () async {
        // Arrange
        await seedMutualFriendship(testUserId, testFriendId);

        // Act
        await repository.removeMutualFriends(testUserId, testFriendId);

        // Assert
        final areFriends =
            await repository.areFriends(testUserId, testFriendId);
        expect(areFriends, isFalse);
      },
          skip:
              'FieldValue.increment conflicts with TestServiceLocator platform bindings (MethodChannelFieldValue vs MockFieldValuePlatform)');

      test('should remove friend as current user', () async {
        // Arrange
        await seedMutualFriendship(testUserId, testFriendId);

        // Act
        final success = await repository.removeFriend(testFriendId);

        // Assert
        expect(success, isTrue);
      },
          skip:
              'FieldValue.increment conflicts with TestServiceLocator platform bindings (MethodChannelFieldValue vs MockFieldValuePlatform)');
    });

    // ===== FRIEND QUERIES =====

    group('Friend Queries', () {
      test('should fetch friend IDs for user', () async {
        // Arrange
        await seedFriendship(testUserId, testFriendId);
        await seedFriendship(testUserId, testOtherUserId);

        // Act
        final friendIds = await repository.fetchFriendIds(testUserId);

        // Assert
        expect(friendIds.length, 2);
        expect(friendIds, containsAll([testFriendId, testOtherUserId]));
      });

      test('should return empty list if no friends', () async {
        // Act
        final friendIds = await repository.fetchFriendIds(testUserId);

        // Assert
        expect(friendIds, isEmpty);
      });

      test('should fetch friend profiles', () async {
        // Arrange
        await seedUserProfile(testFriendId, 'Friend One');
        await seedUserProfile(testOtherUserId, 'Friend Two');

        // Act
        final profiles = await repository
            .fetchFriendProfiles([testFriendId, testOtherUserId]);

        // Assert
        expect(profiles.length, 2);
        expect(profiles.any((p) => p.uid == testFriendId), isTrue);
        expect(profiles.any((p) => p.uid == testOtherUserId), isTrue);
      });

      test('should handle empty profile list', () async {
        // Act
        final profiles = await repository.fetchFriendProfiles([]);

        // Assert
        expect(profiles, isEmpty);
      });

      test('should get friends with profiles', () async {
        // Arrange
        await seedFriendship(testUserId, testFriendId);
        await seedUserProfile(testFriendId, 'Friend One');

        // Act
        final profiles = await repository.getFriendsWithProfiles(testUserId);

        // Assert
        expect(profiles.length, 1);
        expect(profiles.first.uid, testFriendId);
        expect(profiles.first.displayName, 'Friend One');
      });
    });

    // ===== MUTUAL FRIEND DISCOVERY =====

    group('Mutual Friend Discovery', () {
      test('should find mutual friends between two users', () async {
        // Arrange - Both users have 'mutual-friend' as friend
        const mutualFriendId = 'mutual-friend';
        await seedFriendship(testUserId, mutualFriendId);
        await seedFriendship(testFriendId, mutualFriendId);

        // Act
        final mutualFriends =
            await repository.getMutualFriends(testUserId, testFriendId);

        // Assert
        expect(mutualFriends, contains(mutualFriendId));
      });

      test('should return empty list if no mutual friends', () async {
        // Arrange
        await seedFriendship(testUserId, testOtherUserId);
        await seedFriendship(testFriendId, 'different-friend');

        // Act
        final mutualFriends =
            await repository.getMutualFriends(testUserId, testFriendId);

        // Assert
        expect(mutualFriends, isEmpty);
      });

      test('should count mutual friends', () async {
        // Arrange
        const mutual1 = 'mutual-1';
        const mutual2 = 'mutual-2';
        await seedFriendship(testUserId, mutual1);
        await seedFriendship(testUserId, mutual2);
        await seedFriendship(testFriendId, mutual1);
        await seedFriendship(testFriendId, mutual2);

        // Act
        final count =
            await repository.getMutualFriendsCount(testUserId, testFriendId);

        // Assert
        expect(count, 2);
      });
    });

    // ===== REAL-TIME STREAMS =====

    group('Real-time Streams', () {
      test('should stream friend IDs', () async {
        // Arrange
        await seedFriendship(testUserId, testFriendId);

        // Act
        final stream = repository.friendIdsStream(testUserId);

        // Assert
        await expectLater(
          stream.first,
          completion(predicate<List<String>>((ids) {
            return ids.length == 1 && ids.contains(testFriendId);
          })),
        );
      });

      test('should stream friend profiles', () async {
        // Arrange
        await seedFriendship(testUserId, testFriendId);
        await seedUserProfile(testFriendId, 'Friend One');

        // Act
        final stream = repository.friendProfilesStream(testUserId);

        // Assert
        await expectLater(
          stream.first,
          completion(predicate<List<UserProfile>>((profiles) {
            return profiles.length == 1 && profiles.first.uid == testFriendId;
          })),
        );
      });
    });

    // ===== EDGE CASES =====

    group('Edge Cases', () {
      test('should handle empty friend list', () async {
        // Act
        final profiles = await repository.getFriendsWithProfiles(testUserId);

        // Assert
        expect(profiles, isEmpty);
      });

      test('should handle large batch of friend profiles', () async {
        // Arrange - Create 15 friends (tests batching at 10)
        final friendIds = List.generate(15, (i) => 'friend-$i');
        for (final id in friendIds) {
          await seedUserProfile(id, 'Friend $id');
        }

        // Act
        final profiles = await repository.fetchFriendProfiles(friendIds);

        // Assert
        expect(profiles.length, 15);
      });
    });

    // ===== BASE REPOSITORY IMPLEMENTATION =====

    group('Base Repository Implementation', () {
      test('should use correct collection name', () {
        expect(repository.collectionName, 'public_profiles');
      });

      test('should convert entity to ID correctly', () {
        // Arrange
        final profile = UserProfile(
          uid: testUserId,
          displayName: 'Test',
          email: 'test@example.com',
          joinedAt: DateTime.now(),
          lastActiveAt: DateTime.now(),
        );

        // Act
        final id = repository.getId(profile);

        // Assert
        expect(id, testUserId);
      });
    });
  });
}
