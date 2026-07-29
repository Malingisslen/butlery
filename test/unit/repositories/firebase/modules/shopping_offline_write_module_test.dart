/// Unit tests for ShoppingOfflineWriteModule.
///
/// The offline half of collaborative shopping-list writes.
///
/// This file covers the two things the routing-module suite cannot:
/// `onReplayRejected`, which fires from a `catchError` on a queued write that
/// `FakeFirebaseFirestore` always resolves successfully, and the literal key
/// set of `cachedBasePayload`. The routing-module suite already proves the
/// resulting WRITE behaves; what it cannot see is the payload growing a
/// rule-locked key that happens not to change the stored document.
/// `appendedItems` and `appendPayload` are exercised there, not here.
library;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/core/exceptions/permission_exceptions.dart';
import 'package:butlery/models/unified/unified_shopping_item.dart';
import 'package:butlery/models/unified/unified_shopping_list.dart';
import 'package:butlery/repositories/firebase/modules/shopping_offline_write_module.dart';

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

UnifiedShoppingList _list({
  List<UnifiedShoppingItem>? items,
  Map<String, SharedListPermission>? memberPermissions,
  String name = 'Veckans handla',
}) {
  return UnifiedShoppingList.collaborative(
    name: name,
    ownerId: 'alice',
    ownerDisplayName: 'Alice',
    memberPermissions:
        memberPermissions ?? const {'bob': SharedListPermission.edit},
    items: items,
  );
}

UnifiedShoppingItem _item(String name) =>
    UnifiedShoppingItem(id: name, name: name, amount: 1);

/// [list] with an `ownerId` / `createdAt` the model's `copyWith` refuses to
/// move — the shape only a hand-assembled entity can produce, which is what
/// `ShoppingRepository.update` accepts from its callers.
UnifiedShoppingList _rebuilt(
  UnifiedShoppingList list, {
  String? ownerId,
  DateTime? createdAt,
}) => UnifiedShoppingList(
  id: list.id,
  name: list.name,
  ownerId: ownerId ?? list.ownerId,
  ownerDisplayName: list.ownerDisplayName,
  items: list.items,
  createdAt: createdAt ?? list.createdAt,
  updatedAt: list.updatedAt,
  type: list.type,
  memberPermissions: list.memberPermissions,
);

void main() {
  late List<_PermissionCall> calls;
  late ShoppingOfflineWriteModule module;

  setUp(() {
    calls = [];
    module = ShoppingOfflineWriteModule(
      logPermissionCheck:
          ({
            required String userId,
            required String resource,
            required String operation,
            required bool granted,
            String? details,
          }) => calls.add(
            _PermissionCall(userId, resource, operation, granted, details),
          ),
    );
  });

  group('onReplayRejected', () {
    // BUT-1696: the offline path logs an optimistic `granted: true` the moment
    // it queues the write. If the rules then refuse the replay, this row is the
    // ONLY place that claim gets retracted — Firestore rolls the local cache
    // back silently either way. Without this test the whole `if (denied)`
    // branch is deletable with the suite green.
    test('a permission-denied replay records a granted:false correction', () {
      module.onReplayRejected(
        'alice',
        'list-1',
        FirebaseException(plugin: 'cloud_firestore', code: 'permission-denied'),
      );

      expect(calls, hasLength(1));
      final call = calls.single;
      expect(call.userId, 'alice');
      expect(call.resource, 'collaborative_shopping_list');
      expect(call.operation, 'update');
      expect(call.granted, isFalse);
      expect(call.details, contains('list-1'));
      expect(call.details, contains('REJECTED'));
    });

    // The discriminator. A replay that failed because the phone is still in a
    // basement is not an access decision, and writing an audit row for it would
    // make the trail unreadable — every offline session would look like a
    // denial.
    test('a transport failure records no audit row', () {
      module.onReplayRejected(
        'alice',
        'list-1',
        FirebaseException(plugin: 'cloud_firestore', code: 'unavailable'),
      );
      module.onReplayRejected('alice', 'list-1', StateError('boom'));

      expect(calls, isEmpty);
    });
  });

  group('cachedBasePayload', () {
    // The literal key set, pinned. The routing-module test proves the write
    // behaves; this proves the payload cannot grow a rule-locked key by
    // accident — `update()` treats every key as a field path, so one extra
    // entry here is one extra field on the wire.
    test('carries only items and the activity stamp', () {
      final live = _list(items: [_item('mjölk')]);

      final payload = module.cachedBasePayload(live);

      expect(
        payload.keys,
        everyElement(
          isIn([
            'items',
            'updatedAt',
            'lastActivityAt',
            'lastActivityByUserId',
            'lastActivityByDisplayName',
          ]),
        ),
      );
      expect(payload.keys, contains('items'));
      expect(payload.keys, isNot(contains('ownerId')));
      expect(payload.keys, isNot(contains('memberPermissions')));
      expect(payload.keys, isNot(contains('createdAt')));
    });

    // A mutator that leaves the activity stamp unset must not queue nulls —
    // that would wipe another member's attribution on the server.
    //
    // The fixture has to be built with the plain constructor: the
    // `collaborative` factory stamps all four activity fields, which makes the
    // guard unreachable and the assertion a tautology.
    test('omits an activity field the mutator never stamped', () {
      final unstamped = UnifiedShoppingList(
        name: 'Veckans handla',
        ownerId: 'alice',
        ownerDisplayName: 'Alice',
        type: ListType.collaborative,
        items: [_item('mjölk')],
        memberPermissions: const {'bob': SharedListPermission.edit},
      );

      final payload = module.cachedBasePayload(unstamped);

      expect(payload.keys, contains('items'));
      expect(
        payload.keys,
        isNot(contains('lastActivityByUserId')),
        reason: 'an unstamped field must be absent, not queued as null',
      );
      expect(payload.keys, isNot(contains('lastActivityByDisplayName')));
    });
  });

  // BUT-1719: the whole-list write path (rename, member management) used to
  // `set(entity.toFirestore(), merge: true)`, which re-sent the ENTIRE member
  // map on every rename. `merge` unions map keys, so a caller whose copy
  // predated a removal handed the removed member their edit rights back — and
  // `merge` can never delete a key, so removing a member never stuck either.
  group('narrowUpdatePayload', () {
    test('a rename carries the name and nothing about membership', () {
      final stored = _list();
      final payload = module.narrowUpdatePayload(
        'alice',
        stored.copyWith(name: 'Söndagshandel'),
        stored,
        baseIsCached: false,
      );

      expect(payload['name'], 'Söndagshandel');
      expect(
        payload.keys.where((k) => k.startsWith('memberPermissions')),
        isEmpty,
      );
      expect(payload.keys, isNot(contains('ownerId')));
      expect(payload.keys, isNot(contains('createdAt')));
    });

    test('an offline rename against a stale cached base still goes through', () {
      // The ticket's exact scenario: this device has been offline since before
      // Bob was removed, so BOTH the cached base and the caller's copy still
      // list him. Nothing about membership differs, so nothing about
      // membership is written — the rename is not the moment to replay a
      // months-old access-control decision.
      final staleCache = _list();
      final payload = module.narrowUpdatePayload(
        'alice',
        staleCache.copyWith(name: 'Söndagshandel'),
        staleCache,
        baseIsCached: true,
      );

      expect(payload['name'], 'Söndagshandel');
      expect(
        payload.keys.where((k) => k.startsWith('memberPermissions')),
        isEmpty,
      );
    });

    test('removing a member emits a targeted delete, not a shrunken map', () {
      final stored = _list();
      final payload = module.narrowUpdatePayload(
        'alice',
        stored.copyWith(
          memberPermissions: const {'alice': SharedListPermission.admin},
        ),
        stored,
        baseIsCached: false,
      );

      expect(payload['memberPermissions.bob'], isA<FieldValue>());
      expect(
        payload.keys,
        isNot(contains('memberPermissions')),
        reason:
            'a whole-map value merges or replaces depending on the call '
            'used to write it; a field path does not',
      );
    });

    test('adding a member emits only that key', () {
      final stored = _list();
      final payload = module.narrowUpdatePayload(
        'alice',
        stored.copyWith(
          memberPermissions: const {
            'alice': SharedListPermission.admin,
            'bob': SharedListPermission.edit,
            'cecilia': SharedListPermission.view,
          },
        ),
        stored,
        baseIsCached: false,
      );

      expect(payload['memberPermissions.cecilia'], 'view');
      expect(payload.keys, isNot(contains('memberPermissions.bob')));
    });

    test('refuses a membership change made against a cached base', () {
      // Offline, "the caller changed memberPermissions" and "someone else
      // changed it while we were offline" look identical. Replaying the local
      // answer is how a removed member comes back, so this one waits for a
      // server read.
      final stored = _list();

      expect(
        () => module.narrowUpdatePayload(
          'alice',
          stored.copyWith(
            memberPermissions: const {'alice': SharedListPermission.admin},
          ),
          stored,
          baseIsCached: true,
        ),
        throwsA(isA<PermissionDeniedException>()),
      );
      expect(calls.single.granted, isFalse);
    });

    // `privilegedKeys` is a TRIPLE, and only `memberPermissions` had a leg.
    // The other two are reachable for exactly one caller — the OWNER, whose
    // `requireNoPrivilegeEscalation` returns early — so this refusal is the
    // only thing standing between an offline owner and replaying a stale
    // ownership transfer over whoever holds the list now.
    //
    // `copyWith` deliberately cannot move either field, so the mutation is
    // built with the plain constructor — which is exactly how the caller
    // reaches it: `updateCollaborativeList` is `ShoppingRepository.update`'s
    // collaborative leg and takes whatever entity the caller assembled.
    for (final (name, mutate)
        in <(String, UnifiedShoppingList Function(UnifiedShoppingList))>[
          ('ownerId', (l) => _rebuilt(l, ownerId: 'bob')),
          (
            'createdAt',
            (l) => _rebuilt(l, createdAt: DateTime.utc(2020, 1, 1)),
          ),
        ]) {
      test('refuses a $name change made against a cached base', () {
        final stored = _list();

        expect(
          () => module.narrowUpdatePayload(
            'alice',
            mutate(stored),
            stored,
            baseIsCached: true,
          ),
          throwsA(
            isA<PermissionDeniedException>().having(
              (e) => e.toString(),
              'names the refused field',
              contains(name),
            ),
          ),
        );
        expect(calls.single.granted, isFalse);
      });

      test('allows the same $name change against a SERVER base', () {
        // The recall control: the refusal is about the BASE being cached, not
        // about the field being untouchable. Without this a blanket "never
        // write these keys" regression reads as a passing safety test.
        final stored = _list();
        final payload = module.narrowUpdatePayload(
          'alice',
          mutate(stored),
          stored,
          baseIsCached: false,
        );

        expect(payload.keys, contains(name));
      });
    }

    test('an identical entity produces no write at all', () {
      final stored = _list();
      expect(
        module.narrowUpdatePayload(
          'alice',
          stored,
          stored,
          baseIsCached: false,
        ),
        isEmpty,
      );
    });
  });
}
