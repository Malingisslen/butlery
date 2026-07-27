/// GDPR Article 15/20 coverage for the personal-shopping-list leg of
/// [FirebaseDataExportRepository].
///
/// BUT-1697: this method read `users/{uid}/shopping_lists` while
/// `FirebaseShoppingRepository` writes `users/{uid}/unified_shopping_lists`.
/// Nothing failed — the query simply matched zero documents, so every user's
/// data export silently omitted every shopping list they had ever made. The
/// only existing coverage was `content_export_manager_test.dart`, which stubs
/// this repository out and therefore cannot see a wrong collection name.
///
/// The decisive test is the negative one: a list written to the LIVE path must
/// come back, and a list written to the legacy path must NOT be what the export
/// happens to find. Both are asserted against a real fake Firestore, so the
/// path is exercised rather than described.
library;

import 'package:butlery/core/constants/firestore_collections.dart';
import 'package:butlery/models/unified/unified_shopping_list.dart';
import 'package:butlery/repositories/firebase/firebase_data_export_repository.dart';
import 'package:butlery/repositories/firebase/firebase_shopping_repository.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:butlery/core/exceptions/permission_exceptions.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../infrastructure/di/test_service_locator.dart';
import '../../../infrastructure/mocks/production_mocks.dart';
import '../../../test_support/base_unit_test.dart';

void main() {
  group('FirebaseDataExportRepository — personal shopping lists (BUT-1697)', () {
    late FirebaseDataExportRepository repository;
    late FakeFirebaseFirestore firestore;
    late FakeAuthRepository auth;

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
      repository = FirebaseDataExportRepository(
        firestore: firestore,
        authRepository: auth,
      );
    });

    tearDown(() async {
      BaseUnitTest.resetMocks();
      await TestServiceLocator.reset();
    });

    /// Writes a personal list at the path the production shopping repository
    /// uses, so the fixture cannot drift from the writer.
    Future<void> seedLiveList({
      required String listId,
      required String name,
      List<Map<String, dynamic>> items = const [],
    }) async {
      final listRef = firestore
          .collection(FirestoreCollections.users)
          .doc(userId)
          .collection(FirestoreCollections.unifiedShoppingLists)
          .doc(listId);
      await listRef.set(<String, dynamic>{'name': name});
      for (var i = 0; i < items.length; i++) {
        await listRef
            .collection(FirestoreCollections.items)
            .doc('item-$i')
            .set(items[i]);
      }
    }

    /// The premise the whole bug rests on, proved END TO END: a list created
    /// through the production writer must come back out of the production
    /// reader. No constant is named on either side, so this stays honest
    /// through any future rename — it only goes red if the two DIVERGE, which
    /// is exactly the failure that shipped.
    test('a list created via FirebaseShoppingRepository is exported', () async {
      final writer = FirebaseShoppingRepository(
        firestore: firestore,
        authRepository: auth,
      );
      final created = await writer.create(
        UnifiedShoppingList(
          name: 'Skriven av repot',
          ownerId: userId,
          ownerDisplayName: 'Malin',
        ),
      );

      final result = await repository.exportPersonalShoppingLists(userId);

      expect(
        result.map((e) => e['id']),
        contains(created.id),
        reason:
            'the writer and the export reader must resolve to the same '
            'collection; two constants for one concept is what broke Art. 15',
      );
    });

    test('exports a list written to the live personal path', () async {
      await seedLiveList(listId: 'l1', name: 'Veckans inköp');

      final result = await repository.exportPersonalShoppingLists(userId);

      expect(result, hasLength(1));
      expect(result.single['id'], 'l1');
      expect(
        (result.single['data'] as Map)['name'],
        'Veckans inköp',
        reason: 'Article 15 requires the list the user actually created',
      );
    });

    test("exports each list's items subcollection alongside it", () async {
      await seedLiveList(
        listId: 'l1',
        name: 'Veckans inköp',
        items: [
          <String, dynamic>{'name': 'Mjölk', 'amount': 2, 'bought': false},
          <String, dynamic>{'name': 'Ägg', 'amount': 6, 'bought': true},
        ],
      );

      final result = await repository.exportPersonalShoppingLists(userId);

      final items = result.single['items'] as List;
      expect(items, hasLength(2));
      expect(
        items.map((e) => ((e as Map)['data'] as Map)['name']),
        containsAll(<String>['Mjölk', 'Ägg']),
      );
    });

    /// The regression guard. A list at the LEGACY path must not be what makes
    /// the export look healthy — if the reader ever points back there, this
    /// goes red while the live-path tests above would also go red, pinning the
    /// direction of the mistake.
    test('a list at the legacy path is not mistaken for the export', () async {
      await firestore
          .collection(FirestoreCollections.users)
          .doc(userId)
          .collection(FirestoreCollections.userShoppingLists)
          .doc('legacy-1')
          .set(<String, dynamic>{'name': 'gammal lista'});

      final result = await repository.exportPersonalShoppingLists(userId);

      expect(
        result,
        isEmpty,
        reason:
            'the legacy path holds nothing in production (firestore.rules '
            'grants no match for it), so it must not be the export source',
      );
    });

    test('returns an empty list when the user has no lists', () async {
      expect(await repository.exportPersonalShoppingLists(userId), isEmpty);
    });

    test('respects maxLists', () async {
      for (var i = 0; i < 3; i++) {
        await seedLiveList(listId: 'l$i', name: 'lista $i');
      }

      final result = await repository.exportPersonalShoppingLists(
        userId,
        maxLists: 2,
      );

      expect(result, hasLength(2));
    });

    /// Defence-in-depth: the self-export guard must still refuse to export
    /// somebody else's lists even though the path is now correct.
    test('refuses to export another user id', () async {
      await seedLiveList(listId: 'l1', name: 'Veckans inköp');

      await expectLater(
        repository.exportPersonalShoppingLists('someone-else'),
        throwsA(isA<PermissionDeniedException>()),
      );
    });
  });
}
