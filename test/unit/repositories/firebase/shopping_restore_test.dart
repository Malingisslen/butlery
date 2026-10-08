/// BUT-2140 PR 3: the row writes keep the 30-day restore history in the same
/// write as the change, and the two restore operations put a row back.
///
/// Driven through the production seam: [ShoppingItemOperationsModule] over the
/// real [ShoppingRepositoryRoutingModule] on `FakeFirebaseFirestore`. The fake
/// has no transaction isolation and ignores `GetOptions.source`, so nothing
/// here proves atomicity or a real cache read; a stale cache is staged through
/// the injected `fromFirestore` instead.
library;

import 'package:clock/clock.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/core/constants/firestore_collections.dart';
import 'package:butlery/core/exceptions/permission_exceptions.dart';
import 'package:butlery/models/unified/shopping_row_snapshot.dart';
import 'package:butlery/models/unified/unified_shopping_item.dart';
import 'package:butlery/models/unified/unified_shopping_list.dart';
import 'package:butlery/repositories/firebase/modules/shopping_item_operations_module.dart';
import 'package:butlery/repositories/firebase/modules/shopping_repository_routing_module.dart';

import '../../../infrastructure/mocks/production_mocks.dart';

const _alice = 'alice';
const _bob = 'bob';
const _viewer = 'vera';
const _listId = 'list-1';
const _sharedPath = 'unified_shared_shopping_lists';

final _now = DateTime.utc(2026, 10, 8, 12);

/// Records every write a transaction or batch stages, so a test can count
/// operations instead of inferring them from the stored result.
class _CountingTransaction implements Transaction {
  _CountingTransaction(this._inner, this._writes);
  final Transaction _inner;
  final List<String> _writes;

  @override
  Future<DocumentSnapshot<T>> get<T extends Object?>(
    DocumentReference<T> documentReference,
  ) => _inner.get(documentReference);

  @override
  Transaction delete(DocumentReference documentReference) {
    _writes.add('delete');
    _inner.delete(documentReference);
    return this;
  }

  @override
  Transaction update(
    DocumentReference documentReference,
    Map<Object, Object?> data,
  ) {
    _writes.add('update ${data.keys.join(',')}');
    _inner.update(documentReference, data);
    return this;
  }

  @override
  Transaction set<T>(
    DocumentReference<T> documentReference,
    T data, [
    SetOptions? options,
  ]) {
    _writes.add('set ${(data as Map).keys.join(',')}');
    _inner.set(documentReference, data, options);
    return this;
  }
}

class _CountingBatch implements WriteBatch {
  _CountingBatch(this._inner, this._writes);
  final WriteBatch _inner;
  final List<String> _writes;

  @override
  Future<void> commit() => _inner.commit();

  @override
  void delete(DocumentReference document) {
    _writes.add('delete ${document.path}');
    _inner.delete(document);
  }

  @override
  void set<T>(DocumentReference<T> document, T data, [SetOptions? options]) {
    _writes.add('set ${document.path}');
    _inner.set(document, data, options);
  }

  @override
  void update(DocumentReference document, Map<Object, Object?> data) {
    _writes.add('update ${document.path} ${data.keys.join(',')}');
    _inner.update(document, data);
  }
}

class _CountingFirestore extends FakeFirebaseFirestore {
  final List<String> batchWrites = [];

  @override
  WriteBatch batch() => _CountingBatch(super.batch(), batchWrites);
}

class _Harness {
  _Harness({this.uid = _alice, this.offline = false, this.hideFromCache});

  final String uid;

  /// Fails the transaction the way a device without reception does, so the
  /// write goes through the cached-base path.
  final bool offline;

  /// Removes these history ids from what the "cache" returns, which is how a
  /// test stages another device's entry the offline mutator never saw.
  final Set<String>? hideFromCache;

  final _CountingFirestore firestore = _CountingFirestore();
  final List<String> transactionWrites = [];

  late final ShoppingRepositoryRoutingModule routing =
      ShoppingRepositoryRoutingModule(
        firestore: firestore,
        authRepository: FakeAuthRepository(),
        sharedListsRef: firestore.collection(_sharedPath),
        requireCurrentUserId: () => uid,
        validateRequiredFields:
            ({
              required Map<String, dynamic> data,
              required List<String> requiredFields,
              required String resourceType,
            }) {},
        logPermissionCheck: _log,
        fromFirestore: _fromFirestore,
        validateUpdatePermission: (userId, resourceId, entity) async =>
            entity.ownerId == userId ||
            entity.memberPermissions.containsKey(userId),
        transactionRunner: (handler) {
          if (offline) {
            throw FirebaseException(
              plugin: 'cloud_firestore',
              code: 'unavailable',
            );
          }
          return firestore.runTransaction(
            (tx) => handler(_CountingTransaction(tx, transactionWrites)),
          );
        },
      );

  late final ShoppingItemOperationsModule module = ShoppingItemOperationsModule(
    firestore: firestore,
    authRepository: FakeAuthRepository(),
    requireCurrentUserId: () => uid,
    readList: _readList,
    mutateCollaborativeList: routing.mutateCollaborativeList,
    getUserCollection: _personalLists,
    validateOwnership:
        ({
          required String currentUserId,
          required String resourceOwnerId,
          required String resourceType,
          required String resourceId,
        }) async {
          if (currentUserId != resourceOwnerId) {
            throw PermissionDeniedException('not the owner');
          }
        },
    validateRequiredFields:
        ({
          required Map<String, dynamic> data,
          required List<String> requiredFields,
          required String resourceType,
        }) {},
    logPermissionCheck: _log,
    resolveDisplayName: () => uid == _bob ? 'Bob' : 'Alice',
  );

  UnifiedShoppingList _fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final list = UnifiedShoppingList.fromFirestore(doc);
    final hidden = hideFromCache;
    if (hidden == null) return list;
    return list.copyWith(
      recentlyRemoved: [
        for (final s in list.recentlyRemoved)
          if (!hidden.contains(s.id)) s,
      ],
      updatedAt: list.updatedAt,
    );
  }

  Future<void> _log({
    required String userId,
    required String resource,
    required String operation,
    required bool granted,
    String? details,
  }) async {}

  CollectionReference<Map<String, dynamic>> _personalLists(String userId) =>
      firestore
          .collection(FirestoreCollections.users)
          .doc(userId)
          .collection(FirestoreCollections.unifiedShoppingLists);

  DocumentReference<Map<String, dynamic>> get personalRef =>
      _personalLists(_alice).doc(_listId);

  Future<UnifiedShoppingList?> _readList(String id) async {
    final shared = await firestore.collection(_sharedPath).doc(id).get();
    if (shared.exists) return UnifiedShoppingList.fromFirestore(shared);
    final personal = await _personalLists(_alice).doc(id).get();
    return personal.exists ? UnifiedShoppingList.fromFirestore(personal) : null;
  }

  Future<void> seedShared(UnifiedShoppingList list) =>
      firestore.collection(_sharedPath).doc(list.id).set(list.toFirestore());

  Future<void> seedPersonal(UnifiedShoppingList list) async {
    await personalRef.set(list.toFirestore());
    for (final item in list.items) {
      await personalRef
          .collection(FirestoreCollections.items)
          .doc(item.id)
          .set(item.toFirestore());
    }
  }

  Future<UnifiedShoppingList> storedShared() async =>
      UnifiedShoppingList.fromFirestore(
        await firestore.collection(_sharedPath).doc(_listId).get(),
      );

  Future<Map<String, dynamic>> storedSharedRaw() async =>
      (await firestore.collection(_sharedPath).doc(_listId).get()).data()!;

  Future<List<ShoppingRowSnapshot>> storedPersonalHistory() async =>
      UnifiedShoppingList.fromFirestore(
        await personalRef.get(),
      ).recentlyRemoved;

  Future<UnifiedShoppingItem?> storedPersonalRow(String id) async {
    final data =
        (await personalRef.collection(FirestoreCollections.items).doc(id).get())
            .data();
    return data == null ? null : UnifiedShoppingItem.fromFirestore(data);
  }
}

UnifiedShoppingItem _row(
  String id, {
  String? name,
  double amount = 1,
  bool bought = false,
  ShoppingRowSnapshot? previous,
}) => UnifiedShoppingItem(
  id: id,
  name: name ?? id,
  amount: amount,
  unit: 'st',
  bought: bought,
  previous: previous,
);

ShoppingRowSnapshot _entry(String id, {required DateTime at, String? name}) =>
    ShoppingRowSnapshot(
      id: id,
      name: name ?? id,
      amount: 1,
      unit: 'st',
      category: ShoppingCategory.other,
      at: at,
    );

UnifiedShoppingList _shared({
  List<UnifiedShoppingItem> items = const [],
  List<ShoppingRowSnapshot> recentlyRemoved = const [],
}) => UnifiedShoppingList(
  id: _listId,
  name: 'Hushållet',
  ownerId: _alice,
  ownerDisplayName: 'Alice',
  type: ListType.collaborative,
  memberPermissions: const {
    _alice: SharedListPermission.admin,
    _bob: SharedListPermission.edit,
    _viewer: SharedListPermission.view,
  },
  items: items,
  recentlyRemoved: recentlyRemoved,
);

UnifiedShoppingList _personal({
  List<UnifiedShoppingItem> items = const [],
  List<ShoppingRowSnapshot> recentlyRemoved = const [],
}) => UnifiedShoppingList(
  id: _listId,
  name: 'Min lista',
  ownerId: _alice,
  ownerDisplayName: 'Alice',
  items: items,
  recentlyRemoved: recentlyRemoved,
);

/// Lets the unawaited offline `update` land on the fake.
Future<void> _settle() => Future<void>.delayed(Duration.zero);

/// [n] restorable entries, the oldest first, an hour apart.
List<ShoppingRowSnapshot> _history(int n) => [
  for (var i = 0; i < n; i++)
    _entry('h$i', at: _now.subtract(Duration(hours: n - i))),
];

void main() {
  group('shared list, online', () {
    test(
      'a removal is ONE write carrying both items and recentlyRemoved',
      () async {
        final h = _Harness(uid: _bob);
        await h.seedShared(_shared(items: [_row('mjölk'), _row('bröd')]));

        await withClock(
          Clock.fixed(_now),
          () => h.module.removeItem(_listId, 'mjölk'),
        );

        expect(h.transactionWrites, hasLength(1));
        expect(h.transactionWrites.single, contains('items'));
        expect(h.transactionWrites.single, contains('recentlyRemoved'));
        final stored = await h.storedShared();
        expect(stored.items.map((i) => i.id), ['bröd']);
        expect(stored.recentlyRemoved.single.id, 'mjölk');
        expect(stored.recentlyRemoved.single.at.isAtSameMomentAs(_now), isTrue);
      },
    );

    test(
      'removing bought rows ("Rensa klart") records nothing and prunes',
      () async {
        final h = _Harness();
        final expired = _entry(
          'gammal',
          at: _now.subtract(const Duration(days: 31)),
        );
        await h.seedShared(
          _shared(
            items: [_row('mjölk', bought: true), _row('bröd')],
            recentlyRemoved: [expired],
          ),
        );

        await withClock(
          Clock.fixed(_now),
          () => h.module.removeItemsBatch(_listId, ['mjölk']),
        );

        final stored = await h.storedShared();
        expect(stored.items.map((i) => i.id), ['bröd']);
        expect(stored.recentlyRemoved, isEmpty);
      },
    );

    test('a content edit keeps the LIVE row as previous', () async {
      final h = _Harness(uid: _bob);
      await h.seedShared(_shared(items: [_row('ägg', amount: 12)]));

      // The caller's copy is stale: it never saw the 12.
      await withClock(
        Clock.fixed(_now),
        () => h.module.updateItem(_listId, _row('ägg', amount: 6)),
      );

      final row = (await h.storedShared()).items.single;
      expect(row.amount, 6);
      expect(row.previous?.amount, 12);
    });

    test(
      'a tick from a copy without previous leaves the stored previous',
      () async {
        final h = _Harness();
        final earlier = _entry(
          'ägg',
          name: 'ägg (ekologiska)',
          at: _now.subtract(const Duration(days: 1)),
        );
        await h.seedShared(_shared(items: [_row('ägg', previous: earlier)]));

        await withClock(
          Clock.fixed(_now),
          () => h.module.updateItemsBatch(_listId, [
            _row('ägg', bought: true),
          ]),
        );

        final row = (await h.storedShared()).items.single;
        expect(row.bought, isTrue);
        expect(row.previous, earlier);
      },
    );

    test(
      'a check-off via mutateCollaborativeList leaves recentlyRemoved intact',
      () async {
        final h = _Harness();
        final kept = _entry(
          'mjölk',
          at: _now.subtract(const Duration(days: 2)),
        );
        await h.seedShared(
          _shared(items: [_row('bröd')], recentlyRemoved: [kept]),
        );

        await withClock(
          Clock.fixed(_now),
          () => h.routing.mutateCollaborativeList(
            _listId,
            (live) => live.toggleItemBought('bröd', userId: _alice),
          ),
        );

        final stored = await h.storedShared();
        expect(stored.items.single.bought, isTrue);
        expect(stored.recentlyRemoved, [kept]);
      },
    );

    test('a rename from an old copy does not touch recentlyRemoved', () async {
      final h = _Harness();
      final stale = _shared(items: [_row('bröd')]);
      final kept = _entry('mjölk', at: _now.subtract(const Duration(days: 2)));
      await h.seedShared(stale.copyWith(recentlyRemoved: [kept]));

      await h.routing.updateCollaborativeList(stale.copyWith(name: 'Nytt'));

      final stored = await h.storedShared();
      expect(stored.name, 'Nytt');
      expect(stored.recentlyRemoved, [kept]);
    });
  });

  group('shared list, offline', () {
    test(
      'a removal is not refused by the BUT-1706 guard and queues arrayUnion',
      () async {
        // The other device's entry is on the server but not in this device's
        // cache. An overwrite with the cached array would drop it; a union
        // keeps it.
        final otherDevice = _entry(
          'kaffe',
          at: _now.subtract(const Duration(hours: 1)),
        );
        final h = _Harness(uid: _bob, offline: true, hideFromCache: {'kaffe'});
        await h.seedShared(
          _shared(
            items: [_row('mjölk'), _row('bröd')],
            recentlyRemoved: [otherDevice],
          ),
        );

        await withClock(
          Clock.fixed(_now),
          () => h.module.removeItem(_listId, 'mjölk'),
        );
        await _settle();

        final stored = await h.storedShared();
        expect(stored.items.map((i) => i.id), ['bröd']);
        expect(
          stored.recentlyRemoved.map((s) => s.id).toSet(),
          {'kaffe', 'mjölk'},
        );
      },
    );

    test('an expired entry is not pruned offline', () async {
      final expired = _entry(
        'gammal',
        at: _now.subtract(const Duration(days: 31)),
      );
      final h = _Harness(offline: true);
      await h.seedShared(
        _shared(items: [_row('mjölk')], recentlyRemoved: [expired]),
      );

      await withClock(
        Clock.fixed(_now),
        () => h.module.removeItem(_listId, 'mjölk'),
      );
      await _settle();

      final ids = (await h.storedSharedRaw())['recentlyRemoved'] as List;
      expect(ids.map((e) => (e as Map)['id']).toSet(), {'gammal', 'mjölk'});
    });

    test(
      'a restore offline puts the row back and takes the entry out',
      () async {
        final entry = _entry(
          'mjölk',
          at: _now.subtract(const Duration(hours: 2)),
        );
        final h = _Harness(uid: _bob, offline: true);
        await h.seedShared(
          _shared(items: [_row('bröd')], recentlyRemoved: [entry]),
        );

        final row = await withClock(
          Clock.fixed(_now),
          () => h.module.restore.restoreRemovedRow(_listId, entry),
        );
        await _settle();

        expect(row?.id, 'mjölk');
        final stored = await h.storedShared();
        expect(stored.items.map((i) => i.id), ['bröd', 'mjölk']);
        expect(stored.recentlyRemoved, isEmpty);
      },
    );

    test(
      'a restore offline of an entry the cache lacks queues nothing',
      () async {
        final entry = _entry(
          'mjölk',
          at: _now.subtract(const Duration(hours: 2)),
        );
        final h = _Harness(uid: _bob, offline: true);
        await h.seedShared(_shared(items: [_row('bröd')]));
        final before = await h.storedSharedRaw();

        final row = await withClock(
          Clock.fixed(_now),
          () => h.module.restore.restoreRemovedRow(_listId, entry),
        );
        await _settle();

        expect(row, isNull);
        expect(await h.storedSharedRaw(), before);
      },
    );
  });

  group('the cap of 30', () {
    test('offline removals never grow the cached array past 30', () async {
      final h = _Harness(uid: _bob, offline: true);
      final rows = [for (var i = 0; i < 5; i++) _row('r$i')];
      await h.seedShared(_shared(items: rows, recentlyRemoved: _history(28)));

      for (final row in rows) {
        await withClock(
          Clock.fixed(_now),
          () => h.module.removeItem(_listId, row.id),
        );
        await _settle();
        final stored = (await h.storedSharedRaw())['recentlyRemoved'] as List;
        expect(stored.length, lessThanOrEqualTo(30));
      }

      expect((await h.storedShared()).items, isEmpty);
      final ids = (await h.storedShared()).recentlyRemoved.map((s) => s.id);
      expect(ids, containsAll(['r0', 'r1']));
      expect(ids, isNot(contains('r2')));
    });

    test('an offline batch keeps only the newest that fit', () async {
      final h = _Harness(uid: _bob, offline: true);
      final rows = [for (var i = 0; i < 5; i++) _row('r$i')];
      await h.seedShared(_shared(items: rows, recentlyRemoved: _history(28)));

      await withClock(
        Clock.fixed(_now),
        () => h.module.removeItemsBatch(
          _listId,
          rows.map((r) => r.id).toList(),
        ),
      );
      await _settle();

      expect((await h.storedSharedRaw())['recentlyRemoved'], hasLength(30));
    });

    test('an online tick caps a stored array of 40 to the newest 30', () async {
      final h = _Harness();
      await h.seedShared(
        _shared(items: [_row('mjölk')], recentlyRemoved: _history(40)),
      );

      await withClock(
        Clock.fixed(_now),
        () => h.module.updateItem(
          _listId,
          _row('mjölk', bought: true),
          before: _row('mjölk'),
        ),
      );

      final kept = (await h.storedShared()).recentlyRemoved;
      expect(kept, hasLength(30));
      expect(kept.map((s) => s.id), isNot(contains('h9')));
      expect(kept.map((s) => s.id), contains('h10'));
    });
  });

  group('restore on a shared list', () {
    test(
      're-adds the row with its old id, stamps the restorer, drops the entry',
      () async {
        final entry = _entry(
          'mjölk',
          at: _now.subtract(const Duration(days: 3)),
        );
        final h = _Harness(uid: _bob);
        await h.seedShared(
          _shared(items: [_row('bröd')], recentlyRemoved: [entry]),
        );

        await withClock(
          Clock.fixed(_now),
          () => h.module.restore.restoreRemovedRow(_listId, entry),
        );

        expect(h.transactionWrites, hasLength(1));
        final raw = await h.storedSharedRaw();
        final stored = await h.storedShared();
        final restored = stored.items.firstWhere((i) => i.id == 'mjölk');
        expect(restored.addedByUserId, _bob);
        expect(restored.addedByDisplayName, 'Bob');
        expect(stored.recentlyRemoved, isEmpty);
        expect(raw['contributorUserIds'], contains(_bob));
      },
    );

    test('an id already on the list is not duplicated', () async {
      final entry = _entry('mjölk', at: _now.subtract(const Duration(days: 3)));
      final h = _Harness();
      await h.seedShared(
        _shared(
          items: [_row('mjölk', name: 'mjölk 3%')],
          recentlyRemoved: [entry],
        ),
      );

      final row = await withClock(
        Clock.fixed(_now),
        () => h.module.restore.restoreRemovedRow(_listId, entry),
      );

      expect(row, isNull);
      final stored = await h.storedShared();
      expect(stored.items.single.name, 'mjölk 3%');
      expect(stored.recentlyRemoved, isEmpty);
    });

    test('a changed row swaps with its previous, and back again', () async {
      final earlier = _entry(
        'ägg',
        name: 'ägg',
        at: _now.subtract(const Duration(days: 1)),
      );
      final h = _Harness();
      await h.seedShared(
        _shared(
          items: [_row('ägg', name: 'ägg', amount: 6, previous: earlier)],
        ),
      );
      // The seed's previous has amount 1; the row now says 6.

      await withClock(
        Clock.fixed(_now),
        () => h.module.restore.restoreChangedRow(_listId, 'ägg'),
      );
      var row = (await h.storedShared()).items.single;
      expect(row.amount, 1);
      expect(row.previous?.amount, 6);

      await withClock(
        Clock.fixed(_now.add(const Duration(minutes: 1))),
        () => h.module.restore.restoreChangedRow(_listId, 'ägg'),
      );
      row = (await h.storedShared()).items.single;
      expect(row.amount, 6);
      expect(row.previous?.amount, 1);
    });

    test('a view-only member is refused and nothing changes', () async {
      final entry = _entry('mjölk', at: _now.subtract(const Duration(days: 3)));
      final h = _Harness(uid: _viewer);
      await h.seedShared(
        _shared(items: [_row('bröd')], recentlyRemoved: [entry]),
      );

      await expectLater(
        withClock(
          Clock.fixed(_now),
          () => h.module.restore.restoreRemovedRow(_listId, entry),
        ),
        throwsA(isA<PermissionDeniedException>()),
      );

      final stored = await h.storedShared();
      expect(stored.items.map((i) => i.id), ['bröd']);
      expect(stored.recentlyRemoved, [entry]);
    });

    test('an entry older than 30 days is refused without a write', () async {
      final entry = _entry(
        'mjölk',
        at: _now.subtract(const Duration(days: 31)),
      );
      final h = _Harness();
      await h.seedShared(
        _shared(items: [_row('bröd')], recentlyRemoved: [entry]),
      );

      final row = await withClock(
        Clock.fixed(_now),
        () => h.module.restore.restoreRemovedRow(_listId, entry),
      );

      expect(row, isNull);
      expect(h.transactionWrites, isEmpty);
    });

    test('matches on the row id alone and takes every entry for it', () async {
      final stored = _entry(
        'mjölk',
        at: _now.subtract(const Duration(days: 3)),
      );
      final again = _entry('mjölk', at: _now.subtract(const Duration(days: 1)));
      final h = _Harness();
      await h.seedShared(
        _shared(items: [_row('bröd')], recentlyRemoved: [stored, again]),
      );
      // The caller's copy carries an `at` the server never stored.
      final callers = _entry(
        'mjölk',
        at: _now.subtract(const Duration(hours: 1)),
      );

      final row = await withClock(
        Clock.fixed(_now),
        () => h.module.restore.restoreRemovedRow(_listId, callers),
      );

      expect(row?.id, 'mjölk');
      final list = await h.storedShared();
      expect(list.items.map((i) => i.id), ['bröd', 'mjölk']);
      expect(list.recentlyRemoved, isEmpty);
    });

    test('the row comes from the stored entry, not a stale copy', () async {
      final stored = _entry(
        'mjölk',
        name: 'mjölk 3%',
        at: _now.subtract(const Duration(days: 2)),
      );
      final h = _Harness();
      await h.seedShared(
        _shared(items: [_row('bröd')], recentlyRemoved: [stored]),
      );
      // Outside 30 days and with an old name: neither may decide anything.
      final stale = _entry(
        'mjölk',
        at: _now.subtract(const Duration(days: 40)),
      );

      final row = await withClock(
        Clock.fixed(_now),
        () => h.module.restore.restoreRemovedRow(_listId, stale),
      );

      expect(row?.name, 'mjölk 3%');
      final list = await h.storedShared();
      expect(list.items.last.name, 'mjölk 3%');
    });

    test('an expired stored entry is refused whatever the copy says', () async {
      final stored = _entry(
        'mjölk',
        at: _now.subtract(const Duration(days: 31)),
      );
      final h = _Harness();
      await h.seedShared(
        _shared(items: [_row('bröd')], recentlyRemoved: [stored]),
      );
      final fresh = _entry(
        'mjölk',
        at: _now.subtract(const Duration(hours: 1)),
      );

      final row = await withClock(
        Clock.fixed(_now),
        () => h.module.restore.restoreRemovedRow(_listId, fresh),
      );

      expect(row, isNull);
      expect(h.transactionWrites, isEmpty);
    });

    test('an entry the list no longer holds costs no write', () async {
      final entry = _entry('mjölk', at: _now.subtract(const Duration(days: 3)));
      final h = _Harness();
      await h.seedShared(_shared(items: [_row('bröd')]));

      final row = await withClock(
        Clock.fixed(_now),
        () => h.module.restore.restoreRemovedRow(_listId, entry),
      );

      expect(row, isNull);
      expect(h.transactionWrites, isEmpty);
    });

    test('a row with nothing to swap back costs no write', () async {
      final h = _Harness();
      await h.seedShared(_shared(items: [_row('ägg')]));

      final row = await withClock(
        Clock.fixed(_now),
        () => h.module.restore.restoreChangedRow(_listId, 'ägg'),
      );

      expect(row, isNull);
      expect(h.transactionWrites, isEmpty);
    });

    test('any row write prunes entries older than 30 days', () async {
      final expired = _entry(
        'gammal',
        at: _now.subtract(const Duration(days: 31)),
      );
      final kept = _entry('ost', at: _now.subtract(const Duration(days: 2)));
      final h = _Harness();
      await h.seedShared(
        _shared(items: [_row('mjölk')], recentlyRemoved: [expired, kept]),
      );

      await withClock(
        Clock.fixed(_now),
        () => h.module.updateItem(
          _listId,
          _row('mjölk', bought: true),
          before: _row('mjölk'),
        ),
      );

      expect((await h.storedShared()).recentlyRemoved, [kept]);
    });
  });

  group('personal list', () {
    test('a removal costs exactly N+1 operations', () async {
      final h = _Harness();
      final rows = [_row('mjölk'), _row('bröd'), _row('ost')];
      await h.seedPersonal(_personal(items: rows));
      h.firestore.batchWrites.clear();

      await withClock(
        Clock.fixed(_now),
        () => h.module.removeItemsBatch(
          _listId,
          rows.map((r) => r.id).toList(),
          removed: rows,
        ),
      );

      expect(h.firestore.batchWrites, hasLength(rows.length + 1));
      expect(
        (await h.storedPersonalHistory()).map((s) => s.id).toSet(),
        {'mjölk', 'bröd', 'ost'},
      );
    });

    test('expired entries go in a second update in the same batch', () async {
      final expired = _entry(
        'gammal',
        at: _now.subtract(const Duration(days: 31)),
      );
      final kept = _entry('ost', at: _now.subtract(const Duration(days: 2)));
      final h = _Harness();
      await h.seedPersonal(
        _personal(items: [_row('mjölk')], recentlyRemoved: [expired, kept]),
      );
      h.firestore.batchWrites.clear();

      await withClock(
        Clock.fixed(_now),
        () => h.module.removeItem(_listId, 'mjölk', removed: _row('mjölk')),
      );

      expect(h.firestore.batchWrites, hasLength(3));
      expect(
        (await h.storedPersonalHistory()).map((s) => s.id).toSet(),
        {'ost', 'mjölk'},
      );
    });

    test('a removal without the row keeps no history', () async {
      final h = _Harness();
      await h.seedPersonal(_personal(items: [_row('mjölk')]));
      h.firestore.batchWrites.clear();

      await h.module.removeItem(_listId, 'mjölk');

      expect(h.firestore.batchWrites, hasLength(1));
      expect(await h.storedPersonalHistory(), isEmpty);
      expect(await h.storedPersonalRow('mjölk'), isNull);
    });

    test('a content edit writes before as previous', () async {
      final h = _Harness();
      final before = _row('ägg', amount: 12);
      await h.seedPersonal(_personal(items: [before]));

      await withClock(
        Clock.fixed(_now),
        () => h.module.updateItem(
          _listId,
          _row('ägg', amount: 6),
          before: before,
        ),
      );

      final row = await h.storedPersonalRow('ägg');
      expect(row?.amount, 6);
      expect(row?.previous?.amount, 12);
    });

    test('a tick from a stale copy never nulls the stored previous', () async {
      final earlier = _entry('ägg', at: _now.subtract(const Duration(days: 1)));
      final h = _Harness();
      await h.seedPersonal(
        _personal(items: [_row('ägg', previous: earlier)]),
      );
      // This device never saw the edit that set previous.
      final stale = _row('ägg');

      await withClock(
        Clock.fixed(_now),
        () => h.module.updateItem(
          _listId,
          _row('ägg', bought: true),
          before: stale,
        ),
      );

      final row = await h.storedPersonalRow('ägg');
      expect(row?.bought, isTrue);
      expect(row?.previous, earlier);
    });

    test('a removed row is restored with its old id', () async {
      final entry = _entry('mjölk', at: _now.subtract(const Duration(days: 3)));
      final h = _Harness();
      await h.seedPersonal(
        _personal(items: [_row('bröd')], recentlyRemoved: [entry]),
      );

      final row = await withClock(
        Clock.fixed(_now),
        () => h.module.restore.restoreRemovedRow(_listId, entry),
      );

      expect(row?.id, 'mjölk');
      expect((await h.storedPersonalRow('mjölk'))?.name, 'mjölk');
      expect(await h.storedPersonalHistory(), isEmpty);
    });

    test('an id already there is not overwritten', () async {
      final entry = _entry('mjölk', at: _now.subtract(const Duration(days: 3)));
      final h = _Harness();
      await h.seedPersonal(
        _personal(
          items: [_row('mjölk', name: 'mjölk 3%')],
          recentlyRemoved: [entry],
        ),
      );

      final row = await withClock(
        Clock.fixed(_now),
        () => h.module.restore.restoreRemovedRow(_listId, entry),
      );

      expect(row, isNull);
      expect((await h.storedPersonalRow('mjölk'))?.name, 'mjölk 3%');
      expect(await h.storedPersonalHistory(), isEmpty);
    });

    test(
      'a restore removes the entry as stored, int amount included',
      () async {
        final h = _Harness();
        await h.seedPersonal(_personal(items: [_row('bröd')]));
        final stored = _entry(
          'mjölk',
          at: _now.subtract(const Duration(days: 3)),
        );
        await h.personalRef.update({
          'recentlyRemoved': [
            {...stored.toFirestore(), 'amount': 1},
          ],
        });
        h.firestore.batchWrites.clear();
        final callers = _entry(
          'mjölk',
          at: _now.subtract(const Duration(hours: 1)),
        );

        final row = await withClock(
          Clock.fixed(_now),
          () => h.module.restore.restoreRemovedRow(_listId, callers),
        );

        expect(row?.id, 'mjölk');
        expect(await h.storedPersonalHistory(), isEmpty);
      },
    );

    test('the row comes from the stored entry, not a stale copy', () async {
      final stored = _entry(
        'mjölk',
        name: 'mjölk 3%',
        at: _now.subtract(const Duration(days: 2)),
      );
      final h = _Harness();
      await h.seedPersonal(
        _personal(items: [_row('bröd')], recentlyRemoved: [stored]),
      );
      final stale = _entry(
        'mjölk',
        at: _now.subtract(const Duration(days: 40)),
      );

      final row = await withClock(
        Clock.fixed(_now),
        () => h.module.restore.restoreRemovedRow(_listId, stale),
      );

      expect(row?.name, 'mjölk 3%');
      expect((await h.storedPersonalRow('mjölk'))?.name, 'mjölk 3%');
      expect(await h.storedPersonalHistory(), isEmpty);
    });

    test('an entry the list no longer holds costs no write', () async {
      final entry = _entry('mjölk', at: _now.subtract(const Duration(days: 3)));
      final h = _Harness();
      await h.seedPersonal(_personal(items: [_row('bröd')]));
      h.firestore.batchWrites.clear();

      final row = await withClock(
        Clock.fixed(_now),
        () => h.module.restore.restoreRemovedRow(_listId, entry),
      );

      expect(row, isNull);
      expect(h.firestore.batchWrites, isEmpty);
      expect(await h.storedPersonalRow('mjölk'), isNull);
    });

    test('a changed row swaps with its previous', () async {
      final earlier = _entry('ägg', at: _now.subtract(const Duration(days: 1)));
      final h = _Harness();
      await h.seedPersonal(
        _personal(items: [_row('ägg', amount: 6, previous: earlier)]),
      );

      await withClock(
        Clock.fixed(_now),
        () => h.module.restore.restoreChangedRow(_listId, 'ägg'),
      );

      final row = await h.storedPersonalRow('ägg');
      expect(row?.amount, 1);
      expect(row?.previous?.amount, 6);
    });
  });
}
