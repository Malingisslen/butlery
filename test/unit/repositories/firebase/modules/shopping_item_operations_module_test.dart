/// Unit tests for ShoppingItemOperationsModule.
///
/// This module is the layer the shopping UI actually reaches (view →
/// viewmodel → UnifiedShoppingService → ShoppingItemManagementModule →
/// FirebaseShoppingRepository → here), so the five item mutators below are
/// the live write path for every checkbox tap in a shared household list.
///
/// The load-bearing property of every collaborative test here: the mutator is
/// applied to the document the transaction READ, never to the cached list the
/// caller already had in hand. Each fixture makes those two provably differ —
/// `readList` hands back Alice's stale client copy while the stored document
/// carries a tick and an extra item another member landed in the meantime —
/// so re-pointing any mutator from `live` back to `list` (the BUT-1665 bug)
/// fails the assertion instead of quietly passing.
///
/// The module is driven against the REAL ShoppingRepositoryRoutingModule over
/// FakeFirebaseFirestore, matching how FirebaseShoppingRepository wires the
/// two together, so the seam under test is the production one. What that does
/// NOT prove is atomicity: `FakeFirebaseFirestore.runTransaction` is a no-op
/// passthrough with no isolation, abort or retry. True concurrency belongs on
/// the emulator lane.
library;

import 'package:clock/clock.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/core/constants/firestore_collections.dart';
import 'package:butlery/core/exceptions/permission_exceptions.dart';
import 'package:butlery/core/extensions/iterable_extensions.dart';
import 'package:butlery/models/unified/unified_shopping_item.dart';
import 'package:butlery/models/unified/unified_shopping_list.dart';
import 'package:butlery/repositories/firebase/modules/shopping_item_operations_module.dart';
import 'package:butlery/repositories/firebase/modules/shopping_repository_routing_module.dart';

import '../../../../infrastructure/mocks/production_mocks.dart';

const _alice = 'alice';
const _bob = 'bob';
const _listId = 'list-1';
const _sharedPath = 'unified_shared_shopping_lists';

/// Pinned via `withClock` wherever a timestamp is asserted.
final _now = DateTime.utc(2026, 3, 14, 9, 30);
final _earlier = DateTime.utc(2026, 3, 13, 18, 0);

class _PermissionCall {
  final String userId;
  final String resource;
  final String operation;
  final bool granted;
  final String? details;
  _PermissionCall(
    this.userId,
    this.resource,
    this.operation,
    this.granted,
    this.details,
  );
}

class _RequiredFieldsCall {
  final Map<String, dynamic> data;
  final List<String> requiredFields;
  final String resourceType;
  _RequiredFieldsCall(this.data, this.requiredFields, this.resourceType);
}

class _OwnershipCall {
  final String currentUserId;
  final String resourceOwnerId;
  final String resourceType;
  final String resourceId;
  _OwnershipCall(
    this.currentUserId,
    this.resourceOwnerId,
    this.resourceType,
    this.resourceId,
  );
}

/// Wires the module the way FirebaseShoppingRepository does: `readList` is the
/// repository's cached read, `mutateCollaborativeList` is the real routing
/// module's transactional mutator over the same Firestore handle.
class _Harness {
  final FakeFirebaseFirestore firestore = FakeFirebaseFirestore();
  final List<_PermissionCall> permissionCalls = [];
  final List<_RequiredFieldsCall> validationCalls = [];
  final List<_OwnershipCall> ownershipCalls = [];
  int readListCalls = 0;
  int mutateCalls = 0;

  /// What `readList` returns — deliberately stale for the collaborative tests.
  final UnifiedShoppingList? cached;
  final String uid;
  final String displayName;
  final bool requiredFieldsThrows;

  late final FakeAuthRepository auth;
  late final ShoppingRepositoryRoutingModule routing;
  late final ShoppingItemOperationsModule module;

  _Harness({
    required this.cached,
    this.uid = _alice,
    this.displayName = 'Alice Andersson',
    this.requiredFieldsThrows = false,
  }) {
    auth = FakeAuthRepository()
      ..setAuthState(
        user: FakeUser(uid: uid, displayName: displayName),
        userId: uid,
        isAuthenticated: true,
      );

    routing = ShoppingRepositoryRoutingModule(
      firestore: firestore,
      authRepository: auth,
      sharedListsRef: firestore.collection(_sharedPath),
      requireCurrentUserId: () => uid,
      validateRequiredFields: _validateRequiredFields,
      logPermissionCheck: _logPermissionCheck,
      fromFirestore: UnifiedShoppingList.fromFirestore,
      // Mirrors FirebaseShoppingRepository.validateUpdatePermission.
      validateUpdatePermission: (userId, resourceId, entity) async =>
          entity.ownerId == userId ||
          (entity.isCollaborative &&
              entity.memberPermissions.containsKey(userId)),
    );

    module = ShoppingItemOperationsModule(
      firestore: firestore,
      authRepository: auth,
      requireCurrentUserId: () => uid,
      readList: (id) async {
        readListCalls++;
        return cached;
      },
      mutateCollaborativeList: (id, mutate) {
        mutateCalls++;
        return routing.mutateCollaborativeList(id, mutate);
      },
      getUserCollection: (userId) => firestore
          .collection(FirestoreCollections.users)
          .doc(userId)
          .collection(FirestoreCollections.unifiedShoppingLists),
      validateOwnership:
          ({
            required String currentUserId,
            required String resourceOwnerId,
            required String resourceType,
            required String resourceId,
          }) async {
            ownershipCalls.add(
              _OwnershipCall(
                currentUserId,
                resourceOwnerId,
                resourceType,
                resourceId,
              ),
            );
          },
      validateRequiredFields: _validateRequiredFields,
      logPermissionCheck: _logPermissionCheck,
    );
  }

  void _validateRequiredFields({
    required Map<String, dynamic> data,
    required List<String> requiredFields,
    required String resourceType,
  }) {
    validationCalls.add(
      _RequiredFieldsCall(data, requiredFields, resourceType),
    );
    if (requiredFieldsThrows) {
      throw SecurityViolationException('missing required field');
    }
  }

  void _logPermissionCheck({
    required String userId,
    required String resource,
    required String operation,
    required bool granted,
    String? details,
  }) {
    permissionCalls.add(
      _PermissionCall(userId, resource, operation, granted, details),
    );
  }

  Future<void> seedLive(UnifiedShoppingList live) =>
      firestore.collection(_sharedPath).doc(live.id).set(live.toFirestore());

  Future<UnifiedShoppingList> storedList([String id = _listId]) async =>
      UnifiedShoppingList.fromFirestore(
        await firestore.collection(_sharedPath).doc(id).get(),
      );

  Future<List<String>> storedItemIds([String id = _listId]) async =>
      (await storedList(id)).items.map((i) => i.id).toList();

  /// `users/{uid}/unified_shopping_lists/{listId}/items`
  Future<List<String>> personalItemIds({String listId = _listId}) async {
    final snap = await firestore
        .collection(FirestoreCollections.users)
        .doc(uid)
        .collection(FirestoreCollections.unifiedShoppingLists)
        .doc(listId)
        .collection(FirestoreCollections.items)
        .get();
    return snap.docs.map((d) => d.id).toList()..sort();
  }
}

UnifiedShoppingItem _item(String id, {bool bought = false, String? addedBy}) =>
    UnifiedShoppingItem(
      id: id,
      name: id,
      amount: 1,
      unit: 'st',
      category: ShoppingCategory.other,
      bought: bought,
      addedByUserId: addedBy,
    );

/// Server truth: Bob has ticked "mjölk" off and added "bröd" since Alice's
/// client last read the list.
UnifiedShoppingList _liveList() => UnifiedShoppingList(
  id: _listId,
  name: 'Veckohandling',
  ownerId: _alice,
  ownerDisplayName: 'Alice Andersson',
  type: ListType.collaborative,
  memberPermissions: const {
    _alice: SharedListPermission.admin,
    _bob: SharedListPermission.edit,
  },
  items: [
    _item('ägg'),
    _item('mjölk', bought: true),
    _item('bröd', addedBy: _bob),
  ],
  // Attributed to a third household member so "stamps the acting member" is
  // never vacuously true for either Alice or Bob.
  lastActivityAt: _earlier,
  lastActivityByUserId: 'cecilia',
  lastActivityByDisplayName: 'Cecilia Ek',
);

/// Alice's stale client copy — no "bröd", and "mjölk" still unticked. This is
/// what `readList` hands the module, and what the mutators must NOT build on.
UnifiedShoppingList _cachedList() => UnifiedShoppingList(
  id: _listId,
  name: 'Veckohandling',
  ownerId: _alice,
  ownerDisplayName: 'Alice Andersson',
  type: ListType.collaborative,
  memberPermissions: const {
    _alice: SharedListPermission.admin,
    _bob: SharedListPermission.edit,
  },
  items: [_item('ägg'), _item('mjölk')],
  lastActivityAt: _earlier,
  lastActivityByUserId: 'cecilia',
  lastActivityByDisplayName: 'Cecilia Ek',
);

UnifiedShoppingList _personalList() => UnifiedShoppingList(
  id: _listId,
  name: 'Min lista',
  ownerId: _alice,
  ownerDisplayName: 'Alice Andersson',
  items: [_item('ägg')],
);

void main() {
  // Every test in this group would also pass against the cached list if the
  // fixture were identical; it is not. `bröd` exists only on the server and
  // `mjölk` is ticked only on the server, so a mutator reading `list` instead
  // of `live` drops one and un-ticks the other.
  group('collaborative mutators build on the live document', () {
    test('addItem appends onto the live items, not the caller cache', () async {
      final h = _Harness(cached: _cachedList());
      await h.seedLive(_liveList());

      await h.module.addItem(_listId, _item('kaffe'));

      final stored = await h.storedList();
      expect(stored.items.map((i) => i.id), ['ägg', 'mjölk', 'bröd', 'kaffe']);
      expect(stored.items.firstWhere((i) => i.id == 'mjölk').bought, isTrue);
      expect(h.mutateCalls, 1);
    });

    test('addItemsBatch appends onto the live items', () async {
      final h = _Harness(cached: _cachedList());
      await h.seedLive(_liveList());

      await h.module.addItemsBatch(_listId, [_item('kaffe'), _item('smör')]);

      final stored = await h.storedList();
      expect(stored.items.map((i) => i.id), [
        'ägg',
        'mjölk',
        'bröd',
        'kaffe',
        'smör',
      ]);
      expect(stored.items.firstWhere((i) => i.id == 'mjölk').bought, isTrue);
    });

    test('updateItem replaces only the edited item on the live list', () async {
      final h = _Harness(cached: _cachedList());
      await h.seedLive(_liveList());

      await h.module.updateItem(_listId, _item('ägg', bought: true));

      final stored = await h.storedList();
      expect(stored.items.map((i) => i.id), ['ägg', 'mjölk', 'bröd']);
      expect(
        {for (final i in stored.items) i.id: i.bought},
        {
          'ägg': true,
          'mjölk': true, // Bob's tick survives Alice's edit.
          'bröd': false,
        },
      );
    });

    // The sharpest form of the BUT-1665 bug: an item added by another member
    // is absent from the caller's cache, so a cached-base `map()` matches
    // nothing and the user's edit vanishes with no error at all.
    test('updateItem lands on an item only the server knows about', () async {
      final h = _Harness(cached: _cachedList());
      await h.seedLive(_liveList());

      await h.module.updateItem(
        _listId,
        _item('bröd', bought: true, addedBy: _bob),
      );

      final stored = await h.storedList();
      expect(stored.items.map((i) => i.id), ['ägg', 'mjölk', 'bröd']);
      expect(stored.items.firstWhere((i) => i.id == 'bröd').bought, isTrue);
    });

    test('removeItem filters the live items', () async {
      final h = _Harness(cached: _cachedList());
      await h.seedLive(_liveList());

      await h.module.removeItem(_listId, 'ägg');

      final stored = await h.storedList();
      expect(stored.items.map((i) => i.id), ['mjölk', 'bröd']);
      expect(stored.items.firstWhere((i) => i.id == 'mjölk').bought, isTrue);
    });

    test('removeItemsBatch filters the live items', () async {
      final h = _Harness(cached: _cachedList());
      await h.seedLive(_liveList());

      await h.module.removeItemsBatch(_listId, ['ägg', 'aldrig-funnits']);

      final stored = await h.storedList();
      expect(stored.items.map((i) => i.id), ['mjölk', 'bröd']);
      expect(stored.items.firstWhere((i) => i.id == 'mjölk').bought, isTrue);
    });

    // `_withItems` is the single place the shared-list activity banner gets its
    // data. The live doc is seeded as "last touched by Bob yesterday", so the
    // assertion fails if the stamp is dropped rather than merely re-applied.
    test('every collaborative write stamps the acting member', () async {
      final h = _Harness(cached: _cachedList());
      await h.seedLive(_liveList());

      await withClock(Clock.fixed(_now), () async {
        await h.module.addItem(_listId, _item('kaffe'));
      });

      final stored = await h.storedList();
      expect(stored.lastActivityByUserId, _alice);
      expect(stored.lastActivityByDisplayName, 'Alice Andersson');
      expect(stored.lastActivityAt!.isAtSameMomentAs(_now), isTrue);
      expect(stored.updatedAt.isAtSameMomentAs(_now), isTrue);
    });

    // The shared-list activity banner reads these fields. A non-owner member
    // doing the shopping must show up as the actor — the list owner is not who
    // touched it, and the previous stamp belongs to a third member.
    test('a non-owner member is stamped as the actor, not the owner', () async {
      final h = _Harness(
        cached: _cachedList(),
        uid: _bob,
        displayName: 'Bob Bergman',
      );
      await h.seedLive(_liveList());

      await withClock(Clock.fixed(_now), () async {
        await h.module.updateItem(_listId, _item('ägg', bought: true));
      });

      final stored = await h.storedList();
      expect(stored.ownerId, _alice);
      expect(stored.lastActivityByUserId, _bob);
      expect(stored.lastActivityByDisplayName, 'Bob Bergman');
      expect(stored.items.firstWhere((i) => i.id == 'ägg').bought, isTrue);
      expect(stored.items.firstWhere((i) => i.id == 'mjölk').bought, isTrue);
    });

    test('logs a granted audit entry naming the operation', () async {
      final h = _Harness(cached: _cachedList());
      await h.seedLive(_liveList());

      await h.module.removeItem(_listId, 'ägg');

      final itemAudit = h.permissionCalls.last;
      expect(itemAudit.userId, _alice);
      expect(itemAudit.resource, 'shopping_item');
      expect(itemAudit.operation, 'remove');
      expect(itemAudit.granted, isTrue);
      expect(itemAudit.details, contains('Item: ägg'));
    });
  });

  group('personal lists keep using the item subcollection', () {
    test(
      'addItem writes the item doc and never mutates a shared list',
      () async {
        final h = _Harness(cached: _personalList());

        await h.module.addItem(_listId, _item('kaffe'));

        expect(await h.personalItemIds(), ['kaffe']);
        expect(h.mutateCalls, 0);
        final ownership = h.ownershipCalls.single;
        expect(ownership.currentUserId, _alice);
        expect(ownership.resourceOwnerId, _alice);
        expect(ownership.resourceType, 'shopping_list');
        expect(ownership.resourceId, _listId);
      },
    );

    test('addItemsBatch writes every item doc', () async {
      final h = _Harness(cached: _personalList());

      await h.module.addItemsBatch(_listId, [_item('kaffe'), _item('smör')]);

      expect(await h.personalItemIds(), ['kaffe', 'smör']);
      expect(h.mutateCalls, 0);
    });

    test('updateItem writes through to the item doc', () async {
      final h = _Harness(cached: _personalList());
      await h.module.addItem(_listId, _item('kaffe'));

      await h.module.updateItem(_listId, _item('kaffe', bought: true));

      final doc = await h.firestore
          .collection(FirestoreCollections.users)
          .doc(_alice)
          .collection(FirestoreCollections.unifiedShoppingLists)
          .doc(_listId)
          .collection(FirestoreCollections.items)
          .doc('kaffe')
          .get();
      expect(doc.data()!['bought'], isTrue);
      expect(h.mutateCalls, 0);
    });

    test('removeItem deletes the item doc', () async {
      final h = _Harness(cached: _personalList());
      await h.module.addItemsBatch(_listId, [_item('kaffe'), _item('smör')]);

      await h.module.removeItem(_listId, 'kaffe');

      expect(await h.personalItemIds(), ['smör']);
      expect(h.mutateCalls, 0);
    });

    // Firestore caps a batch at 500 writes, so the delete loop chunks. An
    // off-by-one that drops the trailing partial chunk leaves items behind on
    // the user's list, which is why the fixture straddles the cap.
    test('removeItemsBatch deletes past the batch chunk size', () async {
      final h = _Harness(cached: _personalList());
      final ids = List.generate(
        kFirestoreBatchSafeChunkSize + 1,
        (i) => 'vara-$i',
      );
      expect(ids.length, greaterThan(kFirestoreBatchSafeChunkSize));

      final itemsRef = h.firestore
          .collection(FirestoreCollections.users)
          .doc(_alice)
          .collection(FirestoreCollections.unifiedShoppingLists)
          .doc(_listId)
          .collection(FirestoreCollections.items);
      for (final id in ids) {
        await itemsRef.doc(id).set(_item(id).toFirestore());
      }

      await h.module.removeItemsBatch(_listId, ids);

      expect(await h.personalItemIds(), isEmpty);
      expect(h.mutateCalls, 0);
    });
  });

  group('guards', () {
    final missingListCalls =
        <String, Future<void> Function(ShoppingItemOperationsModule m)>{
          'addItem': (m) => m.addItem(_listId, _item('kaffe')),
          'addItemsBatch': (m) => m.addItemsBatch(_listId, [_item('kaffe')]),
          'updateItem': (m) => m.updateItem(_listId, _item('ägg')),
          'removeItem': (m) => m.removeItem(_listId, 'ägg'),
          'removeItemsBatch': (m) => m.removeItemsBatch(_listId, ['ägg']),
        };

    for (final entry in missingListCalls.entries) {
      test(
        '${entry.key} throws ResourceNotFoundException for a gone list',
        () async {
          final h = _Harness(cached: null);

          await expectLater(
            () => entry.value(h.module),
            throwsA(isA<ResourceNotFoundException>()),
          );
          expect(h.mutateCalls, 0);
          expect(h.permissionCalls, isEmpty);
        },
      );
    }

    test('addItem validates the item payload before writing', () async {
      final h = _Harness(cached: _cachedList());
      await h.seedLive(_liveList());

      await h.module.addItem(_listId, _item('kaffe'));

      final call = h.validationCalls.single;
      expect(call.requiredFields, ['name', 'id']);
      expect(call.resourceType, 'shopping_item');
      expect(call.data['id'], 'kaffe');
      expect(call.data['name'], 'kaffe');
    });

    test('a required-field violation blocks the write and the audit', () async {
      final h = _Harness(cached: _cachedList(), requiredFieldsThrows: true);
      await h.seedLive(_liveList());

      await expectLater(
        () => h.module.addItem(_listId, _item('kaffe')),
        throwsA(isA<SecurityViolationException>()),
      );

      expect(await h.storedItemIds(), ['ägg', 'mjölk', 'bröd']);
      expect(h.mutateCalls, 0);
      expect(h.permissionCalls, isEmpty);
    });

    // addItemsBatch gates on the caller's own permission entry before it even
    // reaches the transaction; the routing module re-checks against the live
    // document, but this bar must not be missing here.
    test('addItemsBatch refuses a view-only member', () async {
      final viewOnly = UnifiedShoppingList(
        id: _listId,
        name: 'Veckohandling',
        ownerId: _bob,
        ownerDisplayName: 'Bob Bergman',
        type: ListType.collaborative,
        memberPermissions: const {
          _bob: SharedListPermission.admin,
          _alice: SharedListPermission.view,
        },
        items: [_item('ägg')],
      );
      final h = _Harness(cached: viewOnly);
      await h.seedLive(viewOnly);

      await expectLater(
        () => h.module.addItemsBatch(_listId, [_item('kaffe')]),
        throwsA(isA<PermissionDeniedException>()),
      );

      expect(await h.storedItemIds(), ['ägg']);
      expect(h.mutateCalls, 0);
      expect(h.permissionCalls, isEmpty);
    });

    test('addItemsBatch with no items writes nothing', () async {
      final h = _Harness(cached: _cachedList());
      await h.seedLive(_liveList());

      await h.module.addItemsBatch(_listId, []);

      expect(h.mutateCalls, 0);
      expect(h.permissionCalls, isEmpty);
      expect(await h.storedItemIds(), ['ägg', 'mjölk', 'bröd']);
    });

    // The empty guard sits above the read, so an empty selection costs no
    // Firestore document read at all.
    test('removeItemsBatch with no ids never reads the list', () async {
      final h = _Harness(cached: _cachedList());
      await h.seedLive(_liveList());

      await h.module.removeItemsBatch(_listId, []);

      expect(h.readListCalls, 0);
      expect(h.mutateCalls, 0);
      expect(await h.storedItemIds(), ['ägg', 'mjölk', 'bröd']);
    });
  });
}
