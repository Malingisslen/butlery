/// BUT-2140: Återställ in the pantry edit sheet, through the real repository.
///
/// A save from the edit sheet keeps what it replaced; restoring swaps the two
/// versions and writes the replaced values back as the new previous version,
/// so a restore can itself be undone.
library;

import 'package:clock/clock.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:mocktail/mocktail.dart';

import 'package:butlery/core/di/di_container.dart';
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/models/pantry/pantry_item.dart';
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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeFirebaseFirestore firestore;
  late FirebasePantryRepository repo;
  late PantryService service;

  final now = DateTime.utc(2026, 10, 8, 12);

  final base = PantryItem(
    id: 'p1',
    ingredientName: 'Mjölk',
    quantity: 2,
    unit: 'l',
    location: PantryLocation.fridge,
    addedAt: DateTime.utc(2026, 1, 1),
  );

  setUp(() async {
    // executeServiceOperation's auth pre-flight reads the production
    // ServiceLocator; without it the repository would never be called.
    final auth = _MockAuthRepository();
    when(() => auth.currentUserId).thenReturn(_userId);
    final getIt = GetIt.instance;
    await getIt.reset();
    getIt.registerSingleton<AuthRepository>(auth);
    ServiceLocator.initialize(DIContainer());

    firestore = FakeFirebaseFirestore();
    repo = FirebasePantryRepository(firestore: firestore);
    service = PantryService(
      pantryRepository: repo,
      ingredientRepository: _MockIngredientRepository(),
      matchService: _MockIngredientMatchService(),
    );
    await repo.add(_userId, base);
  });

  tearDown(() async {
    await GetIt.instance.reset();
  });

  Future<PantryItem> stored() async => (await repo.getAll(_userId)).single;

  test('updateItem keeps the replaced values and returns them', () async {
    final edited = base.copyWith(ingredientName: 'Havremjölk', note: 'ny');

    final kept = await withClock(
      Clock.fixed(now),
      () => service.updateItem(_userId, edited, previous: base),
    );

    expect(kept?.fields, {'ingredientName': 'Mjölk', 'note': null});
    expect(kept?.at, now);
    expect((await stored()).previous?.fields, kept?.fields);
  });

  test('updateItem without the previous item keeps nothing', () async {
    final kept = await service.updateItem(
      _userId,
      base.copyWith(note: 'ny'),
    );

    expect(kept, isNull);
    expect((await stored()).previous, isNull);
  });

  test('adjustQuantity (+/−) leaves the previous version alone', () async {
    await service.updateItem(
      _userId,
      base.copyWith(unit: 'dl'),
      previous: base,
    );
    final before = await stored();

    await service.adjustQuantity(_userId, before, 1);

    final after = await stored();
    expect(after.quantity, 3);
    expect(after.previous?.fields, {'unit': 'l'});
  });

  test(
    'restorePrevious swaps the versions, and swapping again undoes it',
    () async {
      final edited = base.copyWith(
        ingredientName: 'Havremjölk',
        note: 'laktosfri',
        location: PantryLocation.pantry,
      );
      await service.updateItem(_userId, edited, previous: base);

      final restored = await withClock(
        Clock.fixed(now),
        () async => service.restorePrevious(_userId, await stored()),
      );

      final afterRestore = await stored();
      expect(afterRestore.ingredientName, 'Mjölk');
      expect(afterRestore.note, isNull);
      expect(afterRestore.location, PantryLocation.fridge);
      expect(afterRestore.quantity, 2);
      expect(afterRestore.previous?.fields, {
        'ingredientName': 'Havremjölk',
        'note': 'laktosfri',
        'location': 'pantry',
      });
      // What the service returns is what is stored, so the snackbar's Ångra
      // can swap again without a read.
      expect(restored.ingredientName, afterRestore.ingredientName);
      expect(restored.note, afterRestore.note);
      expect(restored.previous?.fields, afterRestore.previous?.fields);
      expect(restored.previous?.at, now);

      await service.restorePrevious(_userId, restored);

      final afterUndo = await stored();
      expect(afterUndo.ingredientName, 'Havremjölk');
      expect(afterUndo.note, 'laktosfri');
      expect(afterUndo.location, PantryLocation.pantry);
      expect(afterUndo.previous?.fields, {
        'ingredientName': 'Mjölk',
        'note': null,
        'location': 'fridge',
      });
    },
  );

  test('restorePrevious without a previous version writes nothing', () async {
    await expectLater(
      service.restorePrevious(_userId, base),
      throwsA(isA<StateError>()),
    );
    expect((await stored()).updatedAt, isNull);
  });
}
