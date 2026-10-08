/// BUT-2140: the ViewModel keeps its row in step with Återställ without a
/// read: a save stores the version the service kept, and a restore replaces
/// the row with the item the service returns.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:butlery/core/di/di_container.dart';
import 'package:butlery/core/providers/application_provider.dart' as production;
import 'package:butlery/models/pantry/pantry_item.dart';
import 'package:butlery/models/pantry/pantry_previous_version.dart';
import 'package:butlery/repositories/interfaces/ingredient_repository.dart';
import 'package:butlery/services/pantry/pantry_service.dart';
import 'package:butlery/viewmodels/pantry/pantry_viewmodel.dart';

import '../../../infrastructure/di/test_service_locator.dart';
import '../../../test_support/base_unit_test.dart';

class _MockPantryService extends Mock implements PantryService {}

class _MockIngredientRepository extends Mock implements IngredientRepository {}

void main() {
  final at = DateTime.utc(2026, 10, 8, 12);
  final stored = PantryItem(
    id: 'p1',
    ingredientName: 'Mjölk',
    quantity: 2,
    unit: 'l',
    location: PantryLocation.fridge,
    addedAt: DateTime(2026, 1, 1),
  );

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await BaseUnitTest.setupUnit();
    registerFallbackValue(stored);
  });

  setUp(() async {
    await TestServiceLocator.initialize();
    production.ServiceLocator.initialize(DIContainer());
  });

  tearDown(() async {
    await TestServiceLocator.reset();
  });

  tearDownAll(() async {
    await BaseUnitTest.teardownUnit();
  });

  Future<(PantryViewModel, _MockPantryService)> loaded(PantryItem row) async {
    final service = _MockPantryService();
    when(() => service.getAll(any())).thenAnswer((_) async => [row]);
    final vm = PantryViewModel(
      pantryService: service,
      ingredientRepository: _MockIngredientRepository(),
    );
    await vm.loadPantry();
    return (vm, service);
  }

  test('a save keeps the version the service kept on the row', () async {
    final (vm, service) = await loaded(stored);
    final kept = PantryPreviousVersion(
      fields: const {'ingredientName': 'Mjölk'},
      at: at,
    );
    when(
      () => service.updateItem(
        any(),
        any(),
        previous: any(named: 'previous'),
      ),
    ).thenAnswer((_) async => kept);

    await vm.updateItem(stored.copyWith(ingredientName: 'Havremjölk'));

    expect(vm.items.single.ingredientName, 'Havremjölk');
    expect(vm.items.single.previous, same(kept));
    vm.dispose();
  });

  test(
    'a restore replaces the row with the item the service returns',
    () async {
      final row = stored.copyWith(
        ingredientName: 'Havremjölk',
        previous: PantryPreviousVersion(
          fields: const {'ingredientName': 'Mjölk'},
          at: at,
        ),
      );
      final (vm, service) = await loaded(row);
      final restored = row.withPreviousRestored(at)!;
      when(
        () => service.restorePrevious(any(), row),
      ).thenAnswer((_) async => restored);

      final result = await vm.restorePrevious(row);

      expect(result, same(restored));
      expect(vm.items.single.ingredientName, 'Mjölk');
      expect(vm.items.single.previous?.fields, {
        'ingredientName': 'Havremjölk',
      });
      vm.dispose();
    },
  );

  test('a failed restore returns null and leaves the row as it is', () async {
    final row = stored.copyWith(
      previous: PantryPreviousVersion(
        fields: const {'note': null},
        at: at,
      ),
    );
    final (vm, service) = await loaded(row);
    when(
      () => service.restorePrevious(any(), any()),
    ).thenThrow(StateError('restorePrevious failed'));

    final result = await vm.restorePrevious(row);

    expect(result, isNull);
    expect(vm.hasError, isTrue);
    expect(vm.items.single, same(row));
    vm.dispose();
  });
}
