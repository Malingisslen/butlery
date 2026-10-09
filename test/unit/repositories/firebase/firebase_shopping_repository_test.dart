/// BUT-1723 root-cause coverage for [FirebaseShoppingRepository.create].
///
/// A personal list stores its items in the `items` SUBCOLLECTION, and
/// `readAll()` rebuilds every personal list from that subcollection —
/// OVERWRITING whatever the parent document's `items` array said. So a create
/// that only wrote the document looked correct for the rest of the session and
/// came back empty on the next launch. That is what made
/// `convertCollaborativeToPersonal` a data-loss path: it deleted the shared
/// source on the strength of a copy that had persisted no items at all.
///
/// The fan-out is three lines of production code and every other suite stays
/// green if they are deleted, so it is asserted here against the RAW
/// subcollection — not through the model, which would happily echo back the
/// in-memory items the caller passed in.
library;

import 'package:butlery/core/constants/firestore_collections.dart';
import 'package:butlery/core/exceptions/permission_exceptions.dart';
import 'package:butlery/models/unified/shopping_row_snapshot.dart';
import 'package:butlery/models/unified/unified_shopping_item.dart';
import 'package:butlery/models/unified/unified_shopping_list.dart';
import 'package:butlery/repositories/firebase/firebase_shopping_repository.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../infrastructure/di/test_service_locator.dart';
import '../../../infrastructure/mocks/production_mocks.dart';
import '../../../test_support/base_unit_test.dart';

void main() {
  group('FirebaseShoppingRepository.create — personal item fan-out', () {
    late FakeFirebaseFirestore firestore;
    late FakeAuthRepository auth;
    late FirebaseShoppingRepository repository;

    const userId = 'user-abc';

    setUpAll(() async {
      await BaseUnitTest.setupUnit();
    });

    setUp(() {
      firestore = FakeFirebaseFirestore();
      auth = FakeAuthRepository();
      auth.setAuthState(
        user: FakeUser(uid: userId),
        userId: userId,
        isAuthenticated: true,
      );
      repository = FirebaseShoppingRepository(
        firestore: firestore,
        authRepository: auth,
      );
    });

    tearDown(() async {
      BaseUnitTest.resetMocks();
      await TestServiceLocator.reset();
    });

    CollectionReference<Map<String, dynamic>> itemsOf(String listId) =>
        firestore
            .collection(FirestoreCollections.users)
            .doc(userId)
            .collection(FirestoreCollections.unifiedShoppingLists)
            .doc(listId)
            .collection(FirestoreCollections.items);

    UnifiedShoppingList personalList(List<UnifiedShoppingItem> items) =>
        UnifiedShoppingList(
          name: 'Veckohandling',
          ownerId: userId,
          ownerDisplayName: 'Malin',
          items: items,
        );

    test('writes every item into the items subcollection', () async {
      final created = await repository.create(
        personalList([
          UnifiedShoppingItem(name: 'Mjölk', amount: 2, addedByUserId: userId),
          UnifiedShoppingItem(name: 'Bröd', amount: 1, addedByUserId: userId),
        ]),
      );

      // Read the RAW subcollection — the only thing readAll() trusts.
      final stored = await itemsOf(created.id).get();
      expect(stored.docs, hasLength(2));
      expect(
        stored.docs.map((doc) => doc.data()['name']),
        containsAll(<String>['Mjölk', 'Bröd']),
      );
    });

    test('the created list survives a re-read through readAll', () async {
      final created = await repository.create(
        personalList([
          UnifiedShoppingItem(name: 'Ost', amount: 1, addedByUserId: userId),
        ]),
      );

      final all = await repository.readAll();
      final reread = all.firstWhere((list) => list.id == created.id);

      expect(
        reread.items.map((item) => item.name),
        ['Ost'],
        reason:
            'readAll rebuilds items from the subcollection; an empty result '
            'here is the exact state the conversion deleted the source over',
      );
    });

    test('an empty list writes no item documents', () async {
      final created = await repository.create(personalList(const []));

      final stored = await itemsOf(created.id).get();
      expect(stored.docs, isEmpty);
    });

    // BUT-1743: the fan-out used to re-read the list by id, and that read
    // probes the SHARED collection first — a read the rules deny for a
    // personal id, so every such create paid for it and logged a warning.
    test('a personal create with items never touches the shared '
        'collection', () async {
      final counting = _CountingFirestore();
      final repo = FirebaseShoppingRepository(
        firestore: counting,
        authRepository: auth,
      );
      counting.sharedCollectionRefs = 0;

      final created = await repo.create(
        personalList([
          UnifiedShoppingItem(name: 'Mjölk', amount: 2, addedByUserId: userId),
        ]),
      );

      expect(counting.sharedCollectionRefs, 0);
      final stored = await counting
          .collection(FirestoreCollections.users)
          .doc(userId)
          .collection(FirestoreCollections.unifiedShoppingLists)
          .doc(created.id)
          .collection(FirestoreCollections.items)
          .get();
      expect(stored.docs, hasLength(1));
    });
  });

  // BUT-1743: deleting a personal list's parent document left its `items`
  // subcollection behind. The fake removes a document's whole subtree on
  // delete, which real Firestore does not, so the sweep is pinned on its own
  // and its wiring through a recording subclass.
  group('FirebaseShoppingRepository.delete — personal rows', () {
    late FakeFirebaseFirestore firestore;
    late FakeAuthRepository auth;
    late _RecordingShoppingRepository repository;

    const userId = 'user-abc';

    setUpAll(() async {
      await BaseUnitTest.setupUnit();
    });

    setUp(() {
      firestore = FakeFirebaseFirestore();
      auth = FakeAuthRepository();
      auth.setAuthState(
        user: FakeUser(uid: userId),
        userId: userId,
        isAuthenticated: true,
      );
      repository = _RecordingShoppingRepository(
        firestore: firestore,
        authRepository: auth,
      );
    });

    tearDown(() async {
      BaseUnitTest.resetMocks();
      await TestServiceLocator.reset();
    });

    DocumentReference<Map<String, dynamic>> listDoc(String listId) => firestore
        .collection(FirestoreCollections.users)
        .doc(userId)
        .collection(FirestoreCollections.unifiedShoppingLists)
        .doc(listId);

    CollectionReference<Map<String, dynamic>> itemsOf(String listId) =>
        listDoc(listId).collection(FirestoreCollections.items);

    Future<void> seedList(String listId, {required String ownerId}) =>
        listDoc(listId).set(
          UnifiedShoppingList(
            id: listId,
            name: 'Veckohandling',
            ownerId: ownerId,
            ownerDisplayName: 'Malin',
          ).toFirestore(),
        );

    test('the sweep deletes every row of the list', () async {
      for (var i = 0; i < 3; i++) {
        await itemsOf('gone').doc('row-$i').set({'name': 'Rad $i'});
      }
      await itemsOf('kept').doc('row-x').set({'name': 'Annan lista'});

      await repository.deletePersonalListRowsForReal('gone');

      expect((await itemsOf('gone').get()).docs, isEmpty);
      expect(
        (await itemsOf('kept').get()).docs,
        hasLength(1),
        reason: 'only the deleted list\'s rows go',
      );
    });

    test('deleting a personal list sweeps its rows', () async {
      await seedList('mine', ownerId: userId);

      await repository.delete('mine');

      expect(repository.sweptLists, ['mine']);
    });

    test('a refused delete sweeps nothing', () async {
      // A document in the caller's own collection that names someone else as
      // owner: validateDeletePermission refuses it.
      await seedList('not-mine', ownerId: 'someone-else');

      await expectLater(
        repository.delete('not-mine'),
        throwsA(isA<PermissionDeniedException>()),
      );

      expect(repository.sweptLists, isEmpty);
    });
  });

  // BUT-2140: the whole-list `update` must not write the restore history. A
  // copy held in memory since before a removal carries an older array, and
  // writing it would erase the newer entries.
  group('FirebaseShoppingRepository.update — recentlyRemoved', () {
    late FakeFirebaseFirestore firestore;
    late FakeAuthRepository auth;
    late FirebaseShoppingRepository repository;

    const userId = 'user-abc';

    setUpAll(() async {
      await BaseUnitTest.setupUnit();
    });

    setUp(() {
      firestore = FakeFirebaseFirestore();
      auth = FakeAuthRepository();
      auth.setAuthState(
        user: FakeUser(uid: userId),
        userId: userId,
        isAuthenticated: true,
      );
      repository = FirebaseShoppingRepository(
        firestore: firestore,
        authRepository: auth,
      );
    });

    tearDown(() async {
      BaseUnitTest.resetMocks();
      await TestServiceLocator.reset();
    });

    test(
      'a rename from a stale copy leaves the stored history alone',
      () async {
        final created = await repository.create(
          UnifiedShoppingList(
            name: 'Veckohandling',
            ownerId: userId,
            ownerDisplayName: 'Malin',
          ),
        );
        final listDoc = firestore
            .collection(FirestoreCollections.users)
            .doc(userId)
            .collection(FirestoreCollections.unifiedShoppingLists)
            .doc(created.id);
        final newer = ShoppingRowSnapshot(
          id: 'removed-after-the-copy-was-taken',
          name: 'Mjölk',
          amount: 1,
          unit: '',
          category: ShoppingCategory.other,
          at: DateTime.utc(2026, 10, 8),
        );
        await listDoc.update({
          'recentlyRemoved': [newer.toFirestore()],
        });

        // `created` predates the removal and has an empty history.
        await repository.update(created.copyWith(name: 'Söndagshandel'));

        final stored = (await listDoc.get()).data()!;
        expect(stored['name'], 'Söndagshandel');
        expect(stored['recentlyRemoved'], hasLength(1));
        expect(
          (stored['recentlyRemoved'] as List).single['id'],
          newer.id,
        );
      },
    );
  });
}

/// Counts every reference built to the shared-list collection, which is the
/// only way a read of it can start.
class _CountingFirestore extends FakeFirebaseFirestore {
  int sharedCollectionRefs = 0;

  @override
  CollectionReference<Map<String, dynamic>> collection(String path) {
    if (path == FirestoreCollections.unifiedSharedShoppingLists) {
      sharedCollectionRefs++;
    }
    return super.collection(path);
  }
}

/// Records which lists [FirebaseShoppingRepository.delete] sweeps.
class _RecordingShoppingRepository extends FirebaseShoppingRepository {
  _RecordingShoppingRepository({super.firestore, super.authRepository});

  final List<String> sweptLists = [];

  @override
  Future<void> deletePersonalListRows(String listId) async {
    sweptLists.add(listId);
  }

  Future<void> deletePersonalListRowsForReal(String listId) =>
      super.deletePersonalListRows(listId);
}
