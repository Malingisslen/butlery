/// Emulator-lane test: pantry and personal shopping-list saves made without a
/// connection (BUT-2287, BUT-2288).
///
/// Firestore keeps an offline write in its own queue and sends it on
/// reconnect, but the write's future only settles when the server answers.
/// The fake settles every write at once, so only a real Firestore with its
/// network switched off can show whether a save returns while offline.
///
/// Mock tier skips the group; the emulator tier runs it on an Android
/// emulator through `integration_test/emulator_lane_test.dart`.
@Tags(['integration', 'firebase'])
library;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/core/constants/firestore_collections.dart';
import 'package:butlery/models/pantry/pantry_item.dart';
import 'package:butlery/models/unified/unified_shopping_item.dart';
import 'package:butlery/models/unified/unified_shopping_list.dart';
import 'package:butlery/repositories/firebase/firebase_pantry_repository.dart';
import 'package:butlery/repositories/firebase/modules/shopping_item_operations_module.dart';

import '../../../test_support/emulator_lane.dart';
import '../../../infrastructure/mocks/production_mocks.dart';

const _uid = 'alice';
const _listId = 'veckohandling';

/// Long enough for every save below to wait out its patience, short enough
/// that a save waiting for the server fails the test instead of the lane.
const _offlineBudget = Duration(seconds: 15);

UnifiedShoppingItem _row(String id, {bool bought = false}) =>
    UnifiedShoppingItem(
      id: id,
      name: id,
      amount: 1,
      unit: 'st',
      category: ShoppingCategory.other,
      bought: bought,
    );

ShoppingItemOperationsModule _shopping(
  FirebaseFirestore firestore,
  UnifiedShoppingList list,
) {
  final auth = FakeAuthRepository()
    ..setAuthState(
      user: FakeUser(uid: _uid, displayName: _uid),
      userId: _uid,
      isAuthenticated: true,
    );
  return ShoppingItemOperationsModule(
    firestore: firestore,
    authRepository: auth,
    requireCurrentUserId: () => _uid,
    readList: (_) async => list,
    mutateCollaborativeList: (_, _) =>
        throw StateError('a personal list never takes the shared path'),
    getUserCollection: (userId) => firestore
        .collection(FirestoreCollections.users)
        .doc(userId)
        .collection(FirestoreCollections.unifiedShoppingLists),
    validateOwnership:
        ({
          required String currentUserId,
          required String resourceOwnerId,
          required String resourceType,
          required String resourceId,
        }) async {},
    validateRequiredFields:
        ({
          required Map<String, dynamic> data,
          required List<String> requiredFields,
          required String resourceType,
        }) {},
    logPermissionCheck:
        ({
          required String userId,
          required String resource,
          required String operation,
          required bool granted,
          String? details,
        }) async {},
    resolveDisplayName: () => _uid,
  );
}

void main() {
  group('saves made without a connection (emulator)', () {
    late FirebaseFirestore firestore;

    setUp(() async {
      firestore = await firestoreForLane();
      await clearLane();
    });

    // The lane shares one Firestore instance across suites.
    tearDown(() => firestore.enableNetwork());

    test(
      'pantry: add, change amount, edit and remove return offline and reach the '
      'server on reconnect',
      () async {
        final repo = FirebasePantryRepository(firestore: firestore);
        final pantry = firestore
            .collection(FirestoreCollections.users)
            .doc(_uid)
            .collection(FirestoreCollections.pantry);
        await repo.add(
          _uid,
          PantryItem(
            id: 'gone',
            ingredientName: 'Gammal mjölk',
            quantity: 1,
            unit: 'l',
            location: PantryLocation.fridge,
            addedAt: DateTime.utc(2026, 10, 10),
          ),
        );

        await firestore.disableNetwork();
        await repo
            .add(
              _uid,
              PantryItem(
                id: 'ris',
                ingredientName: 'Ris',
                quantity: 2,
                unit: 'kg',
                location: PantryLocation.pantry,
                addedAt: DateTime.utc(2026, 10, 10),
              ),
            )
            .timeout(_offlineBudget);
        await repo.adjustQuantity(_uid, 'ris', 1).timeout(_offlineBudget);
        await repo
            .updateFields(_uid, 'ris', {
              'note': 'Jasmin',
            })
            .timeout(_offlineBudget);
        await repo.remove(_uid, 'gone').timeout(_offlineBudget);

        final cached = await pantry
            .doc('ris')
            .get(const GetOptions(source: Source.cache));
        expect(cached.data()?['quantity'], 3);
        expect(cached.data()?['note'], 'Jasmin');

        await firestore.enableNetwork();
        await firestore.waitForPendingWrites();
        final server = await pantry.get(
          const GetOptions(source: Source.server),
        );
        expect(
          {
            for (final d in server.docs)
              d.id: (d.data()['quantity'], d.data()['note']),
          },
          {'ris': (3, 'Jasmin')},
        );
      },
    );

    test(
      'personal list: add, add several, tick and remove return offline and reach the '
      'server on reconnect',
      () async {
        final list = UnifiedShoppingList(
          id: _listId,
          name: 'Veckohandling',
          ownerId: _uid,
          ownerDisplayName: _uid,
          // An earlier day, so each write also stamps the list's day.
          updatedAt: DateTime.utc(2026, 1, 1),
        );
        final parent = firestore
            .collection(FirestoreCollections.users)
            .doc(_uid)
            .collection(FirestoreCollections.unifiedShoppingLists)
            .doc(_listId);
        await parent.set(list.toFirestore());
        final shopping = _shopping(firestore, list);
        await shopping.addItem(_listId, _row('bröd'));

        await firestore.disableNetwork();
        await shopping.addItem(_listId, _row('mjölk')).timeout(_offlineBudget);
        await shopping
            .addItemsBatch(_listId, [_row('ägg'), _row('smör')])
            .timeout(_offlineBudget);
        await shopping
            .updateItem(
              _listId,
              _row('mjölk', bought: true),
              before: _row('mjölk'),
            )
            .timeout(_offlineBudget);
        await shopping
            .removeItem(_listId, 'bröd', removed: _row('bröd'))
            .timeout(_offlineBudget);

        await firestore.enableNetwork();
        await firestore.waitForPendingWrites();
        final rows = await parent
            .collection(FirestoreCollections.items)
            .get(const GetOptions(source: Source.server));
        expect(
          {for (final d in rows.docs) d.id: d.data()['bought']},
          {'mjölk': true, 'ägg': false, 'smör': false},
        );
      },
    );
  }, skip: emulatorOnlySkip);
}
