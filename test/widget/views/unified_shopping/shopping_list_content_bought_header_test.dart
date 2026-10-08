// BUT-2201: the shopping list's bought-section heading, drawn per the facit
// (Grafisk manual v6:524; Skarmar v12 del 2 #inkop :915-916 light, :1020-1021
// dark) as "Köpt (N)" with a right-aligned "Rensa köpta" text action.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/viewmodels/unified_shopping_viewmodel.dart';
import 'package:butlery/views/unified_shopping/widgets/shopping_list_content.dart';

import '../../../infrastructure/factories/shopping_list_factory.dart';
import '../../../infrastructure/helpers/widget_test_app.dart';

class _MockUnifiedShoppingViewModel extends Mock
    implements UnifiedShoppingViewModel {}

void main() {
  late _MockUnifiedShoppingViewModel viewModel;

  setUp(() {
    viewModel = _MockUnifiedShoppingViewModel();

    final list = ShoppingListFactory.build(
      items: [
        ShoppingListFactory.buildItem(id: 'i1', name: 'Mjölk', bought: true),
        ShoppingListFactory.buildItem(id: 'i2', name: 'Bröd', bought: true),
        ShoppingListFactory.buildItem(id: 'i3', name: 'Ägg', bought: false),
      ],
    );

    when(() => viewModel.isLoading).thenReturn(false);
    when(() => viewModel.hasError).thenReturn(false);
    when(() => viewModel.error).thenReturn(null);
    when(() => viewModel.activeList).thenReturn(list);
    when(() => viewModel.items).thenReturn(list.items);
    when(() => viewModel.hasItems).thenReturn(true);
    when(() => viewModel.boughtItems).thenReturn(2);
    when(() => viewModel.totalItems).thenReturn(3);
    when(() => viewModel.categoryOrder).thenReturn(['Mejeri', 'Bageri']);
    when(() => viewModel.canEditActiveList).thenReturn(true);
  });

  testWidgets('shows the "Köpt (2)" heading over the bought section', (
    tester,
  ) async {
    await tester.pumpWidget(
      createLocalizedTestApp(
        child: Builder(
          builder: (context) => ShoppingListContent.build(
            context,
            viewModel,
            (_) {},
            (_) {},
            (_) {},
            () {},
            () {},
            () {},
          ),
        ),
      ),
    );

    expect(find.text('Köpt (2)'), findsOneWidget);
    expect(find.text('Köpta'), findsNothing);
  });

  testWidgets(
    '"Rensa köpta" is a real 48 dp text action that calls onClearCompleted',
    (tester) async {
      var cleared = 0;

      await tester.pumpWidget(
        createLocalizedTestApp(
          child: Builder(
            builder: (context) => ShoppingListContent.build(
              context,
              viewModel,
              (_) {},
              (_) {},
              (_) {},
              () {},
              () {},
              () => cleared++,
            ),
          ),
        ),
      );

      final buttonFinder = find.widgetWithText(TextButton, 'Rensa köpta');
      expect(buttonFinder, findsOneWidget);

      final size = tester.getSize(buttonFinder);
      expect(
        size.height,
        greaterThanOrEqualTo(AppDimensions.minTouchTarget),
      );

      await tester.tap(buttonFinder);
      await tester.pump();

      expect(cleared, 1);
    },
  );
}
