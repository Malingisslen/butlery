// The line "Uppdaterad från veckomenyn" reaches the shopping tab: it shows for
// the list on screen, offers Ångra only with a connection, and is gone once the
// user moves to Skafferiet. Mounts the real UnifiedShoppingView so the
// arguments the view gives the bar are what is tested.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:butlery/models/pantry/pantry_item.dart';
import 'package:butlery/models/unified/unified_shopping_item.dart';
import 'package:butlery/repositories/interfaces/category_preferences_repository.dart';
import 'package:butlery/services/shopping/menu_shopping_list_generator.dart';
import 'package:butlery/services/unified/modules/shopping_category_preferences_module.dart';
import 'package:butlery/services/unified/unified_shopping_service.dart';
import 'package:butlery/viewmodels/pantry/pantry_viewmodel.dart';
import 'package:butlery/viewmodels/unified_shopping_viewmodel.dart';
import 'package:butlery/views/unified_shopping_view.dart';

import '../../../infrastructure/di/test_service_locator.dart';
import '../../../infrastructure/factories/shopping_list_factory.dart';
import '../../../infrastructure/mocks/production_mocks.dart';
import '../../../views/design_states/state_harness.dart';

class _MockCategoryPreferences extends Mock
    implements CategoryPreferencesRepository {}

class _MockPantryViewModel extends Mock implements PantryViewModel {}

class _MockGenerator extends Mock implements MenuShoppingListGenerator {}

const _line = 'Uppdaterad från veckomenyn: 3 nya, 1 borttagen';

final _undo = find.byKey(
  const ValueKey('unifiedShopping.weekListFollowNotice.undo'),
);

void _registerPantry() {
  final vm = _MockPantryViewModel();
  when(() => vm.isLoading).thenReturn(false);
  when(() => vm.error).thenReturn(null);
  when(() => vm.hasError).thenReturn(false);
  when(() => vm.items).thenReturn(const []);
  when(() => vm.expiringItems).thenReturn(const []);
  when(() => vm.itemsByLocation(any())).thenReturn(const []);
  when(() => vm.searchResults).thenReturn(const []);
  when(vm.loadPantry).thenAnswer((_) async {});
  TestServiceLocator.registerFactory<PantryViewModel>(() => vm);
}

Future<StateEnvironment> _mount(
  WidgetTester tester, {
  required bool online,
}) async {
  final environment = await StateEnvironment.setUp(online: online);
  final list = ShoppingListFactory.build(
    id: 'list-vecka',
    name: 'Veckans inköp',
    ownerId: 'test-user-123',
    items: const [],
  );
  final service = MockUnifiedShoppingService()
    ..setShoppingState(lists: [list], activeListId: list.id);
  when(service.loadLists).thenAnswer((_) async {});
  when(service.initialize).thenAnswer((_) async {});
  final repository = _MockCategoryPreferences();
  when(repository.getPreferences).thenAnswer((_) async => null);
  when(
    () => service.categoryPreferences,
  ).thenReturn(ShoppingCategoryPreferencesModule(repository: repository));
  TestServiceLocator.registerMock<UnifiedShoppingService>(service);
  TestServiceLocator.registerMock<UnifiedShoppingViewModel>(
    UnifiedShoppingViewModel(),
  );
  _registerPantry();

  final generator = _MockGenerator();
  when(() => generator.takeFollowNotice('list-vecka')).thenAnswer(
    (_) async => WeekListFollowNotice(
      listId: 'list-vecka',
      addedIds: const ['a0', 'a1', 'a2'],
      removed: [UnifiedShoppingItem(id: 'r0', name: 'Mjölk', amount: 1)],
      changed: const [],
      updatedAt: DateTime(2026, 10, 31),
    ),
  );
  when(() => generator.putBackFollowNotice(any())).thenAnswer((_) async {});
  TestServiceLocator.registerMock<MenuShoppingListGenerator>(generator);

  setStateSurface(tester);
  await tester.pumpWidget(
    stateApp(mode: Brightness.light, home: const UnifiedShoppingView()),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
  return environment;
}

void main() {
  late StateEnvironment environment;

  setUpAll(() {
    registerFallbackValue(PantryLocation.fridge);
    registerFallbackValue(
      WeekListFollowNotice(
        listId: '',
        addedIds: const [],
        removed: const [],
        changed: const [],
        updatedAt: DateTime(2026),
      ),
    );
  });

  tearDown(() => environment.tearDown());

  testWidgets('the active list\'s line shows on the shopping tab with Ångra', (
    tester,
  ) async {
    environment = await _mount(tester, online: true);

    expect(find.text(_line), findsOneWidget);
    expect(_undo, findsOneWidget);
  });

  testWidgets('without a connection the line shows without Ångra', (
    tester,
  ) async {
    environment = await _mount(tester, online: false);

    expect(find.text(_line), findsOneWidget);
    expect(_undo, findsNothing);
  });

  // The TabBarView unbuilds the shopping page behind Skafferiet, so this holds
  // the user-visible result; it does not isolate the view's null listId.
  testWidgets('moving to Skafferiet drops the line', (tester) async {
    environment = await _mount(tester, online: true);
    expect(find.text(_line), findsOneWidget);

    await tester.tap(find.text('Skafferiet'));
    await tester.pumpAndSettle();

    expect(find.text(_line), findsNothing);
  });
}
