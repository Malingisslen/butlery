/// The date range under a week's number: "13 apr–19 apr".
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/widgets/menu/calendar/week_range_label.dart';

import '../../infrastructure/helpers/widget_test_app.dart';

void main() {
  Future<String> rangeFor(WidgetTester tester, DateTime weekStart) async {
    late String label;
    await tester.pumpWidget(
      createLocalizedTestApp(
        child: Builder(
          builder: (context) {
            label = formatWeekRange(context, weekStart);
            return const SizedBox.shrink();
          },
        ),
      ),
    );
    return label;
  }

  testWidgets('writes the Monday and the Sunday with Swedish months', (
    tester,
  ) async {
    expect(await rangeFor(tester, DateTime(2026, 4, 13)), '13 apr–19 apr');
  });

  testWidgets('a week that crosses the new year names both months', (
    tester,
  ) async {
    expect(await rangeFor(tester, DateTime(2026, 12, 28)), '28 dec–3 jan');
  });
}
