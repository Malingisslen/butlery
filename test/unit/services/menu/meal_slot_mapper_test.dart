import 'package:butlery/models/menu/weekly_menu_plan.dart';
import 'package:butlery/services/menu/meal_slot_mapper.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('mapMealTypeToSlot', () {
    test(
      '"frukost" maps to ovrigt (slot removed in BUT-211 simplification)',
      () {
        expect(mapMealTypeToSlot('frukost'), MealSlot.ovrigt);
        expect(mapMealTypeToSlot('breakfast'), MealSlot.ovrigt);
      },
    );

    test('"lunch" maps to lunch', () {
      expect(mapMealTypeToSlot('lunch'), MealSlot.lunch);
    });

    test('"middag" / "dinner" map to middag', () {
      expect(mapMealTypeToSlot('middag'), MealSlot.middag);
      expect(mapMealTypeToSlot('dinner'), MealSlot.middag);
    });

    test('snack/dessert/mellanmål/fika all map to ovrigt', () {
      expect(mapMealTypeToSlot('snack'), MealSlot.ovrigt);
      expect(mapMealTypeToSlot('snacks'), MealSlot.ovrigt);
      expect(mapMealTypeToSlot('dessert'), MealSlot.ovrigt);
      expect(mapMealTypeToSlot('mellanmål'), MealSlot.ovrigt);
      expect(mapMealTypeToSlot('mellanmal'), MealSlot.ovrigt);
      expect(mapMealTypeToSlot('fika'), MealSlot.ovrigt);
    });

    test('unknown meal types fall back to middag (most common default)', () {
      expect(mapMealTypeToSlot('unknown_meal_type'), MealSlot.middag);
      expect(mapMealTypeToSlot('whatever'), MealSlot.middag);
    });

    test('matching is case-insensitive', () {
      expect(mapMealTypeToSlot('MIDDAG'), MealSlot.middag);
      expect(mapMealTypeToSlot('Lunch'), MealSlot.lunch);
      expect(mapMealTypeToSlot('FRUKOST'), MealSlot.ovrigt);
    });

    test('whitespace is trimmed', () {
      expect(mapMealTypeToSlot('  middag  '), MealSlot.middag);
      expect(mapMealTypeToSlot('\tlunch\n'), MealSlot.lunch);
    });
  });

  group('MealSlot', () {
    test('only ovrigt is multi-recipe', () {
      expect(MealSlot.lunch.isMulti, false);
      expect(MealSlot.middag.isMulti, false);
      expect(MealSlot.ovrigt.isMulti, true);
    });

    test('display labels are Swedish lowercase', () {
      expect(MealSlot.lunch.displayLabel, 'lunch');
      expect(MealSlot.middag.displayLabel, 'middag');
      expect(MealSlot.ovrigt.displayLabel, 'övrigt');
    });
  });
}
