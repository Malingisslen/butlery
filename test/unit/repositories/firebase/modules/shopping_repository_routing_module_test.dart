/// Unit tests for ShoppingRepositoryRoutingModule.
///
/// The module routes collaborative-list CRUD to the shared collection
/// (/unified_shared_shopping_lists). It depends on a firestore handle,
/// an auth repository, a shared-collection ref, and four injected
/// callables. We pin the contract by driving each public method against
/// FakeFirebaseFirestore and capturing every callback invocation.
library;

// The BUT-1696 cache-miss test mocks two sealed cloud_firestore types; that is
// the only way to make a `Source.cache` read THROW the way real Firestore does
// (fake_cloud_firestore ignores GetOptions entirely).
// ignore_for_file: subtype_of_sealed_class

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

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
  CollectionReference<Map<String, dynamic>>? sharedListsRef,
  UnifiedShoppingList Function(DocumentSnapshot<Map<String, dynamic>>)?
  fromFirestore,
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
    sharedListsRef: sharedListsRef ?? firestore.collection(_sharedPath),
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
    fromFirestore: fromFirestore ?? UnifiedShoppingList.fromFirestore,
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

UnifiedShoppingList _collabList({
  String name = 'Veckans handla',
  List<UnifiedShoppingItem>? items,
}) {
  return UnifiedShoppingList.collaborative(
    name: name,
    ownerId: _userId,
    ownerDisplayName: 'Alice',
    memberPermissions: const {'bob': SharedListPermission.edit},
    items: items,
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
    //
    // The mutator TICKS an existing row deliberately. An append would take
    // BUT-1683's arrayUnion fast path instead, and then neither code would ever
    // exercise the cached-base leg — the one that carries the accepted
    // lost-update deviation and is the whole reason this group exists. This is
    // also the half of BUT-1683's decision that must stay deliberate: an edit
    // of an EXISTING row has no offline-mergeable primitive.
    for (final code in ['unavailable', 'deadline-exceeded']) {
      test(
        '$code falls back to the cached base and returns the tick',
        () async {
          final firestore = FakeFirebaseFirestore();
          final saved = await _routing(
            firestore,
          ).createCollaborativeList(_collabList());
          await firestore.collection(_sharedPath).doc(saved.id).update({
            'items': [_item('mjölk').toFirestore()],
          });

          final permissionCalls = <_PermissionCall>[];
          final offline = _routing(
            firestore,
            permissionCalls: permissionCalls,
            transactionRunner: failsWith(code),
          );
          permissionCalls.clear();

          final merged = await offline.mutateCollaborativeList(
            saved.id,
            (live) => live.copyWith(
              items: [live.items.single.copyWith(bought: true)],
            ),
          );

          // The caller gets the mutated list, so the optimistic tick stands.
          expect(merged.items.single.bought, isTrue);
          expect(permissionCalls.single.granted, isTrue);
          expect(permissionCalls.single.details, contains('cached-base'));

          // The merge write is queued rather than awaited; it lands on the next
          // microtask against the fake.
          await Future<void>.delayed(Duration.zero);
          final snap = await firestore
              .collection(_sharedPath)
              .doc(saved.id)
              .get();
          final stored = (snap.data()!['items'] as List).cast<Map>();
          expect(stored.single['bought'], isTrue);
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
    test('the offline path lets an edit-level member add items', () async {
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

    // BUT-1696 #3: the test above passes only because fake_cloud_firestore
    // ignores GetOptions.source and hands back a non-existent snapshot. REAL
    // Firestore THROWS `unavailable` on a Source.cache miss, so that branch
    // never fired in production and an offline mutation of a never-seen list
    // escaped as a raw FirebaseException. This pins the production shape.
    test('a cache read that THROWS also surfaces as not-found', () async {
      registerFallbackValue(const GetOptions());
      final firestore = FakeFirebaseFirestore();
      final collection = _MockCollectionRef();
      final doc = _MockDocRef();
      when(() => collection.doc(any())).thenReturn(doc);
      when(() => doc.get(any())).thenThrow(
        FirebaseException(plugin: 'cloud_firestore', code: 'unavailable'),
      );

      final module = _routing(
        firestore,
        sharedListsRef: collection,
        transactionRunner: failsWith('unavailable'),
      );

      await expectLater(
        () => module.mutateCollaborativeList('never-seen', (live) => live),
        throwsA(isA<ResourceNotFoundException>()),
      );
    });

    // BUT-1683: the narrowed offline path. An APPEND is queued as an
    // arrayUnion, so a row the client's cache never saw is still there after
    // the replay. Under the old whole-array write "bröd" would be gone.
    test(
      'an offline append unions rather than overwriting the array',
      () async {
        final firestore = FakeFirebaseFirestore();
        final saved = await _routing(
          firestore,
        ).createCollaborativeList(_collabList());

        // Bob added "bröd" from his phone while Alice was offline.
        await firestore.collection(_sharedPath).doc(saved.id).update({
          'items': [_item('bröd').toFirestore()],
        });

        final permissionCalls = <_PermissionCall>[];
        final offline = _routing(
          firestore,
          permissionCalls: permissionCalls,
          transactionRunner: failsWith('unavailable'),
          // Alice's cached copy predates Bob's add — the divergence the fake
          // cannot produce on its own.
          fromFirestore: (doc) =>
              UnifiedShoppingList.fromFirestore(doc).copyWith(items: const []),
        );
        permissionCalls.clear();

        final merged = await offline.mutateCollaborativeList(
          saved.id,
          (live) => live.copyWith(items: [...live.items, _item('mjölk')]),
        );
        expect(merged.items.single.id, 'mjölk');
        expect(permissionCalls.single.details, contains('append-only'));

        await Future<void>.delayed(Duration.zero);
        final snap = await firestore
            .collection(_sharedPath)
            .doc(saved.id)
            .get();
        final stored = (snap.data()!['items'] as List).cast<Map>();
        expect(stored.map((i) => i['id']), containsAll(['bröd', 'mjölk']));
      },
    );

    // BUT-1683/BUT-1697: the append payload is a HAND-BUILT narrow map, not
    // the serialized list, so both halves of it need pinning. The activity
    // stamp must ride along — a replayed row landing under the PREVIOUS
    // editor's name is exactly the defect BUT-1697 removed elsewhere — and the
    // three keys the update rule forbids a non-owner from touching must stay
    // out, or the whole replay is rejected for a member who only ticked a box.
    // Nothing else in this file reads either field on the offline path.
    test(
      'the queued append carries the activity stamp and no rule-locked key',
      () async {
        final firestore = FakeFirebaseFirestore();
        final saved = await _routing(
          firestore,
        ).createCollaborativeList(_collabList());
        final createdAtBefore =
            (await firestore.collection(_sharedPath).doc(saved.id).get())
                    .data()!['createdAt']
                as Timestamp;

        final offline = _routing(
          firestore,
          transactionRunner: failsWith('unavailable'),
        );

        await offline.mutateCollaborativeList(
          saved.id,
          // Owner-driven, so the escalation guard returns early and cannot be
          // what keeps createdAt in place.
          (live) => UnifiedShoppingList(
            id: live.id,
            name: live.name,
            ownerId: live.ownerId,
            ownerDisplayName: live.ownerDisplayName,
            items: [...live.items, _item('mjölk')],
            createdAt: live.createdAt.subtract(const Duration(days: 365)),
            type: ListType.collaborative,
            memberPermissions: live.memberPermissions,
            lastActivityAt: live.lastActivityAt,
            lastActivityByUserId: 'bob',
            lastActivityByDisplayName: 'Bob Bergman',
          ),
        );
        await Future<void>.delayed(Duration.zero);

        final data =
            (await firestore.collection(_sharedPath).doc(saved.id).get())
                .data()!;
        expect((data['items'] as List), hasLength(1));
        expect(data['lastActivityByUserId'], 'bob');
        expect(data['lastActivityByDisplayName'], 'Bob Bergman');
        expect(
          data['createdAt'],
          createdAtBefore,
          reason:
              'createdAt is in the rule\'s forbidden triple — the narrowed '
              'append write must never carry it',
        );
      },
    );

    // The security twin of the append test above, and the one that was missing
    // when the narrowing landed. A TICK is not an append, so it queues the
    // cached-base payload — which used to be `set(mutated.toFirestore(),
    // merge: true)`, i.e. the whole cached document. If the cache is stale for
    // `memberPermissions`, that replay silently reinstates a member the owner
    // removed from another device. Reverting `cachedBasePayload` to the old
    // whole-document write must redden HERE; nothing else covers it.
    test(
      'the queued cached-base write carries no rule-locked key',
      () async {
        final firestore = FakeFirebaseFirestore();
        final saved = await _routing(
          firestore,
        ).createCollaborativeList(_collabList(items: [_item('mjölk')]));

        // The stale ACL has to come from the MUTATOR, not from the stored doc:
        // `fake_cloud_firestore` ignores `GetOptions.source`, so the "cached"
        // read returns current server state and a doc-level divergence cannot
        // be staged. A mutator that carries the pre-removal permission map is
        // the same shape — the payload the offline path is about to queue holds
        // a member the server no longer has.
        //
        // Owner-driven, so the escalation guard returns early and cannot be
        // what keeps the map out of the write.
        final offline = _routing(
          firestore,
          transactionRunner: failsWith('unavailable'),
        );
        await offline.mutateCollaborativeList(
          saved.id,
          (live) => UnifiedShoppingList(
            id: live.id,
            name: live.name,
            ownerId: live.ownerId,
            ownerDisplayName: live.ownerDisplayName,
            items: [live.items.single.copyWith(bought: true)],
            createdAt: live.createdAt,
            type: ListType.collaborative,
            memberPermissions: const {
              'bob': SharedListPermission.edit,
              'carol': SharedListPermission.edit,
            },
            lastActivityAt: live.lastActivityAt,
          ),
        );
        await Future<void>.delayed(Duration.zero);

        final data =
            (await firestore.collection(_sharedPath).doc(saved.id).get())
                .data()!;
        expect(
          (data['items'] as List).single['bought'],
          isTrue,
          reason: 'the tick itself must still land',
        );
        expect(
          (data['memberPermissions'] as Map).keys,
          isNot(contains('carol')),
          reason:
              'a cached-base replay must never carry memberPermissions — an '
              'owner-authored write would silently reinstate whatever the '
              'stale copy said, including a member removed elsewhere',
        );
      },
    );
  });

  // BUT-1696 #4: the third write path in this module used to log
  // `granted: true` behind no client-side decision at all.
  group('createCollaborativeList authorization', () {
    // The create rule has TWO conjuncts and the existing test below fails the
    // FIRST one, so it cannot tell whether the second is enforced at all —
    // classic sibling-branch short-circuit. The plain constructor is the
    // reachable route: unlike the `collaborative` factory it does not seat the
    // owner, and it is on the public interface.
    test('refuses a list that does not seat the creator as a member', () async {
      final firestore = FakeFirebaseFirestore();
      final permissionCalls = <_PermissionCall>[];
      final module = _routing(firestore, permissionCalls: permissionCalls);

      await expectLater(
        () => module.createCollaborativeList(
          UnifiedShoppingList(
            name: 'Handla',
            ownerId: _userId,
            ownerDisplayName: 'Alice',
            type: ListType.collaborative,
            memberPermissions: const {'bob': SharedListPermission.edit},
          ),
        ),
        throwsA(isA<PermissionDeniedException>()),
      );

      expect(permissionCalls.single.granted, isFalse);
      expect(permissionCalls.single.details, contains('memberPermissions'));
      expect((await firestore.collection(_sharedPath).get()).docs, isEmpty);
    });

    test('refuses to create a list owned by someone else', () async {
      final firestore = FakeFirebaseFirestore();
      final permissionCalls = <_PermissionCall>[];
      final module = _routing(firestore, permissionCalls: permissionCalls);

      await expectLater(
        () => module.createCollaborativeList(
          UnifiedShoppingList.collaborative(
            name: 'Handla',
            ownerId: 'bob',
            ownerDisplayName: 'Bob',
            memberPermissions: const {_userId: SharedListPermission.edit},
          ),
        ),
        throwsA(isA<PermissionDeniedException>()),
      );

      expect(permissionCalls.single.granted, isFalse);
      expect(permissionCalls.single.operation, 'create');
      final docs = await firestore.collection(_sharedPath).get();
      expect(docs.docs, isEmpty);
    });
  });

  // BUT-1683 security review: the rule's forbidden-key set for a non-owner is
  // ownerId / memberPermissions / createdAt. The client guard only mirrored
  // the first two, so a whole-list write moving createdAt was audited as a
  // grant and then refused by the server.
  group('privilege-escalation parity with the Firestore rule', () {
    test('a non-owner may not move createdAt', () async {
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
      permissionCalls.clear();

      final moved = UnifiedShoppingList(
        id: saved.id,
        name: saved.name,
        ownerId: saved.ownerId,
        ownerDisplayName: saved.ownerDisplayName,
        items: saved.items,
        createdAt: saved.createdAt.subtract(const Duration(days: 365)),
        type: ListType.collaborative,
        memberPermissions: saved.memberPermissions,
      );

      await expectLater(
        () => bob.updateCollaborativeList(moved),
        throwsA(isA<PermissionDeniedException>()),
      );
      expect(permissionCalls.last.granted, isFalse);
      expect(permissionCalls.last.details, contains('createdAt'));
    });
  });
}

class _MockCollectionRef extends Mock
    implements CollectionReference<Map<String, dynamic>> {}

class _MockDocRef extends Mock
    implements DocumentReference<Map<String, dynamic>> {}
