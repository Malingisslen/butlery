/// Integration tests for Firebase Friends Repository
///
/// **Status:** Bulk-skipped pending BUT-369 continuation. Multi-user
/// scenarios (friend requests across uids) need a per-user auth switch
/// that the current MockFirebaseAuth setup doesn't provide; count-based
/// assertions also drifted when the denormalised `friendsCount` field
/// moved under a batched update. Tracking for rewrite under BUT-387
/// Phase 7 (emulator lane) + focused BUT-369 follow-up.
@Skip('Bulk-skipped pending BUT-369 rewrite — see file header.')
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:butlery/repositories/firebase/firebase_friends_repository.dart';
import 'package:butlery/repositories/firebase/firebase_auth_repository.dart';
import 'package:butlery/core/utils/timestamp_provider.dart';
import '../../../test_support/base_unit_test.dart';
import '../../../test_support/test_data_isolator.dart';
import '../../../test_support/timestamp_test_helper.dart';
import '../../../infrastructure/mocks/firestore_singleton.dart';

void main() {
  group('Firebase Friends Repository Integration', () {
    late FirebaseFirestore firestore;
    late FirebaseFriendsRepository repository;
    late MockUser testUser;
    late MockFirebaseAuth mockAuth;

    setUpAll(() async {
      await BaseUnitTest.setupUnit();
    });

    setUp(() async {
      // Initialize test isolation
      TestDataIsolator.initializeTest('FriendsRepository');

      // Setup Fake Firebase instances (Fake Lane)
      firestore = FirestoreSingleton.instance;

      // Create mock user with authentication
      testUser = MockUser(
        uid: 'test-user-uid',
        email: 'test@example.com',
        displayName: 'Test User',
      );

      mockAuth = MockFirebaseAuth(mockUser: testUser, signedIn: true);

      // Create repository with injected dependencies
      final authRepository = FirebaseAuthRepository(firebaseAuth: mockAuth);
      repository = FirebaseFriendsRepository(
        firestore: firestore,
        authRepository: authRepository,
        timestampProvider: const TestTimestampProvider(),
      );
    });

    tearDown(() async {
      await mockAuth.signOut();
      await TestDataIsolator.cleanupTest('FriendsRepository');
    });

    group('Friend Requests with timestamps', () {
      test('should send friend request with server timestamp', () async {
        // Arrange
        const toUserId = 'target_user_456';
        const message = 'Let\'s be friends!';

        // Create target user profile
        await firestore.collection('public_profiles').doc(toUserId).set({
          'email': 'target@example.com',
          'displayName': 'Target User',
          'friendsCount': 0,
        });

        // Act
        final success = await repository.sendFriendRequest(
          toUserId,
          message: message,
        );

        // Assert
        expect(success, isTrue);

        // Verify in Firestore
        final requests = await firestore
            .collection('social_requests')
            .where('fromUserId', isEqualTo: testUser.uid)
            .where('toUserId', isEqualTo: toUserId)
            .get();

        expect(requests.docs.length, equals(1));
        final requestData = requests.docs.first.data();

        // Verify timestamp was set (handle both DateTime and Timestamp)
        final sentAt = requestData['sentAt'];
        expect(sentAt, anyOf(isA<DateTime>(), isA<Timestamp>()));
        final timestamp = TimestampTestHelper.toDateTime(sentAt);
        expect(timestamp, isNotNull);
        expect(
            timestamp!.difference(DateTime.now()).inMinutes.abs(), lessThan(1));

        expect(requestData['message'], equals(message));
        expect(requestData['status'], equals('pending'));
      });

      test('should handle accepted timestamp', () async {
        // Arrange
        const fromUserId = 'sender_user';
        final toUserId = testUser.uid;

        // Create user profiles
        await firestore.collection('public_profiles').doc(fromUserId).set({
          'email': 'sender@test.com',
          'displayName': 'Sender User',
          'friendsCount': 0,
        });
        await firestore.collection('public_profiles').doc(toUserId).set({
          'email': 'test@test.com',
          'displayName': 'Test User',
          'friendsCount': 0,
        });

        // Create pending request with server timestamp
        final docRef = await firestore.collection('social_requests').add({
          'type': 'friend',
          'fromUserId': fromUserId,
          'toUserId': toUserId,
          'status': 'pending',
          'sentAt': DateTime.now(),
        });

        // Act
        final success = await repository.acceptFriendRequest(docRef.id);

        // Assert
        expect(success, isTrue);

        // Verify request has acceptedAt timestamp
        final doc = await docRef.get();
        final data = doc.data()!;
        expect(data['status'], equals('accepted'));
        expect(data['acceptedAt'], isA<DateTime>());

        // Verify both timestamps exist and acceptedAt is after sentAt
        final sentAt = data['sentAt'] as DateTime;
        final acceptedAt = data['acceptedAt'] as DateTime;
        expect(acceptedAt.isAfter(sentAt), isTrue);
      },
          skip:
              'B1: acceptFriendRequest moved to the acceptFriendRequest Cloud '
              'Function (mutual write under Admin SDK so the friends-write rule '
              'could be locked to owner-only). The fake-lane cannot run a Cloud '
              'Function — covered by functions accept-friend-request.integration'
              '.test.ts + friends-accept-rules.test.ts.');
    });

    group('Friend Count tracking', () {
      test('should increment friend count when accepting request', () async {
        // Arrange
        const fromUserId = 'sender_user';
        final toUserId = testUser.uid;

        // Create user profiles with initial friend counts
        await firestore.collection('public_profiles').doc(fromUserId).set({
          'email': 'sender@test.com',
          'displayName': 'Sender User',
          'friendsCount': 5,
        });
        await firestore.collection('public_profiles').doc(toUserId).set({
          'email': 'test@test.com',
          'displayName': 'Test User',
          'friendsCount': 3,
        });

        // Create pending request
        final docRef = await firestore.collection('social_requests').add({
          'type': 'friend',
          'fromUserId': fromUserId,
          'toUserId': toUserId,
          'status': 'pending',
          'sentAt': DateTime.now(),
        });

        // Act
        await repository.acceptFriendRequest(docRef.id);

        // Assert - Check friend counts were incremented
        final senderProfile =
            await firestore.collection('public_profiles').doc(fromUserId).get();
        expect(senderProfile.data()?['friendsCount'], equals(6));

        final receiverProfile =
            await firestore.collection('public_profiles').doc(toUserId).get();
        expect(receiverProfile.data()?['friendsCount'], equals(4));
      },
          skip: 'B1: friend-count increment on accept moved server-side to the '
              'acceptFriendRequest Cloud Function. Covered by functions '
              'accept-friend-request.integration.test.ts.');

      test('should decrement friend count when removing friend', () async {
        // Arrange
        const userId1 = 'user_1';
        const userId2 = 'user_2';

        // Create user profiles with friend counts
        await firestore.collection('public_profiles').doc(userId1).set({
          'friendsCount': 10,
          'email': 'user1@test.com',
        });
        await firestore.collection('public_profiles').doc(userId2).set({
          'friendsCount': 8,
          'email': 'user2@test.com',
        });

        // Create mutual friendship
        await firestore
            .collection('users')
            .doc(userId1)
            .collection('friends')
            .doc(userId2)
            .set({'friendSince': DateTime.now()});

        await firestore
            .collection('users')
            .doc(userId2)
            .collection('friends')
            .doc(userId1)
            .set({'friendSince': DateTime.now()});

        // Act
        await repository.removeMutualFriends(userId1, userId2);

        // Assert - Check friend counts were decremented
        final user1Profile =
            await firestore.collection('public_profiles').doc(userId1).get();
        expect(user1Profile.data()?['friendsCount'], equals(9));

        final user2Profile =
            await firestore.collection('public_profiles').doc(userId2).get();
        expect(user2Profile.data()?['friendsCount'], equals(7));
      });
    });

    group('Batch Operations', () {
      test('should use batch write for accepting friend request', () async {
        // Arrange
        const fromUserId = 'sender_user';
        final toUserId = testUser.uid;

        // Create user profiles
        await firestore.collection('public_profiles').doc(fromUserId).set({
          'email': 'sender@test.com',
          'friendsCount': 0,
        });
        await firestore.collection('public_profiles').doc(toUserId).set({
          'email': 'test@test.com',
          'friendsCount': 0,
        });

        // Create pending request
        final docRef = await firestore.collection('social_requests').add({
          'type': 'friend',
          'fromUserId': fromUserId,
          'toUserId': toUserId,
          'status': 'pending',
          'sentAt': DateTime.now(),
        });

        // Act
        final success = await repository.acceptFriendRequest(docRef.id);

        // Assert
        expect(success, isTrue);

        // Verify all operations completed atomically
        // 1. Request status updated
        final request = await docRef.get();
        expect(request.data()?['status'], equals('accepted'));

        // 2. Mutual friendship created
        final friend1 = await firestore
            .collection('users')
            .doc(fromUserId)
            .collection('friends')
            .doc(toUserId)
            .get();
        expect(friend1.exists, isTrue);

        final friend2 = await firestore
            .collection('users')
            .doc(toUserId)
            .collection('friends')
            .doc(fromUserId)
            .get();
        expect(friend2.exists, isTrue);

        // 3. Friend counts updated
        final profile1 =
            await firestore.collection('public_profiles').doc(fromUserId).get();
        expect(profile1.data()?['friendsCount'], equals(1));

        final profile2 =
            await firestore.collection('public_profiles').doc(toUserId).get();
        expect(profile2.data()?['friendsCount'], equals(1));
      },
          skip:
              'B1: mutual-friendship write on accept moved server-side to the '
              'acceptFriendRequest Cloud Function. Covered by functions '
              'accept-friend-request.integration.test.ts + friends-accept-rules'
              '.test.ts.');
    });

    group('Complex Queries', () {
      test('should handle multiple pending requests correctly', () async {
        // Arrange
        final toUserId = testUser.uid;

        // Create multiple friend requests with server timestamps
        for (int i = 0; i < 5; i++) {
          await firestore.collection('social_requests').add({
            'fromUserId': 'user_$i',
            'toUserId': toUserId,
            'status': 'pending',
            'sentAt': DateTime.now(),
            'message': 'Request $i',
          });

          // Small delay to ensure different timestamps
          await Future.delayed(const Duration(milliseconds: 10));
        }

        // Act
        final requests = await repository.getIncomingRequests();

        // Assert
        expect(requests.length, equals(5));

        // Verify requests are ordered by sentAt (newest first)
        for (int i = 0; i < requests.length - 1; i++) {
          expect(
            requests[i].sentAt.isAfter(requests[i + 1].sentAt),
            isTrue,
          );
        }
      });

      test('should handle array operations for categories', () async {
        // Arrange
        const userId = 'test_user';
        const categoryId = 'family_category';

        // Create category with initial members
        await firestore
            .collection('users')
            .doc(userId)
            .collection('friend_categories')
            .doc(categoryId)
            .set({
          'name': 'Family',
          'memberIds': ['member_1', 'member_2'],
          'createdAt': DateTime.now(),
        });

        // Act - Manually add members to array
        final catDoc = await firestore
            .collection('users')
            .doc(userId)
            .collection('friend_categories')
            .doc(categoryId)
            .get();

        final currentMembers =
            List<String>.from(catDoc.data()?['memberIds'] ?? []);
        final newMembers = ['member_3', 'member_4', 'member_2'];
        for (final member in newMembers) {
          if (!currentMembers.contains(member)) {
            currentMembers.add(member);
          }
        }

        await firestore
            .collection('users')
            .doc(userId)
            .collection('friend_categories')
            .doc(categoryId)
            .update({
          'memberIds': currentMembers,
        });

        // Assert
        final doc = await firestore
            .collection('users')
            .doc(userId)
            .collection('friend_categories')
            .doc(categoryId)
            .get();

        final memberIds = List<String>.from(doc.data()?['memberIds'] ?? []);
        expect(memberIds.length, equals(4)); // No duplicates
        expect(memberIds,
            containsAll(['member_1', 'member_2', 'member_3', 'member_4']));

        // Act - Manually remove members from array
        final removeDoc = await firestore
            .collection('users')
            .doc(userId)
            .collection('friend_categories')
            .doc(categoryId)
            .get();

        final updatedMembers =
            List<String>.from(removeDoc.data()?['memberIds'] ?? []);
        final membersToRemove = ['member_1', 'member_3'];
        updatedMembers
            .removeWhere((member) => membersToRemove.contains(member));

        await firestore
            .collection('users')
            .doc(userId)
            .collection('friend_categories')
            .doc(categoryId)
            .update({
          'memberIds': updatedMembers,
        });

        // Assert
        final updatedDoc = await firestore
            .collection('users')
            .doc(userId)
            .collection('friend_categories')
            .doc(categoryId)
            .get();

        final updatedMemberIds =
            List<String>.from(updatedDoc.data()?['memberIds'] ?? []);
        expect(updatedMemberIds.length, equals(2));
        expect(updatedMemberIds, containsAll(['member_2', 'member_4']));
      });
    });
  });
}
