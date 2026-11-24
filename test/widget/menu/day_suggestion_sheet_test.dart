import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:butlery/models/menu/weekly_menu_plan.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/widgets/menu/day_suggestion_sheet.dart';

import '../../infrastructure/factories/recipe_factory.dart';
import '../../infrastructure/helpers/widget_test_app.dart';

WeeklyMenuPlan _emptyPlan() => WeeklyMenuPlan(
  id: 'p',
  userId: 'u',
  weekStartDate: DateTime(2026, 11, 23),
  entries: const [],
  createdAt: DateTime(2026, 11, 23),
  updatedAt: DateTime(2026, 11, 23),
);

Recipe _r(int i) =>
    RecipeFactory.build(id: 'r$i', title: 'Rätt $i', mealType: 'Middag');

void main() {
  Future<void> openSheet(
    WidgetTester tester,
    List<Recipe> pool,
    void Function(Recipe?) onResult,
  ) async {
    await tester.pumpWidget(
      createLocalizedTestApp(
        child: Builder(
          builder: (context) => TextButton(
            onPressed: () async => onResult(
              await DaySuggestionSheet.show(
                context,
                plan: _emptyPlan(),
                day: DayOfWeek.tue,
                slot: MealSlot.middag,
                readPoolOverride: () async => pool,
              ),
            ),
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  testWidgets('shows four cards, and the primary button waits for a choice', (
    tester,
  ) async {
    await openSheet(tester, [for (var i = 0; i < 8; i++) _r(i)], (_) {});
    final cards = find.byWidgetPredicate(
      (w) =>
          w.key is ValueKey &&
          '${(w.key as ValueKey).value}'.startsWith('suggestion-card-'),
    );
    expect(cards, findsNWidgets(4));
    expect(find.text('Välj ett kort'), findsOneWidget);
  });

  testWidgets('a locked card survives "Visa andra"', (tester) async {
    await openSheet(tester, [for (var i = 0; i < 12; i++) _r(i)], (_) {});
    final cardKeys = find.byWidgetPredicate(
      (w) =>
          w.key is ValueKey &&
          '${(w.key as ValueKey).value}'.startsWith('suggestion-card-'),
    );
    final firstKey =
        (tester.widget(cardKeys.first).key as ValueKey).value as String;
    final id = firstKey.replaceFirst('suggestion-card-', '');
    await tester.tap(find.byKey(ValueKey('suggestion-lock-$id')));
    await tester.pump();
    await tester.tap(find.text('Visa andra'));
    await tester.pumpAndSettle();
    expect(find.byKey(ValueKey('suggestion-card-$id')), findsOneWidget);
  });

  testWidgets('choosing a card returns that recipe', (tester) async {
    Recipe? got;
    await openSheet(tester, [
      for (var i = 0; i < 6; i++) _r(i),
    ], (r) => got = r);
    final cards = find.byWidgetPredicate(
      (w) =>
          w.key is ValueKey &&
          '${(w.key as ValueKey).value}'.startsWith('suggestion-card-'),
    );
    // Tap one card, then the last: the last must be what comes back.
    await tester.tap(cards.first);
    await tester.pump();
    final last = cards.last;
    final id = ((tester.widget(last).key as ValueKey).value as String)
        .replaceFirst('suggestion-card-', '');
    await tester.tap(last);
    await tester.pump();
    await tester.tap(find.textContaining('Lägg på'));
    await tester.pumpAndSettle();
    expect(got?.id, id);
  });

  testWidgets('an empty pool shows the empty state', (tester) async {
    await openSheet(tester, const [], (_) {});
    expect(find.text('Inga förslag'), findsOneWidget);
  });

  testWidgets('a failing pool read ends in the empty state, not a spinner', (
    tester,
  ) async {
    await tester.pumpWidget(
      createLocalizedTestApp(
        child: Builder(
          builder: (context) => TextButton(
            onPressed: () => DaySuggestionSheet.show(
              context,
              plan: _emptyPlan(),
              day: DayOfWeek.tue,
              slot: MealSlot.middag,
              readPoolOverride: () async => throw StateError('offline'),
            ),
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.text('Inga förslag'), findsOneWidget);
  });
}
