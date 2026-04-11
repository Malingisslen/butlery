/// Maps raw `mealType` strings (from `MenuService.generateMenuFromPrompt`)
/// to the calendar's [MealSlot] enum.
///
/// The existing menu generator returns mealTypes as free-form Swedish/English
/// strings — "frukost", "lunch", "middag", "dessert", etc. The calendar has
/// only three slots (lunch / middag / övrigt), so several source types
/// collapse onto `övrigt`. Pure function, easy to unit test.
library;

import 'package:butlery/models/menu/weekly_menu_plan.dart';

/// Maps a raw mealType string to its calendar [MealSlot].
///
/// - `frukost`, `breakfast`, `dessert`, `mellanmål`, `mellanmal`, `fika`,
///   `snack`, `snacks` → `MealSlot.ovrigt`
/// - `lunch` → `MealSlot.lunch`
/// - `middag`, `dinner` → `MealSlot.middag`
/// - anything unrecognized → `MealSlot.middag` (most common default)
///
/// Matching is case-insensitive and trims whitespace.
MealSlot mapMealTypeToSlot(String rawMealType) {
  final normalized = rawMealType.trim().toLowerCase();
  switch (normalized) {
    case 'lunch':
      return MealSlot.lunch;
    case 'middag':
    case 'dinner':
      return MealSlot.middag;
    case 'frukost':
    case 'breakfast':
    case 'dessert':
    case 'mellanmål':
    case 'mellanmal':
    case 'fika':
    case 'snack':
    case 'snacks':
      return MealSlot.ovrigt;
    default:
      return MealSlot.middag;
  }
}
