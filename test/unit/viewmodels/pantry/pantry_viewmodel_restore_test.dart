/// BUT-954: pins the ViewModel half of the snackbar-undo contract — after
/// `restoreItem`, the list contains the SERVICE-RETURNED item (fresh document
/// ID), not the stale pre-delete one. A regression that re-appends the old
/// item would leave the UI holding a dead ID: a second swipe-delete of the
/// restored row would target a nonexistent document.
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

  final removed = PantryItem(
    id: 'old-id',
    ingredientName: 'Mjölk',
    quantity: 1,
    unit: 'l',
    location: PantryLocation.fridge,
    addedAt: DateTime(2026, 1, 1),
  );

  test('restoreItem appends the service-returned item with its fresh id',
      () async {
    final service = _MockPantryService();
    when(() => service.restoreItem(any(), removed))
        .thenAnswer((_) async => removed.copyWith(id: 'new-id'));

    final vm = PantryViewModel(
      pantryService: service,
      ingredientRepository: _MockIngredientRepository(),
    );

    await vm.restoreItem(removed);

    expect(vm.items, hasLength(1));
    expect(vm.items.single.id, 'new-id',
        reason: 'The list must hold the re-persisted document id — keeping '
            '"old-id" would make follow-up operations target a deleted doc.');
    expect(vm.items.single.ingredientName, 'Mjölk');
    expect(vm.hasError, isFalse);
    vm.dispose();
  });
}
