/// Kärnflöde steg 9C: PantryService.takeCooked and its Ångra, through the
/// real repository.
library;

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:mocktail/mocktail.dart';

import 'package:butlery/core/di/di_container.dart';
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/models/pantry/pantry_item.dart';
import 'package:butlery/services/pantry/cooked_pantry_plan.dart';
import 'package:butlery/repositories/firebase/firebase_pantry_repository.dart';
import 'package:butlery/repositories/interfaces/auth_repository.dart';
import 'package:butlery/repositories/interfaces/ingredient_repository.dart';
import 'package:butlery/services/ingredient_match_service.dart';
import 'package:butlery/services/pantry/pantry_service.dart';

class _MockAuthRepository extends Mock implements AuthRepository {}

class _MockIngredientRepository extends Mock implements IngredientRepository {}

class _MockIngredientMatchService extends Mock
    implements IngredientMatchService {}

const _userId = 'user-alice';

/// Refuses the quantity change of one row, as a refused write does.
class _RefusingRepository extends FirebasePantryRepository {
  _RefusingRepository(this.refuseId, {super.firestore});

  final String refuseId;

  @override
  Future<void> adjustQuantity(String userId, String itemId, double delta) {
    if (itemId == refuseId) throw StateError('write refused');
    return super.adjustQuantity(userId, itemId, delta);
  }
}

PantryItem _row(String id, double qty, String unit) => PantryItem(
  id: id,
  ingredientName: id,
  quantity: qty,
  unit: unit,
  location: PantryLocation.pantry,
  addedAt: DateTime.utc(2026, 1, 1),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeFirebaseFirestore firestore;
  late FirebasePantryRepository repo;
  late PantryService service;

  Future<void> build(FirebasePantryRepository Function() make) async {
    final auth = _MockAuthRepository();
    when(() => auth.currentUserId).thenReturn(_userId);
    final getIt = GetIt.instance;
    await getIt.reset();
    getIt.registerSingleton<AuthRepository>(auth);
    ServiceLocator.initialize(DIContainer());
    repo = make();
    service = PantryService(
      pantryRepository: repo,
      ingredientRepository: _MockIngredientRepository(),
      matchService: _MockIngredientMatchService(),
    );
    await repo.add(_userId, _row('flour', 5, 'dl'));
    await repo.add(_userId, _row('sugar', 2, 'dl'));
    await repo.add(_userId, _row('eggs', 6, 'st'));
  }

  setUp(() async {
    firestore = FakeFirebaseFirestore();
    await build(() => FirebasePantryRepository(firestore: firestore));
  });

  tearDown(() async {
    await GetIt.instance.reset();
  });

  Future<Map<String, double?>> stored() async => {
    for (final i in await repo.getAll(_userId)) i.id: i.quantity,
  };

  test('takeCooked lessens a row and removes one it empties', () async {
    final written = await service.takeCooked(_userId, [
      CookedPantryTake(item: _row('flour', 5, 'dl'), amount: 2),
      CookedPantryTake(item: _row('sugar', 2, 'dl'), amount: 2),
    ]);

    expect(written, hasLength(2));
    expect(await stored(), {'flour': 3.0, 'eggs': 6.0});
  });

  test('undoTakeCooked puts a removed row back whole and adds the amount '
      'back to a lessened one', () async {
    final takes = [
      CookedPantryTake(item: _row('flour', 5, 'dl'), amount: 2),
      CookedPantryTake(item: _row('sugar', 2, 'dl'), amount: 2),
    ];
    final written = await service.takeCooked(_userId, takes);

    await service.undoTakeCooked(_userId, written);

    expect(await stored(), {'flour': 5.0, 'sugar': 2.0, 'eggs': 6.0});
  });

  test('undo adds the amount back to what the row holds now, so a purchase '
      'made in between is kept', () async {
    final written = await service.takeCooked(_userId, [
      CookedPantryTake(item: _row('flour', 5, 'dl'), amount: 2),
    ]);
    await repo.adjustQuantity(_userId, 'flour', 1);

    await service.undoTakeCooked(_userId, written);

    expect((await stored())['flour'], 6.0);
  });

  test('a refused write stops the pass and carries what was written', () async {
    await build(() => _RefusingRepository('sugar', firestore: firestore));
    final takes = [
      CookedPantryTake(item: _row('flour', 5, 'dl'), amount: 1),
      CookedPantryTake(item: _row('sugar', 2, 'dl'), amount: 1),
      CookedPantryTake(item: _row('eggs', 6, 'st'), amount: 1),
    ];

    Object? thrown;
    try {
      await service.takeCooked(_userId, takes);
    } catch (e) {
      thrown = e;
    }

    expect(thrown, isA<CookedPantryTakeFailed>());
    final failed = thrown! as CookedPantryTakeFailed;
    expect([for (final t in failed.written) t.item.id], ['flour']);
    expect(await stored(), {'flour': 4.0, 'sugar': 2.0, 'eggs': 6.0});

    await service.undoTakeCooked(_userId, failed.written);
    expect((await stored())['flour'], 5.0);
  });
}
