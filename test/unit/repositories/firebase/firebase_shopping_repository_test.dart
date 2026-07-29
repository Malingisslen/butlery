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
  });
}
