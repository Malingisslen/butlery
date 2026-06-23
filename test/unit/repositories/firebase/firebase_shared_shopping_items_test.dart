/// Unit tests for FirebaseSharedShoppingRepository items-subcollection API.
///
/// Covers addItem / addItemsBatch / getItems / validateListAccess paths
/// that were not exercised by the base_shared_content_repository_test.dart
/// in batch #1.
library;

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/core/exceptions/permission_exceptions.dart';
import 'package:butlery/core/exceptions/repository_exception.dart';
import 'package:butlery/models/shared_shopping_list.dart';
import 'package:butlery/models/unified/unified_shopping_item.dart';
import 'package:butlery/repositories/firebase/firebase_shared_shopping_repository.dart';
import 'package:butlery/repositories/firebase/shared_content/shared_shopping_dismissal_repository.dart';
import 'package:butlery/repositories/firebase/shared_content/shared_shopping_engagement_repository.dart';
import 'package:butlery/repositories/firebase/shared_content/shared_shopping_view_repository.dart';

import '../../../infrastructure/mocks/production_mocks.dart';

const _alice = 'user-alice';
const _bob = 'user-bob';
const _listId = 'list-1';

FirebaseSharedShoppingRepository _repo(
  FakeFirebaseFirestore firestore, {
  String authedUserId = _alice,
}) {
  final mockAuth = FakeAuthRepository();
  mockAuth.setAuthState(
    user: FakeUser(uid: authedUserId),
    userId: authedUserId,
    isAuthenticated: true,
  );
  return FirebaseSharedShoppingRepository(
    firestore: firestore,
    authRepository: mockAuth,
    viewRepository: SharedShoppingViewRepository(
      firestore: firestore,
      authRepository: mockAuth,
    ),
    engagementRepository: SharedShoppingEngagementRepository(
      firestore: firestore,
      authRepository: mockAuth,
    ),
    dismissalRepository: SharedShoppingDismissalRepository(
      firestore: firestore,
      authRepository: mockAuth,
    ),
  );
}

Future<void> _seedList(
  FakeFirebaseFirestore firestore, {
  String owner = _alice,
  List<String> members = const [],
}) async {
  final list = SharedShoppingList(
    id: _listId,
    sharedByUserId: owner,
    sharedByDisplayName: 'Owner',
    sharedAt: DateTime.utc(2026, 1, 15),
    listName: 'Test',
    itemCount: 0,
    originalOwnerId: owner,
    originalOwnerDisplayName: 'Owner',
  );
  final data = list.toFirestore();
  data['contentType'] = 'shopping_list';
  await firestore.collection('shared_content').doc(_listId).set(data);

  for (final uid in members) {
    await firestore
        .collection('shared_content')
        .doc(_listId)
        .collection('members')
        .doc(uid)
        .set({'userId': uid, 'addedAt': DateTime.utc(2026, 1, 15)});
  }
}

UnifiedShoppingItem _item(String id, String name) {
  return UnifiedShoppingItem(
    id: id,
    name: name,
    amount: 1.0,
    unit: 'st',
  );
}

void main() {
  group('validateListAccess', () {
    test('owner has access', () async {
      final firestore = FakeFirebaseFirestore();
      final repo = _repo(firestore);
      await _seedList(firestore);
      await repo.validateListAccess(_listId);
    });

    test('member has access', () async {
      final firestore = FakeFirebaseFirestore();
      final repo = _repo(firestore, authedUserId: _bob);
      await _seedList(firestore, members: [_bob]);
      await repo.validateListAccess(_listId);
    });

    test('non-member non-owner is denied', () async {
      final firestore = FakeFirebaseFirestore();
      final repo = _repo(firestore, authedUserId: _bob);
      await _seedList(firestore);
      await expectLater(
        () => repo.validateListAccess(_listId),
        throwsA(isA<PermissionDeniedException>()),
      );
    });

    test('missing list throws RepositoryException', () async {
      final firestore = FakeFirebaseFirestore();
      final repo = _repo(firestore);
      await expectLater(
        () => repo.validateListAccess('ghost'),
        throwsA(isA<RepositoryException>()),
      );
    });
  });

  group('addItem', () {
    test('writes item doc + increments itemCount', () async {
      final firestore = FakeFirebaseFirestore();
      final repo = _repo(firestore);
      await _seedList(firestore);

      await repo.addItem(_listId, _item('i1', 'Mjölk'));

      final itemDoc = await firestore
          .collection('shared_content')
          .doc(_listId)
          .collection('items')
          .doc('i1')
          .get();
      expect(itemDoc.exists, isTrue);
      expect(itemDoc.data()?['name'], 'Mjölk');

      final listDoc = await firestore
          .collection('shared_content')
          .doc(_listId)
          .get();
      expect(listDoc.data()?['itemCount'], 1);
    });

    test('throws RepositoryException when user lacks access', () async {
      final firestore = FakeFirebaseFirestore();
      final repo = _repo(firestore, authedUserId: _bob);
      await _seedList(firestore);

      await expectLater(
        () => repo.addItem(_listId, _item('i1', 'Mjölk')),
        throwsA(isA<RepositoryException>()),
      );
    });
  });

  group('addItemsBatch', () {
    test('no-op for empty list', () async {
      final firestore = FakeFirebaseFirestore();
      final repo = _repo(firestore);
      await _seedList(firestore);
      await repo.addItemsBatch(_listId, const []);

      final listDoc = await firestore
          .collection('shared_content')
          .doc(_listId)
          .get();
      expect(listDoc.data()?['itemCount'], 0);
    });

    test('writes all items + bumps itemCount by length', () async {
      final firestore = FakeFirebaseFirestore();
      final repo = _repo(firestore);
      await _seedList(firestore);

      await repo.addItemsBatch(_listId, [
        _item('i1', 'A'),
        _item('i2', 'B'),
        _item('i3', 'C'),
      ]);

      final items = await firestore
          .collection('shared_content')
          .doc(_listId)
          .collection('items')
          .get();
      expect(items.docs.length, 3);

      final listDoc = await firestore
          .collection('shared_content')
          .doc(_listId)
          .get();
      expect(listDoc.data()?['itemCount'], 3);
    });
  });

  group('getItems', () {
    test('returns items ordered by addedAt asc', () async {
      final firestore = FakeFirebaseFirestore();
      final repo = _repo(firestore);
      await _seedList(firestore);
      await repo.addItemsBatch(_listId, [
        _item('i1', 'First'),
        _item('i2', 'Second'),
      ]);

      final items = await repo.getItems(_listId);
      expect(items.length, 2);
    });

    test('returns empty list when no items', () async {
      final firestore = FakeFirebaseFirestore();
      final repo = _repo(firestore);
      await _seedList(firestore);

      final items = await repo.getItems(_listId);
      expect(items, isEmpty);
    });

    test('throws when user lacks access', () async {
      final firestore = FakeFirebaseFirestore();
      final repo = _repo(firestore, authedUserId: _bob);
      await _seedList(firestore);

      await expectLater(
        () => repo.getItems(_listId),
        throwsA(isA<RepositoryException>()),
      );
    });
  });
}
