/// BUT-2486: the bulk-move sheet does not offer a lunch that is a lunchbox as
/// a target — a dish moved there would sit unseen under the box.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/models/menu/lunchbox_plan.dart';
import 'package:butlery/models/menu/weekly_menu_plan.dart';
import 'package:butlery/widgets/menu/calendar/move_target_sheet.dart';

import '../../infrastructure/helpers/widget_test_app.dart';

void main() {
  Future<void> open(WidgetTester tester, WeeklyMenuPlan? plan) async {
    tester.view.physicalSize = const Size(400, 4000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      createLocalizedTestApp(
        child: Builder(
          builder: (context) => TextButton(
            onPressed: () => showMoveTargetSheet(context, plan: plan),
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  String row(DayOfWeek day, MealSlot slot) =>
      '${day.displayLabel} · ${slot.displayLabel}';

  testWidgets('a box day offers its middag and övrigt but not its lunch', (
    tester,
  ) async {
    final plan = WeeklyMenuPlan.empty(userId: 'u', date: DateTime(2026, 4, 6))
        .copyWith(
          lunchboxes: {
            DayOfWeek.tue: const Lunchbox(source: LunchboxSource.prepDay),
          },
        );

    await open(tester, plan);

    expect(find.text(row(DayOfWeek.tue, MealSlot.lunch)), findsNothing);
    expect(find.text(row(DayOfWeek.tue, MealSlot.middag)), findsOneWidget);
    expect(find.text(row(DayOfWeek.tue, MealSlot.ovrigt)), findsOneWidget);
    expect(find.text(row(DayOfWeek.wed, MealSlot.lunch)), findsOneWidget);
  });

  testWidgets('without a plan every place is offered', (tester) async {
    await open(tester, null);

    for (final day in DayOfWeek.values) {
      for (final slot in MealSlot.values) {
        expect(find.text(row(day, slot)), findsOneWidget);
      }
    }
  });
}
