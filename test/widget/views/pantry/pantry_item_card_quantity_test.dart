/// BUT-1863: an empty unit is a real stored value (a recipe line with no
/// amount, checked off from the shopping list), so the quantity line must not
/// carry a trailing space for it.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';

import 'package:butlery/models/pantry/pantry_item.dart';
import 'package:butlery/viewmodels/pantry/pantry_selection_manager.dart';
import 'package:butlery/viewmodels/pantry/pantry_viewmodel.dart';
import 'package:butlery/views/pantry/pantry_item_card.dart';

import '../../../infrastructure/helpers/widget_test_app.dart';
import '../../../infrastructure/helpers/base_widget_test.dart';

class _MockPantryViewModel extends Mock implements PantryViewModel {}

void main() {
  setUpAll(() async {
    await BaseWidgetTest.setupWidget();
  });

  tearDown(() async {
    await BaseWidgetTest.teardownWidget();
  });

  Future<void> pumpCard(WidgetTester tester, {required String unit}) async {
    final item = PantryItem(
      id: 'p_1',
      ingredientName: 'Mjölk',
      quantity: 1,
      unit: unit,
      location: PantryLocation.fridge,
      addedAt: DateTime(2026, 1, 1),
    );
    await tester.pumpWidget(
      createLocalizedTestApp(
        child: MultiProvider(
          providers: [
            ChangeNotifierProvider<PantryViewModel>.value(
              value: _MockPantryViewModel(),
            ),
            ChangeNotifierProvider<PantrySelectionManager>.value(
              value: PantrySelectionManager(),
            ),
          ],
          child: ListView(children: [PantryItemCard(item: item)]),
        ),
      ),
    );
  }

  testWidgets('an empty unit shows the quantity with no trailing space', (
    tester,
  ) async {
    await pumpCard(tester, unit: '');

    expect(find.text('1'), findsOneWidget);
    expect(find.text('1 '), findsNothing);
  });

  testWidgets('a unit is shown after the quantity', (tester) async {
    await pumpCard(tester, unit: 'l');

    expect(find.text('1 l'), findsOneWidget);
  });
}
