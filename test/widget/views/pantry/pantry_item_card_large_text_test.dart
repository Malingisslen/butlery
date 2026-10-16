/// At 200 % text the expiry badge sits under the amount, so the amount keeps
/// its words whole instead of being squeezed into a narrow column.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';

import 'package:butlery/models/pantry/pantry_item.dart';
import 'package:butlery/viewmodels/pantry/pantry_selection_manager.dart';
import 'package:butlery/viewmodels/pantry/pantry_viewmodel.dart';
import 'package:butlery/views/pantry/pantry_item_card.dart';

import '../../../infrastructure/helpers/base_widget_test.dart';
import '../../../infrastructure/helpers/widget_test_app.dart';
import '../../../infrastructure/helpers/word_break_finder.dart';

class _MockPantryViewModel extends Mock implements PantryViewModel {}

void main() {
  setUpAll(BaseWidgetTest.setupWidget);
  tearDown(BaseWidgetTest.teardownWidget);

  testWidgets('a card with an expiry date wraps between words at 200 % text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final item = PantryItem(
      id: 'p_1',
      ingredientName: 'Kokosmjölk',
      quantity: 2,
      unit: 'st',
      location: PantryLocation.fridge,
      addedAt: DateTime(2026, 1, 1),
      expiryDate: DateTime.now().add(const Duration(days: 3)),
    );
    await tester.pumpWidget(
      createLocalizedTestApp(
        child: Builder(
          builder: (context) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: const TextScaler.linear(2)),
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
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(findMidWordBreaks(tester), isEmpty);
  });
}
