/// A pantry add with no amount reaches the service as null. The service
/// defaults an omitted quantity to 1, so a view model that drops the argument
/// would store "1 st" where the user asked for "har hemma".
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:butlery/core/di/di_container.dart';
import 'package:butlery/core/providers/application_provider.dart' as production;
import 'package:butlery/models/pantry/pantry_item.dart';
import 'package:butlery/models/tagging/ingredient_data.dart';
import 'package:butlery/repositories/interfaces/ingredient_repository.dart';
import 'package:butlery/services/pantry/pantry_service.dart';
import 'package:butlery/viewmodels/pantry/pantry_viewmodel.dart';

import '../../../infrastructure/di/test_service_locator.dart';
import '../../../test_support/base_unit_test.dart';

const _ingredientFixture = IngredientData(
  id: 'salt',
  swedish: 'Salt',
  english: 'Salt',
  group: 'other',
  properties: {},
);

class _MockPantryService extends Mock implements PantryService {}

class _MockIngredientRepository extends Mock implements IngredientRepository {}

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await BaseUnitTest.setupUnit();
    registerFallbackValue(_ingredientFixture);
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

  final added = PantryItem(
    id: 'new-id',
    ingredientName: 'Salt',
    quantity: null,
    unit: 'st',
    location: PantryLocation.pantry,
    addedAt: DateTime(2026, 1, 1),
  );
  const ingredient = _ingredientFixture;

  late _MockPantryService service;
  late PantryViewModel vm;

  setUp(() {
    service = _MockPantryService();
    vm = PantryViewModel(
      pantryService: service,
      ingredientRepository: _MockIngredientRepository(),
    );
  });

  tearDown(() => vm.dispose());

  group('addItemFromText', () {
    Future<void> stubAndAdd(double? quantity) async {
      when(
        () => service.addFromText(
          any(),
          any(),
          quantity: any(named: 'quantity'),
          unit: any(named: 'unit'),
          location: any(named: 'location'),
          expiryDate: any(named: 'expiryDate'),
          note: any(named: 'note'),
        ),
      ).thenAnswer((_) async => added);
      await vm.addItemFromText('Salt', quantity: quantity);
    }

    test('forwards a null quantity instead of the default 1', () async {
      await stubAndAdd(null);

      verify(
        () => service.addFromText(
          any(),
          'Salt',
          quantity: null,
          unit: any(named: 'unit'),
          location: any(named: 'location'),
          expiryDate: any(named: 'expiryDate'),
          note: any(named: 'note'),
        ),
      ).called(1);
      expect(vm.items, [added]);
    });

    test('forwards a typed quantity', () async {
      await stubAndAdd(6);

      verify(
        () => service.addFromText(
          any(),
          'Salt',
          quantity: 6,
          unit: any(named: 'unit'),
          location: any(named: 'location'),
          expiryDate: any(named: 'expiryDate'),
          note: any(named: 'note'),
        ),
      ).called(1);
    });
  });

  group('addItemFromIngredient', () {
    Future<void> stubAndAdd(double? quantity) async {
      when(
        () => service.addFromIngredient(
          any(),
          any(),
          quantity: any(named: 'quantity'),
          unit: any(named: 'unit'),
          location: any(named: 'location'),
          expiryDate: any(named: 'expiryDate'),
          note: any(named: 'note'),
        ),
      ).thenAnswer((_) async => added);
      await vm.addItemFromIngredient(ingredient, quantity: quantity);
    }

    test('forwards a null quantity instead of the default 1', () async {
      await stubAndAdd(null);

      verify(
        () => service.addFromIngredient(
          any(),
          ingredient,
          quantity: null,
          unit: any(named: 'unit'),
          location: any(named: 'location'),
          expiryDate: any(named: 'expiryDate'),
          note: any(named: 'note'),
        ),
      ).called(1);
      expect(vm.items, [added]);
    });

    test('forwards a typed quantity', () async {
      await stubAndAdd(6);

      verify(
        () => service.addFromIngredient(
          any(),
          ingredient,
          quantity: 6,
          unit: any(named: 'unit'),
          location: any(named: 'location'),
          expiryDate: any(named: 'expiryDate'),
          note: any(named: 'note'),
        ),
      ).called(1);
    });
  });

  // Kärnflöde 10G: a staple added from the sheet must reach the service
  // flagged, or it is stored as an ordinary row and bought again.
  group('a staple', () {
    test('addItemFromText forwards isStaple', () async {
      when(
        () => service.addFromText(
          any(),
          any(),
          quantity: any(named: 'quantity'),
          unit: any(named: 'unit'),
          location: any(named: 'location'),
          expiryDate: any(named: 'expiryDate'),
          note: any(named: 'note'),
          isStaple: any(named: 'isStaple'),
        ),
      ).thenAnswer((_) async => added);

      await vm.addItemFromText('Salt', quantity: null, isStaple: true);

      verify(
        () => service.addFromText(
          any(),
          'Salt',
          quantity: null,
          unit: any(named: 'unit'),
          location: any(named: 'location'),
          expiryDate: any(named: 'expiryDate'),
          note: any(named: 'note'),
          isStaple: true,
        ),
      ).called(1);
    });

    test('addItemFromIngredient forwards isStaple', () async {
      when(
        () => service.addFromIngredient(
          any(),
          any(),
          quantity: any(named: 'quantity'),
          unit: any(named: 'unit'),
          location: any(named: 'location'),
          expiryDate: any(named: 'expiryDate'),
          note: any(named: 'note'),
          isStaple: any(named: 'isStaple'),
        ),
      ).thenAnswer((_) async => added);

      await vm.addItemFromIngredient(
        ingredient,
        quantity: null,
        isStaple: true,
      );

      verify(
        () => service.addFromIngredient(
          any(),
          ingredient,
          quantity: null,
          unit: any(named: 'unit'),
          location: any(named: 'location'),
          expiryDate: any(named: 'expiryDate'),
          note: any(named: 'note'),
          isStaple: true,
        ),
      ).called(1);
    });
  });
}
