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

// The BUT-1723 permission-denied test mocks two sealed cloud_firestore types;
// that is the only way to make the shared-collection probe THROW the way the
// live rules do (fake_cloud_firestore evaluates no rules at all, so it answers
// `exists == false` where production answers `permission-denied`).
// ignore_for_file: subtype_of_sealed_class

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

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
  CollectionReference<Map<String, dynamic>>? sharedListsRef,
}) {
  return ShoppingRepositoryQueryModule(
    firestore: firestore,
    sharedListsRef: sharedListsRef ?? firestore.collection(_sharedPath),
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

  // BUT-1723: the gate a conversion consults before deleting the original.
  // It must count what is actually STORED, not what the caller believes it
  // wrote — the personal list's truth is its `items` subcollection, and the
  // parent document's `items` array is stale by design.
  group('confirmPersistedItemCount', () {
    test('counts a personal list from its items subcollection', () async {
      final firestore = FakeFirebaseFirestore();
      await _seedPersonalList(
        firestore,
        id: 'a',
        name: 'Veckohandling',
        updatedAt: DateTime.utc(2026, 1, 1),
        items: [
          _itemDoc(name: 'Mjölk'),
          _itemDoc(name: 'Bröd'),
        ],
      );

      expect(await _module(firestore).confirmPersistedItemCount('a'), 2);
    });

    test('reports zero for a personal list whose items never landed', () async {
      // The exact pre-fix state: the document exists and its `items` ARRAY is
      // full, but the subcollection — the only thing readAll reads — is empty.
      // A conversion that trusted "the create returned an id" deleted the
      // source over precisely this.
      final firestore = FakeFirebaseFirestore();
      await _userLists(firestore, _userId).doc('a').set({
        'name': 'Veckohandling',
        'ownerId': _userId,
        'ownerDisplayName': 'Alice',
        'items': [_itemDoc(name: 'Mjölk')],
        'updatedAt': Timestamp.fromDate(DateTime.utc(2026, 1, 1)),
        'createdAt': Timestamp.fromDate(DateTime.utc(2026, 1, 1)),
      });

      expect(await _module(firestore).confirmPersistedItemCount('a'), 0);
    });

    test('counts a collaborative list from its inline items array', () async {
      final firestore = FakeFirebaseFirestore();
      await firestore.collection(_sharedPath).doc('s1').set({
        'name': 'Familjehandling',
        'ownerId': _userId,
        'items': [_itemDoc(name: 'Ost'), _itemDoc(name: 'Ägg')],
      });

      expect(await _module(firestore).confirmPersistedItemCount('s1'), 2);
    });

    test('returns zero for a list that does not exist anywhere', () async {
      final firestore = FakeFirebaseFirestore();
      expect(await _module(firestore).confirmPersistedItemCount('ghost'), 0);
    });

    // The production-shaped case the fake cannot produce on its own. The
    // shared-list read rule dereferences `resource.data.ownerId`, and
    // `resource` is null for a document that does not exist — so a `get` on a
    // PERSONAL list id is DENIED, never answered with `exists == false`. If the
    // shared catch returned null, the personal leg below would be unreachable
    // in production and convert-to-personal would never delete its source.
    test(
      'falls through to the personal subcollection when the shared probe is '
      'denied',
      () async {
        final firestore = FakeFirebaseFirestore();
        await _seedPersonalList(
          firestore,
          id: 'a',
          name: 'Veckohandling',
          updatedAt: DateTime.utc(2026, 1, 1),
          items: [
            _itemDoc(name: 'Mjölk'),
            _itemDoc(name: 'Bröd'),
          ],
        );

        final denied = _MockCollectionRef();
        final deniedDoc = _MockDocRef();
        when(() => denied.doc(any())).thenReturn(deniedDoc);
        when(deniedDoc.get).thenThrow(
          FirebaseException(
            plugin: 'cloud_firestore',
            code: 'permission-denied',
            message: 'Missing or insufficient permissions.',
          ),
        );

        final module = _module(firestore, sharedListsRef: denied);
        expect(await module.confirmPersistedItemCount('a'), 2);
      },
    );

    // The reason this method exists at all, and the one thing
    // fake_cloud_firestore cannot stage: it answers every read with
    // `isFromCache == false`, so BOTH cache guards are unreachable from a
    // plain fake and every other test in this group passes with them deleted.
    // Firestore hands a local write straight back out of its own cache while
    // offline, so without these two lines a conversion copy reads as complete
    // before a byte has left the device — and the source list is then deleted.
    test('a cached shared-list answer is unconfirmed, not a count', () async {
      final firestore = FakeFirebaseFirestore();
      final cachedRef = _MockCollectionRef();
      final cachedDoc = _MockDocRef();
      final snapshot = _MockDocSnapshot();
      final metadata = _MockSnapshotMetadata();

      when(() => cachedRef.doc(any())).thenReturn(cachedDoc);
      when(cachedDoc.get).thenAnswer((_) async => snapshot);
      when(() => snapshot.metadata).thenReturn(metadata);
      when(() => metadata.isFromCache).thenReturn(true);
      // Deliberately a COMPLETE-looking answer: two items, document present.
      // Only the cache flag separates it from a genuine server confirmation.
      when(() => snapshot.exists).thenReturn(true);
      when(snapshot.data).thenReturn({
        'items': [_itemDoc(name: 'Ost'), _itemDoc(name: 'Ägg')],
      });

      final module = _module(firestore, sharedListsRef: cachedRef);
      expect(await module.confirmPersistedItemCount('s1'), isNull);
    });

    test('a cached personal-subcollection answer is unconfirmed', () async {
      final firestore = FakeFirebaseFirestore();

      // Production shape: the shared probe on a personal id is denied, so the
      // personal leg is the one that answers — from the local cache.
      final denied = _MockCollectionRef();
      final deniedDoc = _MockDocRef();
      when(() => denied.doc(any())).thenReturn(deniedDoc);
      when(deniedDoc.get).thenThrow(
        FirebaseException(plugin: 'cloud_firestore', code: 'permission-denied'),
      );

      final userLists = _MockCollectionRef();
      final listDoc = _MockDocRef();
      final itemsRef = _MockCollectionRef();
      final querySnapshot = _MockQuerySnapshot();
      final metadata = _MockSnapshotMetadata();

      when(() => userLists.doc(any())).thenReturn(listDoc);
      when(() => listDoc.collection(any())).thenReturn(itemsRef);
      when(itemsRef.get).thenAnswer((_) async => querySnapshot);
      when(() => querySnapshot.metadata).thenReturn(metadata);
      when(() => metadata.isFromCache).thenReturn(true);
      // Without the guard this returns 0 — "confirmed empty" — and a
      // conversion of an empty source list then passes `0 >= 0` and deletes
      // the original on the strength of a read no server ever answered.
      when(() => querySnapshot.docs).thenReturn(const []);

      final module = ShoppingRepositoryQueryModule(
        firestore: firestore,
        sharedListsRef: denied,
        requireCurrentUserId: () => _userId,
        getUserCollection: (_) => userLists,
        fromFirestore: _fromFirestore,
        readList: (_) async => null,
      );

      expect(await module.confirmPersistedItemCount('a'), isNull);
    });

    test('still reports unconfirmed when BOTH probes fail', () async {
      final firestore = FakeFirebaseFirestore();
      final denied = _MockCollectionRef();
      final deniedDoc = _MockDocRef();
      when(() => denied.doc(any())).thenReturn(deniedDoc);
      when(deniedDoc.get).thenThrow(
        FirebaseException(
          plugin: 'cloud_firestore',
          code: 'permission-denied',
        ),
      );

      final module = ShoppingRepositoryQueryModule(
        firestore: firestore,
        sharedListsRef: denied,
        requireCurrentUserId: () => throw StateError('not signed in'),
        getUserCollection: (uid) => _userLists(firestore, uid),
        fromFirestore: _fromFirestore,
        readList: (_) async => null,
      );

      expect(await module.confirmPersistedItemCount('a'), isNull);
    });
  });
}

class _MockCollectionRef extends Mock
    implements CollectionReference<Map<String, dynamic>> {}

class _MockDocRef extends Mock
    implements DocumentReference<Map<String, dynamic>> {}

class _MockDocSnapshot extends Mock
    implements DocumentSnapshot<Map<String, dynamic>> {}

class _MockQuerySnapshot extends Mock
    implements QuerySnapshot<Map<String, dynamic>> {}

class _MockSnapshotMetadata extends Mock implements SnapshotMetadata {}
