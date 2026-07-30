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
  Object? logPermissionCheckThrows,
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
    // BUT-1741: the module's callback is `Future<void> Function(...)`, so a
    // plain `void` closure no longer type-checks here.
    logPermissionCheck:
        ({
          required String userId,
          required String resource,
          required String operation,
          required bool granted,
          String? details,
        }) async {
          permissionCalls?.add(
            _PermissionCall(userId, resource, operation, granted, details),
          );
          if (logPermissionCheckThrows != null) {
            throw logPermissionCheckThrows;
          }
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

/// BUT-1758 (BUT-1733 AC2): the contributor-union invariant, asserted in ONE
/// place.
///
/// Every write path that persists `items` owes the erasure trail
/// (`contributorUserIds`), and each of the four write-site tests used to
/// hand-roll the same read-then-compare. Four copies is four places for a fifth
/// write path to be added with no assertion at all — which is exactly how
/// `updateCollaborativeList` became a trail-less fourth path (BUT-1733). One
/// helper makes the invariant a single named thing to reuse.
///
/// Set semantics, not list equality: the transactional path builds the array
/// from a Dart Set, so element order is not stable across writes. [because] is
/// required so a failure names the write path that skipped the union rather than
/// just printing two sets.
Future<void> _expectContributorTrail(
  FakeFirebaseFirestore firestore,
  String listId,
  Set<String> expected, {
  required String because,
}) async {
  final data = (await firestore.collection(_sharedPath).doc(listId).get())
      .data();
  final trail = data?[ShoppingRepositoryRoutingModule.contributorsField];
  expect(
    trail,
    isA<List<dynamic>>(),
    reason:
        'no contributorUserIds array on the stored list at all — $because '
        '(account erasure cannot FIND this list once the writer leaves it)',
  );
  expect(
    (trail as List).whereType<String>().toSet(),
    expected,
    reason: because,
  );
}

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
  // BUT-1741 acceptance 3. The injected audit sink is async, and a `void`
  // parameter type ACCEPTED the async implementation while dropping its
  // future — so a failing audit write escaped as an unhandled async error
  // nobody could attribute to a shopping list, and the call reported success.
  // Now the callback is `Future<void> Function(...)` and every call site
  // awaits, so a throwing sink surfaces at the caller. Written per write path,
  // because the covariance opt-out was per call site.
  group('a throwing audit write surfaces rather than vanishing', () {
    Object failingSink() => StateError('audit sink is down');

    test('on the create path', () async {
      final firestore = FakeFirebaseFirestore();
      final module = _routing(
        firestore,
        logPermissionCheckThrows: failingSink(),
      );

      await expectLater(
        () => module.createCollaborativeList(_collabList()),
        throwsA(isA<StateError>()),
      );
    });

    test('on the whole-list update path', () async {
      final firestore = FakeFirebaseFirestore();
      final saved = await _routing(
        firestore,
      ).createCollaborativeList(_collabList());

      final module = _routing(
        firestore,
        logPermissionCheckThrows: failingSink(),
      );
      await expectLater(
        () => module.updateCollaborativeList(saved.copyWith(name: 'Ny')),
        throwsA(isA<StateError>()),
      );
    });

    test('on the transactional mutate path', () async {
      final firestore = FakeFirebaseFirestore();
      final saved = await _routing(
        firestore,
      ).createCollaborativeList(_collabList());

      final module = _routing(
        firestore,
        logPermissionCheckThrows: failingSink(),
      );
      await expectLater(
        () => module.mutateCollaborativeList(
          saved.id,
          (live) => live.copyWith(name: 'Ny'),
        ),
        throwsA(isA<StateError>()),
      );
    });

    test('on a guard DENIAL, where the row is the only record of the '
        'refusal', () async {
      // The denial audit row is the one an operator reads after the fact. If
      // it fails silently the refusal still happens but leaves no trace, which
      // is the worst of the four cases and the reason this is not folded into
      // the three above.
      final firestore = FakeFirebaseFirestore();
      final saved = await _routing(
        firestore,
      ).createCollaborativeList(_collabList());

      // Cecilia is not a member at all, so requireEditRights refuses.
      final stranger = _routing(
        firestore,
        currentUid: 'cecilia',
        logPermissionCheckThrows: failingSink(),
      );
      await expectLater(
        () => stranger.updateCollaborativeList(saved.copyWith(name: 'Ny')),
        throwsA(isA<StateError>()),
      );
    });
  });

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
      // BUT-1706: `items` and `createdAt` are here because the create RULE
      // requires them — `hasRequiredFields(['ownerId', 'memberPermissions',
      // 'items', 'createdAt'])`. Without them the client granted a create the
      // server then refused, and the audit row recorded the grant. Keep this
      // list a superset of the rule's; `name` is a client-side extra.
      expect(call.requiredFields, [
        'name',
        'ownerId',
        'memberPermissions',
        'items',
        'createdAt',
      ]);
      expect(call.resourceType, 'collaborative_shopping_list');
      expect(call.data['name'], isNotNull);
      expect(
        call.data.keys,
        containsAll(<String>[
          'ownerId',
          'memberPermissions',
          'items',
          'createdAt',
        ]),
        reason:
            'the payload must actually carry every field the rule requires, or '
            'the widened guard would reject every legitimate create',
      );
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

    // The owner is the only role the Firestore rule lets touch the member map.
    // BUT-1726: member management (add/remove/permission/leave) now goes
    // through [updateCollaborativeListMembership], which is where the intent is
    // declared. Driven through THAT method, not by hand-passing the named
    // argument — the argument existing is not the same as production reaching
    // it, and hand-passing it here is exactly how the strip shipped unnoticed.
    test('the owner may still rewrite memberPermissions', () async {
      final firestore = FakeFirebaseFirestore();
      final owner = _routing(firestore);
      final saved = await owner.createCollaborativeList(_collabList());

      await owner.updateCollaborativeListMembership(
        saved.copyWith(
          memberPermissions: {
            ...saved.memberPermissions,
            'cecilia': SharedListPermission.view,
          },
        ),
        saved,
      );

      final snap = await firestore.collection(_sharedPath).doc(saved.id).get();
      expect(snap.data()!['memberPermissions'], {
        _userId: 'admin',
        'bob': 'edit',
        'cecilia': 'view',
      });
    });

    // BUT-1719. The payload-narrowing itself is pinned in
    // shopping_offline_write_module_test.dart, where `narrowUpdatePayload` can
    // be called directly (including the cached-base leg, which
    // FakeFirebaseFirestore cannot produce — it always reports isFromCache
    // false). What this layer proves is that the narrowed payload reaches
    // Firestore as an `update`, so a removal actually lands.
    //
    // `merge: true` could never DELETE a map key, so removing a member never
    // removed them server-side.
    test(
      'removing a member drops the key rather than merging it back',
      () async {
        final firestore = FakeFirebaseFirestore();
        final owner = _routing(firestore);
        final saved = await owner.createCollaborativeList(_collabList());

        await owner.updateCollaborativeListMembership(
          saved.copyWith(
            memberPermissions: {_userId: SharedListPermission.admin},
          ),
          saved,
        );

        final snap = await firestore
            .collection(_sharedPath)
            .doc(saved.id)
            .get();
        expect(snap.data()!['memberPermissions'], isNot(contains('bob')));
      },
    );

    test('writes nothing when the entity matches the stored doc', () async {
      final firestore = FakeFirebaseFirestore();
      final owner = _routing(firestore);
      final saved = await owner.createCollaborativeList(_collabList());

      // Count WRITES, not values. Comparing the document before and after
      // cannot tell "skipped the write" from "wrote the identical bytes back",
      // so `if (payload.isNotEmpty)` stays green when deleted — and the whole
      // point of the narrowing is that an unchanged field must not be RE-SENT,
      // because the rule compares `diff(resource.data).affectedKeys()`. A
      // snapshot listener fires once per write regardless of whether the
      // stored value moved.
      var writes = 0;
      final sub = firestore
          .collection(_sharedPath)
          .doc(saved.id)
          .snapshots()
          .listen((_) => writes++);
      await pumpEventQueue();
      final afterSubscribe = writes;

      await owner.updateCollaborativeList(saved);
      await pumpEventQueue();
      expect(
        writes,
        afterSubscribe,
        reason: 'an identical entity must not reach Firestore at all',
      );

      // Positive control in the SAME fixture: one changed field DOES write, so
      // the assertion above cannot be passing because the listener is dead.
      await owner.updateCollaborativeList(
        saved.copyWith(name: 'Söndagshandel'),
      );
      await pumpEventQueue();
      expect(writes, greaterThan(afterSubscribe));

      await sub.cancel();
    });
  });

  // BUT-1726. `updateCollaborativeList` takes a WHOLE entity and works out
  // "what the caller changed" by diffing it against a fresh server read. The
  // caller's entity is an in-memory copy the view has been holding, so
  // anything that moved on the server since then reads as a deliberate edit —
  // and for `memberPermissions` that turns pure staleness into an ACL rewrite.
  // Nothing caught it: the escalation guard returns early for the owner, and
  // `baseIsCached` asked whether the FRESH READ came from cache, which is a
  // question about the side that is never stale.
  //
  // `fake_cloud_firestore.update()` deep-merges nested maps, so "another
  // device changed the membership" has to be staged with `set()`.
  group('a stale in-memory base', () {
    Future<void> rewriteMembers(
      FakeFirebaseFirestore firestore,
      String listId,
      Map<String, String> members,
    ) async {
      final ref = firestore.collection(_sharedPath).doc(listId);
      final data = (await ref.get()).data()!;
      await ref.set({...data, 'memberPermissions': members});
    }

    test('a rename does not resurrect a member removed elsewhere', () async {
      final firestore = FakeFirebaseFirestore();
      final owner = _routing(firestore);
      // `saved` is the copy Alice's tablet is holding: it still lists Bob.
      final saved = await owner.createCollaborativeList(_collabList());
      // Alice removed Bob from her phone.
      await rewriteMembers(firestore, saved.id, {_userId: 'admin'});

      await owner.updateCollaborativeList(
        saved.copyWith(name: 'Söndagshandel'),
      );

      final data = (await firestore.collection(_sharedPath).doc(saved.id).get())
          .data()!;
      expect(data['name'], 'Söndagshandel', reason: 'the rename must land');
      expect(
        (data['memberPermissions'] as Map).keys,
        isNot(contains('bob')),
        reason:
            'the tablet never touched the member map; its stale copy of it '
            'must not be replayed as an ACL change',
      );
    });

    test('a rename does not revoke a member added elsewhere', () async {
      final firestore = FakeFirebaseFirestore();
      final owner = _routing(firestore);
      final saved = await owner.createCollaborativeList(_collabList());
      await rewriteMembers(firestore, saved.id, {
        _userId: 'admin',
        'bob': 'edit',
        'cecilia': 'view',
      });

      await owner.updateCollaborativeList(
        saved.copyWith(name: 'Söndagshandel'),
      );

      final data = (await firestore.collection(_sharedPath).doc(saved.id).get())
          .data()!;
      expect(
        (data['memberPermissions'] as Map).keys,
        contains('cecilia'),
        reason:
            'the mirror image: the stale copy lacks Cecilia, and a rename must '
            'not emit the FieldValue.delete() that absence looks like',
      );
    });

    // BUT-1726 review: the guard shipped opt-in and NOTHING opted in, so every
    // membership operation wrote `updatedAt` alone and reported success. The
    // suite stayed green because its ACL tests hand-passed the named argument.
    // These two pin the split from the other side: the membership entry point
    // must LAND an ACL edit with no test-only argument in sight, and the plain
    // update must not, so widening the strip reddens something.
    test('the membership entry point lands the ACL edit', () async {
      final firestore = FakeFirebaseFirestore();
      final owner = _routing(firestore);
      final saved = await owner.createCollaborativeList(_collabList());

      await owner.updateCollaborativeListMembership(
        saved.copyWith(
          memberPermissions: {_userId: SharedListPermission.admin},
        ),
        saved,
      );

      final data = (await firestore.collection(_sharedPath).doc(saved.id).get())
          .data()!;
      expect(
        (data['memberPermissions'] as Map).keys,
        isNot(contains('bob')),
        reason:
            'a household member removed in the UI must be removed on the '
            'server, not merely from the copy the caller holds',
      );
    });

    test('the content path leaves the ACL exactly as it found it', () async {
      final firestore = FakeFirebaseFirestore();
      final owner = _routing(firestore);
      final saved = await owner.createCollaborativeList(_collabList());

      // The same removal, submitted as a content edit. The rename lands; the
      // ACL does not move, because this path cannot tell a removal from a
      // stale copy.
      await owner.updateCollaborativeList(
        saved.copyWith(
          name: 'Söndagshandel',
          memberPermissions: {_userId: SharedListPermission.admin},
        ),
      );

      final data = (await firestore.collection(_sharedPath).doc(saved.id).get())
          .data()!;
      expect(data['name'], 'Söndagshandel');
      expect((data['memberPermissions'] as Map).keys, contains('bob'));
    });

    test('a personal list cannot be routed through membership', () async {
      final firestore = FakeFirebaseFirestore();
      final owner = _routing(firestore);
      final saved = await owner.createCollaborativeList(_collabList());
      final personal = UnifiedShoppingList(
        id: saved.id,
        name: saved.name,
        ownerId: saved.ownerId,
        ownerDisplayName: saved.ownerDisplayName,
        items: saved.items,
        type: ListType.personal,
        memberPermissions: saved.memberPermissions,
      );

      expect(
        () => owner.updateCollaborativeListMembership(personal, saved),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('the dropped access-control paths are audited', () async {
      final firestore = FakeFirebaseFirestore();
      final permissionCalls = <_PermissionCall>[];
      final owner = _routing(firestore, permissionCalls: permissionCalls);
      final saved = await owner.createCollaborativeList(_collabList());
      await rewriteMembers(firestore, saved.id, {_userId: 'admin'});
      permissionCalls.clear();

      await owner.updateCollaborativeList(saved.copyWith(name: 'Ny lista'));

      final dropped = permissionCalls.where((c) => !c.granted);
      expect(dropped, hasLength(1));
      expect(dropped.single.details, contains('memberPermissions'));
      expect(dropped.single.details, contains('dropped'));
    });

    // The declared-intent leg. A caller that IS managing membership hands over
    // the base it computed the change from; if the server has moved past that
    // base, the answer being replayed was computed against state that no
    // longer exists, so it is refused rather than applied.
    test('a declared membership change on a stale base is refused', () async {
      final firestore = FakeFirebaseFirestore();
      final permissionCalls = <_PermissionCall>[];
      final owner = _routing(firestore, permissionCalls: permissionCalls);
      final saved = await owner.createCollaborativeList(_collabList());
      await rewriteMembers(firestore, saved.id, {_userId: 'admin'});
      permissionCalls.clear();

      await expectLater(
        () => owner.updateCollaborativeListMembership(
          saved.copyWith(
            memberPermissions: {
              ...saved.memberPermissions,
              'cecilia': SharedListPermission.view,
            },
          ),
          saved,
        ),
        // The specific subtype, because the WORDING turns on it: the owner is
        // not missing a right, their copy is old, and only that story tells
        // them to reload. `shoppingFailureMessage` switches on this type.
        throwsA(isA<StaleAccessControlBaseException>()),
      );

      final data = (await firestore.collection(_sharedPath).doc(saved.id).get())
          .data()!;
      expect((data['memberPermissions'] as Map).keys, isNot(contains('bob')));
      expect(
        (data['memberPermissions'] as Map).keys,
        isNot(contains('cecilia')),
      );
      expect(permissionCalls.last.granted, isFalse);
    });
  });

  // BUT-1725: the erasure trail. Account deletion finds a user's shared lists
  // by membership or ownership, and a user who LEFT a list has neither — while
  // their name stays on every item they added. `contributorUserIds` is the
  // append-only handle that makes those lists reachable, so it has to be
  // written by the same paths that stamp the attribution.
  group('contributorUserIds', () {
    test('seats the creator on create', () async {
      final firestore = FakeFirebaseFirestore();
      final saved = await _routing(
        firestore,
      ).createCollaborativeList(_collabList());

      await _expectContributorTrail(
        firestore,
        saved.id,
        {_userId},
        because:
            'a list created from a conversion arrives with items already '
            'stamped addedByUserId, and those never pass the mutate path',
      );
    });

    test('unions an item-writing member who is not the owner', () async {
      final firestore = FakeFirebaseFirestore();
      final saved = await _routing(
        firestore,
      ).createCollaborativeList(_collabList());

      final bob = _routing(firestore, currentUid: 'bob');
      await bob.mutateCollaborativeList(
        saved.id,
        (live) => live.copyWith(items: [...live.items, _item('mjolk')]),
      );

      await _expectContributorTrail(
        firestore,
        saved.id,
        {_userId, 'bob'},
        because: 'the transactional item path must union the writer in',
      );
    });

    // BUT-1733: `updateCollaborativeList` is the fourth write path, and it
    // persisted the whole `items` array while contributing nothing to the
    // trail — so a member whose only edits went through the whole-list path
    // (a converted list, a bulk item rewrite) stayed invisible to erasure.
    test('a whole-list update that writes items extends the trail', () async {
      final firestore = FakeFirebaseFirestore();
      final saved = await _routing(
        firestore,
      ).createCollaborativeList(_collabList());

      final bob = _routing(firestore, currentUid: 'bob');
      await bob.updateCollaborativeList(
        saved.copyWith(items: [_item('mjölk')]),
      );

      await _expectContributorTrail(
        firestore,
        saved.id,
        {_userId, 'bob'},
        because:
            'the whole-list path persists the items array, so it owes the '
            'trail exactly as the transactional path does (BUT-1733)',
      );
    });

    // The discriminator: the trail records who touched the ROWS, because it
    // exists to find a list whose items still carry someone's name. Opening
    // the settings is not that, and stamping it would grow an array the rule
    // caps at 200 entries.
    test('a rename alone does not extend the trail', () async {
      final firestore = FakeFirebaseFirestore();
      final saved = await _routing(
        firestore,
      ).createCollaborativeList(_collabList());

      final bob = _routing(firestore, currentUid: 'bob');
      await bob.updateCollaborativeList(saved.copyWith(name: 'Söndagshandel'));

      final snap = await firestore.collection(_sharedPath).doc(saved.id).get();
      expect(snap.data()!['name'], 'Söndagshandel');
      // Same helper as the positive sites, so the negative case is stated in
      // the same terms: bob must be ABSENT, not merely "the set is short".
      await _expectContributorTrail(
        firestore,
        saved.id,
        {_userId},
        because:
            'a rename persists no items, so it must not stamp the writer — '
            'the trail records who touched the ROWS',
      );
    });

    // The OFFLINE leg. Every test above drives an ONLINE write — the create,
    // the transaction, and the whole-list update — so `_withContributorTrail`
    // on the QUEUED payload was unasserted, and deleting it there left the
    // whole group green. A shop-aisle edit is the likeliest way a
    // member ever touches a list they later leave, so it is precisely the case
    // where the erasure handle must still be written: without it, that user's
    // name stays on the row and account deletion can no longer find the list.
    test('an offline edit still extends the trail', () async {
      final firestore = FakeFirebaseFirestore();
      final saved = await _routing(
        firestore,
      ).createCollaborativeList(_collabList());
      await firestore.collection(_sharedPath).doc(saved.id).update({
        'items': [_item('mjölk').toFirestore()],
      });

      final bob = _routing(
        firestore,
        currentUid: 'bob',
        transactionRunner: (_) async => throw FirebaseException(
          plugin: 'cloud_firestore',
          code: 'unavailable',
        ),
      );
      // A tick, not an append: an append takes BUT-1683's arrayUnion fast path,
      // which is a different payload builder. Both must carry the trail.
      await bob.mutateCollaborativeList(
        saved.id,
        (live) =>
            live.copyWith(items: [live.items.single.copyWith(bought: true)]),
      );

      await _expectContributorTrail(
        firestore,
        saved.id,
        {_userId, 'bob'},
        because:
            'the offline cached-base payload must carry the trail too — a '
            'shop-aisle tick is how a member touches a list they later leave',
      );
    });

    test('an offline append still extends the trail', () async {
      final firestore = FakeFirebaseFirestore();
      final saved = await _routing(
        firestore,
      ).createCollaborativeList(_collabList());

      final bob = _routing(
        firestore,
        currentUid: 'bob',
        transactionRunner: (_) async => throw FirebaseException(
          plugin: 'cloud_firestore',
          code: 'unavailable',
        ),
      );
      await bob.mutateCollaborativeList(
        saved.id,
        (live) => live.copyWith(items: [...live.items, _item('bröd')]),
      );

      await _expectContributorTrail(
        firestore,
        saved.id,
        {_userId, 'bob'},
        because:
            "the append fast path (BUT-1683's arrayUnion) is a DIFFERENT "
            'payload builder from the cached-base one, and owes the same trail',
      );
    });

    // BUT-1706: the offline payload carries `items` plus the activity stamp and
    // NOTHING else, and that used to be a comment. A mutator that appended a row
    // and renamed the list queued only the row, returned the renamed object to
    // the caller, and the rename was gone on the next read — success reported,
    // change lost. No live mutator does this; the guard exists for the next one.
    test('an offline mutation that also renames the list is REFUSED, not '
        'silently stripped', () async {
      final firestore = FakeFirebaseFirestore();
      final saved = await _routing(
        firestore,
      ).createCollaborativeList(_collabList());

      final bob = _routing(
        firestore,
        currentUid: 'bob',
        transactionRunner: (_) async => throw FirebaseException(
          plugin: 'cloud_firestore',
          code: 'unavailable',
        ),
      );

      await expectLater(
        bob.mutateCollaborativeList(
          saved.id,
          (live) => live.copyWith(
            items: [...live.items, _item('bröd')],
            name: 'Söndagshandel',
          ),
        ),
        throwsA(
          isA<ArgumentError>().having(
            (e) => e.message.toString(),
            'message',
            contains('dropped silently'),
          ),
        ),
      );

      final snap = await firestore.collection(_sharedPath).doc(saved.id).get();
      // `items` is the FALSIFIABLE half: without the guard the append reaches
      // the arrayUnion payload and this row lands, so 0-vs-1 discriminates.
      // `name` alone cannot — the offline payload never carries it in either
      // world, so that assertion holds whether the guard exists or not.
      expect(
        snap.data()!['items'],
        isEmpty,
        reason:
            'a refused mutation must not half-apply: the appended row must NOT '
            'have been queued',
      );
      expect(
        snap.data()!['name'],
        'Veckans handla',
        reason: 'and the rename it was refused for must not be stored either',
      );
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
