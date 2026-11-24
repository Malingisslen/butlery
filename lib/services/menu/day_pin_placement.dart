/// Places day pins on a week before the chronological fill: typed pins
/// ("tacofredag") and the pins saved weekly rules make (BUT-2490). Pure.
library;

import 'package:butlery/models/menu/parsed_menu_request.dart';
import 'package:butlery/models/menu/weekly_menu_plan.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/services/menu/meal_slot_mapper.dart';
import 'package:butlery/services/menu_service.dart';

class DayPinPlacementResult {
  const DayPinPlacementResult({
    required this.consumedIds,
    required this.rulePinsPlaced,
  });

  /// Recipes the pins took, placed or dropped; the fill skips them.
  final Set<String> consumedIds;

  /// Per generated meal key, how many rule pins got a dish on their day.
  final Map<String, int> rulePinsPlaced;
}

abstract final class DayPinPlacement {
  /// Adds an entry to [entries] for each pin that can be placed.
  ///
  /// A typed pin that cannot be placed falls through to the fill (BUT-1241,
  /// BUT-1668). A rule pin never does: on a day already passed, on a slot
  /// that already holds a dish, or where no candidate is allowed, its dish
  /// is dropped, so a rule never moves a dish to another day and never
  /// touches what the user planned. When [allowed] refuses the picked dish
  /// on its day, the next generated dish that meets the rule is tried.
  static DayPinPlacementResult place({
    required List<DayPin> pins,
    required Map<String, List<Recipe>> generated,
    required List<WeeklyMenuPlanEntry> entries,
    required int anchorIndex,
    required bool Function(Recipe recipe, DayOfWeek day, MealSlot slot) allowed,
    required WeeklyMenuPlanEntry Function(
      DayOfWeek day,
      MealSlot slot,
      Recipe recipe,
    )
    entryFor,
  }) {
    final consumed = <String>{};
    final rulePlaced = <String, int>{};
    for (final pin in pins) {
      final slotKey = pin.mealType;
      final recipes = generated[slotKey];
      if (recipes == null) continue;
      // weekdayIndex is 1-based (Mon=1), DayOfWeek is 0-based index.
      final dayIdx = (pin.weekdayIndex - 1).clamp(0, DayOfWeek.sun.index);
      final day = DayOfWeek.values[dayIdx];
      final slot = mapMealTypeToSlot(slotKey);
      bool occupied() =>
          !slot.isMulti && entries.any((e) => e.day == day && e.slot == slot);

      if (pin.fromRule) {
        final candidates = recipes
            .where(
              (r) =>
                  !consumed.contains(r.id) &&
                  MenuService.matchesConstraint(r, pin.constraint),
            )
            .toList();
        if (candidates.isEmpty) continue;
        // The first match is the dish generation drew for this rule.
        consumed.add(candidates.first.id);
        if (dayIdx < anchorIndex || occupied()) continue;
        final chosen = candidates
            .where((r) => allowed(r, day, slot))
            .firstOrNull;
        if (chosen == null) continue;
        consumed.add(chosen.id);
        entries.add(entryFor(day, slot, chosen));
        rulePlaced[slotKey] = (rulePlaced[slotKey] ?? 0) + 1;
        continue;
      }

      final match = recipes
          .where(
            (r) =>
                !consumed.contains(r.id) &&
                (pin.constraint.requiredTags.isEmpty ||
                    (r.tagResult?.hasAllTags(pin.constraint.requiredTags) ??
                        false)),
          )
          .firstOrNull;
      if (match == null) continue;
      // BUT-1668: a pin must respect the today-anchor. Pinning "tacofredag"
      // on a Saturday would place a recipe on a day that already passed, so
      // skip the pin and let the recipe fall through to the chronological
      // fill. anchorIndex is 0 for any non-current week, so future weeks are
      // unaffected.
      if (dayIdx < anchorIndex) continue;
      // BUT-1241: a pin must not double-stack an occupied single slot
      // (e.g. the user already hand-placed Friday middag in the manual
      // placement flow). Skip the pin and let the recipe fall through to
      // the chronological fill instead.
      if (occupied()) continue;
      if (!allowed(match, day, slot)) continue;
      consumed.add(match.id);
      entries.add(entryFor(day, slot, match));
    }
    return DayPinPlacementResult(
      consumedIds: consumed,
      rulePinsPlaced: rulePlaced,
    );
  }

  /// [overflow] without the dishes rule pins pushed out: a rule takes one of
  /// the week's places, so a week asked for one dish per free day would
  /// otherwise send one dish to the tray for every rule placed. The last
  /// overflowed dishes of each meal key go first, at most as many as rules
  /// were placed for it.
  static List<Recipe> withoutRuleSurplus(
    List<Recipe> overflow,
    Map<String, String> overflowMealTypes,
    Map<String, int> rulePinsPlaced,
  ) {
    if (rulePinsPlaced.isEmpty || overflow.isEmpty) return overflow;
    final left = Map<String, int>.from(rulePinsPlaced);
    final kept = <Recipe>[];
    for (final recipe in overflow.reversed) {
      final key = overflowMealTypes[recipe.id];
      final budget = key == null ? 0 : (left[key] ?? 0);
      if (budget > 0) {
        left[key!] = budget - 1;
        continue;
      }
      kept.add(recipe);
    }
    return kept.reversed.toList();
  }
}
