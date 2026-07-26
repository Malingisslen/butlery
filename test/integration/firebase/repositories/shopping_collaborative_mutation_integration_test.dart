/// Emulator-lane integration test for the collaborative shopping-list write
/// path (BUT-1665).
///
/// This is the one property the unit suites structurally cannot express.
/// `FakeFirebaseFirestore.runTransaction` is a no-op passthrough — it calls the
/// handler once, writes immediately, and has no isolation, abort or retry — so
/// two genuinely interleaved writers clobber each other on the fake while
/// succeeding against real Firestore. The unit tests in
/// `test/unit/repositories/firebase/modules/shopping_item_operations_module_test.dart`
/// and `..._routing_module_test.dart` therefore pin only that the mutator's
/// base is a server read; the atomicity half lives here.
///
/// Mock tier skips the group; the emulator tier runs it:
/// `flutter test test/integration --dart-define=USE_EMULATOR=true`
/// (requires `firebase emulators:start --only firestore`).
// Only `integration` — `firebase` is not declared in dart_test.yaml and an
// undeclared tag makes every run print a warning.
@Tags(['integration'])
library;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/models/unified/unified_shopping_item.dart';
import 'package:butlery/models/unified/unified_shopping_list.dart';
import 'package:butlery/repositories/firebase/modules/shopping_repository_routing_module.dart';

import '../../../test_support/emulator_lane.dart';
import '../../../infrastructure/mocks/production_mocks.dart';

const _alice = 'alice';
const _bob = 'bob';
const _sharedPath = 'unified_shared_shopping_lists';

UnifiedShoppingItem _item(String id, {bool bought = false}) =>
    UnifiedShoppingItem(
      id: id,
      name: id,
      amount: 1,
      unit: 'st',
      category: ShoppingCategory.other,
      bought: bought,
    );

ShoppingRepositoryRoutingModule _routing(
  FirebaseFirestore firestore,
  String uid,
) {
  final auth = FakeAuthRepository()
    ..setAuthState(
      user: FakeUser(uid: uid, displayName: uid),
      userId: uid,
      isAuthenticated: true,
    );

  return ShoppingRepositoryRoutingModule(
    firestore: firestore,
    authRepository: auth,
    sharedListsRef: firestore.collection(_sharedPath),
    requireCurrentUserId: () => uid,
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
        }) {},
    fromFirestore: UnifiedShoppingList.fromFirestore,
    validateUpdatePermission: (userId, resourceId, entity) async =>
        entity.ownerId == userId ||
        (entity.isCollaborative &&
            entity.memberPermissions.containsKey(userId)),
  );
}

void main() {
  group(
    'collaborative list mutation under real transactions (emulator)',
    () {
      late FirebaseFirestore firestore;

      setUp(() async {
        firestore = await firestoreForLane();
        await clearLane();
      });

      // Two household members tick two DIFFERENT items in the same window. Both
      // transactions start before either has committed, so one of them must be
      // retried by Firestore against the other's result. Both ticks must land.
      test('two overlapping writers both land their tick', () async {
        final alice = _routing(firestore, _alice);
        final bob = _routing(firestore, _bob);

        final saved = await alice.createCollaborativeList(
          UnifiedShoppingList.collaborative(
            name: 'Veckohandling',
            ownerId: _alice,
            ownerDisplayName: 'Alice',
            memberPermissions: const {_bob: SharedListPermission.edit},
            items: [_item('mjölk'), _item('bröd')],
          ),
        );

        UnifiedShoppingList tick(UnifiedShoppingList live, String id) =>
            live.copyWith(
              items: live.items
                  .map((i) => i.id == id ? i.copyWith(bought: true) : i)
                  .toList(),
            );

        // Started before either is awaited — this is the interleaving the fake
        // cannot reproduce.
        final aliceWrite = alice.mutateCollaborativeList(
          saved.id,
          (live) => tick(live, 'mjölk'),
        );
        final bobWrite = bob.mutateCollaborativeList(
          saved.id,
          (live) => tick(live, 'bröd'),
        );
        await Future.wait([aliceWrite, bobWrite]);

        final stored = UnifiedShoppingList.fromFirestore(
          await firestore.collection(_sharedPath).doc(saved.id).get(),
        );
        expect(
          {for (final i in stored.items) i.id: i.bought},
          {
            'mjölk': true,
            'bröd': true,
          },
        );
      });
    },
    skip: emulatorOnlySkip,
  );
}
