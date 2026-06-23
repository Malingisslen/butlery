/// BUT-948: gates the pantry card's multi-select behaviour — long-press enters
/// selection (showing the checkbox), the selected row reads as selected to a11y,
/// and toggling the last row off auto-exits selection mode. Swipe-to-delete is
/// suppressed while selecting (the bulk bar owns deletion then).
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

  final item = PantryItem(
    id: 'p_1',
    ingredientName: 'Mjölk',
    quantity: 1,
    unit: 'l',
    location: PantryLocation.fridge,
    addedAt: DateTime(2026, 1, 1),
  );

  Future<PantrySelectionManager> pumpCard(WidgetTester tester) async {
    final mockVm = _MockPantryViewModel();
    when(() => mockVm.removeItem(any())).thenAnswer((_) async {});
    final selection = PantrySelectionManager();

    await tester.pumpWidget(
      createLocalizedTestApp(
        child: MultiProvider(
          providers: [
            ChangeNotifierProvider<PantryViewModel>.value(value: mockVm),
            ChangeNotifierProvider<PantrySelectionManager>.value(
              value: selection,
            ),
          ],
          child: ListView(children: [PantryItemCard(item: item)]),
        ),
      ),
    );
    return selection;
  }

  testWidgets('long-press enters selection mode and shows the checkbox', (
    tester,
  ) async {
    final selection = await pumpCard(tester);

    await tester.longPress(find.text('Mjölk'));
    await tester.pumpAndSettle();

    expect(selection.isSelectionMode, isTrue);
    expect(selection.isSelected('p_1'), isTrue);
    expect(
      find.byIcon(Icons.check_circle),
      findsOneWidget,
      reason: 'the long-pressed row is selected, so it shows the filled mark',
    );
  });

  testWidgets('swipe does not delete while in selection mode', (tester) async {
    final selection = await pumpCard(tester);
    selection.enterSelectionMode('p_1');
    await tester.pumpAndSettle();

    // Try to swipe the row away.
    await tester.drag(find.text('Mjölk'), const Offset(-500, 0));
    await tester.pumpAndSettle();

    expect(
      find.text('Mjölk'),
      findsOneWidget,
      reason: 'no Dismissible in selection mode — the bulk bar deletes',
    );
  });

  testWidgets('tapping the last selected row exits selection mode', (
    tester,
  ) async {
    final selection = await pumpCard(tester);
    selection.enterSelectionMode('p_1');
    await tester.pumpAndSettle();

    await tester.tap(find.text('Mjölk'));
    await tester.pumpAndSettle();

    expect(
      selection.isSelectionMode,
      isFalse,
      reason: 'deselecting the only row drops back to the normal list',
    );
  });
}
