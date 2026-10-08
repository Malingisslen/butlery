/// BUT-2140: the "Förra versionen · i går [Återställ]" row in the pantry edit
/// sheet.
///
/// The row is there only while a previous version younger than 30 days
/// exists. Restoring is class 1 (ui-conventions.md, BUT-954): no dialog, the
/// sheet closes, and the snackbar's Ångra swaps the versions back.
library;

import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';

import 'package:butlery/models/pantry/pantry_item.dart';
import 'package:butlery/models/pantry/pantry_previous_version.dart';
import 'package:butlery/viewmodels/pantry/pantry_viewmodel.dart';
import 'package:butlery/views/pantry/add_pantry_item_sheet.dart';
import 'package:butlery/views/pantry/pantry_previous_version_row.dart';

import '../../../infrastructure/helpers/base_widget_test.dart';
import '../../../infrastructure/helpers/widget_test_app.dart';

class _MockPantryViewModel extends Mock implements PantryViewModel {}

void main() {
  final now = DateTime(2026, 10, 8, 12);

  PantryItem item({required Duration age}) => PantryItem(
    id: 'p1',
    ingredientName: 'Havremjölk',
    quantity: 1,
    unit: 'l',
    location: PantryLocation.fridge,
    addedAt: DateTime(2026, 1, 1),
    note: 'laktosfri',
    previous: PantryPreviousVersion(
      fields: const {'ingredientName': 'Mjölk', 'note': null},
      at: now.subtract(age),
    ),
  );

  setUpAll(() async {
    await BaseWidgetTest.setupWidget();
    registerFallbackValue(item(age: Duration.zero));
  });

  tearDown(() async {
    await BaseWidgetTest.teardownWidget();
  });

  late _MockPantryViewModel vm;

  setUp(() {
    vm = _MockPantryViewModel();
    when(() => vm.searchResults).thenReturn(const []);
    when(() => vm.isLoading).thenReturn(false);
    when(() => vm.hasError).thenReturn(false);
    when(() => vm.error).thenReturn(null);
  });

  /// Opens the edit sheet for [existing] the way the item card does, so a
  /// pop closes the sheet and the snackbar lands on the view beneath it.
  Future<void> openSheet(WidgetTester tester, PantryItem existing) async {
    await tester.pumpWidget(
      createLocalizedTestApp(
        child: ChangeNotifierProvider<PantryViewModel>.value(
          value: vm,
          child: Builder(
            builder: (context) => TextButton(
              onPressed: () => showModalBottomSheet<void>(
                context: context,
                isScrollControlled: true,
                builder: (_) => ChangeNotifierProvider<PantryViewModel>.value(
                  value: vm,
                  child: AddPantryItemSheet(existingItem: existing),
                ),
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  testWidgets('a version from 29 days ago shows the row', (tester) async {
    await withClock(Clock.fixed(now), () async {
      await openSheet(tester, item(age: const Duration(days: 29)));

      expect(find.byType(AddPantryItemSheet), findsOneWidget);
      expect(find.textContaining('Förra versionen'), findsOneWidget);
      expect(find.byKey(PantryPreviousVersionRow.restoreButtonKey), findsOne);
    });
  });

  testWidgets('a version 30 days old is hidden', (tester) async {
    await withClock(Clock.fixed(now), () async {
      await openSheet(tester, item(age: const Duration(days: 30)));

      expect(find.byType(AddPantryItemSheet), findsOneWidget);
      expect(find.textContaining('Förra versionen'), findsNothing);
    });
  });

  testWidgets('an item without a previous version has no row', (
    tester,
  ) async {
    await withClock(Clock.fixed(now), () async {
      final plain = PantryItem(
        id: 'p2',
        ingredientName: 'Salt',
        quantity: 1,
        unit: 'st',
        location: PantryLocation.spiceRack,
        addedAt: DateTime(2026, 1, 1),
      );
      await openSheet(tester, plain);

      expect(find.textContaining('Förra versionen'), findsNothing);
    });
  });

  testWidgets(
    'Återställ restores without a dialog, closes the sheet, and Ångra swaps back',
    (tester) async {
      await withClock(Clock.fixed(now), () async {
        final current = item(age: const Duration(hours: 2));
        // PantryItem compares by id, so one stub answers both calls with the
        // swap of whatever it is given.
        when(() => vm.restorePrevious(any())).thenAnswer(
          (inv) async => (inv.positionalArguments.single as PantryItem)
              .withPreviousRestored(now),
        );
        await openSheet(tester, current);

        await tester.tap(find.byKey(PantryPreviousVersionRow.restoreButtonKey));
        await tester.pumpAndSettle();

        expect(find.byType(AlertDialog), findsNothing);
        expect(find.byType(AddPantryItemSheet), findsNothing);
        expect(find.text('Förra versionen är återställd'), findsOneWidget);

        await tester.tap(find.text('Ångra'));
        await tester.pumpAndSettle();

        final calls = verify(
          () => vm.restorePrevious(captureAny()),
        ).captured.cast<PantryItem>();
        // The first call was the restore; Ångra passes back what it returned.
        expect(calls, hasLength(2));
        expect(calls.first.ingredientName, 'Havremjölk');
        expect(calls.last.ingredientName, 'Mjölk');
        expect(calls.last.previous?.fields['ingredientName'], 'Havremjölk');
      });
    },
  );

  testWidgets('a failed restore keeps the sheet open with Försök igen', (
    tester,
  ) async {
    await withClock(Clock.fixed(now), () async {
      final current = item(age: const Duration(hours: 2));
      when(() => vm.restorePrevious(current)).thenAnswer((_) async => null);
      await openSheet(tester, current);

      await tester.tap(find.byKey(PantryPreviousVersionRow.restoreButtonKey));
      await tester.pumpAndSettle();

      expect(find.byType(AddPantryItemSheet), findsOneWidget);
      expect(
        find.text('Kunde inte återställa förra versionen'),
        findsOneWidget,
      );
      expect(find.text('Försök igen'), findsOneWidget);
    });
  });
}
