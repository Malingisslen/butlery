import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:butlery/l10n/app_localizations_sv.dart';
import 'package:butlery/models/menu/meal_box.dart';
import 'package:butlery/widgets/pantry/meal_boxes/meal_box_ui.dart';

MealBox _box(
  MealBoxLocation location,
  DateTime storedOn, {
  Map<String, int> takes = const {},
}) => MealBox(
  id: 'a',
  recipeTitle: 'Chili',
  location: location,
  storedOn: storedOn,
  count: 5,
  takes: takes,
);

void main() {
  final sv = AppLocalizationsSv();
  // Wednesday 2026-11-25.
  final now = DateTime(2026, 11, 25, 12);

  setUpAll(() => initializeDateFormatting('sv'));

  String subtitle(MealBox box) => mealBoxSubtitle(sv, 'sv', box, now: now);

  test('fridge: today, a weekday, then a date', () {
    expect(
      subtitle(_box(MealBoxLocation.fridge, DateTime(2026, 11, 25, 8))),
      'Kylen · lagat i dag',
    );
    expect(
      subtitle(_box(MealBoxLocation.fridge, DateTime(2026, 11, 22))),
      'Kylen · lagat sön',
    );
    expect(
      subtitle(_box(MealBoxLocation.fridge, DateTime(2026, 11, 9))),
      'Kylen · lagat 9 nov',
    );
  });

  test('freezer shows the date', () {
    expect(
      subtitle(_box(MealBoxLocation.freezer, DateTime(2026, 11, 9))),
      'Frysen · 9 nov',
    );
  });

  test('planned lunches add what is taken and when', () {
    expect(
      subtitle(
        _box(
          MealBoxLocation.freezer,
          DateTime(2026, 11, 9),
          takes: {'2026-11-25': 1},
        ),
      ),
      'Frysen · 9 nov · 1 tas ons',
    );
    expect(
      subtitle(
        _box(
          MealBoxLocation.fridge,
          DateTime(2026, 11, 25),
          takes: {'2026-11-26': 1, '2026-11-27': 2},
        ),
      ),
      'Kylen · lagat i dag · 3 planerade',
    );
  });
}
