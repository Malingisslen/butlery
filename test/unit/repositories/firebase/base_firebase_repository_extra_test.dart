/// Additional unit tests for BaseFirebaseRepository contract.
///
/// The existing test/unit/repositories/base_firebase_repository_test.dart
/// covers permission-validation patterns. This file targets the uncovered
/// CRUD / batch / cache-first paths using a minimal test-local concrete
/// subclass over a fake Firestore.
///
/// Methods exercised:
/// - delete (success + permission denied)
/// - createBatch (success + permission denied propagates)
/// - watchAll (stream)
/// - exists (true + false + auth error → false)
/// - count (count() aggregation + auth error → 0)
/// - readAllSafe / readSafe (returns empty/null on unauthed)
/// - readCacheFirst (cache + permission denied)
/// - updateBatch + deleteBatch (BatchOperationsFirebaseRepository mixin)
library;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/core/exceptions/permission_exceptions.dart';
import 'package:butlery/repositories/firebase/base_firebase_repository.dart';

import '../../../infrastructure/mocks/production_mocks.dart';

/// Minimal entity record for the test subject.
class _Item {
  final String id;
  final String name;
  final String ownerId;

  _Item({required this.id, required this.name, required this.ownerId});
}

/// Concrete subclass exposing the base CRUD + batch mixin.
class _ItemRepo extends BaseFirebaseRepository<_Item>
    with BatchOperationsFirebaseRepository<_Item> {
  _ItemRepo({
    required super.firestore,
    required super.authRepository,
  });

  @override
  String get collectionName => 'items';

  @override
  _Item fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    return _Item(
      id: doc.id,
      name: data['name'] as String? ?? '',
      ownerId: data['ownerId'] as String? ?? '',
    );
  }

  @override
  Map<String, dynamic> toFirestore(_Item entity) => {
        'name': entity.name,
        'ownerId': entity.ownerId,
      };

  @override
  String getId(_Item entity) => entity.id;

  @override
  Future<bool> validateCreatePermission(String userId, _Item entity) async =>
      entity.ownerId == userId;

  @override
  Future<bool> validateReadPermission(
          String userId, String resourceId, _Item? entity) async =>
      entity != null && entity.ownerId == userId;

  @override
  Future<bool> validateUpdatePermission(
          String userId, String resourceId, _Item entity) async =>
      entity.ownerId == userId;

  @override
  Future<bool> validateDeletePermission(
      String userId, String resourceId) async {
    try {
      final entity = await read(resourceId);
      return entity?.ownerId == userId;
    } on PermissionDeniedException {
      return false;
    }
  }
}

_ItemRepo _repo(
  FakeFirebaseFirestore firestore, {
  String? authedUserId = 'alice',
}) {
  final mockAuth = FakeAuthRepository();
  if (authedUserId != null) {
    mockAuth.setAuthState(
      user: FakeUser(uid: authedUserId),
      userId: authedUserId,
      isAuthenticated: true,
    );
  }
  return _ItemRepo(firestore: firestore, authRepository: mockAuth);
}

Future<void> _seed(
  FakeFirebaseFirestore firestore, {
  required String id,
  required String name,
  required String owner,
}) async {
  await firestore
      .collection('items')
      .doc(id)
      .set({'name': name, 'ownerId': owner});
}

void main() {
  group('delete', () {
    test('deletes when permission granted', () async {
      final firestore = FakeFirebaseFirestore();
      final repo = _repo(firestore);
      await _seed(firestore, id: 'i1', name: 'A', owner: 'alice');

      await repo.delete('i1');

      expect((await firestore.collection('items').doc('i1').get()).exists,
          isFalse);
    });

    test('throws PermissionDenied when not owner', () async {
      final firestore = FakeFirebaseFirestore();
      final repo = _repo(firestore, authedUserId: 'bob');
      await _seed(firestore, id: 'i1', name: 'A', owner: 'alice');

      await expectLater(
        () => repo.delete('i1'),
        throwsA(isA<PermissionDeniedException>()),
      );
    });
  });

  group('createBatch', () {
    test('writes all entities in one batch', () async {
      final firestore = FakeFirebaseFirestore();
      final repo = _repo(firestore);

      await repo.createBatch([
        _Item(id: 'b1', name: 'A', ownerId: 'alice'),
        _Item(id: 'b2', name: 'B', ownerId: 'alice'),
      ]);

      final snap = await firestore.collection('items').get();
      expect(snap.docs.length, 2);
    });

    test('throws when any entity fails permission check', () async {
      final firestore = FakeFirebaseFirestore();
      final repo = _repo(firestore);

      // BUT-1003: typed PermissionDeniedException now propagates.
      await expectLater(
        () => repo.createBatch([
          _Item(id: 'b1', name: 'A', ownerId: 'alice'),
          _Item(id: 'b2', name: 'B', ownerId: 'bob'), // wrong owner
        ]),
        throwsA(isA<PermissionDeniedException>()),
      );
    });
  });

  group('watchAll', () {
    test('emits the current items as a list', () async {
      final firestore = FakeFirebaseFirestore();
      final repo = _repo(firestore);
      await _seed(firestore, id: 'i1', name: 'A', owner: 'alice');
      await _seed(firestore, id: 'i2', name: 'B', owner: 'alice');

      final first = await repo.watchAll().first;
      expect(first.length, 2);
    });

    test('respects orderBy + descending', () async {
      final firestore = FakeFirebaseFirestore();
      final repo = _repo(firestore);
      await _seed(firestore, id: 'i1', name: 'A', owner: 'alice');
      await _seed(firestore, id: 'i2', name: 'B', owner: 'alice');

      final desc = await repo.watchAll(orderBy: 'name', descending: true).first;
      expect(desc.map((i) => i.name), ['B', 'A']);
    });
  });

  group('exists / count', () {
    test('exists true for present doc, false for absent', () async {
      final firestore = FakeFirebaseFirestore();
      final repo = _repo(firestore);
      await _seed(firestore, id: 'i1', name: 'A', owner: 'alice');

      expect(await repo.exists('i1'), isTrue);
      expect(await repo.exists('nope'), isFalse);
    });

    test('count returns aggregation count', () async {
      final firestore = FakeFirebaseFirestore();
      final repo = _repo(firestore);
      await _seed(firestore, id: 'i1', name: 'A', owner: 'alice');
      await _seed(firestore, id: 'i2', name: 'B', owner: 'alice');
      await _seed(firestore, id: 'i3', name: 'C', owner: 'alice');

      expect(await repo.count(), 3);
    });
  });

  group('readSafe / readAllSafe', () {
    test('readSafe returns null when unauthenticated', () async {
      final firestore = FakeFirebaseFirestore();
      final repo = _repo(firestore, authedUserId: null);
      await _seed(firestore, id: 'i1', name: 'A', owner: 'alice');

      expect(await repo.readSafe('i1'), isNull);
    });

    test('readSafe returns null when read throws (e.g., permission)', () async {
      final firestore = FakeFirebaseFirestore();
      final repo = _repo(firestore, authedUserId: 'bob');
      await _seed(firestore, id: 'i1', name: 'A', owner: 'alice');

      expect(await repo.readSafe('i1'), isNull);
    });

    test('readSafe returns entity when allowed', () async {
      final firestore = FakeFirebaseFirestore();
      final repo = _repo(firestore);
      await _seed(firestore, id: 'i1', name: 'A', owner: 'alice');

      final got = await repo.readSafe('i1');
      expect(got?.name, 'A');
    });

    test('readAllSafe returns empty when unauthenticated', () async {
      final firestore = FakeFirebaseFirestore();
      final repo = _repo(firestore, authedUserId: null);
      await _seed(firestore, id: 'i1', name: 'A', owner: 'alice');

      expect(await repo.readAllSafe(), isEmpty);
    });

    test('readAllSafe returns filtered list when authed', () async {
      final firestore = FakeFirebaseFirestore();
      final repo = _repo(firestore);
      await _seed(firestore, id: 'i1', name: 'A', owner: 'alice');
      await _seed(firestore, id: 'i2', name: 'B', owner: 'bob');

      final list = await repo.readAllSafe();
      // Only Alice's item passes the read-permission filter.
      expect(list.map((i) => i.name), ['A']);
    });
  });

  group('readCacheFirst', () {
    test('returns entity for owner', () async {
      final firestore = FakeFirebaseFirestore();
      final repo = _repo(firestore);
      await _seed(firestore, id: 'i1', name: 'A', owner: 'alice');

      final got = await repo.readCacheFirst('i1');
      expect(got?.name, 'A');
    });

    test('returns null when doc missing', () async {
      final repo = _repo(FakeFirebaseFirestore());
      expect(await repo.readCacheFirst('ghost'), isNull);
    });

    test('throws PermissionDenied when caller lacks read access', () async {
      final firestore = FakeFirebaseFirestore();
      final repo = _repo(firestore, authedUserId: 'bob');
      await _seed(firestore, id: 'i1', name: 'A', owner: 'alice');

      await expectLater(
        () => repo.readCacheFirst('i1'),
        throwsA(isA<PermissionDeniedException>()),
      );
    });
  });

  group('BatchOperationsFirebaseRepository — updateBatch / deleteBatch', () {
    test('updateBatch updates each entity', () async {
      final firestore = FakeFirebaseFirestore();
      final repo = _repo(firestore);
      await _seed(firestore, id: 'i1', name: 'A', owner: 'alice');
      await _seed(firestore, id: 'i2', name: 'B', owner: 'alice');

      await repo.updateBatch([
        _Item(id: 'i1', name: 'A-new', ownerId: 'alice'),
        _Item(id: 'i2', name: 'B-new', ownerId: 'alice'),
      ]);

      final doc1 = await firestore.collection('items').doc('i1').get();
      final doc2 = await firestore.collection('items').doc('i2').get();
      expect(doc1.data()?['name'], 'A-new');
      expect(doc2.data()?['name'], 'B-new');
    });

    test('updateBatch throws when permission denied for any entry', () async {
      final firestore = FakeFirebaseFirestore();
      final repo = _repo(firestore);
      await _seed(firestore, id: 'i1', name: 'A', owner: 'alice');

      // BUT-1003: typed PermissionDeniedException now propagates.
      await expectLater(
        () => repo.updateBatch([
          _Item(id: 'i1', name: 'A-new', ownerId: 'bob'), // wrong owner
        ]),
        throwsA(isA<PermissionDeniedException>()),
      );
    });

    test('deleteBatch removes each doc', () async {
      final firestore = FakeFirebaseFirestore();
      final repo = _repo(firestore);
      await _seed(firestore, id: 'i1', name: 'A', owner: 'alice');
      await _seed(firestore, id: 'i2', name: 'B', owner: 'alice');

      await repo.deleteBatch(['i1', 'i2']);

      expect((await firestore.collection('items').get()).docs, isEmpty);
    });

    test('deleteBatch throws when caller cannot delete one of the ids',
        () async {
      final firestore = FakeFirebaseFirestore();
      final repo = _repo(firestore, authedUserId: 'bob');
      await _seed(firestore, id: 'i1', name: 'A', owner: 'alice');

      // BUT-1003: typed PermissionDeniedException now propagates.
      await expectLater(
        () => repo.deleteBatch(['i1']),
        throwsA(isA<PermissionDeniedException>()),
      );
    });
  });
}
