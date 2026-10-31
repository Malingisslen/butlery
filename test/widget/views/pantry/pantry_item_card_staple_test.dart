/// A pantry staple ("Finns alltid hemma") shows a Basvara badge and "alltid
/// hemma" instead of an amount, and never an expiry badge.
library;

import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';

import 'package:butlery/l10n/app_localizations.dart';
import 'package:butlery/models/pantry/pantry_item.dart';
import 'package:butlery/viewmodels/pantry/pantry_selection_manager.dart';
import 'package:butlery/viewmodels/pantry/pantry_viewmodel.dart';
import 'package:butlery/views/pantry/pantry_item_card.dart';

import '../../../infrastructure/helpers/base_widget_test.dart';
import '../../../infrastructure/helpers/widget_test_app.dart';

class _MockPantryViewModel extends Mock implements PantryViewModel {}

void main() {
  setUpAll(() async {
    await BaseWidgetTest.setupWidget();
  });

  tearDown(() async {
    await BaseWidgetTest.teardownWidget();
  });

  late AppLocalizations l10n;

  Future<void> pumpCard(
    WidgetTester tester, {
    required bool isStaple,
    DateTime? expiryDate,
    double? quantity = 2,
  }) async {
    final item = PantryItem(
      id: 'p_1',
      ingredientName: 'Salt',
      quantity: quantity,
      unit: 'dl',
      location: PantryLocation.pantry,
      addedAt: DateTime(2026, 1, 1),
      expiryDate: expiryDate,
      isStaple: isStaple,
    );
    await withClock(Clock.fixed(DateTime(2026, 9, 1)), () async {
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
            child: Builder(
              builder: (context) {
                l10n = AppLocalizations.of(context);
                return ListView(children: [PantryItemCard(item: item)]);
              },
            ),
          ),
        ),
      );
    });
  }

  bool isExpiryText(Widget w) =>
      w is Text && (w.data ?? '').toLowerCase().contains('utgår');

  testWidgets('a staple shows the Basvara badge and "alltid hemma", with no '
      'expiry badge even when a date is set', (tester) async {
    await pumpCard(tester, isStaple: true, expiryDate: DateTime(2026, 9, 30));

    expect(
      find.descendant(
        of: find.byKey(PantryItemCard.stapleBadgeKey),
        // The pill draws its label in capitals.
        matching: find.byWidgetPredicate(
          (w) =>
              w is Text &&
              w.data?.toLowerCase() == l10n.pantryStapleBadge.toLowerCase(),
        ),
      ),
      findsOneWidget,
    );
    expect(l10n.pantryStapleBadge, 'Basvara');
    expect(find.text(l10n.pantryStapleAmount), findsOneWidget);
    expect(l10n.pantryStapleAmount, 'alltid hemma');
    expect(find.byWidgetPredicate(isExpiryText), findsNothing);
    expect(find.text('2 dl'), findsNothing);
  });

  testWidgets('a non-staple with a date shows its expiry and no staple '
      'badge', (tester) async {
    await pumpCard(tester, isStaple: false, expiryDate: DateTime(2026, 9, 30));

    expect(find.byKey(PantryItemCard.stapleBadgeKey), findsNothing);
    expect(find.text(l10n.pantryStapleAmount), findsNothing);
    expect(find.byWidgetPredicate(isExpiryText), findsOneWidget);
    expect(find.text('2 dl'), findsOneWidget);
  });
}
