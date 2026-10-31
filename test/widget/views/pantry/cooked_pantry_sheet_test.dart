/// Kärnflöde steg 9C: the sheet that offers to take a cooked recipe's
/// ingredients out of the pantry.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/models/pantry/pantry_item.dart';
import 'package:butlery/services/pantry/cooked_pantry_plan.dart';
import 'package:butlery/views/pantry/cooked_pantry_sheet.dart';

import '../../../infrastructure/helpers/base_widget_test.dart';
import '../../../infrastructure/helpers/widget_test_app.dart';

PantryItem _row(String id, String name, double qty, String unit) => PantryItem(
  id: id,
  ingredientName: name,
  quantity: qty,
  unit: unit,
  location: PantryLocation.pantry,
  addedAt: DateTime.utc(2026, 1, 1),
);

void main() {
  setUpAll(() async {
    await BaseWidgetTest.setupWidget();
  });

  final takes = [
    CookedPantryTake(item: _row('a', 'Mjöl', 5, 'dl'), amount: 2),
    CookedPantryTake(item: _row('b', 'Socker', 2, 'dl'), amount: 2),
  ];

  List<CookedPantryTake>? result;
  var closed = false;

  Future<void> open(WidgetTester tester) async {
    result = null;
    closed = false;
    await tester.pumpWidget(
      createLocalizedTestApp(
        child: Builder(
          builder: (context) => TextButton(
            onPressed: () async {
              result = await showCookedPantrySheet(
                context,
                takes: takes,
                portions: 4,
              );
              closed = true;
            },
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  testWidgets('renders title, rows, remaining line and confirm count', (
    tester,
  ) async {
    await open(tester);

    expect(find.text('Dra av från skafferiet?'), findsOneWidget);
    expect(find.textContaining('för 4 portioner'), findsOneWidget);
    expect(find.text('Mjöl'), findsOneWidget);
    expect(find.text('har 5 dl, kvar 3 dl'), findsOneWidget);
    expect(find.text('har 2 dl, tas bort ur skafferiet'), findsOneWidget);
    expect(find.text('Dra av 2 varor'), findsOneWidget);
    expect(find.text('Hoppa över'), findsOneWidget);
  });

  testWidgets('unticking a row lowers the count; none left disables confirm', (
    tester,
  ) async {
    await open(tester);

    await tester.tap(find.text('Mjöl'));
    await tester.pump();
    expect(find.text('Dra av 1 vara'), findsOneWidget);

    await tester.tap(find.text('Socker'));
    await tester.pump();
    final button = tester.widget<FilledButton>(find.byType(FilledButton));
    expect(button.onPressed, isNull);

    await tester.tap(find.text('Mjöl'));
    await tester.pump();
    expect(find.text('Dra av 1 vara'), findsOneWidget);
  });

  testWidgets('rows carry checked semantics', (tester) async {
    final handle = tester.ensureSemantics();
    await open(tester);

    expect(
      tester.getSemantics(find.text('Mjöl')),
      matchesSemantics(
        label: 'Mjöl, dra av 2 dl',
        hasCheckedState: true,
        isChecked: true,
        hasTapAction: true,
      ),
    );
    handle.dispose();
  });

  testWidgets('editing an amount changes the take and clamps to the stock', (
    tester,
  ) async {
    await open(tester);

    await tester.tap(find.text('2 dl').first);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '9');
    await tester.tap(find.text('Spara'));
    await tester.pumpAndSettle();

    expect(find.text('har 5 dl, tas bort ur skafferiet'), findsOneWidget);

    await tester.tap(find.text('5 dl').first);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '1,5');
    await tester.tap(find.text('Spara'));
    await tester.pumpAndSettle();
    expect(find.text('har 5 dl, kvar 3,5 dl'), findsOneWidget);

    await tester.tap(find.text('Dra av 2 varor'));
    await tester.pumpAndSettle();
    expect(result!.first.amount, 1.5);
    expect(result!.last.amount, 2);
  });

  testWidgets('an amount of zero unticks the row', (tester) async {
    await open(tester);

    await tester.tap(find.text('2 dl').first);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '0');
    await tester.tap(find.text('Spara'));
    await tester.pumpAndSettle();

    expect(find.text('Dra av 1 vara'), findsOneWidget);
    await tester.tap(find.text('Dra av 1 vara'));
    await tester.pumpAndSettle();
    expect([for (final t in result!) t.item.id], ['b']);
  });

  testWidgets('Hoppa över returns null', (tester) async {
    await open(tester);

    await tester.tap(find.text('Hoppa över'));
    await tester.pumpAndSettle();

    expect(closed, isTrue);
    expect(result, isNull);
  });

  testWidgets('Dra av returns the ticked takes', (tester) async {
    await open(tester);

    await tester.tap(find.text('Socker'));
    await tester.pump();
    await tester.tap(find.text('Dra av 1 vara'));
    await tester.pumpAndSettle();

    expect([for (final t in result!) t.item.id], ['a']);
    expect(result!.single.amount, 2);
  });
}
