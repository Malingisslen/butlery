// A mass delete that fails must say so and keep the selection, so the shopper
// can try again; it must not offer an undo for items that were never removed.
// These drive the real UnifiedShoppingView over the real view model; only the
// service seam is faked.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:butlery/l10n/app_localizations_sv.dart';
import 'package:butlery/repositories/interfaces/category_preferences_repository.dart';
import 'package:butlery/services/unified/modules/shopping_category_preferences_module.dart';
import 'package:butlery/services/unified/unified_shopping_service.dart';
import 'package:butlery/viewmodels/unified_shopping_viewmodel.dart';
import 'package:butlery/views/unified_shopping_view.dart';
import 'package:butlery/widgets/common/selection_bulk_bar.dart';

import '../../../infrastructure/di/test_service_locator.dart';
import '../../../infrastructure/factories/shopping_list_factory.dart';
import '../../../infrastructure/mocks/production_mocks.dart';
import '../../../views/design_states/state_harness.dart';

class _MockCategoryPreferences extends Mock
    implements CategoryPreferencesRepository {}

final _sv = AppLocalizationsSv();

const _listId = 'list-egen';

void main() {
  late StateEnvironment environment;
  late MockUnifiedShoppingService service;

  setUp(() async {
    environment = await StateEnvironment.setUp(online: true);

    service = MockUnifiedShoppingService();
    service.setShoppingState(
      lists: [
        ShoppingListFactory.build(
          id: _listId,
          name: 'Veckohandling',
          items: [
            ShoppingListFactory.buildItem(
              id: 'i1',
              name: 'Gul lök',
              category: 'Frukt & grönt',
            ),
            ShoppingListFactory.buildItem(
              id: 'i2',
              name: 'Potatis',
              category: 'Frukt & grönt',
            ),
          ],
        ),
      ],
      activeListId: _listId,
    );
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
  });

  tearDown(() async {
    await environment.tearDown();
  });

  Future<void> selectBothAndDelete(WidgetTester tester) async {
    setStateSurface(tester);
    await tester.pumpWidget(
      stateApp(mode: Brightness.light, home: const UnifiedShoppingView()),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    await tester.tap(find.byKey(const ValueKey('shopping-select-enter')));
    await tester.pump();
    await tester.tap(find.textContaining('Gul lök'));
    await tester.pump();
    await tester.tap(find.textContaining('Potatis'));
    await tester.pump();
    expect(find.text(_sv.bulkSelectedCount(2)), findsWidgets);

    await tester.tap(
      find.descendant(
        of: find.byType(SelectionBulkBar),
        matching: find.text(_sv.commonDelete),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
  }

  testWidgets('a failed mass delete says so, keeps the selection and offers '
      'no undo', (tester) async {
    when(
      () => service.removeItemFromActiveList(any()),
    ).thenAnswer((_) async => false);

    await selectBothAndDelete(tester);

    verify(() => service.removeItemFromActiveList('i1')).called(1);
    verify(() => service.removeItemFromActiveList('i2')).called(1);
    expect(find.textContaining(_sv.shoppingBulkRemoveFailed), findsOneWidget);
    expect(
      find.textContaining(_sv.shoppingBulkRemoveFailedKept),
      findsOneWidget,
    );
    expect(find.text(_sv.bulkSelectedCount(2)), findsWidgets);
    expect(find.byType(SelectionBulkBar), findsOneWidget);
    expect(find.text(_sv.commonUndo), findsNothing);
  });

  testWidgets('a mass delete that works clears the selection and offers undo', (
    tester,
  ) async {
    when(
      () => service.removeItemFromActiveList(any()),
    ).thenAnswer((_) async => true);

    await selectBothAndDelete(tester);

    expect(find.textContaining(_sv.shoppingBulkRemoveFailed), findsNothing);
    expect(find.byType(SelectionBulkBar), findsNothing);
    expect(find.text(_sv.shoppingItemsRemovedUndoMessage(2)), findsOneWidget);
    expect(find.text(_sv.commonUndo), findsOneWidget);
  });
}
