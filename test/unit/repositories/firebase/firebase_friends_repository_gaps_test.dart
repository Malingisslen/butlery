/// Gap-filling tests for FirebaseFriendsRepository.
///
/// The existing test/unit/repositories/firebase_friends_repository_test.dart
/// covers permission validation thoroughly but skips the delegated request
/// + invitation paths because they go through TestServiceLocator setup. This
/// file uses the lightweight FakeFirebaseFirestore + MockAuthRepository
/// pattern and targets the still-uncovered chunks:
///
/// - `acceptFriendRequest` (the atomic transaction at lines 124-220 of SUT)
/// - friend-request delegation (sendRequest, fetchRequest, requestExists,
///   getIncomingRequests/getSentRequests, streams)
/// - group-invitation delegation (save/update/delete/get/has/accept/reject,
///   fetchReceived/Sent, streams, batch ops)
/// - relationship facade-passthroughs (areFriends, addMutual, removeMutual,
///   removeFriend, fetchFriendIds, friendIdsStream, fetchFriendProfiles)
/// - category facade-passthroughs (save, update, delete, fetch, get,
///   updateMembers, addFriendToCategory, removeFriendFromCategory,
///   categoriesStream, searchCategories)
/// - `getComprehensiveFriendStatistics` (aggregates across 3 sub-repos)
library;

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/models/friend_category.dart';
import 'package:butlery/models/friend_request.dart';
import 'package:butlery/models/group_invitation.dart';
import 'package:butlery/models/social_request.dart';
import 'package:butlery/models/user_profile.dart';
import 'package:butlery/repositories/firebase/firebase_friends_repository.dart';

import '../../../infrastructure/mocks/production_mocks.dart';

const _alice = 'user-alice';
const _bob = 'user-bob';

FirebaseFriendsRepository _repo(
  FakeFirebaseFirestore firestore, {
  String authedUserId = _alice,
}) {
  final mockAuth = MockAuthRepository();
  mockAuth.setAuthState(
    user: FakeUser(uid: authedUserId),
    userId: authedUserId,
    isAuthenticated: true,
  );
  return FirebaseFriendsRepository(
    firestore: firestore,
    authRepository: mockAuth,
  );
}

UserProfile _profile(String uid, {String displayName = 'User'}) {
  return UserProfile(
    uid: uid,
    displayName: displayName,
    email: '$uid@example.com',
    joinedAt: DateTime.utc(2026, 1, 1),
    lastActiveAt: DateTime.utc(2026, 1, 1),
  );
}

Future<void> _seedFriendRequest(
  FakeFirebaseFirestore firestore, {
  String id = 'req-1',
  String from = _alice,
  String to = _bob,
  SocialRequestStatus status = SocialRequestStatus.pending,
}) async {
  final req = SocialRequest(
    id: id,
    type: SocialRequestType.friend,
    fromUserId: from,
    toUserId: to,
    status: status,
    sentAt: DateTime.utc(2026, 1, 1),
    expiresAt: DateTime.utc(2026, 1, 15),
  );
  await firestore.collection('social_requests').doc(id).set(req.toFirestore());
}

Future<void> _seedProfile(
  FakeFirebaseFirestore firestore,
  UserProfile profile,
) async {
  await firestore.collection('public_profiles').doc(profile.uid).set({
    ...profile.toFirestore(),
    'friendsCount': profile.friendsCount,
  });
}

GroupInvitation _invitation({
  String id = 'inv-1',
  String groupId = 'g1',
  String from = _alice,
  String to = _bob,
}) {
  return GroupInvitation(
    id: id,
    groupId: groupId,
    groupName: 'Team',
    groupEmoji: '🍳',
    fromUserId: from,
    fromUserName: from,
    toUserId: to,
    sentAt: DateTime.utc(2026, 1, 1),
    expiresAt: DateTime.utc(2026, 1, 15),
  );
}

void main() {
  group('friend request delegation', () {
    test('sendRequest creates a friend social request', () async {
      final firestore = FakeFirebaseFirestore();
      final repo = _repo(firestore);

      final req = FriendRequest(
        id: 'r1',
        fromUserId: _alice,
        toUserId: _bob,
        message: 'hej',
        sentAt: DateTime.utc(2026, 1, 1),
        expiresAt: DateTime.utc(2026, 1, 15),
      );
      await repo.sendRequest(req);

      // The id is regenerated inside SocialRequest.friendRequest — so query.
      final snap = await firestore
          .collection('social_requests')
          .where('toUserId', isEqualTo: _bob)
          .get();
      expect(snap.docs, hasLength(1));
      expect(snap.docs.first.data()['type'], 'friend');
    });

    test('sendFriendRequest returns false when sender == recipient', () async {
      final repo = _repo(FakeFirebaseFirestore());
      expect(await repo.sendFriendRequest(_alice), isFalse);
    });

    test('sendFriendRequest returns false when one already exists', () async {
      final firestore = FakeFirebaseFirestore();
      final repo = _repo(firestore);
      await _seedFriendRequest(firestore);

      expect(await repo.sendFriendRequest(_bob), isFalse);
    });

    test('sendFriendRequest returns true on success', () async {
      final firestore = FakeFirebaseFirestore();
      final repo = _repo(firestore);

      expect(await repo.sendFriendRequest(_bob), isTrue);
    });

    test('rejectFriendRequest updates status to rejected', () async {
      final firestore = FakeFirebaseFirestore();
      final repo = _repo(firestore, authedUserId: _bob);
      await _seedFriendRequest(firestore);

      expect(await repo.rejectFriendRequest('req-1'), isTrue);
      final doc =
          await firestore.collection('social_requests').doc('req-1').get();
      expect(doc.data()?['status'], 'rejected');
    });

    test('rejectFriendRequest returns false on permission error', () async {
      final firestore = FakeFirebaseFirestore();
      final repo = _repo(firestore, authedUserId: _alice);
      await _seedFriendRequest(firestore); // alice is sender, cannot reject

      expect(await repo.rejectFriendRequest('req-1'), isFalse);
    });

    test('cancelFriendRequest deletes the request', () async {
      final firestore = FakeFirebaseFirestore();
      final repo = _repo(firestore);
      await _seedFriendRequest(firestore);

      expect(await repo.cancelFriendRequest('req-1'), isTrue);
      expect(
          (await firestore.collection('social_requests').doc('req-1').get())
              .exists,
          isFalse);
    });

    test('fetchRequest maps to FriendRequest', () async {
      final firestore = FakeFirebaseFirestore();
      final repo = _repo(firestore);
      await _seedFriendRequest(firestore);

      final got = await repo.fetchRequest('req-1');
      expect(got, isNotNull);
      expect(got!.fromUserId, _alice);
    });

    test('requestExists true when pending pair exists', () async {
      final firestore = FakeFirebaseFirestore();
      final repo = _repo(firestore);
      await _seedFriendRequest(firestore);

      expect(await repo.requestExists(_alice, _bob), isTrue);
      expect(await repo.requestExists(_bob, _alice), isFalse);
    });

    test('getIncomingRequests / getSentRequests return current user-scoped',
        () async {
      final firestore = FakeFirebaseFirestore();
      final aliceRepo = _repo(firestore);
      final bobRepo = _repo(firestore, authedUserId: _bob);
      await _seedFriendRequest(firestore);

      final incoming = await bobRepo.getIncomingRequests();
      final sent = await aliceRepo.getSentRequests();

      expect(incoming.length, 1);
      expect(sent.length, 1);
      expect(incoming.first.toUserId, _bob);
      expect(sent.first.fromUserId, _alice);
    });

    test('incomingRequestsStream / sentRequestsStream emit pending requests',
        () async {
      final firestore = FakeFirebaseFirestore();
      final repo = _repo(firestore);
      await _seedFriendRequest(firestore);

      final incoming = await repo.incomingRequestsStream(_bob).first;
      final sent = await repo.sentRequestsStream(_alice).first;

      expect(incoming.length, 1);
      expect(sent.length, 1);
    });
  });

  group('acceptFriendRequest (atomic transaction)', () {
    test('creates mutual friend docs, updates request, bumps counts', () async {
      final firestore = FakeFirebaseFirestore();
      // Recipient (bob) accepts.
      final repo = _repo(firestore, authedUserId: _bob);
      await _seedFriendRequest(firestore);
      await _seedProfile(firestore, _profile(_alice, displayName: 'Alice'));
      await _seedProfile(firestore, _profile(_bob, displayName: 'Bob'));

      expect(await repo.acceptFriendRequest('req-1'), isTrue);

      // Request status flipped
      final reqDoc =
          await firestore.collection('social_requests').doc('req-1').get();
      expect(reqDoc.data()?['status'], 'accepted');

      // Both mutual friend docs created with lowercased displayName
      final aliceFriendOfBob = await firestore
          .collection('users')
          .doc(_alice)
          .collection('friends')
          .doc(_bob)
          .get();
      final bobFriendOfAlice = await firestore
          .collection('users')
          .doc(_bob)
          .collection('friends')
          .doc(_alice)
          .get();
      expect(aliceFriendOfBob.exists, isTrue);
      expect(bobFriendOfAlice.exists, isTrue);
      expect(aliceFriendOfBob.data()?['displayNameLower'], 'bob');
      expect(bobFriendOfAlice.data()?['displayNameLower'], 'alice');

      // Profiles got friendsCount bumped
      final aliceProfile =
          await firestore.collection('public_profiles').doc(_alice).get();
      final bobProfile =
          await firestore.collection('public_profiles').doc(_bob).get();
      expect(aliceProfile.data()?['friendsCount'], 1);
      expect(bobProfile.data()?['friendsCount'], 1);
    });

    test('returns false when request is missing', () async {
      final firestore = FakeFirebaseFirestore();
      final repo = _repo(firestore, authedUserId: _bob);
      expect(await repo.acceptFriendRequest('ghost'), isFalse);
    });

    test('returns false when caller is not recipient', () async {
      final firestore = FakeFirebaseFirestore();
      final repo =
          _repo(firestore, authedUserId: _alice); // sender, not recipient
      await _seedFriendRequest(firestore);
      await _seedProfile(firestore, _profile(_alice));
      await _seedProfile(firestore, _profile(_bob));

      expect(await repo.acceptFriendRequest('req-1'), isFalse);
    });

    test('returns false when request is no longer pending', () async {
      final firestore = FakeFirebaseFirestore();
      final repo = _repo(firestore, authedUserId: _bob);
      await _seedFriendRequest(firestore,
          status: SocialRequestStatus.cancelled);
      await _seedProfile(firestore, _profile(_alice));
      await _seedProfile(firestore, _profile(_bob));

      expect(await repo.acceptFriendRequest('req-1'), isFalse);
    });
  });

  group('group invitation delegation', () {
    test('saveInvitation persists with original ID', () async {
      final firestore = FakeFirebaseFirestore();
      final repo = _repo(firestore);

      await repo.saveInvitation(_invitation(id: 'inv-9'));

      final doc =
          await firestore.collection('social_requests').doc('inv-9').get();
      expect(doc.exists, isTrue);
      expect(doc.data()?['type'], 'groupInvitation');
    });

    test('updateInvitation forwards data to status update', () async {
      final firestore = FakeFirebaseFirestore();
      final repo = _repo(firestore, authedUserId: _alice);
      await repo.saveInvitation(_invitation(id: 'inv-2'));

      // Sender can cancel via updateInvitation.
      await repo.updateInvitation(
          'inv-2', {'status': SocialRequestStatus.cancelled.name});
      final doc =
          await firestore.collection('social_requests').doc('inv-2').get();
      expect(doc.data()?['status'], 'cancelled');
    });

    test('deleteInvitation removes the doc', () async {
      final firestore = FakeFirebaseFirestore();
      final repo = _repo(firestore);
      await repo.saveInvitation(_invitation(id: 'inv-3'));

      await repo.deleteInvitation('inv-3');
      expect(
          (await firestore.collection('social_requests').doc('inv-3').get())
              .exists,
          isFalse);
    });

    test('getInvitation returns GroupInvitation when doc exists', () async {
      final firestore = FakeFirebaseFirestore();
      final repo = _repo(firestore);
      await repo.saveInvitation(_invitation(id: 'inv-4'));

      final got = await repo.getInvitation('inv-4');
      expect(got, isNotNull);
      expect(got!.groupId, 'g1');
    });

    test('getInvitation returns null when missing', () async {
      final repo = _repo(FakeFirebaseFirestore());
      expect(await repo.getInvitation('ghost'), isNull);
    });

    test('hasPendingInvitation checks pair', () async {
      final firestore = FakeFirebaseFirestore();
      final repo = _repo(firestore);
      await repo.saveInvitation(_invitation(groupId: 'team-1'));

      expect(await repo.hasPendingInvitation('team-1', _bob), isTrue);
      expect(await repo.hasPendingInvitation('team-2', _bob), isFalse);
    });

    test('acceptInvitation flips status to accepted', () async {
      final firestore = FakeFirebaseFirestore();
      final aliceRepo = _repo(firestore, authedUserId: _alice);
      final bobRepo = _repo(firestore, authedUserId: _bob);
      await aliceRepo.saveInvitation(_invitation(id: 'inv-5'));

      expect(await bobRepo.acceptInvitation('inv-5'), isTrue);
      final doc =
          await firestore.collection('social_requests').doc('inv-5').get();
      expect(doc.data()?['status'], 'accepted');
    });

    test('rejectInvitation flips status to rejected', () async {
      final firestore = FakeFirebaseFirestore();
      final aliceRepo = _repo(firestore, authedUserId: _alice);
      final bobRepo = _repo(firestore, authedUserId: _bob);
      await aliceRepo.saveInvitation(_invitation(id: 'inv-6'));

      expect(await bobRepo.rejectInvitation('inv-6'), isTrue);
      final doc =
          await firestore.collection('social_requests').doc('inv-6').get();
      expect(doc.data()?['status'], 'rejected');
    });

    test('acceptInvitation / rejectInvitation return false on failure',
        () async {
      final firestore = FakeFirebaseFirestore();
      final repo = _repo(firestore);

      expect(await repo.acceptInvitation('ghost'), isFalse);
      expect(await repo.rejectInvitation('ghost'), isFalse);
    });

    test('fetchReceivedInvitations / fetchSentInvitations return correct lists',
        () async {
      final firestore = FakeFirebaseFirestore();
      final aliceRepo = _repo(firestore, authedUserId: _alice);
      final bobRepo = _repo(firestore, authedUserId: _bob);

      await aliceRepo.saveInvitation(_invitation(id: 'i1'));
      await aliceRepo.saveInvitation(_invitation(id: 'i2'));

      final received = await bobRepo.fetchReceivedInvitations(_bob);
      final sent = await aliceRepo.fetchSentInvitations(_alice);

      expect(received.length, 2);
      expect(sent.length, 2);
    });

    test('receivedInvitationsStream / sentInvitationsStream emit', () async {
      final firestore = FakeFirebaseFirestore();
      final repo = _repo(firestore);
      await repo.saveInvitation(_invitation(id: 'i-stream'));

      final received = await repo.receivedInvitationsStream(_bob).first;
      final sent = await repo.sentInvitationsStream(_alice).first;
      expect(received.length, 1);
      expect(sent.length, 1);
    });

    test('expiredInvitations / oldInvitations / batch ops round-trip',
        () async {
      final firestore = FakeFirebaseFirestore();
      final repo = _repo(firestore);
      await repo.saveInvitation(_invitation(id: 'i-old'));
      await repo.saveInvitation(_invitation(id: 'i-new'));

      // expiredInvitations as of far-future
      final expired = await repo.expiredInvitations(DateTime.utc(2030, 1, 1));
      expect(expired.length, greaterThan(0));

      final old = await repo.oldInvitations(_bob, DateTime.utc(2030, 1, 1));
      expect(old.length, greaterThan(0));

      // Batch update + delete
      await repo.updateDocuments(expired, {'status': 'expired'});
      final afterUpdate =
          await firestore.collection('social_requests').doc('i-old').get();
      expect(afterUpdate.data()?['status'], 'expired');

      await repo.deleteDocuments(expired);
      final afterDelete =
          (await firestore.collection('social_requests').doc('i-old').get())
              .exists;
      expect(afterDelete, isFalse);
    });
  });

  group('relationship facade passthroughs', () {
    test('addMutualFriends + areFriends + removeMutualFriends round-trip',
        () async {
      final firestore = FakeFirebaseFirestore();
      final repo = _repo(firestore);
      await _seedProfile(firestore, _profile(_alice));
      await _seedProfile(firestore, _profile(_bob));

      expect(await repo.areFriends(_alice, _bob), isFalse);
      await repo.addMutualFriends(_alice, _bob);
      expect(await repo.areFriends(_alice, _bob), isTrue);

      await repo.removeMutualFriends(_alice, _bob);
      expect(await repo.areFriends(_alice, _bob), isFalse);
    });

    test('fetchFriendIds + friendIdsStream return added friends', () async {
      final firestore = FakeFirebaseFirestore();
      final repo = _repo(firestore);
      await _seedProfile(firestore, _profile(_alice));
      await _seedProfile(firestore, _profile(_bob));
      await repo.addMutualFriends(_alice, _bob);

      expect(await repo.fetchFriendIds(_alice), [_bob]);
      final stream = await repo.friendIdsStream(_alice).first;
      expect(stream, [_bob]);
    });

    test('fetchFriendProfiles returns profile docs for ids', () async {
      final firestore = FakeFirebaseFirestore();
      final repo = _repo(firestore);
      await _seedProfile(firestore, _profile(_bob, displayName: 'Bob'));

      final profiles = await repo.fetchFriendProfiles([_bob]);
      expect(profiles.map((p) => p.uid), [_bob]);
      expect(profiles.first.displayName, 'Bob');
    });

    test('removeFriend deletes for current user (lightweight delegation)',
        () async {
      final firestore = FakeFirebaseFirestore();
      final repo = _repo(firestore);
      await _seedProfile(firestore, _profile(_alice));
      await _seedProfile(firestore, _profile(_bob));
      await repo.addMutualFriends(_alice, _bob);

      expect(await repo.removeFriend(_bob), isTrue);
      expect(await repo.areFriends(_alice, _bob), isFalse);
    });
  });

  group('category facade passthroughs', () {
    FriendCategory cat(String id, String name) {
      return FriendCategory(
        id: id,
        ownerId: _alice,
        name: name,
        emoji: '👥',
        friendUserIds: const [],
        createdAt: DateTime.utc(2026, 1, 1),
        updatedAt: DateTime.utc(2026, 1, 1),
      );
    }

    test('saveCategory + fetchCategories round-trip', () async {
      final firestore = FakeFirebaseFirestore();
      final repo = _repo(firestore);

      await repo.saveCategory(_alice, cat('c1', 'Friends'));
      final got = await repo.fetchCategories(_alice);
      expect(got.length, 1);
      expect(got.first.name, 'Friends');
    });

    test('getCategory returns specific category by id', () async {
      final firestore = FakeFirebaseFirestore();
      final repo = _repo(firestore);
      await repo.saveCategory(_alice, cat('c1', 'Friends'));

      final got = await repo.getCategory(_alice, 'c1');
      expect(got, isNotNull);
      expect(got!.name, 'Friends');
    });

    test('updateCategory persists data changes', () async {
      final firestore = FakeFirebaseFirestore();
      final repo = _repo(firestore);
      await repo.saveCategory(_alice, cat('c1', 'Friends'));

      await repo.updateCategory(_alice, 'c1', {'name': 'Family'});
      final got = await repo.getCategory(_alice, 'c1');
      expect(got!.name, 'Family');
    });

    test('updateCategoryMembers swaps member list', () async {
      final firestore = FakeFirebaseFirestore();
      final repo = _repo(firestore);
      await repo.saveCategory(_alice, cat('c1', 'Friends'));

      await repo.updateCategoryMembers(_alice, 'c1', [_bob]);
      final got = await repo.getCategory(_alice, 'c1');
      expect(got!.friendUserIds, [_bob]);
    });

    test('addFriendToCategory + removeFriendFromCategory mutate members',
        () async {
      final firestore = FakeFirebaseFirestore();
      final repo = _repo(firestore);
      await repo.saveCategory(_alice, cat('c1', 'Friends'));

      await repo.addFriendToCategory(_alice, 'c1', _bob);
      expect((await repo.getCategory(_alice, 'c1'))!.friendUserIds,
          contains(_bob));

      await repo.removeFriendFromCategory(_alice, 'c1', _bob);
      expect((await repo.getCategory(_alice, 'c1'))!.friendUserIds,
          isNot(contains(_bob)));
    });

    test('deleteCategory removes the doc', () async {
      final firestore = FakeFirebaseFirestore();
      final repo = _repo(firestore);
      await repo.saveCategory(_alice, cat('c1', 'Friends'));

      await repo.deleteCategory(_alice, 'c1');
      expect(await repo.getCategory(_alice, 'c1'), isNull);
    });
  });

  group('comprehensive statistics', () {
    test('getComprehensiveFriendStatistics aggregates 4 sub-stats', () async {
      final firestore = FakeFirebaseFirestore();
      final repo = _repo(firestore);
      await _seedProfile(firestore, _profile(_alice));
      await _seedProfile(firestore, _profile(_bob));
      await repo.addMutualFriends(_alice, _bob);
      await _seedFriendRequest(firestore, id: 'r1', from: _bob, to: _alice);
      await repo.saveInvitation(_invitation(id: 'i1', from: _alice, to: _bob));

      final stats = await repo.getComprehensiveFriendStatistics(_alice);

      expect(stats.keys,
          containsAll({'friends', 'requests', 'categories', 'invitations'}));
      expect(stats['requests'], isA<Map>());
      expect(stats['invitations'], isA<Map>());
    });
  });
}
