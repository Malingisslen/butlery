// BUT-723: Inköp on a tablet in landscape shows every list on the left and
// the active list on the right; portrait and phones keep the dropdown.

import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:butlery/l10n/app_localizations_sv.dart';
import 'package:butlery/models/pantry/pantry_item.dart';
import 'package:butlery/models/unified/unified_shopping_item.dart';
import 'package:butlery/models/unified/unified_shopping_list.dart';
import 'package:butlery/repositories/interfaces/category_preferences_repository.dart';
import 'package:butlery/services/unified/modules/shopping_category_preferences_module.dart';
import 'package:butlery/services/unified/types/service_states.dart';
import 'package:butlery/viewmodels/pantry/pantry_viewmodel.dart';
import 'package:butlery/services/unified/unified_shopping_service.dart';
import 'package:butlery/viewmodels/unified_shopping_viewmodel.dart';
import 'package:butlery/views/unified_shopping/widgets/shopping_lists_pane.dart';
import 'package:butlery/views/unified_shopping_view.dart';
import 'package:butlery/widgets/common/selection_bulk_bar.dart';

import '../../../infrastructure/di/test_service_locator.dart';
import '../../../infrastructure/factories/shopping_list_factory.dart';
import '../../../infrastructure/mocks/production_mocks.dart';
import '../../../views/design_states/state_harness.dart';

class _MockCategoryPreferences extends Mock
    implements CategoryPreferencesRepository {}

class _MockPantryViewModel extends Mock implements PantryViewModel {}

/// An empty pantry, enough for the Skafferiet tab to draw.
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

final _sv = AppLocalizationsSv();

const _landscape = Size(1280, 800);
const _portrait = Size(800, 1280);

UnifiedShoppingItem _item(String id, String name) =>
    ShoppingListFactory.buildItem(id: id, name: name, category: 'Mejeri');

final _weekly = ShoppingListFactory.build(
  id: 'list-vecka',
  name: 'Veckans inköp',
  ownerId: 'test-user-123',
  items: [_item('i1', 'Gul lök'), _item('i2', 'Mjölk')],
);

final _weekend = ShoppingListFactory.build(
  id: 'list-helg',
  name: 'Helgmiddag',
  ownerId: 'test-user-123',
  type: ListType.collaborative,
  items: [_item('i3', 'Grädde')],
);

MockUnifiedShoppingService _mountService() {
  final lists = [_weekly, _weekend];
  final service = MockUnifiedShoppingService()
    ..setShoppingState(lists: lists, activeListId: _weekly.id);
  when(service.loadLists).thenAnswer((_) async {});
  when(service.initialize).thenAnswer((_) async {});
  when(() => service.setActiveList(any())).thenAnswer((invocation) async {
    final id = invocation.positionalArguments.first as String;
    service
      ..setShoppingState(lists: lists, activeListId: id)
      ..emitState(ShoppingStateData(lists: lists, activeListId: id));
    return true;
  });
  final repository = _MockCategoryPreferences();
  when(repository.getPreferences).thenAnswer((_) async => null);
  when(
    () => service.categoryPreferences,
  ).thenReturn(ShoppingCategoryPreferencesModule(repository: repository));
  TestServiceLocator.registerMock<UnifiedShoppingService>(service);
  TestServiceLocator.registerMock<UnifiedShoppingViewModel>(
    UnifiedShoppingViewModel(),
  );
  return service;
}

Future<void> _pumpShopping(WidgetTester tester, Size size) async {
  setStateSurface(tester, size: size);
  await tester.pumpWidget(
    stateApp(mode: Brightness.light, home: const UnifiedShoppingView()),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}

Finder _card(String id) => find.byKey(ValueKey('shopping-pane-list-$id'));

bool _isSelected(WidgetTester tester, String name) =>
    tester
        .getSemantics(
          find.ancestor(
            of: find.text(name),
            matching: find.bySemanticsLabel(
              RegExp('^${_sv.a11yShoppingPickList}'),
            ),
          ),
        )
        .getSemanticsData()
        .flagsCollection
        .isSelected ==
    ui.Tristate.isTrue;

void main() {
  late StateEnvironment environment;
  late MockUnifiedShoppingService service;

  setUpAll(() => registerFallbackValue(PantryLocation.fridge));

  setUp(() async {
    environment = await StateEnvironment.setUp(online: true);
    service = _mountService();
  });

  tearDown(() async {
    await environment.tearDown();
  });

  testWidgets(
    'landscape: every list is a card, the active one marked, and the '
    'right side carries the active list without the dropdown',
    (tester) async {
      final semantics = tester.ensureSemantics();
      await _pumpShopping(tester, _landscape);

      expect(find.byType(ShoppingListsPane), findsOneWidget);
      expect(find.text(_sv.shoppingListsCount(2)), findsOneWidget);
      expect(_card(_weekly.id), findsOneWidget);
      expect(_card(_weekend.id), findsOneWidget);
      expect(
        find.descendant(
          of: _card(_weekend.id),
          matching: find.text(
            '${_sv.shoppingItemCount(1)} · ${_sv.shoppingPermissionShared}',
          ),
        ),
        findsOneWidget,
      );
      expect(_isSelected(tester, _weekly.name), isTrue);
      expect(_isSelected(tester, _weekend.name), isFalse);

      // The right side's bar names the active list, and the dropdown that
      // would repeat the cards is gone.
      expect(find.byType(DropdownButton<String>), findsNothing);
      // The add button and Välj moved with the list to the right side.
      expect(
        find.byKey(const ValueKey('test-shopping-list-add')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('shopping-select-enter')),
        findsOneWidget,
      );
      expect(find.textContaining('Gul lök'), findsOneWidget);
      semantics.dispose();
    },
  );

  testWidgets('landscape: a card tap makes that list active', (tester) async {
    final semantics = tester.ensureSemantics();
    await _pumpShopping(tester, _landscape);

    await tester.tap(_card(_weekend.id));
    await tester.pump();
    await tester.pump();

    verify(() => service.setActiveList(_weekend.id)).called(1);
    expect(_isSelected(tester, _weekend.name), isTrue);
    expect(_isSelected(tester, _weekly.name), isFalse);
    expect(find.textContaining('Grädde'), findsOneWidget);
    expect(find.textContaining('Gul lök'), findsNothing);
    semantics.dispose();
  });

  testWidgets(
    'landscape: selecting rows puts the bulk bar on the right, and picking '
    'another list ends the selection',
    (tester) async {
      await _pumpShopping(tester, _landscape);

      await tester.tap(find.byKey(const ValueKey('shopping-select-enter')));
      await tester.pump();
      expect(find.byType(SelectionBulkBar), findsOneWidget);
      expect(
        find.ancestor(
          of: find.byType(SelectionBulkBar),
          matching: find.byType(ShoppingTwoPanes),
        ),
        findsOneWidget,
      );

      await tester.tap(_card(_weekend.id));
      await tester.pump();
      await tester.pump();

      expect(find.byType(SelectionBulkBar), findsNothing);
      expect(
        find.byKey(const ValueKey('shopping-selection-cancel')),
        findsNothing,
      );
    },
  );

  testWidgets('landscape: Ny inköpslista opens the create dialog', (
    tester,
  ) async {
    await _pumpShopping(tester, _landscape);

    await tester.tap(find.byKey(const ValueKey('shopping-pane-new-list')));
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsOneWidget);
    expect(find.text(_sv.shoppingCreateNewList), findsOneWidget);
  });

  testWidgets(
    'landscape: Skafferiet keeps the tabs on the left and drops the cards',
    (tester) async {
      _registerPantry();
      await _pumpShopping(tester, _landscape);

      await tester.tap(find.text(_sv.shoppingTabPantry));
      await tester.pumpAndSettle();

      expect(
        find.descendant(
          of: find.byType(ShoppingListsPane),
          matching: find.text(_sv.shoppingTabPantry),
        ),
        findsOneWidget,
      );
      expect(_card(_weekly.id), findsNothing);
    },
  );

  testWidgets('portrait keeps the phone layout with the dropdown', (
    tester,
  ) async {
    await _pumpShopping(tester, _portrait);

    expect(find.byType(ShoppingListsPane), findsNothing);
    expect(find.byType(DropdownButton<String>), findsOneWidget);
  });

  testWidgets(
    'portrait: selecting rows swaps the add button for the bulk bar and '
    'Avbryt ends it',
    (tester) async {
      await _pumpShopping(tester, _portrait);
      const addButton = ValueKey('test-shopping-list-add');
      expect(find.byType(SelectionBulkBar), findsNothing);
      expect(find.byKey(addButton), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('shopping-select-enter')));
      await tester.pumpAndSettle();

      expect(find.byType(SelectionBulkBar), findsOneWidget);
      expect(find.byKey(addButton), findsNothing);
      expect(find.text(_sv.bulkSelectedCount(0)), findsWidgets);

      await tester.tap(find.byKey(const ValueKey('shopping-selection-cancel')));
      await tester.pump();

      expect(find.byType(SelectionBulkBar), findsNothing);
      expect(
        find.byKey(const ValueKey('shopping-selection-cancel')),
        findsNothing,
      );
    },
  );
}
