/// Unit tests for ShoppingRepositoryRoutingModule.
///
/// The module routes collaborative-list CRUD to the shared collection
/// (/unified_shared_shopping_lists). It depends on a firestore handle,
/// an auth repository, a shared-collection ref, and four injected
/// callables. We pin the contract by driving each public method against
/// FakeFirebaseFirestore and capturing every callback invocation.
library;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/core/exceptions/permission_exceptions.dart';
import 'package:butlery/models/unified/unified_shopping_item.dart';
import 'package:butlery/models/unified/unified_shopping_list.dart';
import 'package:butlery/repositories/firebase/modules/shopping_repository_routing_module.dart';

import '../../../../infrastructure/mocks/production_mocks.dart';

const _userId = 'alice';
const _sharedPath = 'unified_shared_shopping_lists';

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

ShoppingRepositoryRoutingModule _routing(
  FakeFirebaseFirestore firestore, {
  List<_PermissionCall>? permissionCalls,
  List<_RequiredFieldsCall>? validationCalls,
  bool requiredFieldsThrows = false,
  String? currentUid,
  CollaborativeListTransactionRunner? transactionRunner,
}) {
  return ShoppingRepositoryRoutingModule(
    transactionRunner: transactionRunner,
    // Mirrors FirebaseShoppingRepository.validateUpdatePermission: the owner
    // always passes, other users need a member entry.
    validateUpdatePermission: (userId, resourceId, entity) async =>
        entity.ownerId == userId ||
        (entity.isCollaborative &&
            entity.memberPermissions.containsKey(userId)),
    firestore: firestore,
    authRepository: FakeAuthRepository(),
    sharedListsRef: firestore.collection(_sharedPath),
    requireCurrentUserId: () => currentUid ?? _userId,
    validateRequiredFields:
        ({
          required Map<String, dynamic> data,
          required List<String> requiredFields,
          required String resourceType,
        }) {
          validationCalls?.add(
            _RequiredFieldsCall(data, requiredFields, resourceType),
          );
          if (requiredFieldsThrows) {
            throw SecurityViolationException('missing required field');
          }
        },
    logPermissionCheck:
        ({
          required String userId,
          required String resource,
          required String operation,
          required bool granted,
          String? details,
        }) {
          permissionCalls?.add(
            _PermissionCall(userId, resource, operation, granted, details),
          );
        },
    fromFirestore: UnifiedShoppingList.fromFirestore,
  );
}

UnifiedShoppingItem _item(String id, {bool bought = false}) =>
    UnifiedShoppingItem(
      id: id,
      name: id,
      amount: 1,
      unit: 'st',
      category: ShoppingCategory.other,
      bought: bought,
    );

UnifiedShoppingList _collabList({String name = 'Veckans handla'}) {
  return UnifiedShoppingList.collaborative(
    name: name,
    ownerId: _userId,
    ownerDisplayName: 'Alice',
    memberPermissions: const {'bob': SharedListPermission.edit},
  );
}

void main() {
  group('createCollaborativeList', () {
    test('writes to shared collection with generated id', () async {
      final firestore = FakeFirebaseFirestore();
      final permissionCalls = <_PermissionCall>[];
      final validationCalls = <_RequiredFieldsCall>[];
      final module = _routing(
        firestore,
        permissionCalls: permissionCalls,
        validationCalls: validationCalls,
      );

      final input = _collabList(name: 'Helgens handla');
      final saved = await module.createCollaborativeList(input);

      // Saved list has a fresh id from the docRef, not the entity input id.
      expect(saved.id, isNotEmpty);
      expect(saved.name, 'Helgens handla');

      final snap = await firestore.collection(_sharedPath).doc(saved.id).get();
      expect(snap.exists, isTrue);
      expect(snap.data()!['name'], 'Helgens handla');
      expect(snap.data()!['ownerId'], _userId);
    });

    test('validates required fields before writing', () async {
      final firestore = FakeFirebaseFirestore();
      final validationCalls = <_RequiredFieldsCall>[];
      final module = _routing(firestore, validationCalls: validationCalls);

      await module.createCollaborativeList(_collabList());

      final call = validationCalls.single;
      expect(call.requiredFields, ['name', 'ownerId', 'memberPermissions']);
      expect(call.resourceType, 'collaborative_shopping_list');
      expect(call.data['name'], isNotNull);
    });

    test('logs successful permission check on create', () async {
      final firestore = FakeFirebaseFirestore();
      final permissionCalls = <_PermissionCall>[];
      final module = _routing(firestore, permissionCalls: permissionCalls);

      await module.createCollaborativeList(_collabList(name: 'X'));

      expect(permissionCalls, hasLength(1));
      final call = permissionCalls.single;
      expect(call.userId, _userId);
      expect(call.resource, 'collaborative_shopping_list');
      expect(call.operation, 'create');
      expect(call.granted, isTrue);
      expect(call.details, contains('List: X'));
    });

    test(
      'propagates required-fields violations — no write, no perm log',
      () async {
        final firestore = FakeFirebaseFirestore();
        final permissionCalls = <_PermissionCall>[];
        final module = _routing(
          firestore,
          permissionCalls: permissionCalls,
          requiredFieldsThrows: true,
        );

        await expectLater(
          () => module.createCollaborativeList(_collabList()),
          throwsA(isA<SecurityViolationException>()),
        );

        final col = await firestore.collection(_sharedPath).get();
        expect(col.docs, isEmpty);
        expect(permissionCalls, isEmpty);
      },
    );
  });

  group('updateCollaborativeList', () {
    test('throws ResourceNotFoundException when doc does not exist', () async {
      final firestore = FakeFirebaseFirestore();
      final module = _routing(firestore);
      final entity = _collabList();

      await expectLater(
        () => module.updateCollaborativeList(entity),
        throwsA(isA<ResourceNotFoundException>()),
      );
    });

    test('merges update into existing shared doc', () async {
      final firestore = FakeFirebaseFirestore();
      final existing = _collabList(name: 'Original');
      // Seed via createCollaborativeList so the doc is well-formed.
      final module = _routing(firestore);
      final saved = await module.createCollaborativeList(existing);

      // Build a same-id entity with a new name.
      final renamed = UnifiedShoppingList(
        id: saved.id,
        name: 'Renamed',
        ownerId: saved.ownerId,
        ownerDisplayName: saved.ownerDisplayName,
        items: saved.items,
        type: saved.type,
        memberPermissions: saved.memberPermissions,
      );

      final returned = await module.updateCollaborativeList(renamed);
      expect(returned.name, 'Renamed');

      final snap = await firestore.collection(_sharedPath).doc(saved.id).get();
      expect(snap.data()!['name'], 'Renamed');
    });

    test('logs successful update permission check', () async {
      final firestore = FakeFirebaseFirestore();
      final permissionCalls = <_PermissionCall>[];
      final module = _routing(firestore, permissionCalls: permissionCalls);
      final saved = await module.createCollaborativeList(_collabList());
      permissionCalls.clear();

      await module.updateCollaborativeList(saved);

      expect(permissionCalls, hasLength(1));
      final call = permissionCalls.single;
      expect(call.resource, 'collaborative_shopping_list');
      expect(call.operation, 'update');
      expect(call.granted, isTrue);
    });

    test('denies a caller who is neither owner nor member', () async {
      final firestore = FakeFirebaseFirestore();
      final permissionCalls = <_PermissionCall>[];
      final saved = await _routing(
        firestore,
      ).createCollaborativeList(_collabList());

      final intruder = _routing(
        firestore,
        permissionCalls: permissionCalls,
        currentUid: 'mallory',
      );

      await expectLater(
        () => intruder.updateCollaborativeList(saved),
        throwsA(isA<PermissionDeniedException>()),
      );
      expect(permissionCalls.single.granted, isFalse);
    });

    // This method writes the WHOLE list, so it must not be a softer gate than
    // the item path: a view-only member passes `validateUpdatePermission`
    // (which only checks membership) but must still be refused here.
    test('denies a view-only member and never writes', () async {
      final firestore = FakeFirebaseFirestore();
      final saved = await _routing(firestore).createCollaborativeList(
        UnifiedShoppingList.collaborative(
          name: 'Handla',
          ownerId: _userId,
          ownerDisplayName: 'Alice',
          memberPermissions: const {'bob': SharedListPermission.view},
        ),
      );

      final permissionCalls = <_PermissionCall>[];
      final viewer = _routing(
        firestore,
        permissionCalls: permissionCalls,
        currentUid: 'bob',
      );

      await expectLater(
        () => viewer.updateCollaborativeList(
          saved.copyWith(name: 'Kapad lista'),
        ),
        throwsA(isA<PermissionDeniedException>()),
      );

      expect(permissionCalls.single.granted, isFalse);
      final snap = await firestore.collection(_sharedPath).doc(saved.id).get();
      expect(snap.data()!['name'], 'Handla');
    });

    test(
      'refuses a member who promotes itself to admin in the written payload',
      () async {
        final firestore = FakeFirebaseFirestore();
        // bob is an edit-level member, so he legitimately reaches the write.
        final saved = await _routing(
          firestore,
        ).createCollaborativeList(_collabList());

        final permissionCalls = <_PermissionCall>[];
        final bob = _routing(
          firestore,
          permissionCalls: permissionCalls,
          currentUid: 'bob',
        );

        await expectLater(
          () => bob.updateCollaborativeList(
            saved.copyWith(
              memberPermissions: {
                ...saved.memberPermissions,
                'bob': SharedListPermission.admin,
              },
            ),
          ),
          throwsA(isA<PermissionDeniedException>()),
        );

        expect(permissionCalls.single.granted, isFalse);
        final snap = await firestore
            .collection(_sharedPath)
            .doc(saved.id)
            .get();
        expect(
          snap.data()!['memberPermissions'],
          {_userId: 'admin', 'bob': 'edit'},
        );
        expect(snap.data()!['ownerId'], _userId);
      },
    );

    test('refuses a member who names itself as the new owner', () async {
      final firestore = FakeFirebaseFirestore();
      final saved = await _routing(
        firestore,
      ).createCollaborativeList(_collabList());

      final bob = _routing(firestore, currentUid: 'bob');
      final hijacked = UnifiedShoppingList(
        id: saved.id,
        name: saved.name,
        ownerId: 'bob',
        ownerDisplayName: 'Bob',
        items: saved.items,
        type: saved.type,
        memberPermissions: saved.memberPermissions,
      );

      await expectLater(
        () => bob.updateCollaborativeList(hijacked),
        throwsA(isA<PermissionDeniedException>()),
      );

      final snap = await firestore.collection(_sharedPath).doc(saved.id).get();
      expect(snap.data()!['ownerId'], _userId);
    });

    // The escalation guard must not block the everyday collaborative edit.
    test('an edit-level member may still rename the list', () async {
      final firestore = FakeFirebaseFirestore();
      final saved = await _routing(
        firestore,
      ).createCollaborativeList(_collabList());

      final bob = _routing(firestore, currentUid: 'bob');
      await bob.updateCollaborativeList(saved.copyWith(name: 'Söndagshandel'));

      final snap = await firestore.collection(_sharedPath).doc(saved.id).get();
      expect(snap.data()!['name'], 'Söndagshandel');
    });

    // The owner is the only role the Firestore rule lets touch the member map,
    // and member management (add/remove/leave) routes through this method.
    test('the owner may still rewrite memberPermissions', () async {
      final firestore = FakeFirebaseFirestore();
      final owner = _routing(firestore);
      final saved = await owner.createCollaborativeList(_collabList());

      await owner.updateCollaborativeList(
        saved.copyWith(
          memberPermissions: {
            ...saved.memberPermissions,
            'cecilia': SharedListPermission.view,
          },
        ),
      );

      final snap = await firestore.collection(_sharedPath).doc(saved.id).get();
      expect(snap.data()!['memberPermissions'], {
        _userId: 'admin',
        'bob': 'edit',
        'cecilia': 'view',
      });
    });
  });

  // BUT-1665. What these fake-backed tests pin, and nothing more: the mutator's
  // base object comes from a SERVER READ inside the transaction handler rather
  // than from the caller's client cache, and the escalation/edit-rights gates
  // run against that server state.
  //
  // They do NOT prove atomicity or concurrency safety.
  // `FakeFirebaseFirestore.runTransaction` is a no-op passthrough: it builds a
  // dummy transaction, calls the handler exactly once, writes immediately,
  // drops `SetOptions`, and ignores `timeout` and `maxAttempts`. There is no
  // isolation, no abort and no retry, so two genuinely interleaved writers
  // cannot even be expressed here — the second would clobber the first on the
  // fake while succeeding in production. That property needs the emulator lane
  // (`firestoreForLane()` + `emulatorOnlySkip`); see
  // test/integration/firebase/repositories/shopping_collaborative_mutation_integration_test.dart.
  group('mutateCollaborativeList', () {
    test('applies the mutator to the live doc and stores the result', () async {
      final firestore = FakeFirebaseFirestore();
      final module = _routing(firestore);
      final saved = await module.createCollaborativeList(_collabList());

      final merged = await module.mutateCollaborativeList(
        saved.id,
        (live) => live.copyWith(items: [...live.items, _item('mjölk')]),
      );

      expect(merged.items.map((i) => i.id), ['mjölk']);
      final snap = await firestore.collection(_sharedPath).doc(saved.id).get();
      final stored = (snap.data()!['items'] as List).cast<Map>();
      expect(stored.map((i) => i['id']), ['mjölk']);
    });

    // Sequential by construction, not a race: the point is that the third
    // mutator's base is the doc as the SERVER has it after Bob's write, not
    // the list Alice's client was holding.
    test(
      'the mutator sees the LIVE items, so an earlier tick by another member survives',
      () async {
        final firestore = FakeFirebaseFirestore();
        final module = _routing(firestore);
        final saved = await module.createCollaborativeList(_collabList());

        // Alice's client cached a list with both items unbought.
        await module.mutateCollaborativeList(
          saved.id,
          (live) => live.copyWith(
            items: [_item('mjölk'), _item('bröd')],
          ),
        );

        // Bob ticks "bröd" off from his own device.
        await module.mutateCollaborativeList(
          saved.id,
          (live) => live.copyWith(
            items: live.items
                .map((i) => i.id == 'bröd' ? i.copyWith(bought: true) : i)
                .toList(),
          ),
        );

        // Alice now ticks "mjölk". Her mutator only touches mjölk and reads
        // everything else from the live doc — the old cached-base write would
        // have reset bröd to unbought here.
        final merged = await module.mutateCollaborativeList(
          saved.id,
          (live) => live.copyWith(
            items: live.items
                .map((i) => i.id == 'mjölk' ? i.copyWith(bought: true) : i)
                .toList(),
          ),
        );

        expect(
          {for (final i in merged.items) i.id: i.bought},
          {'mjölk': true, 'bröd': true},
        );
      },
    );

    test('throws ResourceNotFoundException for a missing doc', () async {
      final firestore = FakeFirebaseFirestore();
      final module = _routing(firestore);

      await expectLater(
        () => module.mutateCollaborativeList('nope', (live) => live),
        throwsA(isA<ResourceNotFoundException>()),
      );
    });

    test('logs a granted audit entry naming the merged list', () async {
      final firestore = FakeFirebaseFirestore();
      final permissionCalls = <_PermissionCall>[];
      final module = _routing(firestore, permissionCalls: permissionCalls);
      final saved = await module.createCollaborativeList(
        _collabList(name: 'Handla'),
      );
      permissionCalls.clear();

      await module.mutateCollaborativeList(saved.id, (live) => live);

      final call = permissionCalls.single;
      expect(call.operation, 'update');
      expect(call.granted, isTrue);
      expect(call.details, contains('Handla'));
    });

    // Audit integrity: a grant must never be recorded for a check that was
    // never run, and a view-only member must not be able to tick items.
    test('denies a view-only member and never writes', () async {
      final firestore = FakeFirebaseFirestore();
      final owner = _routing(firestore);
      final saved = await owner.createCollaborativeList(
        UnifiedShoppingList.collaborative(
          name: 'Handla',
          ownerId: _userId,
          ownerDisplayName: 'Alice',
          memberPermissions: const {'bob': SharedListPermission.view},
        ),
      );

      final permissionCalls = <_PermissionCall>[];
      final viewer = _routing(
        firestore,
        permissionCalls: permissionCalls,
        currentUid: 'bob',
      );

      await expectLater(
        () => viewer.mutateCollaborativeList(
          saved.id,
          (live) => live.copyWith(items: [_item('smyg')]),
        ),
        throwsA(isA<PermissionDeniedException>()),
      );

      expect(permissionCalls.single.granted, isFalse);
      final snap = await firestore.collection(_sharedPath).doc(saved.id).get();
      expect(snap.data()!['items'], isEmpty);
    });

    test('an edit-level member may mutate', () async {
      final firestore = FakeFirebaseFirestore();
      final saved = await _routing(
        firestore,
      ).createCollaborativeList(_collabList());

      final bob = _routing(firestore, currentUid: 'bob');
      final merged = await bob.mutateCollaborativeList(
        saved.id,
        (live) => live.copyWith(items: [_item('bröd')]),
      );

      expect(merged.items.single.id, 'bröd');
    });

    // The mutator is caller-supplied and this method is public repository API,
    // so it persists a caller-shaped WHOLE document exactly like
    // updateCollaborativeList does. An arbitrary-callback API is the easier
    // bypass, not the harder one, so it needs the same escalation bar.
    test('refuses a mutator that names the caller as the new owner', () async {
      final firestore = FakeFirebaseFirestore();
      final saved = await _routing(
        firestore,
      ).createCollaborativeList(_collabList());

      final permissionCalls = <_PermissionCall>[];
      final bob = _routing(
        firestore,
        permissionCalls: permissionCalls,
        currentUid: 'bob',
      );

      await expectLater(
        () => bob.mutateCollaborativeList(
          saved.id,
          // copyWith cannot move ownerId, so the mutator rebuilds the list —
          // exactly what a malicious caller would have to do.
          (live) => UnifiedShoppingList(
            id: live.id,
            name: live.name,
            ownerId: 'bob',
            ownerDisplayName: 'Bob',
            items: [...live.items, _item('smyg')],
            type: live.type,
            memberPermissions: live.memberPermissions,
          ),
        ),
        throwsA(isA<PermissionDeniedException>()),
      );

      // Nothing written, and the refusal is recorded as a denial.
      final snap = await firestore.collection(_sharedPath).doc(saved.id).get();
      expect(snap.data()!['ownerId'], _userId);
      expect(snap.data()!['items'], isEmpty);
      expect(permissionCalls.last.granted, isFalse);
      expect(permissionCalls.last.details, contains('ownerId'));
    });

    // The everyday collaborative mutation must still pass the guard.
    test('an edit-level member may still mutate items', () async {
      final firestore = FakeFirebaseFirestore();
      final saved = await _routing(
        firestore,
      ).createCollaborativeList(_collabList());

      final bob = _routing(firestore, currentUid: 'bob');
      await bob.mutateCollaborativeList(
        saved.id,
        (live) => live.copyWith(items: [...live.items, _item('mjölk')]),
      );

      final snap = await firestore.collection(_sharedPath).doc(saved.id).get();
      expect((snap.data()!['items'] as List), hasLength(1));
    });

    // Member management legitimately routes through the owner, so the guard
    // must not lock the owner out of their own list.
    test('the owner may still add a member through a mutator', () async {
      final firestore = FakeFirebaseFirestore();
      final owner = _routing(firestore);
      final saved = await owner.createCollaborativeList(_collabList());

      await owner.mutateCollaborativeList(
        saved.id,
        (live) => live.copyWith(
          memberPermissions: {
            ...live.memberPermissions,
            'cecilia': SharedListPermission.view,
          },
        ),
      );

      final snap = await firestore.collection(_sharedPath).doc(saved.id).get();
      expect(snap.data()!['memberPermissions'], {
        _userId: 'admin',
        'bob': 'edit',
        'cecilia': 'view',
      });
    });
  });

  // BUT-1665 review: a Firestore transaction cannot run without a server
  // round-trip, so in a shop with bad reception the tick has to land via the
  // cached-base fallback instead of failing (which would roll the tick back on
  // screen). fake_cloud_firestore cannot raise these platform codes, so the
  // transaction runner is injected.
  group('mutateCollaborativeList offline fallback', () {
    CollaborativeListTransactionRunner failsWith(String code) =>
        (_) async =>
            throw FirebaseException(plugin: 'cloud_firestore', code: code);

    // Both codes mean the same thing in a shop: no server round-trip happened.
    // 'deadline-exceeded' is what the platform reports once the module's short
    // transaction budget runs out on a flaky-but-present connection.
    for (final code in ['unavailable', 'deadline-exceeded']) {
      test(
        '$code falls back to the cached base and returns the tick',
        () async {
          final firestore = FakeFirebaseFirestore();
          final saved = await _routing(
            firestore,
          ).createCollaborativeList(_collabList());

          final permissionCalls = <_PermissionCall>[];
          final offline = _routing(
            firestore,
            permissionCalls: permissionCalls,
            transactionRunner: failsWith(code),
          );
          permissionCalls.clear();

          final merged = await offline.mutateCollaborativeList(
            saved.id,
            (live) => live.copyWith(items: [...live.items, _item('mjölk')]),
          );

          // The caller gets the mutated list, so the optimistic tick stands.
          expect(merged.items.single.id, 'mjölk');
          expect(permissionCalls.single.granted, isTrue);
          expect(permissionCalls.single.details, contains('offline'));

          // The merge write is queued rather than awaited; it lands on the next
          // microtask against the fake.
          await Future<void>.delayed(Duration.zero);
          final snap = await firestore
              .collection(_sharedPath)
              .doc(saved.id)
              .get();
          final stored = (snap.data()!['items'] as List).cast<Map>();
          expect(stored.map((i) => i['id']), ['mjölk']);
        },
      );
    }

    // 'aborted' is retry contention on a WORKING connection — re-basing on the
    // cache there would drop another member's tick, so it must escape.
    test('an online failure code is rethrown, not absorbed', () async {
      final firestore = FakeFirebaseFirestore();
      final saved = await _routing(
        firestore,
      ).createCollaborativeList(_collabList());

      final module = _routing(
        firestore,
        transactionRunner: failsWith('aborted'),
      );

      await expectLater(
        () => module.mutateCollaborativeList(
          saved.id,
          (live) => live.copyWith(items: [_item('mjölk')]),
        ),
        throwsA(isA<FirebaseException>()),
      );

      final snap = await firestore.collection(_sharedPath).doc(saved.id).get();
      expect(snap.data()!['items'], isEmpty);
    });

    test('the offline path still refuses a view-only member', () async {
      final firestore = FakeFirebaseFirestore();
      final saved = await _routing(firestore).createCollaborativeList(
        UnifiedShoppingList.collaborative(
          name: 'Handla',
          ownerId: _userId,
          ownerDisplayName: 'Alice',
          memberPermissions: const {'bob': SharedListPermission.view},
        ),
      );

      final viewer = _routing(
        firestore,
        currentUid: 'bob',
        transactionRunner: failsWith('unavailable'),
      );

      await expectLater(
        () => viewer.mutateCollaborativeList(
          saved.id,
          (live) => live.copyWith(items: [_item('smyg')]),
        ),
        throwsA(isA<PermissionDeniedException>()),
      );

      await Future<void>.delayed(Duration.zero);
      final snap = await firestore.collection(_sharedPath).doc(saved.id).get();
      expect(snap.data()!['items'], isEmpty);
    });

    // Positive control for the denial below: same member, same leg, same
    // mutator shape — only the memberPermissions rewrite differs, so the
    // denial cannot be coming from anything but the escalation guard.
    test('the offline path lets an edit-level member tick items', () async {
      final firestore = FakeFirebaseFirestore();
      final saved = await _routing(
        firestore,
      ).createCollaborativeList(_collabList());

      final bob = _routing(
        firestore,
        currentUid: 'bob',
        transactionRunner: failsWith('unavailable'),
      );

      final merged = await bob.mutateCollaborativeList(
        saved.id,
        (live) => live.copyWith(items: [...live.items, _item('mjölk')]),
      );

      expect(merged.items.single.id, 'mjölk');
      await Future<void>.delayed(Duration.zero);
      final snap = await firestore.collection(_sharedPath).doc(saved.id).get();
      expect((snap.data()!['items'] as List), hasLength(1));
    });

    // The cached base makes the escalation check weaker, not unnecessary: this
    // leg persists a caller-shaped whole document too, and the queued write is
    // replayed by Firestore on reconnect without any further client check.
    test('the offline path refuses a self-promoting mutator', () async {
      final firestore = FakeFirebaseFirestore();
      final saved = await _routing(
        firestore,
      ).createCollaborativeList(_collabList());

      final permissionCalls = <_PermissionCall>[];
      final bob = _routing(
        firestore,
        permissionCalls: permissionCalls,
        currentUid: 'bob',
        transactionRunner: failsWith('unavailable'),
      );

      await expectLater(
        () => bob.mutateCollaborativeList(
          saved.id,
          (live) => live.copyWith(
            items: [...live.items, _item('mjölk')],
            memberPermissions: {
              ...live.memberPermissions,
              'bob': SharedListPermission.admin,
            },
          ),
        ),
        throwsA(isA<PermissionDeniedException>()),
      );

      // The offline write is queued rather than awaited, so drain a microtask
      // before asserting that nothing was queued at all.
      await Future<void>.delayed(Duration.zero);
      final snap = await firestore.collection(_sharedPath).doc(saved.id).get();
      expect(snap.data()!['memberPermissions'], {
        _userId: 'admin',
        'bob': 'edit',
      });
      expect(snap.data()!['items'], isEmpty);
      expect(permissionCalls.last.granted, isFalse);
      expect(permissionCalls.last.details, contains('memberPermissions'));
    });

    test('a missing cached doc surfaces as not-found', () async {
      final firestore = FakeFirebaseFirestore();
      final module = _routing(
        firestore,
        transactionRunner: failsWith('unavailable'),
      );

      await expectLater(
        () => module.mutateCollaborativeList('nope', (live) => live),
        throwsA(isA<ResourceNotFoundException>()),
      );
    });
  });
}
