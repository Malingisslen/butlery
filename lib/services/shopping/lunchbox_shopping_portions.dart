// lib/services/shopping/lunchbox_shopping_portions.dart

import 'package:butlery/models/menu/lunchbox_plan.dart';
import 'package:butlery/models/menu/weekly_menu_plan.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/services/shopping/menu_shopping_aggregator.dart';

/// BUT-2486: what a week's lunchboxes add to its shopping list. Pure: the
/// recipes come from [LunchboxShoppingPortions.of]'s lookup, never a read.
class LunchboxShoppingPortions {
  const LunchboxShoppingPortions._({
    required this.extraMiddagPortions,
    required this.placements,
    required this.portions,
  });

  static const empty = LunchboxShoppingPortions._(
    extraMiddagPortions: {},
    placements: [],
    portions: 0,
  );

  /// Boxes of same-week leftovers, by the day whose middag is cooked bigger.
  /// Only days whose middag can be scaled (a recipe with portions) are here.
  final Map<DayOfWeek, int> extraMiddagPortions;

  /// Boxes cooked as their own dish (prep day, the app's suggestion), one
  /// placement per box.
  final List<ScaledRecipe> placements;

  /// The portions this adds to the list, for "N extra portioner till lunch".
  /// A box that adds nothing is not counted.
  final int portions;

  bool get isEmpty => portions == 0;

  /// The recipe ids [plan]'s boxes need looked up besides its entries.
  static Set<String> recipeIdsOf(WeeklyMenuPlan plan) => {
    for (final box in plan.lunchboxes.values)
      if (_buysOwnDish(box) && box.recipeIdIn(plan) != null)
        box.recipeIdIn(plan)!,
  };

  static LunchboxShoppingPortions of(
    WeeklyMenuPlan plan,
    Recipe? Function(String recipeId) recipeFor,
  ) {
    if (plan.lunchboxes.isEmpty) return empty;
    final extra = <DayOfWeek, int>{};
    final placements = <ScaledRecipe>[];
    var portions = 0;
    for (final box in plan.lunchboxes.values) {
      if (box.followsMiddag) {
        final middag = plan.entryAt(box.fromDay!, MealSlot.middag);
        final recipe = middag == null ? null : recipeFor(middag.recipeId);
        if (_portionsOf(recipe) == null) continue;
        extra.update(
          box.fromDay!,
          (n) => n + box.portions,
          ifAbsent: () => box.portions,
        );
        portions += box.portions;
      } else if (_buysOwnDish(box)) {
        final id = box.recipeIdIn(plan);
        final recipe = id == null ? null : recipeFor(id);
        final authored = _portionsOf(recipe);
        if (authored == null) continue;
        placements.add((recipe: recipe!, factor: box.portions / authored));
        portions += box.portions;
      }
      // Leftovers from the previous week were cooked then: nothing to buy.
    }
    return LunchboxShoppingPortions._(
      extraMiddagPortions: Map.unmodifiable(extra),
      placements: List.unmodifiable(placements),
      portions: portions,
    );
  }

  /// Boxes whose dish is cooked for the box alone.
  static bool _buysOwnDish(Lunchbox box) => switch (box.source) {
    LunchboxSource.prepDay || LunchboxSource.suggestion => true,
    LunchboxSource.leftovers => false,
  };

  static int? _portionsOf(Recipe? recipe) {
    final portions = recipe?.portions;
    return portions == null || portions <= 0 ? null : portions;
  }
}
