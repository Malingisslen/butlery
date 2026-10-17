// The meal-type bars on the collection stats page step from the foreground
// ink toward the page, so the biggest bar reads darkest on paper and lightest
// on the dark page. cs.primary is ink in BOTH schemes, so a bar drawn in it
// vanished on the dark page.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/theme/app_theme.dart';
import 'package:butlery/views/settings/collection_stats/meal_type_bar.dart';

void main() {
  Future<Color> fillOf(
    WidgetTester tester,
    ThemeData theme, {
    required int rank,
    required int ranks,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: theme,
        home: Scaffold(
          body: MealTypeBar(
            label: 'Middag',
            value: 4,
            maxValue: 4,
            rank: rank,
            ranks: ranks,
          ),
        ),
      ),
    );
    return tester
        .widget<ColoredBox>(
          find.descendant(
            of: find.byType(FractionallySizedBox),
            matching: find.byType(ColoredBox),
          ),
        )
        .color;
  }

  for (final (name, theme) in [
    ('light', AppTheme.lightTheme),
    ('dark', AppTheme.darkTheme),
  ]) {
    testWidgets('$name: the biggest bar is drawn in the foreground colour', (
      tester,
    ) async {
      final cs = theme.colorScheme;
      final fill = await fillOf(tester, theme, rank: 0, ranks: 3);

      expect(fill, cs.onSurface);
    });

    testWidgets('$name: lower ranks fade toward the page, not toward ink', (
      tester,
    ) async {
      final cs = theme.colorScheme;
      final biggest = await fillOf(tester, theme, rank: 0, ranks: 3);
      final smallest = await fillOf(tester, theme, rank: 2, ranks: 3);

      expect(smallest, isNot(biggest));
      expect(smallest, Color.lerp(cs.onSurface, cs.surface, 0.55));
    });
  }

  test(
    'premise: in dark mode the foreground colour differs from cs.primary',
    () {
      final cs = AppTheme.darkTheme.colorScheme;
      expect(cs.onSurface, isNot(cs.primary));
    },
  );
}
