/// P5-U28: the pantry row shows when it was last changed
/// (produktregler.md:105), in the relative forms of content-style-guide.md:34-36.
library;

import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';

import 'package:butlery/l10n/app_localizations.dart';
import 'package:butlery/models/pantry/pantry_item.dart';
import 'package:butlery/viewmodels/pantry/pantry_selection_manager.dart';
import 'package:butlery/viewmodels/pantry/pantry_viewmodel.dart';
import 'package:butlery/views/pantry/pantry_item_card.dart';

import '../../../infrastructure/helpers/widget_test_app.dart';
import '../../../infrastructure/helpers/base_widget_test.dart';

class _MockPantryViewModel extends Mock implements PantryViewModel {}

void main() {
  final sv = lookupAppLocalizations(const Locale('sv'));
  final now = DateTime(2026, 9, 23, 15, 30);

  setUpAll(() async {
    await initializeDateFormatting('sv');
    await BaseWidgetTest.setupWidget();
  });

  tearDown(() async {
    await BaseWidgetTest.teardownWidget();
  });

  group('changedLabel', () {
    String label(DateTime at) => PantryItemCard.changedLabel(sv, at, now);

    test('under a minute is "nu"', () {
      expect(label(now.subtract(const Duration(seconds: 20))), 'ändrad nu');
    });

    test('under an hour counts minutes', () {
      expect(
        label(now.subtract(const Duration(minutes: 5))),
        'ändrad för 5 min sedan',
      );
    });

    test('earlier today is "i dag" with a 24-hour time', () {
      expect(label(DateTime(2026, 9, 23, 9, 4)), 'ändrad i dag 09:04');
    });

    test('yesterday is "i går", in two words', () {
      expect(label(DateTime(2026, 9, 22, 23, 50)), 'ändrad i går');
    });

    test('older is the date, without the year this year', () {
      expect(label(DateTime(2026, 7, 9, 12)), 'ändrad 9 juli');
    });

    test('another year carries the year', () {
      expect(label(DateTime(2025, 7, 9, 12)), 'ändrad 9 juli 2025');
    });
  });

  Future<void> pumpCard(WidgetTester tester, PantryItem item) async {
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

  PantryItem item({double? quantity, DateTime? updatedAt}) => PantryItem(
    id: 'p_1',
    ingredientName: 'Mjölk',
    quantity: quantity,
    unit: 'l',
    location: PantryLocation.fridge,
    addedAt: DateTime(2026, 1, 1),
    updatedAt: updatedAt,
  );

  testWidgets('a changed row shows the amount and when it changed', (
    tester,
  ) async {
    await withClock(Clock.fixed(now), () async {
      await pumpCard(
        tester,
        item(quantity: 2, updatedAt: DateTime(2026, 9, 22, 8)),
      );
    });

    expect(find.text('2 l · ändrad i går'), findsOneWidget);
  });

  testWidgets('a row never changed shows only the amount', (tester) async {
    await pumpCard(tester, item(quantity: 2));

    expect(find.text('2 l'), findsOneWidget);
    expect(find.textContaining('ändrad'), findsNothing);
  });

  testWidgets('a row without an amount shows no lone unit', (tester) async {
    await withClock(Clock.fixed(now), () async {
      await pumpCard(
        tester,
        item(updatedAt: now.subtract(const Duration(minutes: 3))),
      );
    });

    expect(find.text('ändrad för 3 min sedan'), findsOneWidget);
    expect(find.text('l'), findsNothing);
  });
}
