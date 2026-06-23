/// BUT-948: pins the ViewModel half of pantry multi-select bulk delete +
/// bulk undo. Intent: bulkRemoveItems deletes exactly the selected ids (and
/// nothing else) and restoreItems re-appends every removed row with its fresh
/// service-returned document id — the same correctness contract as the
/// single-item swipe-undo flow, applied to a batch.
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

PantryItem _item(String id) => PantryItem(
  id: id,
  ingredientName: 'Item $id',
  quantity: 1,
  unit: 'st',
  location: PantryLocation.fridge,
  addedAt: DateTime(2026, 1, 1),
);

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await BaseUnitTest.setupUnit();
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

  PantryViewModel buildVm(_MockPantryService service) => PantryViewModel(
    pantryService: service,
    ingredientRepository: _MockIngredientRepository(),
  );

  test('bulkRemoveItems deletes only the selected ids', () async {
    final service = _MockPantryService();
    when(
      () => service.getAll(any()),
    ).thenAnswer((_) async => [_item('a'), _item('b'), _item('c')]);
    when(() => service.removeItem(any(), any())).thenAnswer((_) async {});

    final vm = buildVm(service);
    await vm.loadPantry();
    expect(vm.items, hasLength(3));

    await vm.bulkRemoveItems({'a', 'c'});

    expect(
      vm.items.map((i) => i.id),
      ['b'],
      reason: 'only the two selected rows are gone; the unselected one stays',
    );
    verify(() => service.removeItem(any(), 'a')).called(1);
    verify(() => service.removeItem(any(), 'c')).called(1);
    verifyNever(() => service.removeItem(any(), 'b'));
    expect(vm.hasError, isFalse);
    vm.dispose();
  });

  test('bulkRemoveItems is a no-op for an empty selection', () async {
    final service = _MockPantryService();
    when(() => service.getAll(any())).thenAnswer((_) async => [_item('a')]);

    final vm = buildVm(service);
    await vm.loadPantry();

    await vm.bulkRemoveItems(const <String>{});

    expect(vm.items, hasLength(1));
    verifyNever(() => service.removeItem(any(), any()));
    vm.dispose();
  });

  test('restoreItems re-appends every removed row with its fresh id', () async {
    final service = _MockPantryService();
    final a = _item('a');
    final b = _item('b');
    when(
      () => service.restoreItem(any(), a),
    ).thenAnswer((_) async => a.copyWith(id: 'a-new'));
    when(
      () => service.restoreItem(any(), b),
    ).thenAnswer((_) async => b.copyWith(id: 'b-new'));

    // An undeleted row is already present — undo must append, not replace.
    when(() => service.getAll(any())).thenAnswer((_) async => [_item('c')]);
    final vm = buildVm(service);
    await vm.loadPantry();

    await vm.restoreItems([a, b]);

    expect(
      vm.items.map((i) => i.id),
      ['c', 'a-new', 'b-new'],
      reason:
          'undo re-adds the removed rows alongside the surviving one, '
          'with the re-persisted ids — not the deleted ones',
    );
    expect(vm.hasError, isFalse);
    vm.dispose();
  });
}
