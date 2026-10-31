/// The one rule for "does this recipe fit this meal" in the menu, shared by
/// generation, swap and the calendar. Menu keys are the parser's lowercase
/// slot keys ('lunch', 'middag', 'ovrigt', ...); a recipe's `mealType` is one
/// of `MealTypes.all` or free text. The calendar has only three slots
/// (lunch / middag / övrigt), so several source types collapse onto `övrigt`.
/// Pure functions, easy to unit test.
library;

import 'package:butlery/models/menu/weekly_menu_plan.dart';
import 'package:butlery/models/recipe/meal_types.dart';

const _ovrigtKey = 'ovrigt';

bool _isOvrigt(String raw) {
  final key = raw.trim().toLowerCase();
  return key == _ovrigtKey || key == 'övrigt';
}

/// Canonical lowercase menu key for a meal type (a recipe's or a request's).
///
/// Unknown or empty text becomes 'middag': the same default the app gives a
/// recipe saved without a meal type, so such a recipe is still plannable.
String menuMealKey(String rawMealType) {
  if (_isOvrigt(rawMealType)) return _ovrigtKey;
  return (MealTypes.match(rawMealType) ?? MealTypes.middag).toLowerCase();
}

/// Whether a recipe with [recipeMealType] fits the requested menu key.
///
/// An 'ovrigt' request accepts any recipe: that slot is not a meal type, so
/// its own constraint (for example a tag) does the selecting.
bool fitsMealSlot(String recipeMealType, String requestedKey) {
  if (_isOvrigt(requestedKey)) return true;
  return menuMealKey(recipeMealType) == menuMealKey(requestedKey);
}

/// Maps a raw mealType string to its calendar [MealSlot]: lunch and middag
/// keep their slot, everything else (including 'ovrigt') lands in `övrigt`,
/// and unknown text falls back to middag like [menuMealKey].
MealSlot mapMealTypeToSlot(String rawMealType) {
  switch (menuMealKey(rawMealType)) {
    case 'lunch':
      return MealSlot.lunch;
    case 'middag':
      return MealSlot.middag;
    default:
      return MealSlot.ovrigt;
  }
}
