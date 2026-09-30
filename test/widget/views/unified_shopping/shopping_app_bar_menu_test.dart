// BUT-2201: the root bar's overflow menu gains two entries — "Sortera
// kategorier" (only with an active list) and "Avmarkera alla" (only once
// something is bought).

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:butlery/viewmodels/unified_shopping_viewmodel.dart';
import 'package:butlery/views/unified_shopping/widgets/shopping_app_bar.dart';

import '../../../infrastructure/factories/shopping_list_factory.dart';
import '../../../infrastructure/helpers/widget_test_app.dart';

class _MockUnifiedShoppingViewModel extends Mock
    implements UnifiedShoppingViewModel {}

Future<void> _pumpMenu(
  WidgetTester tester,
  UnifiedShoppingViewModel viewModel, {
  VoidCallback? onSortCategories,
  VoidCallback? onUncheckAll,
}) async {
  await tester.pumpWidget(
    createLocalizedTestApp(
      wrapInScaffold: false,
      child: Builder(
        builder: (context) => Scaffold(
          appBar: AppBar(
            actions: ShoppingAppBar.buildHeaderActions(
              context,
              viewModel,
              () {},
              () {},
              () {},
              () {},
              onSortCategories: onSortCategories,
              onUncheckAll: onUncheckAll,
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.byKey(const ValueKey('shopping-root-more')));
  await tester.pumpAndSettle();
}

void main() {
  late _MockUnifiedShoppingViewModel viewModel;

  setUp(() {
    viewModel = _MockUnifiedShoppingViewModel();
    when(() => viewModel.hasItems).thenReturn(false);
    when(() => viewModel.boughtItems).thenReturn(0);
    when(() => viewModel.activeList).thenReturn(null);
  });

  testWidgets(
    'Sortera kategorier shows with an active list and calls onSortCategories',
    (tester) async {
      when(
        () => viewModel.activeList,
      ).thenReturn(ShoppingListFactory.build());
      var sorted = 0;

      await _pumpMenu(
        tester,
        viewModel,
        onSortCategories: () => sorted++,
      );

      expect(find.text('Sortera kategorier'), findsOneWidget);
      expect(find.text('Avmarkera alla'), findsNothing);

      await tester.tap(find.text('Sortera kategorier'));
      await tester.pumpAndSettle();

      expect(sorted, 1);
    },
  );

  testWidgets(
    'Sortera kategorier is absent without an active list, even with a callback',
    (tester) async {
      await _pumpMenu(tester, viewModel, onSortCategories: () {});

      expect(find.text('Sortera kategorier'), findsNothing);
    },
  );

  testWidgets(
    'Avmarkera alla shows once something is bought and calls onUncheckAll',
    (tester) async {
      when(
        () => viewModel.activeList,
      ).thenReturn(ShoppingListFactory.build());
      when(() => viewModel.boughtItems).thenReturn(3);
      var unchecked = 0;

      await _pumpMenu(
        tester,
        viewModel,
        onUncheckAll: () => unchecked++,
      );

      expect(find.text('Avmarkera alla'), findsOneWidget);

      await tester.tap(find.text('Avmarkera alla'));
      await tester.pumpAndSettle();

      expect(unchecked, 1);
    },
  );

  testWidgets(
    'Avmarkera alla is absent with nothing bought, even with a callback',
    (tester) async {
      when(
        () => viewModel.activeList,
      ).thenReturn(ShoppingListFactory.build());
      when(() => viewModel.boughtItems).thenReturn(0);

      await _pumpMenu(tester, viewModel, onUncheckAll: () {});

      expect(find.text('Avmarkera alla'), findsNothing);
    },
  );
}
