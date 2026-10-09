/// Gap-filling tests for FriendCategoryRepository.
///
/// Existing test/unit/repositories/friends/friend_category_repository_test.dart
/// covers basic CRUD. This file targets the still-uncovered branches:
/// - addSelfToCategory (arrayUnion + permission audit log)
/// - fetchMemberCategories (collectionGroup query)
/// - handOverGroup (callable call + outcome mapping)
/// - memberCategoriesStream (collectionGroup snapshots)
/// - getCategoryStatistics (aggregation: totalCategories, averageSize, largest)
/// - searchCategories (name + description text search)
/// - getEmptyCategories, getLargestCategories
/// - categoryNameExists (case-insensitive + excludeId)
/// - bulkUpdateCategories (batch write)
// ignore_for_file: subtype_of_sealed_class
library;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:butlery/core/exceptions/permission_exceptions.dart';
import 'package:butlery/models/friend_category.dart';
import 'package:butlery/models/social/group_hand_over_outcome.dart';
import 'package:butlery/repositories/firebase/friends/friend_category_repository.dart';

import '../../../infrastructure/mocks/production_mocks.dart';

class _MockFunctions extends Mock implements FirebaseFunctions {}

class _MockCallable extends Mock implements HttpsCallable {}

class _FakeCallableResult extends Fake implements HttpsCallableResult<Object?> {
  @override
  Object? get data => null;
}

class _MockFirestore extends Mock implements FirebaseFirestore {}

class _MockCollection extends Mock
    implements CollectionReference<Map<String, dynamic>> {}

class _MockDoc extends Mock
    implements DocumentReference<Map<String, dynamic>> {}

class _MockSnapshot extends Mock
    implements DocumentSnapshot<Map<String, dynamic>> {}

const _alice = 'user-alice';
const _bob = 'user-bob';

FriendCategoryRepository _repo(
  FakeFirebaseFirestore firestore, {
  String authedUserId = _alice,
}) {
  final mockAuth = FakeAuthRepository();
  mockAuth.setAuthState(
    user: FakeUser(uid: authedUserId),
    userId: authedUserId,
    isAuthenticated: true,
  );
  return FriendCategoryRepository(
    firestore: firestore,
    authRepository: mockAuth,
  );
}

FriendCategory _cat({
  required String id,
  required String name,
  String owner = _alice,
  String? description,
  List<String> members = const [],
}) {
  return FriendCategory(
    id: id,
    ownerId: owner,
    name: name,
    description: description,
    emoji: '👥',
    friendUserIds: members,
    createdAt: DateTime.utc(2026, 1, 1),
    updatedAt: DateTime.utc(2026, 1, 1),
  );
}

Future<void> _seed(
  FakeFirebaseFirestore firestore, {
  required String ownerId,
  required FriendCategory category,
}) async {
  await firestore
      .collection('users')
      .doc(ownerId)
      .collection('friend_categories')
      .doc(category.id)
      .set(category.toFirestore());
}

void main() {
  group('addSelfToCategory', () {
    test('appends current user to friendUserIds', () async {
      final firestore = FakeFirebaseFirestore();
      final repo = _repo(firestore, authedUserId: _bob);
      await _seed(
        firestore,
        ownerId: _alice,
        category: _cat(id: 'c1', name: 'Friends'),
      );

      await repo.addSelfToCategory(_alice, 'c1');

      final doc = await firestore
          .collection('users')
          .doc(_alice)
          .collection('friend_categories')
          .doc('c1')
          .get();
      expect(doc.data()?['friendUserIds'], contains(_bob));
    });
  });

  group('removeSelfFromCategory', () {
    test('removes only the current user and stamps updatedAt', () async {
      final firestore = FakeFirebaseFirestore();
      final repo = _repo(firestore, authedUserId: _bob);
      await _seed(
        firestore,
        ownerId: _alice,
        category: _cat(id: 'c1', name: 'Friends', members: [_alice, _bob]),
      );
      final ref = firestore
          .collection('users')
          .doc(_alice)
          .collection('friend_categories')
          .doc('c1');
      final updatedBefore = (await ref.get()).data()?['updatedAt'];

      await repo.removeSelfFromCategory(_alice, 'c1');

      final data = (await ref.get()).data();
      expect(data?['friendUserIds'], [_alice]);
      expect(data?['updatedAt'], isNotNull);
      expect(data?['updatedAt'], isNot(updatedBefore));
    });
  });

  group('fetchMemberCategories', () {
    test('returns categories where user is a friendUserIds member', () async {
      final firestore = FakeFirebaseFirestore();
      final repo = _repo(firestore);
      await _seed(
        firestore,
        ownerId: _alice,
        category: _cat(id: 'c1', name: 'A', members: [_bob]),
      );
      await _seed(
        firestore,
        ownerId: _alice,
        category: _cat(id: 'c2', name: 'B', members: []),
      );
      await _seed(
        firestore,
        ownerId: 'someone-else',
        category: _cat(id: 'c3', name: 'C', members: [_bob]),
      );

      final results = await repo.fetchMemberCategories(_bob);
      expect(results.map((c) => c.id).toSet(), {'c1', 'c3'});
    });
  });

  group('handOverGroup', () {
    late _MockFunctions functions;
    late _MockCallable callable;
    late FakeFirebaseFirestore firestore;
    late FriendCategoryRepository repo;

    setUp(() async {
      firestore = FakeFirebaseFirestore();
      await _seed(
        firestore,
        ownerId: _alice,
        category: _cat(id: 'c1', name: 'Fredagsmiddag', members: [_bob]),
      );
      functions = _MockFunctions();
      callable = _MockCallable();
      when(() => functions.httpsCallable(any())).thenReturn(callable);
      final mockAuth = FakeAuthRepository();
      mockAuth.setAuthState(
        user: FakeUser(uid: _alice),
        userId: _alice,
        isAuthenticated: true,
      );
      repo = FriendCategoryRepository(
        firestore: firestore,
        authRepository: mockAuth,
        functions: functions,
      );
    });

    void stubRefusal(String code, String message) {
      when(() => callable.call<Object?>(any())).thenThrow(
        FirebaseFunctionsException(code: code, message: message),
      );
    }

    test(
      'calls handOverGroup with the group and new owner, returns done',
      () async {
        when(
          () => callable.call<Object?>(any()),
        ).thenAnswer((_) async => _FakeCallableResult());

        final outcome = await repo.handOverGroup('c1', _bob);

        expect(outcome, GroupHandOverOutcome.done);
        verify(() => functions.httpsCallable('handOverGroup')).called(1);
        verify(
          () => callable.call<Object?>({'groupId': 'c1', 'newOwnerId': _bob}),
        ).called(1);
      },
    );

    test('failed-precondition naming the household maps to '
        'newOwnerNotInHousehold', () async {
      stubRefusal('failed-precondition', 'new-owner-not-in-household');

      expect(
        await repo.handOverGroup('c1', _bob),
        GroupHandOverOutcome.newOwnerNotInHousehold,
      );
    });

    test('any other failed-precondition maps to unavailable', () async {
      stubRefusal('failed-precondition', 'group-not-handoverable');

      expect(
        await repo.handOverGroup('c1', _bob),
        GroupHandOverOutcome.unavailable,
      );
    });

    test('a blank failed-precondition message maps to unavailable', () async {
      stubRefusal('failed-precondition', '');

      expect(
        await repo.handOverGroup('c1', _bob),
        GroupHandOverOutcome.unavailable,
      );
    });

    test('the household message under another code maps to failed', () async {
      stubRefusal('permission-denied', 'new-owner-not-in-household');

      expect(
        await repo.handOverGroup('c1', _bob),
        GroupHandOverOutcome.failed,
      );
    });

    test('an unrelated code maps to failed', () async {
      stubRefusal('unavailable', 'network');

      expect(
        await repo.handOverGroup('c1', _bob),
        GroupHandOverOutcome.failed,
      );
    });

    void stubCommittedThenThrow(String code) {
      when(() => callable.call<Object?>(any())).thenAnswer((_) async {
        await firestore.doc('users/$_alice/friend_categories/c1').delete();
        throw FirebaseFunctionsException(code: code, message: 'lost');
      });
    }

    test('permission-denied after the group left this account during the '
        'call maps to done', () async {
      stubCommittedThenThrow('permission-denied');

      expect(await repo.handOverGroup('c1', _bob), GroupHandOverOutcome.done);
    });

    test('a transport error after the server committed maps to done', () async {
      stubCommittedThenThrow('deadline-exceeded');

      expect(await repo.handOverGroup('c1', _bob), GroupHandOverOutcome.done);
    });

    test(
      'failed-precondition never reads as done, even with the group gone',
      () async {
        when(() => callable.call<Object?>(any())).thenAnswer((_) async {
          await firestore.doc('users/$_alice/friend_categories/c1').delete();
          throw FirebaseFunctionsException(
            code: 'failed-precondition',
            message: 'open-report',
          );
        });

        expect(
          await repo.handOverGroup('c1', _bob),
          GroupHandOverOutcome.unavailable,
        );
      },
    );

    group('when the server cannot be asked', () {
      late _MockDoc groupDoc;
      late FriendCategoryRepository offlineRepo;
      late List<GetOptions?> readOptions;

      setUpAll(() => registerFallbackValue(const GetOptions()));

      setUp(() {
        final db = _MockFirestore();
        final users = _MockCollection();
        final userDoc = _MockDoc();
        final groups = _MockCollection();
        groupDoc = _MockDoc();
        when(() => db.collection('users')).thenReturn(users);
        when(() => users.doc(_alice)).thenReturn(userDoc);
        when(() => userDoc.collection('friend_categories')).thenReturn(groups);
        when(() => groups.doc('c1')).thenReturn(groupDoc);
        readOptions = [];
        final mockAuth = FakeAuthRepository();
        mockAuth.setAuthState(
          user: FakeUser(uid: _alice),
          userId: _alice,
          isAuthenticated: true,
        );
        offlineRepo = FriendCategoryRepository(
          firestore: db,
          authRepository: mockAuth,
          functions: functions,
        );
      });

      void stubReads(List<bool?> answers) {
        final queue = List<bool?>.from(answers);
        when(() => groupDoc.get(any())).thenAnswer((inv) async {
          readOptions.add(inv.positionalArguments.first as GetOptions?);
          final exists = queue.removeAt(0);
          if (exists == null) throw FirebaseException(plugin: 'firestore');
          final snap = _MockSnapshot();
          when(() => snap.exists).thenReturn(exists);
          return snap;
        });
      }

      test(
        'a failed read before the call returns failed, with no call',
        () async {
          stubReads([null]);

          expect(
            await offlineRepo.handOverGroup('c1', _bob),
            GroupHandOverOutcome.failed,
          );
          verifyNever(() => callable.call<Object?>(any()));
        },
      );

      test('a failed read after an error never reads as done', () async {
        stubReads([true, null]);
        stubRefusal('permission-denied', 'Not allowed.');

        expect(
          await offlineRepo.handOverGroup('c1', _bob),
          GroupHandOverOutcome.failed,
        );
      });

      test('both reads ask the server, never the cache', () async {
        stubReads([true, false]);
        stubRefusal('deadline-exceeded', 'lost');

        expect(
          await offlineRepo.handOverGroup('c1', _bob),
          GroupHandOverOutcome.done,
        );
        expect(readOptions.map((o) => o?.source), [
          Source.server,
          Source.server,
        ]);
      });
    });

    test('a group not stored under the caller is not offered to the server '
        '(moved by the old field-only transfer)', () async {
      await firestore.doc('users/$_alice/friend_categories/c1').delete();
      await _seed(
        firestore,
        ownerId: _bob,
        category: _cat(id: 'c1', name: 'Fredagsmiddag', owner: _alice),
      );

      expect(
        await repo.handOverGroup('c1', _bob),
        GroupHandOverOutcome.failed,
      );
      verifyNever(() => callable.call<Object?>(any()));
    });
  });

  group('getCategoriesContainingFriend', () {
    test('returns only categories the friend is a member of', () async {
      final firestore = FakeFirebaseFirestore();
      final repo = _repo(firestore);
      await _seed(
        firestore,
        ownerId: _alice,
        category: _cat(id: 'c1', name: 'A', members: ['carol']),
      );
      await _seed(
        firestore,
        ownerId: _alice,
        category: _cat(id: 'c2', name: 'B', members: ['carol', 'dave']),
      );
      await _seed(
        firestore,
        ownerId: _alice,
        category: _cat(id: 'c3', name: 'C', members: ['dave']),
      );

      final results = await repo.getCategoriesContainingFriend(_alice, 'carol');
      expect(results.map((c) => c.id).toSet(), {'c1', 'c2'});
    });
  });

  group('streams', () {
    test('categoriesStream emits owned categories', () async {
      final firestore = FakeFirebaseFirestore();
      final repo = _repo(firestore);
      await _seed(
        firestore,
        ownerId: _alice,
        category: _cat(id: 'c1', name: 'Friends'),
      );
      await _seed(
        firestore,
        ownerId: _alice,
        category: _cat(id: 'c2', name: 'Family'),
      );

      final first = await repo.categoriesStream(_alice).first;
      expect(first.length, 2);
    });

    test(
      'memberCategoriesStream emits categories user is a member of',
      () async {
        final firestore = FakeFirebaseFirestore();
        final repo = _repo(firestore);
        await _seed(
          firestore,
          ownerId: _alice,
          category: _cat(id: 'c1', name: 'A', members: [_bob]),
        );
        await _seed(
          firestore,
          ownerId: _alice,
          category: _cat(id: 'c2', name: 'B', members: ['carol']),
        );

        final first = await repo.memberCategoriesStream(_bob).first;
        expect(first.map((c) => c.id), ['c1']);
      },
    );
  });

  group('getCategoryStatistics', () {
    test('aggregates total counts + averageSize + largest', () async {
      final firestore = FakeFirebaseFirestore();
      final repo = _repo(firestore);
      await _seed(
        firestore,
        ownerId: _alice,
        category: _cat(id: 'c1', name: 'Small', members: ['a']),
      );
      await _seed(
        firestore,
        ownerId: _alice,
        category: _cat(id: 'c2', name: 'Big', members: ['a', 'b', 'c']),
      );

      final stats = await repo.getCategoryStatistics(_alice);
      expect(stats['totalCategories'], 2);
      expect(stats['totalMembers'], 4);
      expect(stats['averageSize'], 2);
      expect(stats['largestCategorySize'], 3);
      expect(stats['largestCategoryName'], 'Big');
      expect(stats['hasCategories'], isTrue);
    });

    test('returns zero / null values when no categories', () async {
      final repo = _repo(FakeFirebaseFirestore());

      final stats = await repo.getCategoryStatistics(_alice);
      expect(stats['totalCategories'], 0);
      expect(stats['totalMembers'], 0);
      expect(stats['averageSize'], 0);
      expect(stats['largestCategorySize'], 0);
      expect(stats['largestCategoryName'], isNull);
      expect(stats['hasCategories'], isFalse);
    });
  });

  group('searchCategories', () {
    test('matches name (case-insensitive)', () async {
      final firestore = FakeFirebaseFirestore();
      final repo = _repo(firestore);
      await _seed(
        firestore,
        ownerId: _alice,
        category: _cat(id: 'c1', name: 'Friends'),
      );
      await _seed(
        firestore,
        ownerId: _alice,
        category: _cat(id: 'c2', name: 'Family'),
      );

      final results = await repo.searchCategories(_alice, 'FRI');
      expect(results.map((c) => c.id), ['c1']);
    });

    test('matches description when present', () async {
      final firestore = FakeFirebaseFirestore();
      final repo = _repo(firestore);
      await _seed(
        firestore,
        ownerId: _alice,
        category: _cat(
          id: 'c1',
          name: 'Friends',
          description: 'Close acquaintances',
        ),
      );

      final results = await repo.searchCategories(_alice, 'close');
      expect(results.map((c) => c.id), ['c1']);
    });
  });

  group('getEmptyCategories / getLargestCategories / categoryNameExists', () {
    test('getEmptyCategories returns only zero-member categories', () async {
      final firestore = FakeFirebaseFirestore();
      final repo = _repo(firestore);
      await _seed(
        firestore,
        ownerId: _alice,
        category: _cat(id: 'c1', name: 'Empty'),
      );
      await _seed(
        firestore,
        ownerId: _alice,
        category: _cat(id: 'c2', name: 'NonEmpty', members: ['x']),
      );

      final empties = await repo.getEmptyCategories(_alice);
      expect(empties.map((c) => c.id), ['c1']);
    });

    test('getLargestCategories sorts desc and applies limit', () async {
      final firestore = FakeFirebaseFirestore();
      final repo = _repo(firestore);
      await _seed(
        firestore,
        ownerId: _alice,
        category: _cat(id: 'c1', name: 'Small', members: ['a']),
      );
      await _seed(
        firestore,
        ownerId: _alice,
        category: _cat(id: 'c2', name: 'Medium', members: ['a', 'b']),
      );
      await _seed(
        firestore,
        ownerId: _alice,
        category: _cat(id: 'c3', name: 'Big', members: ['a', 'b', 'c', 'd']),
      );

      final top2 = await repo.getLargestCategories(_alice, limit: 2);
      expect(top2.map((c) => c.id), ['c3', 'c2']);
    });

    test('categoryNameExists case-insensitive + excludes given id', () async {
      final firestore = FakeFirebaseFirestore();
      final repo = _repo(firestore);
      await _seed(
        firestore,
        ownerId: _alice,
        category: _cat(id: 'c1', name: 'Friends'),
      );

      expect(await repo.categoryNameExists(_alice, 'FRIENDS'), isTrue);
      expect(
        await repo.categoryNameExists(
          _alice,
          'FRIENDS',
          excludeCategoryId: 'c1',
        ),
        isFalse,
      );
      expect(await repo.categoryNameExists(_alice, 'NewName'), isFalse);
    });
  });

  group('bulkUpdateCategories', () {
    test('batch-updates multiple categories', () async {
      final firestore = FakeFirebaseFirestore();
      final repo = _repo(firestore);
      await _seed(
        firestore,
        ownerId: _alice,
        category: _cat(id: 'c1', name: 'A'),
      );
      await _seed(
        firestore,
        ownerId: _alice,
        category: _cat(id: 'c2', name: 'B'),
      );

      await repo.bulkUpdateCategories(_alice, {
        'c1': {'name': 'A-updated'},
        'c2': {'name': 'B-updated'},
      });

      final c1 = await firestore
          .collection('users')
          .doc(_alice)
          .collection('friend_categories')
          .doc('c1')
          .get();
      final c2 = await firestore
          .collection('users')
          .doc(_alice)
          .collection('friend_categories')
          .doc('c2')
          .get();
      expect(c1.data()?['name'], 'A-updated');
      expect(c2.data()?['name'], 'B-updated');
    });

    test('rejects when current user is not target user', () async {
      final repo = _repo(FakeFirebaseFirestore(), authedUserId: _bob);

      await expectLater(
        () => repo.bulkUpdateCategories(_alice, {
          'c1': {'name': 'x'},
        }),
        throwsA(isA<PermissionDeniedException>()),
      );
    });
  });
}
