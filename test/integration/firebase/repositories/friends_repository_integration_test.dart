/// Emulator-lane integration tests for [FirebaseFriendsRepository].
///
/// These cover what the in-memory fake cannot reproduce faithfully:
/// transactional friend-count bookkeeping (`FieldValue.increment` inside
/// `runTransaction`) and `arrayUnion`/`arrayRemove` category membership.
/// Accepting a request is not covered here: it is a Cloud Function call, so
/// it lives in the functions test suites.
///
/// The emulator runs without security rules, so rules-level denials are not
/// asserted here; the repository's own client-side permission checks are.
@Tags(['integration', 'firebase'])
library;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/core/exceptions/permission_exceptions.dart';
import 'package:butlery/models/friend_category.dart';
import 'package:butlery/repositories/firebase/firebase_auth_repository.dart';
import 'package:butlery/repositories/firebase/firebase_friends_repository.dart';

import '../../../test_support/emulator_lane.dart';

void main() {
  group('Firebase Friends Repository Integration', () {
    late FirebaseFirestore firestore;
    late FirebaseFriendsRepository repository;

    const me = 'test-user-uid';

    Future<void> seedProfile(String uid, {int friendsCount = 0}) => firestore
        .collection('public_profiles')
        .doc(uid)
        .set({'displayName': 'User $uid', 'friendsCount': friendsCount});

    Future<void> seedFriendDoc(String owner, String friend) => firestore
        .collection('users')
        .doc(owner)
        .collection('friends')
        .doc(friend)
        .set({'displayNameLower': friend});

    Future<int?> friendsCount(String uid) async {
      final doc = await firestore
          .collection('public_profiles')
          .doc(uid)
          .get(const GetOptions(source: Source.server));
      return doc.data()?['friendsCount'] as int?;
    }

    Future<bool> friendDocExists(String owner, String friend) async {
      final doc = await firestore
          .collection('users')
          .doc(owner)
          .collection('friends')
          .doc(friend)
          .get(const GetOptions(source: Source.server));
      return doc.exists;
    }

    Future<void> seedRequest({
      required String from,
      required String to,
      String status = 'pending',
      String type = 'friend',
      String? message,
    }) => firestore.collection('social_requests').add({
      'type': type,
      'fromUserId': from,
      'toUserId': to,
      'status': status,
      'sentAt': Timestamp.now(),
      'message': message,
    });

    setUp(() async {
      firestore = await firestoreForLane();
      await clearLane();

      final mockAuth = MockFirebaseAuth(
        mockUser: MockUser(
          uid: me,
          email: 'test@example.com',
          displayName: 'Test User',
        ),
        signedIn: true,
      );
      repository = FirebaseFriendsRepository(
        firestore: firestore,
        authRepository: FirebaseAuthRepository(firebaseAuth: mockAuth),
      );
    });

    group('Friend requests', () {
      test('sendFriendRequest stores a pending request with the message and '
          'a timestamp', () async {
        const target = 'target_user_456';

        final sent = await repository.sendFriendRequest(
          target,
          message: 'Let\'s be friends!',
        );

        expect(sent, isTrue);
        final stored = await firestore
            .collection('social_requests')
            .where('fromUserId', isEqualTo: me)
            .where('toUserId', isEqualTo: target)
            .get(const GetOptions(source: Source.server));
        expect(stored.docs, hasLength(1));
        final data = stored.docs.single.data();
        expect(data['type'], 'friend');
        expect(data['status'], 'pending');
        expect(data['message'], 'Let\'s be friends!');
        expect(data['sentAt'], isA<Timestamp>());
      });

      test('a second request to the same person is refused and writes '
          'nothing', () async {
        const target = 'target_user_456';
        expect(await repository.sendFriendRequest(target), isTrue);

        final again = await repository.sendFriendRequest(target);

        expect(again, isFalse);
        final stored = await firestore
            .collection('social_requests')
            .where('toUserId', isEqualTo: target)
            .get(const GetOptions(source: Source.server));
        expect(stored.docs, hasLength(1));
      });

      test('a request to yourself is refused and writes nothing', () async {
        final sent = await repository.sendFriendRequest(me);

        expect(sent, isFalse);
        final stored = await firestore
            .collection('social_requests')
            .get(const GetOptions(source: Source.server));
        expect(stored.docs, isEmpty);
      });

      test('getIncomingRequests returns only pending friend requests '
          'addressed to the current user', () async {
        for (var i = 0; i < 3; i++) {
          await seedRequest(from: 'user_$i', to: me, message: 'Request $i');
        }
        await seedRequest(from: 'user_x', to: me, status: 'rejected');
        await seedRequest(from: 'user_y', to: me, type: 'groupInvitation');
        await seedRequest(from: 'user_z', to: 'someone_else');

        final incoming = await repository.getIncomingRequests();

        expect(
          incoming.map((r) => r.fromUserId),
          unorderedEquals(['user_0', 'user_1', 'user_2']),
        );
        expect(
          incoming.map((r) => r.message),
          unorderedEquals(['Request 0', 'Request 1', 'Request 2']),
        );
      });

      test('the sender can cancel a request, a stranger cannot', () async {
        final stranger = FirebaseFriendsRepository(
          firestore: firestore,
          authRepository: FirebaseAuthRepository(
            firebaseAuth: MockFirebaseAuth(
              mockUser: MockUser(uid: 'stranger'),
              signedIn: true,
            ),
          ),
        );
        final ref = await firestore.collection('social_requests').add({
          'type': 'friend',
          'fromUserId': me,
          'toUserId': 'target',
          'status': 'pending',
          'sentAt': Timestamp.now(),
        });

        expect(await stranger.cancelFriendRequest(ref.id), isFalse);
        expect(
          (await ref.get(const GetOptions(source: Source.server))).exists,
          isTrue,
        );

        expect(await repository.cancelFriendRequest(ref.id), isTrue);
        expect(
          (await ref.get(const GetOptions(source: Source.server))).exists,
          isFalse,
        );
      });
    });

    group('Friend count bookkeeping', () {
      test('removeMutualFriends deletes both friend docs and decrements '
          'both counts', () async {
        await seedProfile('user_1', friendsCount: 10);
        await seedProfile('user_2', friendsCount: 8);
        await seedFriendDoc('user_1', 'user_2');
        await seedFriendDoc('user_2', 'user_1');

        await repository.removeMutualFriends('user_1', 'user_2');

        expect(await friendDocExists('user_1', 'user_2'), isFalse);
        expect(await friendDocExists('user_2', 'user_1'), isFalse);
        expect(await friendsCount('user_1'), 9);
        expect(await friendsCount('user_2'), 7);
      });

      test('removeMutualFriends after a half-written friendship only '
          'decrements the side that exists', () async {
        await seedProfile('user_1', friendsCount: 4);
        await seedProfile('user_2', friendsCount: 4);
        await seedFriendDoc('user_1', 'user_2');

        await repository.removeMutualFriends('user_1', 'user_2');

        expect(await friendDocExists('user_1', 'user_2'), isFalse);
        expect(await friendsCount('user_1'), 3);
        expect(await friendsCount('user_2'), 4);
      });

      test(
        'removeFriend removes the current user from the other side too',
        () async {
          await seedProfile(me, friendsCount: 2);
          await seedProfile('pal', friendsCount: 2);
          await seedFriendDoc(me, 'pal');
          await seedFriendDoc('pal', me);

          expect(await repository.removeFriend('pal'), isTrue);

          expect(await repository.areFriends(me, 'pal'), isFalse);
          expect(await repository.areFriends('pal', me), isFalse);
          expect(await friendsCount(me), 1);
          expect(await friendsCount('pal'), 1);
        },
      );

      test('addMutualFriends writes both sides once and does not double-count '
          'when repeated', () async {
        await seedProfile('user_1', friendsCount: 5);
        await seedProfile('user_2', friendsCount: 3);

        await repository.addMutualFriends('user_1', 'user_2');
        await repository.addMutualFriends('user_1', 'user_2');

        expect(await repository.areFriends('user_1', 'user_2'), isTrue);
        expect(await repository.areFriends('user_2', 'user_1'), isTrue);
        expect(await friendsCount('user_1'), 6);
        expect(await friendsCount('user_2'), 4);
      });

      test('addMutualFriends repairs a half-written friendship without '
          'touching the counts', () async {
        await seedProfile('user_1', friendsCount: 5);
        await seedProfile('user_2', friendsCount: 3);
        await seedFriendDoc('user_1', 'user_2');

        await repository.addMutualFriends('user_1', 'user_2');

        expect(await friendDocExists('user_2', 'user_1'), isTrue);
        expect(await friendsCount('user_1'), 5);
        expect(await friendsCount('user_2'), 3);
      });
    });

    group('Friend categories', () {
      Future<FriendCategory> seedCategory(List<String> members) async {
        final category = FriendCategory.create(
          ownerId: me,
          name: 'Family',
          friendUserIds: members,
        );
        await repository.saveCategory(me, category);
        return category;
      }

      Future<List<String>> storedMembers(FriendCategory category) async {
        final stored = await repository.getCategory(me, category.id);
        return stored!.friendUserIds;
      }

      test('adding a friend twice keeps one entry; removing takes only that '
          'friend out', () async {
        final category = await seedCategory(['member_1', 'member_2']);

        await repository.addFriendToCategory(me, category.id, 'member_3');
        await repository.addFriendToCategory(me, category.id, 'member_3');
        await repository.addFriendToCategory(me, category.id, 'member_2');

        expect(
          await storedMembers(category),
          unorderedEquals(['member_1', 'member_2', 'member_3']),
        );

        await repository.removeFriendFromCategory(me, category.id, 'member_1');

        expect(
          await storedMembers(category),
          unorderedEquals(['member_2', 'member_3']),
        );
      });

      test('updateCategoryMembers replaces the member list', () async {
        final category = await seedCategory(['member_1', 'member_2']);

        await repository.updateCategoryMembers(me, category.id, ['member_9']);

        expect(await storedMembers(category), ['member_9']);
      });

      test('a user cannot edit or delete another user\'s category', () async {
        final category = await seedCategory(['member_1']);

        await expectLater(
          repository.addFriendToCategory('someone_else', category.id, 'x'),
          throwsA(isA<PermissionDeniedException>()),
        );
        await expectLater(
          repository.deleteCategory('someone_else', category.id),
          throwsA(isA<PermissionDeniedException>()),
        );
        expect(await storedMembers(category), ['member_1']);
      });

      test('deleteCategory removes the category', () async {
        final category = await seedCategory(['member_1']);

        await repository.deleteCategory(me, category.id);

        expect(await repository.getCategory(me, category.id), isNull);
      });
    });
  }, skip: emulatorOnlySkip);
}
