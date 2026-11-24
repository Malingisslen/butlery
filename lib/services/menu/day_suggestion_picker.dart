import 'dart:math';

import 'package:butlery/models/menu/weekly_menu_plan.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/services/menu/meal_slot_mapper.dart';
import 'package:butlery/services/menu/protein_category.dart';

/// Picks the dishes offered for an empty menu day (BUT-2497).
///
/// Rules only, over a pool the caller has already made allergen-safe: nothing
/// here decides what is safe to eat, so a recipe the pool let in is never
/// removed or re-judged.
abstract final class DaySuggestionPicker {
  static const int defaultCount = 4;

  /// Up to [count] minus the locked cards, best first.
  ///
  /// A dish scores higher the longer ago it was cooked (never cooked highest),
  /// lower when a neighbouring day's [slot] already has the same protein
  /// category, and a random nudge keeps "show others" from repeating itself.
  /// Dishes in [shown] are skipped until nothing else is left.
  static List<Recipe> pick({
    required List<Recipe> pool,
    required WeeklyMenuPlan? plan,
    required DayOfWeek day,
    required MealSlot slot,
    required DateTime now,
    List<Recipe> locked = const [],
    Set<String> shown = const {},
    int count = defaultCount,
    Random? random,
  }) {
    final wanted = count - locked.length;
    if (wanted <= 0) return const [];
    final rng = random ?? Random();
    final taken = <String>{
      ...locked.map((r) => r.id),
      ...?plan?.entries.map((e) => e.recipeId),
    };
    final eligible = pool
        .where(
          (r) => !taken.contains(r.id) && fitsMealSlot(r.mealType, slot.name),
        )
        .toList();
    final fresh = eligible.where((r) => !shown.contains(r.id)).toList();
    final candidates = fresh.length >= wanted ? fresh : eligible;

    final neighbourProteins = _neighbourProteins(plan, day, slot, pool);
    final scored = [
      for (final r in candidates)
        (
          recipe: r,
          score:
              _recencyScore(r, now) +
              (neighbourProteins.contains(ProteinCategory.categoryOf(r))
                  ? -2.0
                  : 0.0) +
              rng.nextDouble() * 1.5,
        ),
    ]..sort((a, b) => b.score.compareTo(a.score));
    return [for (final s in scored.take(wanted)) s.recipe];
  }

  static double _recencyScore(Recipe r, DateTime now) {
    final cooked = r.lastCookedAt;
    // Older recipes carry no cook count; with no date they count as never
    // cooked, like a recipe that has not been cooked at all.
    if (cooked == null) return 3;
    final days = now.difference(cooked).inDays;
    return (days / 30).clamp(0, 3).toDouble();
  }

  static Set<String?> _neighbourProteins(
    WeeklyMenuPlan? plan,
    DayOfWeek day,
    MealSlot slot,
    List<Recipe> pool,
  ) {
    if (plan == null) return const {};
    final byId = {for (final r in pool) r.id: r};
    final result = <String?>{};
    for (final offset in const [-1, 1]) {
      final i = day.index + offset;
      if (i < 0 || i >= DayOfWeek.values.length) continue;
      for (final e in plan.entriesAt(DayOfWeek.values[i], slot)) {
        final recipe = byId[e.recipeId];
        if (recipe != null) result.add(ProteinCategory.categoryOf(recipe));
      }
    }
    result.remove(null);
    return result;
  }
}
