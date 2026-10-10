/// Maps a meal-type string to the calendar's [MealSlot] enum: the menu
/// generator's lowercase slot keys ("middag", "ovrigt") and a recipe's
/// `mealType`, which is one of `MealTypes.all` or free text. The calendar has
/// only three slots (lunch / middag / övrigt), so several source types
/// collapse onto `övrigt`. Pure function, easy to unit test.
library;

import 'package:butlery/models/menu/weekly_menu_plan.dart';

/// Maps a raw mealType string to its calendar [MealSlot].
///
/// - `frukost`, `breakfast`, `dessert`, `mellanmål`, `mellanmal`, `fika`,
///   `snack`, `snacks`, `ovrigt`, `övrigt` → `MealSlot.ovrigt`
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
    case 'ovrigt':
    case 'övrigt':
      return MealSlot.ovrigt;
    default:
      return MealSlot.middag;
  }
}
