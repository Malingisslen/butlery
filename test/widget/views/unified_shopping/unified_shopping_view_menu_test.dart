// BUT-2201: "Sortera kategorier" and "Avmarkera alla" moved from buttons
// under the list selector into the root bar's overflow menu. The app bar
// hides each entry when its callback is null, so these tests mount the real
// UnifiedShoppingView over the real view model and a mocked service — the
// screen that passes those callbacks — rather than the app bar alone.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:butlery/l10n/app_localizations_sv.dart';
import 'package:butlery/models/unified/unified_shopping_item.dart';
import 'package:butlery/repositories/interfaces/category_preferences_repository.dart';
import 'package:butlery/services/unified/modules/shopping_category_preferences_module.dart';
import 'package:butlery/services/unified/unified_shopping_service.dart';
import 'package:butlery/viewmodels/unified_shopping_viewmodel.dart';
import 'package:butlery/views/unified_shopping/widgets/category_order_sheet.dart';
import 'package:butlery/views/unified_shopping_view.dart';

import '../../../infrastructure/di/test_service_locator.dart';
import '../../../infrastructure/factories/shopping_list_factory.dart';
import '../../../infrastructure/mocks/production_mocks.dart';
import '../../../views/design_states/state_harness.dart';

class _MockCategoryPreferences extends Mock
    implements CategoryPreferencesRepository {}

final _sv = AppLocalizationsSv();

UnifiedShoppingItem _item(String id, String name, {bool bought = false}) =>
    ShoppingListFactory.buildItem(
      id: id,
      name: name,
      category: 'Frukt & grönt',
      bought: bought,
    );

/// The real shopping tab over a service whose active list has one bought
/// item, so both moved menu entries are eligible to show.
MockUnifiedShoppingService _mountService() {
  final list = ShoppingListFactory.build(
    id: 'list-vecka',
    name: 'Veckans inköp',
    ownerId: 'test-user-123',
    items: [
      _item('i1', 'Gul lök'),
      _item('i2', 'Koriander', bought: true),
    ],
  );
  final service = MockUnifiedShoppingService()
    ..setShoppingState(lists: [list], activeListId: list.id);
  when(service.loadLists).thenAnswer((_) async {});
  when(service.initialize).thenAnswer((_) async {});
  when(service.uncheckAllItems).thenAnswer((_) async => true);
  final repository = _MockCategoryPreferences();
  when(repository.getPreferences).thenAnswer((_) async => null);
  final preferences = ShoppingCategoryPreferencesModule(repository: repository);
  when(() => service.categoryPreferences).thenReturn(preferences);
  TestServiceLocator.registerMock<UnifiedShoppingService>(service);
  TestServiceLocator.registerMock<UnifiedShoppingViewModel>(
    UnifiedShoppingViewModel(),
  );
  return service;
}

Future<void> _openMoreMenu(WidgetTester tester) async {
  setStateSurface(tester);
  await tester.pumpWidget(
    stateApp(mode: Brightness.light, home: const UnifiedShoppingView()),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
  await tester.tap(find.byKey(const ValueKey('shopping-root-more')));
  await tester.pumpAndSettle();
}

void main() {
  late StateEnvironment environment;
  late MockUnifiedShoppingService service;

  setUp(() async {
    environment = await StateEnvironment.setUp(online: true);
    service = _mountService();
  });

  tearDown(() async {
    await environment.tearDown();
  });

  testWidgets(
    'the more menu offers Sortera kategorier and Avmarkera alla, and '
    'Avmarkera alla unchecks the list through the service',
    (tester) async {
      await _openMoreMenu(tester);

      expect(find.text(_sv.shoppingSortCategories), findsOneWidget);
      expect(find.text(_sv.shoppingUncheckAll), findsOneWidget);
      verifyNever(service.uncheckAllItems);

      await tester.tap(find.text(_sv.shoppingUncheckAll));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      verify(service.uncheckAllItems).called(1);
      expect(find.text(_sv.shoppingAllUnchecked), findsOneWidget);
    },
  );

  testWidgets('Sortera kategorier opens the category order sheet', (
    tester,
  ) async {
    await _openMoreMenu(tester);
    expect(find.byType(CategoryOrderSheet), findsNothing);

    await tester.tap(find.text(_sv.shoppingSortCategories));
    await tester.pumpAndSettle();

    expect(find.byType(CategoryOrderSheet), findsOneWidget);
  });
}
