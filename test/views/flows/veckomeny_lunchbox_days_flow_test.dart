/// BUT-2486 part 6 · the week menu's lunchbox days, from the chip to the saved
/// week.
///
/// A day chosen in the empty state reaches the automatic placement, which
/// puts a fridge box on that day and says so in the receipt. With the
/// meal-box switch off the chips are not there and the boxes are never read.
///
/// The real VeckomenyView runs (veckomeny_flow_harness.dart), under a fixed
/// Monday so Wednesday is still ahead. The boxes come from a stub of the
/// fridge read, the one edge the harness leaves to the test.
library;

import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/l10n/app_localizations_sv.dart';
import 'package:butlery/models/menu/meal_box.dart';
import 'package:butlery/models/menu/weekly_menu_plan.dart';
import 'package:butlery/models/user_allergen_preferences.dart';
import 'package:butlery/services/feature_flags/feature_flag_service.dart';
import 'package:butlery/viewmodels/menu/stock_lunch_fill.dart';
import 'package:butlery/widgets/menu/veckomeny_lunchbox_days.dart';

import '../../infrastructure/di/test_service_locator.dart';
import 'veckomeny_flow_harness.dart';

final _sv = AppLocalizationsSv();

class _MealBoxFlag extends Fake implements FeatureFlagService {
  @override
  bool isEnabled(String flag) => flag == FeatureFlags.enableMealBoxes;
}

void main() {
  late VeckomenyFlowHarness h;
  late int boxReads;

  Future<void> start({required bool switchOn}) async {
    boxReads = 0;
    h = VeckomenyFlowHarness();
    await h.setUp(
      stockLunchFill: StockLunchFill(
        enabled: () => true,
        readBoxes: () async {
          boxReads++;
          return [
            MealBox(
              id: 'box-1',
              recipeId: 'dinner-5',
              recipeTitle: 'Middag 5',
              location: MealBoxLocation.fridge,
              storedOn: DateTime(2026, 9, 20),
              count: 1,
            ),
          ];
        },
        householdPrefs: () async => UserAllergenPreferences.none,
      ),
    );
    h.menu.next = {
      'Middag': [flowDinner(1), flowDinner(2), flowDinner(3)],
    };
    if (switchOn) {
      TestServiceLocator.registerMock<FeatureFlagService>(_MealBoxFlag());
    }
  }

  tearDown(() => h.tearDown());

  Future<void> runOnMonday(Future<void> Function() body) =>
      withClock(Clock.fixed(flowMonday), body);

  Future<void> generateAndPlace(WidgetTester tester) async {
    await h.generate(tester, 'tre middagar');
    await tester.pumpAndSettle();
    await tester.tap(find.text(_sv.menuPlaceAutoButton));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
  }

  testWidgets('a chosen weekday gets a fridge box in the placed week, and '
      'the receipt counts the box beside the dishes', (tester) async {
    await start(switchOn: true);
    await runOnMonday(() async {
      await h.pump(tester);
      expect(find.byType(VeckomenyLunchboxDays), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('lunchbox-day-wed')));
      await tester.pump();
      await generateAndPlace(tester);

      expect(boxReads, 1);
      final week = h.repository.saves.single;
      expect(week.lunchboxes.keys, [DayOfWeek.wed]);
      expect(week.lunchboxes[DayOfWeek.wed]?.mealBoxId, 'box-1');
      expect(week.lunchboxes[DayOfWeek.wed]?.recipeId, 'dinner-5');
      expect(find.text(_sv.menuAutoPlacedWithBoxesToast(3, 1)), findsOneWidget);
    });
  });

  testWidgets('a week generated with no day chosen reads no boxes and says '
      'nothing about them', (tester) async {
    await start(switchOn: true);
    await runOnMonday(() async {
      await h.pump(tester);

      await generateAndPlace(tester);

      expect(boxReads, 0);
      expect(h.repository.saves.single.lunchboxes, isEmpty);
      expect(find.text(_sv.menuAutoPlacedToast(3)), findsOneWidget);
    });
  });

  testWidgets('with the meal-box switch off there are no weekday chips and '
      'no box is read or placed', (tester) async {
    await start(switchOn: false);
    await runOnMonday(() async {
      await h.pump(tester);
      expect(find.byType(VeckomenyLunchboxDays), findsNothing);

      await generateAndPlace(tester);

      expect(boxReads, 0);
      expect(h.repository.saves.single.lunchboxes, isEmpty);
      expect(find.text(_sv.menuAutoPlacedToast(3)), findsOneWidget);
    });
  });
}
