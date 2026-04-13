/// Unit tests for UnifiedFriendsService and its sub-modules
///
/// The UnifiedFriendsService facade cannot be constructed in unit tests because
/// its constructor creates FirebaseFriendsRepository (which needs real Firebase).
/// Instead we test:
/// 1. FriendsUtilityOperations — getFriendsOfUser, getRecentCollaborators, etc.
/// 2. FriendsFirebaseSyncOperations — friend request / relationship Firebase sync
/// 3. MockUnifiedFriendsService — verifies the mock matches the production API
///    (state management, feature interface access, internal operations)
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';

import 'package:butlery/models/user_profile.dart';
import 'package:butlery/models/friend_request.dart';
import 'package:butlery/services/unified/friends/friends_utility_operations.dart';
import 'package:butlery/services/unified/friends/friends_firebase_sync.dart';
import 'package:butlery/services/unified/types/service_states.dart';

import '../../../infrastructure/mocks/production_mocks.dart';

void main() {
  // -----------------------------------------------------------------------
  // Part 1: MockUnifiedFriendsService — verifies mock exposes production API
  // -----------------------------------------------------------------------
  group('MockUnifiedFriendsService API contract', () {
    late MockUnifiedFriendsService mock;

    setUp(() {
      mock = MockUnifiedFriendsService();
    });

    tearDown(() {
      mock.dispose();
    });

    test('defaults to empty state', () {
      mock.setFriendsState();
      expect(mock.friends, isEmpty);
      expect(mock.incomingRequests, isEmpty);
      expect(mock.outgoingRequests, isEmpty);
      expect(mock.blockedUsers, isEmpty);
      expect(mock.isInitialized, isFalse);
      expect(mock.isLoading, isFalse);
      expect(mock.error, isNull);
      expect(mock.hasError, isFalse);
    });

    test('setFriendsState configures friends list', () {
      final friend = UserProfile(
        uid: 'f1',
        displayName: 'Friend 1',
        email: 'f1@example.com',
        joinedAt: DateTime.now(),
        lastActiveAt: DateTime.now(),
      );
      mock.setFriendsState(friends: [friend], isInitialized: true);

      expect(mock.friends.length, 1);
      expect(mock.friends.first.uid, 'f1');
      expect(mock.isInitialized, isTrue);
    });

    test('setFriendsState configures requests', () {
      final incoming = FriendRequest(
        id: 'r1',
        fromUserId: 'sender',
        toUserId: 'me',
        sentAt: DateTime.now(),
        status: FriendRequestStatus.pending,
      );
      final outgoing = FriendRequest(
        id: 'r2',
        fromUserId: 'me',
        toUserId: 'target',
        sentAt: DateTime.now(),
        status: FriendRequestStatus.pending,
      );
      mock.setFriendsState(
        incomingRequests: [incoming],
        outgoingRequests: [outgoing],
      );

      expect(mock.incomingRequests.length, 1);
      expect(mock.outgoingRequests.length, 1);
    });

    test('setFriendsState configures blocked users', () {
      mock.setFriendsState(blockedUsers: {'blocked-1', 'blocked-2'});

      expect(mock.blockedUsers, contains('blocked-1'));
      expect(mock.blockedUsers, contains('blocked-2'));
      expect(mock.blockedUsers.length, 2);
    });

    test('setFriendsState configures error state', () {
      mock.setFriendsState(error: 'Network error');

      expect(mock.hasError, isTrue);
      expect(mock.error, 'Network error');
    });

    test('stateStream emits state', () async {
      mock.setFriendsState(isInitialized: true);

      // stateStream should be a valid stream
      expect(mock.stateStream, isA<Stream<FriendsServiceState>>());
    });

    test('loading state can be configured', () {
      mock.setFriendsState(isLoading: true);
      expect(mock.isLoading, isTrue);
    });
  });

  // -----------------------------------------------------------------------
  // Part 2: FriendsUtilityOperations — uses FakeFirebaseFirestore directly
  // -----------------------------------------------------------------------
  group('getFriendsOfUser', () {
    late FakeFirebaseFirestore fakeFirestore;
    late FriendsUtilityOperations utilityOps;

    setUp(() {
      fakeFirestore = FakeFirebaseFirestore();
      utilityOps = FriendsUtilityOperations(
        firestore: fakeFirestore,
        getCurrentUserId: () => 'test-user-id',
        getBlockedUsers: () => <String>{},
        getIncomingRequests: () => <FriendRequest>[],
        getOutgoingRequests: () => <FriendRequest>[],
      );
    });

    test('should return friends list for a user', () async {
      final friendIds = ['friend-1', 'friend-2'];
      await fakeFirestore
          .collection('users')
          .doc('user-456')
          .set({'displayName': 'Target User', 'friends': friendIds});

      for (final friendId in friendIds) {
        await fakeFirestore.collection('users').doc(friendId).set({
          'displayName': 'Friend $friendId',
          'email': '$friendId@example.com',
          'joinedAt': Timestamp.now(),
          'lastActiveAt': Timestamp.now(),
        });
      }

      final friends = await utilityOps.getFriendsOfUser('user-456');

      expect(friends.length, equals(2));
      expect(friends.map((f) => f.uid), containsAll(friendIds));
    });

    test('should return empty list when user has no friends', () async {
      await fakeFirestore
          .collection('users')
          .doc('lonely-user')
          .set({'displayName': 'Lonely User', 'friends': []});

      final friends = await utilityOps.getFriendsOfUser('lonely-user');
      expect(friends, isEmpty);
    });

    test('should return empty list when user does not exist', () async {
      final friends = await utilityOps.getFriendsOfUser('non-existent');
      expect(friends, isEmpty);
    });
  });

  group('getRecentCollaborators', () {
    late FakeFirebaseFirestore fakeFirestore;
    late FriendsUtilityOperations utilityOps;

    setUp(() {
      fakeFirestore = FakeFirebaseFirestore();
      utilityOps = FriendsUtilityOperations(
        firestore: fakeFirestore,
        getCurrentUserId: () => 'test-user-id',
        getBlockedUsers: () => <String>{},
        getIncomingRequests: () => <FriendRequest>[],
        getOutgoingRequests: () => <FriendRequest>[],
      );
    });

    test('should return recent collaborators from members subcollection',
        () async {
      const collaborator1 = 'collab-1';
      const collaborator2 = 'collab-2';

      await fakeFirestore
          .collection('shared_content')
          .doc('recipe-1')
          .collection('members')
          .add({
        'userId': 'test-user-id',
        'addedBy': collaborator1,
      });

      await fakeFirestore
          .collection('shared_content')
          .doc('recipe-2')
          .collection('members')
          .add({
        'userId': 'test-user-id',
        'addedBy': collaborator2,
      });

      await fakeFirestore.collection('users').doc(collaborator1).set({
        'displayName': 'Collaborator 1',
        'email': 'c1@example.com',
      });

      await fakeFirestore.collection('users').doc(collaborator2).set({
        'displayName': 'Collaborator 2',
        'email': 'c2@example.com',
      });

      final collaborators = await utilityOps.getRecentCollaborators();

      expect(collaborators.length, equals(2));
      expect(collaborators.map((c) => c.uid),
          containsAll([collaborator1, collaborator2]));
    });

    test('should return empty list when no collaborators', () async {
      final collaborators = await utilityOps.getRecentCollaborators();
      expect(collaborators, isEmpty);
    });

    test('should return empty list when user is not authenticated', () async {
      final noAuthOps = FriendsUtilityOperations(
        firestore: fakeFirestore,
        getCurrentUserId: () => null,
        getBlockedUsers: () => <String>{},
        getIncomingRequests: () => <FriendRequest>[],
        getOutgoingRequests: () => <FriendRequest>[],
      );

      final collaborators = await noAuthOps.getRecentCollaborators();
      expect(collaborators, isEmpty);
    });

    test('should exclude self from collaborators', () async {
      await fakeFirestore
          .collection('shared_content')
          .doc('recipe-self')
          .collection('members')
          .add({
        'userId': 'test-user-id',
        'addedBy': 'test-user-id',
      });

      final collaborators = await utilityOps.getRecentCollaborators();
      expect(collaborators, isEmpty);
    });
  });

  group('getRecentShoppingCollaborators', () {
    late FakeFirebaseFirestore fakeFirestore;
    late FriendsUtilityOperations utilityOps;

    setUp(() {
      fakeFirestore = FakeFirebaseFirestore();
      utilityOps = FriendsUtilityOperations(
        firestore: fakeFirestore,
        getCurrentUserId: () => 'test-user-id',
        getBlockedUsers: () => <String>{},
        getIncomingRequests: () => <FriendRequest>[],
        getOutgoingRequests: () => <FriendRequest>[],
      );
    });

    test('should return recent shopping list collaborators', () async {
      const collaborator1 = 'shop-collab-1';
      const collaborator2 = 'shop-collab-2';

      await fakeFirestore.collection('shopping_lists').add({
        'ownerId': collaborator1,
        'collaborators': ['test-user-id', collaborator2],
        'lastModified': Timestamp.now(),
      });

      await fakeFirestore.collection('users').doc(collaborator1).set({
        'displayName': 'Shopping Collab 1',
        'email': 's1@example.com',
      });

      await fakeFirestore.collection('users').doc(collaborator2).set({
        'displayName': 'Shopping Collab 2',
        'email': 's2@example.com',
      });

      final collaborators = await utilityOps.getRecentShoppingCollaborators();

      expect(collaborators.length, equals(2));
      expect(collaborators.map((c) => c.uid),
          containsAll([collaborator1, collaborator2]));
    });

    test('should return empty list when no shopping collaborators', () async {
      final collaborators = await utilityOps.getRecentShoppingCollaborators();
      expect(collaborators, isEmpty);
    });
  });

  // -----------------------------------------------------------------------
  // Part 3: FriendsFirebaseSyncOperations — sync logic with FakeFirestore
  // -----------------------------------------------------------------------
  group('Friend Request Firebase Sync', () {
    late FakeFirebaseFirestore fakeFirestore;
    late FriendsFirebaseSyncOperations syncOps;

    setUp(() {
      fakeFirestore = FakeFirebaseFirestore();
      syncOps = FriendsFirebaseSyncOperations(
        firestore: fakeFirestore,
        getCurrentUserId: () => 'test-user-id',
      );
    });

    test('should sync friend request to Firebase', () async {
      final request = FriendRequest(
        id: 'req-123',
        fromUserId: 'test-user-id',
        toUserId: 'target-user',
        message: 'Let\'s be friends!',
        sentAt: DateTime.now(),
        status: FriendRequestStatus.pending,
      );

      await syncOps.syncFriendRequestToFirebase(request);

      final requests = await fakeFirestore
          .collection('social_requests')
          .where('fromUserId', isEqualTo: 'test-user-id')
          .get();

      expect(requests.docs.length, equals(1));
      final data = requests.docs.first.data();
      expect(data['toUserId'], equals('target-user'));
      expect(data['message'], equals('Let\'s be friends!'));
      expect(data['type'], equals('friend'));
      expect(data['status'], equals('pending'));
    });

    test('should update friend request status to accepted', () async {
      final request = FriendRequest(
        id: 'req-456',
        fromUserId: 'sender',
        toUserId: 'test-user-id',
        sentAt: DateTime.now(),
        status: FriendRequestStatus.pending,
      );

      await fakeFirestore.collection('social_requests').add({
        'type': 'friend',
        'fromUserId': request.fromUserId,
        'toUserId': request.toUserId,
        'status': 'pending',
        'sentAt': request.sentAt,
      });

      final acceptedRequest = request.copyWith(
        status: FriendRequestStatus.accepted,
        respondedAt: DateTime.now(),
      );

      await syncOps.updateFriendRequestStatus(acceptedRequest);

      final requests = await fakeFirestore
          .collection('social_requests')
          .where('fromUserId', isEqualTo: 'sender')
          .get();

      expect(requests.docs.first.data()['status'], equals('accepted'));
    });

    test('should delete cancelled friend request', () async {
      final request = FriendRequest(
        id: 'req-cancel',
        fromUserId: 'test-user-id',
        toUserId: 'other-user',
        sentAt: DateTime.now(),
        status: FriendRequestStatus.pending,
      );

      await fakeFirestore.collection('social_requests').add({
        'type': 'friend',
        'fromUserId': request.fromUserId,
        'toUserId': request.toUserId,
        'status': 'pending',
        'sentAt': request.sentAt,
      });

      final cancelledRequest = request.copyWith(
        status: FriendRequestStatus.cancelled,
      );

      await syncOps.updateFriendRequestStatus(cancelledRequest);

      final requests = await fakeFirestore
          .collection('social_requests')
          .where('fromUserId', isEqualTo: 'test-user-id')
          .get();

      expect(requests.docs, isEmpty);
    });
  });

  group('Friend Relationship Firebase Sync', () {
    late FakeFirebaseFirestore fakeFirestore;
    late FriendsFirebaseSyncOperations syncOps;

    setUp(() {
      fakeFirestore = FakeFirebaseFirestore();
      syncOps = FriendsFirebaseSyncOperations(
        firestore: fakeFirestore,
        getCurrentUserId: () => 'test-user-id',
      );
    });

    test('should sync friend to Firebase with mutual relationship', () async {
      final friend = UserProfile(
        uid: 'friend-789',
        displayName: 'My Friend',
        email: 'friend@example.com',
        joinedAt: DateTime.now(),
        lastActiveAt: DateTime.now(),
      );

      await syncOps.syncFriendToFirebase(friend);

      final userFriend = await fakeFirestore
          .collection('users')
          .doc('test-user-id')
          .collection('friends')
          .doc('friend-789')
          .get();

      expect(userFriend.exists, isTrue);
      expect(userFriend.data()?['displayName'], equals('My Friend'));
      expect(userFriend.data()?['displayNameLower'], equals('my friend'));

      final reverseFriend = await fakeFirestore
          .collection('users')
          .doc('friend-789')
          .collection('friends')
          .doc('test-user-id')
          .get();

      expect(reverseFriend.exists, isTrue);
    });

    test('should remove friend from Firebase bidirectionally', () async {
      const friendId = 'friend-to-remove';

      await fakeFirestore
          .collection('users')
          .doc('test-user-id')
          .collection('friends')
          .doc(friendId)
          .set({'friendSince': Timestamp.now()});

      await fakeFirestore
          .collection('users')
          .doc(friendId)
          .collection('friends')
          .doc('test-user-id')
          .set({'friendSince': Timestamp.now()});

      await syncOps.removeFriendFromFirebase(friendId);

      final userFriend = await fakeFirestore
          .collection('users')
          .doc('test-user-id')
          .collection('friends')
          .doc(friendId)
          .get();
      expect(userFriend.exists, isFalse);

      final reverseFriend = await fakeFirestore
          .collection('users')
          .doc(friendId)
          .collection('friends')
          .doc('test-user-id')
          .get();
      expect(reverseFriend.exists, isFalse);
    });

    test('should not sync when user is not authenticated', () async {
      final noAuthSyncOps = FriendsFirebaseSyncOperations(
        firestore: fakeFirestore,
        getCurrentUserId: () => null,
      );

      final friend = UserProfile(
        uid: 'friend-no-auth',
        displayName: 'No Auth Friend',
        email: 'noauth@example.com',
        joinedAt: DateTime.now(),
        lastActiveAt: DateTime.now(),
      );

      await noAuthSyncOps.syncFriendToFirebase(friend);

      final result = await fakeFirestore
          .collection('users')
          .doc('friend-no-auth')
          .collection('friends')
          .get();

      expect(result.docs, isEmpty);
    });
  });
}
