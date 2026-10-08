/// BUT-2140: a row removed through the shopping service can be restored from
/// the entry the service holds in memory, in the same session.
///
/// The service and the repository each take the time of a removal from their
/// own clock read, so the in-memory entry and the stored one can differ in
/// `at`. The clock here advances on every read to make that visible; matching
/// an entry on anything but the row id then restores nothing.
library;

import 'package:clock/clock.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/core/constants/firestore_collections.dart';
import 'package:butlery/models/unified/unified_shopping_item.dart';
import 'package:butlery/models/unified/unified_shopping_list.dart';
import 'package:butlery/repositories/firebase/firebase_shopping_repository.dart';
import 'package:butlery/services/unified/modules/shopping_item_management_module.dart';
import 'package:butlery/services/unified/modules/shopping_restore_module.dart';

import '../../../../infrastructure/di/test_service_locator.dart';
import '../../../../infrastructure/mocks/production_mocks.dart';
import '../../../../test_support/base_unit_test.dart';

const _uid = 'alice';

void main() {
  late FakeFirebaseFirestore firestore;
  late FirebaseShoppingRepository repository;

  setUpAll(() async => BaseUnitTest.setupUnit());

  setUp(() {
    firestore = FakeFirebaseFirestore();
    final auth = FakeAuthRepository()
      ..setAuthState(
        user: FakeUser(uid: _uid),
        userId: _uid,
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

  /// Every read of the clock is 7 ms after the previous one.
  Clock ticking() {
    var t = DateTime.utc(2026, 10, 8, 12);
    return Clock(() => t = t.add(const Duration(milliseconds: 7)));
  }

  Future<UnifiedShoppingList> seed(ListType type) async {
    final row = UnifiedShoppingItem(id: 'mjölk', name: 'mjölk', amount: 1);
    final list = UnifiedShoppingList(
      id: 'L',
      name: 'Lista',
      ownerId: _uid,
      ownerDisplayName: 'Alice',
      type: type,
      items: [row],
      memberPermissions: type == ListType.collaborative
          ? const {_uid: SharedListPermission.admin}
          : const {},
    );
    if (type == ListType.collaborative) {
      await firestore
          .collection(FirestoreCollections.unifiedSharedShoppingLists)
          .doc('L')
          .set(list.toFirestore());
    } else {
      final parent = firestore
          .collection(FirestoreCollections.users)
          .doc(_uid)
          .collection(FirestoreCollections.unifiedShoppingLists)
          .doc('L');
      await parent.set(list.toFirestore());
      await parent
          .collection(FirestoreCollections.items)
          .doc(row.id)
          .set(row.toFirestore());
    }
    return list;
  }

  for (final type in [ListType.personal, ListType.collaborative]) {
    test('$type: remove, then restore the in-memory entry', () async {
      final lists = [await seed(type)];
      final items = ShoppingItemManagementModule(
        repository: repository,
        lists: lists,
        getActiveListId: () => 'L',
        notifyListeners: () {},
        getCategoryPreferences: () => throw StateError('not used by a removal'),
      );
      final restore = ShoppingRestoreModule(
        repository: repository,
        lists: lists,
        notifyListeners: () {},
        reportFailure: (_) {},
      );

      await withClock(ticking(), () async {
        expect(await items.removeItemFromActiveList('mjölk'), isTrue);
        final entry = lists.single.recentlyRemoved.single;

        expect(await restore.restoreRemovedRow('L', entry), isTrue);
      });

      final stored = await repository.read('L');
      expect(stored!.recentlyRemoved, isEmpty);
      if (type == ListType.personal) {
        final row = await firestore
            .collection(FirestoreCollections.users)
            .doc(_uid)
            .collection(FirestoreCollections.unifiedShoppingLists)
            .doc('L')
            .collection(FirestoreCollections.items)
            .doc('mjölk')
            .get();
        expect(row.exists, isTrue);
      } else {
        expect(stored.items.map((i) => i.id), ['mjölk']);
      }
      expect(lists.single.items.map((i) => i.id), ['mjölk']);
      expect(lists.single.recentlyRemoved, isEmpty);
    });
  }
}
