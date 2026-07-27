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
}
