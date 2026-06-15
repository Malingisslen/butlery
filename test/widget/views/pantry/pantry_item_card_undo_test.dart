/// BUT-954: gates for the pantry swipe-delete → snackbar-undo flow.
///
/// The confirm dialog was removed (pantry rows are the reversible-destructive
/// class per ui-conventions.md); these tests pin the replacement contract:
/// swipe deletes immediately, the snackbar shows "Ångra", and tapping it
/// restores the exact removed item. Messenger + strings are captured before
/// dismissal — the snackbar must appear even though the row's element is
/// deactivated when onDismissed fires.
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

  Future<_MockPantryViewModel> pumpAndSwipe(WidgetTester tester) async {
    final mockVm = _MockPantryViewModel();
    when(() => mockVm.removeItem(any())).thenAnswer((_) async {});
    when(() => mockVm.restoreItem(item)).thenAnswer((_) async {});

    await tester.pumpWidget(
      createLocalizedTestApp(
        child: MultiProvider(
          providers: [
            ChangeNotifierProvider<PantryViewModel>.value(value: mockVm),
            // BUT-948: the card now reads selection state; provide a real
            // (empty) manager so the non-selection swipe path is exercised.
            ChangeNotifierProvider<PantrySelectionManager>.value(
                value: PantrySelectionManager()),
          ],
          child: ListView(children: [PantryItemCard(item: item)]),
        ),
      ),
    );

    await tester.drag(find.text('Mjölk'), const Offset(-500, 0));
    await tester.pumpAndSettle();
    return mockVm;
  }

  testWidgets('swipe deletes immediately — no confirm dialog', (tester) async {
    final mockVm = await pumpAndSwipe(tester);

    expect(find.byType(AlertDialog), findsNothing,
        reason: 'Reversible-destructive class: a dialog on a recoverable '
            'action is friction without protection (ui-conventions.md).');
    verify(() => mockVm.removeItem('p_1')).called(1);
  });

  testWidgets('undo snackbar appears after dismissal and restores the item',
      (tester) async {
    final mockVm = await pumpAndSwipe(tester);

    expect(find.byType(SnackBar), findsOneWidget,
        reason: 'Messenger is captured pre-dismissal, so the snackbar must '
            'survive the row element being deactivated.');
    expect(find.text('Ångra'), findsOneWidget);

    await tester.tap(find.text('Ångra'));
    await tester.pumpAndSettle();

    verify(() => mockVm.restoreItem(item)).called(1);
  });
}
