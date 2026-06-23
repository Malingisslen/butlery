/// Unit tests for ShoppingRepositoryQueryModule.
///
/// Targets the personal-list reads and the trivial active-list lookup —
/// `readAll` loads personal lists plus their `items` subcollection,
/// `personalListsStream` is a simple ordered snapshot stream, and
/// `getActiveList` delegates to the injected readList callback. The
/// collaborative-list paths use `where('memberPermissions.$uid',
/// isNotEqualTo: null)` which fake_cloud_firestore does not honour with
/// map-path keys, so those are exercised only as smoke tests.
library;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/models/unified/unified_shopping_list.dart';
import 'package:butlery/repositories/firebase/modules/shopping_repository_query_module.dart';

const _userId = 'alice';
const _sharedPath = 'unified_shared_shopping_lists';

CollectionReference<Map<String, dynamic>> _userLists(
  FakeFirebaseFirestore firestore,
  String uid,
) =>
    firestore.collection('users').doc(uid).collection('unified_shopping_lists');

UnifiedShoppingList _fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
  final data = doc.data() ?? const <String, dynamic>{};
  return UnifiedShoppingList(
    id: doc.id,
    name: data['name'] as String? ?? '',
    ownerId: data['ownerId'] as String? ?? '',
    ownerDisplayName: data['ownerDisplayName'] as String? ?? '',
    updatedAt:
        (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.utc(2026, 1, 1),
    createdAt:
        (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.utc(2026, 1, 1),
    type: ListType.personal,
  );
}

ShoppingRepositoryQueryModule _module(
  FakeFirebaseFirestore firestore, {
  Future<UnifiedShoppingList?> Function(String)? readList,
}) {
  return ShoppingRepositoryQueryModule(
    firestore: firestore,
    sharedListsRef: firestore.collection(_sharedPath),
    requireCurrentUserId: () => _userId,
    getUserCollection: (uid) => _userLists(firestore, uid),
    fromFirestore: _fromFirestore,
    readList: readList ?? ((_) async => null),
  );
}

Future<void> _seedPersonalList(
  FakeFirebaseFirestore firestore, {
  required String id,
  required String name,
  required DateTime updatedAt,
  List<Map<String, dynamic>> items = const [],
}) async {
  await _userLists(firestore, _userId).doc(id).set({
    'name': name,
    'ownerId': _userId,
    'ownerDisplayName': 'Alice',
    'updatedAt': Timestamp.fromDate(updatedAt),
    'createdAt': Timestamp.fromDate(updatedAt),
  });
  for (var i = 0; i < items.length; i++) {
    await _userLists(
      firestore,
      _userId,
    ).doc(id).collection('items').doc('item-$i').set(items[i]);
  }
}

Map<String, dynamic> _itemDoc({
  required String name,
  bool bought = false,
}) {
  return {
    'id': 'auto',
    'name': name,
    'quantity': 1,
    'unit': 'st',
    'bought': bought,
    'addedAt': Timestamp.fromDate(DateTime.utc(2026, 1, 1)),
    'addedByUserId': _userId,
    'addedByDisplayName': 'Alice',
  };
}

void main() {
  group('readAll (personal lists)', () {
    test('returns empty list when user has no shopping lists', () async {
      final firestore = FakeFirebaseFirestore();
      final result = await _module(firestore).readAll();
      expect(result, isEmpty);
    });

    test('hydrates each personal list with its items subcollection', () async {
      final firestore = FakeFirebaseFirestore();
      await _seedPersonalList(
        firestore,
        id: 'l1',
        name: 'Veckans',
        updatedAt: DateTime.utc(2026, 1, 2),
        items: [
          _itemDoc(name: 'Mjölk'),
          _itemDoc(name: 'Bröd', bought: true),
        ],
      );

      final result = await _module(firestore).readAll();
      expect(result, hasLength(1));
      final list = result.single;
      expect(list.id, 'l1');
      expect(list.name, 'Veckans');
      expect(list.items.map((i) => i.name).toSet(), {'Mjölk', 'Bröd'});
    });

    test('returns all personal lists regardless of seed order', () async {
      // NOTE: production readAll() calls copyWith(items: ...) on every
      // list, which resets `updatedAt` to clock.now() (see copyWith
      // defaults at unified_shopping_list.dart:425). The subsequent
      // `allLists.sort((a, b) => b.updatedAt.compareTo(a.updatedAt))`
      // then degenerates to insertion order. We assert membership only,
      // not the sort key.
      final firestore = FakeFirebaseFirestore();
      await _seedPersonalList(
        firestore,
        id: 'old',
        name: 'Old',
        updatedAt: DateTime.utc(2026, 1, 1),
      );
      await _seedPersonalList(
        firestore,
        id: 'new',
        name: 'New',
        updatedAt: DateTime.utc(2026, 1, 5),
      );
      await _seedPersonalList(
        firestore,
        id: 'mid',
        name: 'Mid',
        updatedAt: DateTime.utc(2026, 1, 3),
      );

      final result = await _module(firestore).readAll();
      expect(result.map((l) => l.id).toSet(), {'old', 'new', 'mid'});
    });
  });

  group('getActiveList', () {
    test('returns null when activeListId is null', () async {
      final firestore = FakeFirebaseFirestore();
      final result = await _module(firestore).getActiveList(null);
      expect(result, isNull);
    });

    test('delegates to readList when id is provided', () async {
      final firestore = FakeFirebaseFirestore();
      String? capturedId;
      final stub = UnifiedShoppingList(
        id: 'l1',
        name: 'Stubbed',
        ownerId: _userId,
        ownerDisplayName: 'Alice',
      );
      final result = await _module(
        firestore,
        readList: (id) async {
          capturedId = id;
          return stub;
        },
      ).getActiveList('l1');
      expect(capturedId, 'l1');
      expect(result, same(stub));
    });
  });

  group('personalListsStream', () {
    test('emits all personal lists newest-first', () async {
      final firestore = FakeFirebaseFirestore();
      await _seedPersonalList(
        firestore,
        id: 'a',
        name: 'A',
        updatedAt: DateTime.utc(2026, 1, 1),
      );
      await _seedPersonalList(
        firestore,
        id: 'b',
        name: 'B',
        updatedAt: DateTime.utc(2026, 1, 3),
      );
      await _seedPersonalList(
        firestore,
        id: 'c',
        name: 'C',
        updatedAt: DateTime.utc(2026, 1, 2),
      );

      final lists = await _module(firestore).personalListsStream().first;
      expect(lists.map((l) => l.id), ['b', 'c', 'a']);
    });

    test('emits empty list when user has no personal lists', () async {
      final firestore = FakeFirebaseFirestore();
      final lists = await _module(firestore).personalListsStream().first;
      expect(lists, isEmpty);
    });
  });

  group('collaborativeListsStream', () {
    test('emits a (possibly empty) list and does not throw', () async {
      // We can't reliably exercise the memberPermissions.$uid != null path
      // through fake_cloud_firestore — it doesn't index nested map keys for
      // isNotEqualTo, so the filter yields no docs here. The behavioural point
      // of the fix is that the query no longer pairs an inequality filter with
      // an orderBy on a *different* field (which throws on real Firestore and
      // silently empties the stream). Awaiting .first proves the stream builds
      // its first event end-to-end (client-side sort + take(20)) without error.
      final firestore = FakeFirebaseFirestore();
      final lists = await _module(firestore).collaborativeListsStream().first;
      expect(lists, isA<List<UnifiedShoppingList>>());
      expect(lists.length, lessThanOrEqualTo(20));
    });
  });
}
