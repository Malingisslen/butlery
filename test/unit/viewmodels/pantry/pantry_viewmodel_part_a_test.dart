/// P5-U28: the ViewModel sends an edit as a change from the row it holds, so
/// only the edited fields are written (produktregler.md:105), and a relative
/// change as a delta (produktregler.md:146).
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:butlery/core/di/di_container.dart';
import 'package:butlery/core/providers/application_provider.dart' as production;
import 'package:butlery/models/pantry/pantry_item.dart';
import 'package:butlery/repositories/interfaces/ingredient_repository.dart';
import 'package:butlery/services/pantry/pantry_service.dart';
import 'package:butlery/viewmodels/pantry/pantry_viewmodel.dart';

import '../../../infrastructure/di/test_service_locator.dart';
import '../../../test_support/base_unit_test.dart';

class _MockPantryService extends Mock implements PantryService {}

class _MockIngredientRepository extends Mock implements IngredientRepository {}

void main() {
  final stored = PantryItem(
    id: 'p1',
    ingredientName: 'Mjöl',
    quantity: 6,
    unit: 'dl',
    location: PantryLocation.pantry,
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

  Future<(PantryViewModel, _MockPantryService)> loaded() async {
    final service = _MockPantryService();
    when(() => service.getAll(any())).thenAnswer((_) async => [stored]);
    final vm = PantryViewModel(
      pantryService: service,
      ingredientRepository: _MockIngredientRepository(),
    );
    await vm.loadPantry();
    return (vm, service);
  }

  test('updateItem passes the row it holds as previous', () async {
    final (vm, service) = await loaded();
    when(
      () => service.updateItem(
        any(),
        any(),
        previous: any(named: 'previous'),
      ),
    ).thenAnswer((_) async {});

    await vm.updateItem(stored.copyWith(note: 'ekologiskt'));

    final previous =
        verify(
              () => service.updateItem(
                any(),
                any(),
                previous: captureAny(named: 'previous'),
              ),
            ).captured.single
            as PantryItem;
    expect(previous.note, isNull);
    expect(vm.items.single.note, 'ekologiskt');
    expect(vm.items.single.updatedAt, isNotNull);
    vm.dispose();
  });

  test('an edit without an amount keeps the known amount on the row', () async {
    final (vm, service) = await loaded();
    when(
      () => service.updateItem(
        any(),
        any(),
        previous: any(named: 'previous'),
      ),
    ).thenAnswer((_) async {});

    await vm.updateItem(stored.copyWith(clearQuantity: true));

    expect(vm.items.single.quantity, 6);
    vm.dispose();
  });

  test('adjustQuantity sends the delta and moves the row by it', () async {
    final (vm, service) = await loaded();
    when(
      () => service.adjustQuantity(any(), any(), any()),
    ).thenAnswer((_) async => true);

    await vm.adjustQuantity(stored, -2);

    verify(() => service.adjustQuantity(any(), stored, -2)).called(1);
    expect(vm.items.single.quantity, 4);
    vm.dispose();
  });
}
