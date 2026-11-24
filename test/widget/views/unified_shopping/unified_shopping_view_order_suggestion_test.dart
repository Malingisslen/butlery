// The order suggestion reaches the shopping tab: with a store picked and a
// steady habit counted, the real UnifiedShoppingView shows the banner, and
// Ja moves the category in the store's order. Mounts the real view so the
// banner hook in the view is what is tested.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:butlery/models/category_preferences.dart';
import 'package:butlery/models/pantry/pantry_item.dart';
import 'package:butlery/models/unified/unified_shopping_item.dart';
import 'package:butlery/repositories/interfaces/category_preferences_repository.dart';
import 'package:butlery/services/shopping/store_order_learner.dart';
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

const _userId = 'test-user-123';
const _listId = 'list-vecka';

final _banner = find.byKey(const ValueKey('unifiedShopping.orderSuggestion'));
final _yes = find.byKey(const ValueKey('unifiedShopping.orderSuggestion.yes'));

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

Future<ShoppingCategoryPreferencesModule> _mount(
  WidgetTester tester, {
  required bool habit,
}) async {
  final list = ShoppingListFactory.build(
    id: _listId,
    name: 'Veckans inköp',
    ownerId: _userId,
    items: const <UnifiedShoppingItem>[],
  );
  final service = MockUnifiedShoppingService()
    ..setShoppingState(lists: [list], activeListId: list.id);
  when(service.loadLists).thenAnswer((_) async {});
  when(service.initialize).thenAnswer((_) async {});
  final repository = _MockCategoryPreferences();
  when(repository.getPreferences).thenAnswer((_) async => null);
  when(() => repository.savePreferences(any())).thenAnswer((_) async {});
  final preferences = ShoppingCategoryPreferencesModule(
    repository: repository,
  );
  await preferences.load();
  final store = (await preferences.addStore('ICA Maxi'))!;
  // Dairy first, so a habit of meat before dairy is out of order.
  await preferences.saveStoreCategoryOrder(store.id, [
    'dairy',
    'meat',
  ]);
  await preferences.setActiveStore(_listId, store.id);
  when(() => service.categoryPreferences).thenReturn(preferences);
  TestServiceLocator.registerMock<UnifiedShoppingService>(service);

  SharedPreferences.setMockInitialValues({});
  final learner = StoreOrderLearner(await SharedPreferences.getInstance());
  if (habit) {
    for (var i = 0; i < StoreOrderLearner.minTicks; i++) {
      learner.endVisit();
      for (final category in ['meat', 'dairy']) {
        await learner.recordTick(
          userId: _userId,
          storeId: store.id,
          listId: _listId,
          category: category,
        );
      }
    }
    learner.endVisit();
  }
  TestServiceLocator.registerMock<UnifiedShoppingViewModel>(
    UnifiedShoppingViewModel(orderLearner: learner),
  );
  _registerPantry();

  setStateSurface(tester);
  await tester.pumpWidget(
    stateApp(mode: Brightness.light, home: const UnifiedShoppingView()),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
  return preferences;
}

void main() {
  late StateEnvironment environment;

  setUpAll(() {
    registerFallbackValue(PantryLocation.fridge);
    registerFallbackValue(CategoryPreferences());
  });

  setUp(() async {
    environment = await StateEnvironment.setUp(online: true);
  });
  tearDown(() => environment.tearDown());

  testWidgets('a counted habit shows the banner under the store chip', (
    tester,
  ) async {
    await _mount(tester, habit: true);

    expect(_banner, findsOneWidget);
  });

  testWidgets('without a counted habit no banner shows', (tester) async {
    await _mount(tester, habit: false);

    expect(_banner, findsNothing);
  });

  testWidgets('Ja moves the category and the banner goes', (tester) async {
    final preferences = await _mount(tester, habit: true);

    await tester.tap(_yes);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(preferences.activeStoreFor(_listId)!.categoryOrder.first, 'meat');
    expect(_banner, findsNothing);
  });
}
