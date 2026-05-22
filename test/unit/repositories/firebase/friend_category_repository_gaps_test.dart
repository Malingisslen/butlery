/// Gap-filling tests for FriendCategoryRepository.
///
/// Existing test/unit/repositories/friends/friend_category_repository_test.dart
/// covers basic CRUD. This file targets the still-uncovered branches:
/// - addSelfToCategory (arrayUnion + permission audit log)
/// - fetchMemberCategories (collectionGroup query)
/// - transferOwnership (transaction + TOCTOU guard)
/// - memberCategoriesStream (collectionGroup snapshots)
/// - getCategoryStatistics (aggregation: totalCategories, averageSize, largest)
/// - searchCategories (name + description text search)
/// - getEmptyCategories, getLargestCategories
/// - categoryNameExists (case-insensitive + excludeId)
/// - bulkUpdateCategories (batch write)
library;

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/core/exceptions/permission_exceptions.dart';
import 'package:butlery/models/friend_category.dart';
import 'package:butlery/repositories/firebase/friends/friend_category_repository.dart';

import '../../../infrastructure/mocks/production_mocks.dart';

const _alice = 'user-alice';
const _bob = 'user-bob';

FriendCategoryRepository _repo(
  FakeFirebaseFirestore firestore, {
  String authedUserId = _alice,
}) {
  final mockAuth = MockAuthRepository();
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
      await _seed(firestore,
          ownerId: _alice, category: _cat(id: 'c1', name: 'Friends'));

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

  group('fetchMemberCategories', () {
    test('returns categories where user is a friendUserIds member', () async {
      final firestore = FakeFirebaseFirestore();
      final repo = _repo(firestore);
      await _seed(firestore,
          ownerId: _alice,
          category: _cat(id: 'c1', name: 'A', members: [_bob]));
      await _seed(firestore,
          ownerId: _alice, category: _cat(id: 'c2', name: 'B', members: []));
      await _seed(firestore,
          ownerId: 'someone-else',
          category: _cat(id: 'c3', name: 'C', members: [_bob]));

      final results = await repo.fetchMemberCategories(_bob);
      expect(results.map((c) => c.id).toSet(), {'c1', 'c3'});
    });
  });

  group('transferOwnership', () {
    test('atomically flips ownerId when caller is current owner', () async {
      final firestore = FakeFirebaseFirestore();
      final repo = _repo(firestore);
      await _seed(firestore,
          ownerId: _alice,
          category: _cat(id: 'c1', name: 'Friends', owner: _alice));

      await repo.transferOwnership(_alice, 'c1', _bob);

      final doc = await firestore
          .collection('users')
          .doc(_alice)
          .collection('friend_categories')
          .doc('c1')
          .get();
      expect(doc.data()?['ownerId'], _bob);
    });

    test('rejects when caller is not the current owner', () async {
      final firestore = FakeFirebaseFirestore();
      final repo = _repo(firestore, authedUserId: _bob);

      await expectLater(
        () => repo.transferOwnership(_alice, 'c1', _bob),
        throwsA(isA<PermissionDeniedException>()),
      );
    });

    test('throws ResourceNotFoundException when category missing', () async {
      final repo = _repo(FakeFirebaseFirestore());

      await expectLater(
        () => repo.transferOwnership(_alice, 'ghost', _bob),
        throwsA(isA<ResourceNotFoundException>()),
      );
    });
  });

  group('getCategoriesContainingFriend', () {
    test('returns only categories the friend is a member of', () async {
      final firestore = FakeFirebaseFirestore();
      final repo = _repo(firestore);
      await _seed(firestore,
          ownerId: _alice,
          category: _cat(id: 'c1', name: 'A', members: ['carol']));
      await _seed(firestore,
          ownerId: _alice,
          category: _cat(id: 'c2', name: 'B', members: ['carol', 'dave']));
      await _seed(firestore,
          ownerId: _alice,
          category: _cat(id: 'c3', name: 'C', members: ['dave']));

      final results = await repo.getCategoriesContainingFriend(_alice, 'carol');
      expect(results.map((c) => c.id).toSet(), {'c1', 'c2'});
    });
  });

  group('streams', () {
    test('categoriesStream emits owned categories', () async {
      final firestore = FakeFirebaseFirestore();
      final repo = _repo(firestore);
      await _seed(firestore,
          ownerId: _alice, category: _cat(id: 'c1', name: 'Friends'));
      await _seed(firestore,
          ownerId: _alice, category: _cat(id: 'c2', name: 'Family'));

      final first = await repo.categoriesStream(_alice).first;
      expect(first.length, 2);
    });

    test('memberCategoriesStream emits categories user is a member of',
        () async {
      final firestore = FakeFirebaseFirestore();
      final repo = _repo(firestore);
      await _seed(firestore,
          ownerId: _alice,
          category: _cat(id: 'c1', name: 'A', members: [_bob]));
      await _seed(firestore,
          ownerId: _alice,
          category: _cat(id: 'c2', name: 'B', members: ['carol']));

      final first = await repo.memberCategoriesStream(_bob).first;
      expect(first.map((c) => c.id), ['c1']);
    });
  });

  group('getCategoryStatistics', () {
    test('aggregates total counts + averageSize + largest', () async {
      final firestore = FakeFirebaseFirestore();
      final repo = _repo(firestore);
      await _seed(firestore,
          ownerId: _alice,
          category: _cat(id: 'c1', name: 'Small', members: ['a']));
      await _seed(firestore,
          ownerId: _alice,
          category: _cat(id: 'c2', name: 'Big', members: ['a', 'b', 'c']));

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
      await _seed(firestore,
          ownerId: _alice, category: _cat(id: 'c1', name: 'Friends'));
      await _seed(firestore,
          ownerId: _alice, category: _cat(id: 'c2', name: 'Family'));

      final results = await repo.searchCategories(_alice, 'FRI');
      expect(results.map((c) => c.id), ['c1']);
    });

    test('matches description when present', () async {
      final firestore = FakeFirebaseFirestore();
      final repo = _repo(firestore);
      await _seed(firestore,
          ownerId: _alice,
          category: _cat(
              id: 'c1', name: 'Friends', description: 'Close acquaintances'));

      final results = await repo.searchCategories(_alice, 'close');
      expect(results.map((c) => c.id), ['c1']);
    });
  });

  group('getEmptyCategories / getLargestCategories / categoryNameExists', () {
    test('getEmptyCategories returns only zero-member categories', () async {
      final firestore = FakeFirebaseFirestore();
      final repo = _repo(firestore);
      await _seed(firestore,
          ownerId: _alice, category: _cat(id: 'c1', name: 'Empty'));
      await _seed(firestore,
          ownerId: _alice,
          category: _cat(id: 'c2', name: 'NonEmpty', members: ['x']));

      final empties = await repo.getEmptyCategories(_alice);
      expect(empties.map((c) => c.id), ['c1']);
    });

    test('getLargestCategories sorts desc and applies limit', () async {
      final firestore = FakeFirebaseFirestore();
      final repo = _repo(firestore);
      await _seed(firestore,
          ownerId: _alice,
          category: _cat(id: 'c1', name: 'Small', members: ['a']));
      await _seed(firestore,
          ownerId: _alice,
          category: _cat(id: 'c2', name: 'Medium', members: ['a', 'b']));
      await _seed(firestore,
          ownerId: _alice,
          category: _cat(id: 'c3', name: 'Big', members: ['a', 'b', 'c', 'd']));

      final top2 = await repo.getLargestCategories(_alice, limit: 2);
      expect(top2.map((c) => c.id), ['c3', 'c2']);
    });

    test('categoryNameExists case-insensitive + excludes given id', () async {
      final firestore = FakeFirebaseFirestore();
      final repo = _repo(firestore);
      await _seed(firestore,
          ownerId: _alice, category: _cat(id: 'c1', name: 'Friends'));

      expect(await repo.categoryNameExists(_alice, 'FRIENDS'), isTrue);
      expect(
          await repo.categoryNameExists(_alice, 'FRIENDS',
              excludeCategoryId: 'c1'),
          isFalse);
      expect(await repo.categoryNameExists(_alice, 'NewName'), isFalse);
    });
  });

  group('bulkUpdateCategories', () {
    test('batch-updates multiple categories', () async {
      final firestore = FakeFirebaseFirestore();
      final repo = _repo(firestore);
      await _seed(firestore,
          ownerId: _alice, category: _cat(id: 'c1', name: 'A'));
      await _seed(firestore,
          ownerId: _alice, category: _cat(id: 'c2', name: 'B'));

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
          'c1': {'name': 'x'}
        }),
        throwsA(isA<PermissionDeniedException>()),
      );
    });
  });
}
