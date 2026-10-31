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
      // The menu parser's own key for a slot outside lunch and dinner.
      expect(mapMealTypeToSlot('ovrigt'), MealSlot.ovrigt);
      expect(mapMealTypeToSlot('övrigt'), MealSlot.ovrigt);
    });

    test('synonyms and canonical spellings use the shared normalisation', () {
      expect(mapMealTypeToSlot('Huvudrätt'), MealSlot.middag);
      expect(mapMealTypeToSlot('Efterrätt'), MealSlot.ovrigt);
      expect(mapMealTypeToSlot('Mellanmål'), MealSlot.ovrigt);
      expect(mapMealTypeToSlot(''), MealSlot.middag);
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

  group('menuMealKey', () {
    test('every canonical type gives its lowercase key', () {
      expect(menuMealKey('Frukost'), 'frukost');
      expect(menuMealKey('Lunch'), 'lunch');
      expect(menuMealKey('Middag'), 'middag');
      expect(menuMealKey('Dessert'), 'dessert');
      expect(menuMealKey('Mellanmål'), 'mellanmål');
      expect(menuMealKey('Fika'), 'fika');
    });

    test('synonyms resolve through MealTypes', () {
      expect(menuMealKey('Huvudrätt'), 'middag');
      expect(menuMealKey('dinner'), 'middag');
      expect(menuMealKey('efterrätt'), 'dessert');
      expect(menuMealKey('snack'), 'mellanmål');
      expect(menuMealKey('  Main   course '), 'middag');
    });

    test('empty and unknown text default to middag', () {
      expect(menuMealKey(''), 'middag');
      expect(menuMealKey('Soppor'), 'middag');
      expect(menuMealKey('Förrätt'), 'middag');
    });

    test('ovrigt keeps its own key', () {
      expect(menuMealKey('ovrigt'), 'ovrigt');
      expect(menuMealKey('Övrigt'), 'ovrigt');
    });
  });

  group('fitsMealSlot', () {
    test('matches a recipe whose normalised type equals the request', () {
      expect(fitsMealSlot('Middag', 'middag'), isTrue);
      expect(fitsMealSlot('Huvudrätt', 'middag'), isTrue);
      expect(fitsMealSlot('efterrätt', 'dessert'), isTrue);
      expect(fitsMealSlot('dinner', 'Middag'), isTrue);
      expect(fitsMealSlot('Lunch', 'middag'), isFalse);
      expect(fitsMealSlot('Frukost', 'lunch'), isFalse);
    });

    test('empty and unknown recipe types fit middag only', () {
      expect(fitsMealSlot('', 'middag'), isTrue);
      expect(fitsMealSlot('Soppor', 'middag'), isTrue);
      expect(fitsMealSlot('', 'lunch'), isFalse);
      expect(fitsMealSlot('Soppor', 'dessert'), isFalse);
    });

    test('an ovrigt request accepts any recipe', () {
      for (final type in ['Middag', 'Lunch', 'Fika', '', 'Soppor']) {
        expect(fitsMealSlot(type, 'ovrigt'), isTrue, reason: type);
        expect(fitsMealSlot(type, 'övrigt'), isTrue, reason: type);
      }
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
