// BUT-2183 5p (B104): the cell left behind during a calendar drag is faint by
// ONE named constant, not an AppDimensions.opacity* step.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/models/menu/weekly_menu_plan.dart';
import 'package:butlery/theme/app_theme.dart';
import 'package:butlery/widgets/menu/calendar/calendar_drag.dart';

void main() {
  test('the ghost keeps its faintness', () {
    expect(kCalendarDragGhostOpacity, 0.3);
  });

  for (final (mode, theme) in [
    ('light', AppTheme.lightTheme),
    ('dark', AppTheme.darkTheme),
  ]) {
    testWidgets('the picked-up cell draws at the ghost opacity in $mode', (
      tester,
    ) async {
      const entry = WeeklyMenuPlanEntry(
        id: 'e1',
        day: DayOfWeek.mon,
        slot: MealSlot.middag,
        recipeId: 'r1',
        recipeTitle: 'Köttbullar',
      );
      await tester.pumpWidget(
        MaterialApp(
          theme: theme,
          home: Scaffold(
            body: Center(
              child: Builder(
                builder: (context) => wrapAsDraggable(
                  context: context,
                  payload: MovePayload(entry),
                  child: const SizedBox(
                    key: Key('cell'),
                    width: 80,
                    height: 40,
                    child: Text('cell'),
                  ),
                ),
              ),
            ),
          ),
        ),
      );

      expect(find.byType(Opacity), findsNothing);

      final gesture = await tester.startGesture(
        tester.getCenter(find.byKey(const Key('cell'))),
      );
      await tester.pump(const Duration(milliseconds: 700));
      await gesture.moveBy(const Offset(0, 60));
      await tester.pump();

      final ghost = tester.widget<Opacity>(
        find.descendant(
          of: find.byType(LongPressDraggable<CalendarDragPayload>),
          matching: find.byType(Opacity),
        ),
      );
      expect(ghost.opacity, kCalendarDragGhostOpacity);

      await gesture.up();
      await tester.pump();
    });
  }
}
