// A group menu dish with a long name stays within two lines and ends in an
// ellipsis instead of growing the cell (A34).

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/widgets/menu/calendar/calendar_slot_cells.dart';

import '../../infrastructure/helpers/widget_test_app.dart';

void main() {
  Widget cell({int? maxTitleLines, int extraCount = 0}) =>
      createLocalizedTestApp(
        child: Center(
          child: SizedBox(
            width: 90,
            child: CalendarDishCell(
              title: 'Soppa med rökt skinka och stekt potatis från ugnen',
              marks: const CalendarCellMarks(),
              semanticsLabel: 'Visa',
              onTap: () {},
              extraCount: extraCount,
              maxTitleLines: maxTitleLines,
            ),
          ),
        ),
      );

  testWidgets('maxTitleLines caps the name at two lines with an ellipsis', (
    tester,
  ) async {
    await tester.pumpWidget(cell(maxTitleLines: 2));
    final text = tester.widget<Text>(find.textContaining('Soppa med'));
    expect(text.maxLines, 2);
    expect(text.overflow, TextOverflow.ellipsis);
  });

  testWidgets('without a cap the name keeps growing the cell', (tester) async {
    await tester.pumpWidget(cell());
    final uncapped = tester.getSize(find.byType(CalendarDishCell)).height;
    await tester.pumpWidget(cell(maxTitleLines: 2));
    final capped = tester.getSize(find.byType(CalendarDishCell)).height;
    expect(capped, lessThan(uncapped));
  });

  testWidgets('a place with more dishes caps the name the same way', (
    tester,
  ) async {
    await tester.pumpWidget(cell(maxTitleLines: 2, extraCount: 1));
    final text = tester.widget<RichText>(
      find
          .descendant(
            of: find.byType(CalendarDishCell),
            matching: find.byType(RichText),
          )
          .first,
    );
    expect(text.maxLines, 2);
    expect(text.overflow, TextOverflow.ellipsis);
  });
}
