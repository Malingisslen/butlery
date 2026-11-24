// lib/viewmodels/menu/weekly_lunchboxes.dart

import 'package:butlery/models/menu/lunchbox_plan.dart';
import 'package:butlery/models/menu/weekly_menu_plan.dart';
import 'package:butlery/models/recipe_unified.dart';

/// What the calendar reads about a week's lunchboxes (BUT-2486), from the
/// week and the recipes already loaded. Makes no reads of its own.
class WeeklyLunchboxes {
  WeeklyLunchboxes._();

  /// The recipe [box] holds in [plan], when it is in the library.
  static Recipe? recipeOf(
    Lunchbox box,
    WeeklyMenuPlan plan,
    Recipe? Function(String recipeId) recipeFor,
  ) {
    final id = box.recipeIdIn(plan);
    return id == null ? null : recipeFor(id);
  }

  /// The dish's name: the recipe's current title, else the name stored with
  /// the dish (on the box, or on the middag same-week leftovers follow).
  /// Null when the box holds no dish at all.
  static String? titleOf(
    Lunchbox box,
    WeeklyMenuPlan plan,
    Recipe? Function(String recipeId) recipeFor,
  ) {
    final recipe = recipeOf(box, plan, recipeFor);
    if (recipe != null) return recipe.title;
    if (box.followsMiddag) {
      final middag = plan.entryAt(box.fromDay!, MealSlot.middag);
      return middag?.titleFor(null);
    }
    final stored = box.recipeTitle;
    return stored == null || stored.isEmpty ? null : stored;
  }

  /// The loaded recipes that suit a lunchbox, by name.
  static List<Recipe> suggestions(Iterable<Recipe> recipes) =>
      recipes.where(LunchboxSuitability.suits).toList()..sort(
        (a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()),
      );

  /// The middag [day]'s leftovers would come from in the same week: the day
  /// before. Null on Monday, whose day before is in another week.
  static DayOfWeek? leftoversDayFor(DayOfWeek day) =>
      day.index == 0 ? null : DayOfWeek.values[day.index - 1];
}
