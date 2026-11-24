import 'package:butlery/models/menu/week_template_entry.dart';
import 'package:butlery/models/menu/weekly_menu_plan.dart';
import 'package:butlery/models/recipe_unified.dart';

/// What is known about a template dish's recipe when the template is used.
enum TemplateDishState {
  /// The recipe exists; its current name and tags are used.
  found,

  /// A read of the recipe answered that it is gone: the dish is not placed.
  missing,

  /// The recipe could not be read: the dish is placed under its saved name
  /// and nothing is known about its allergens.
  unverified,
}

class TemplateDish {
  final WeekTemplateEntry entry;
  final Recipe? recipe;
  final TemplateDishState state;

  const TemplateDish({required this.entry, required this.state, this.recipe});

  /// The recipe's own title when it is known, so a renamed recipe reads as it
  /// does in the library; the saved title otherwise.
  String get title {
    final current = recipe?.title;
    return current == null || current.trim().isEmpty
        ? entry.recipeTitle
        : current;
  }
}

enum WeekTemplateApplyMode {
  /// Only places with nothing planned get the template's dish.
  fillEmpty,

  /// Every place the template has a dish for is overwritten; other places
  /// are left alone.
  replace,
}

class WeekTemplateApplyResult {
  final WeeklyMenuPlan plan;
  final List<String> addedEntryIds;
  final List<WeeklyMenuPlanEntry> removedEntries;
  final int missingCount;

  const WeekTemplateApplyResult({
    required this.plan,
    required this.addedEntryIds,
    required this.removedEntries,
    required this.missingCount,
  });

  bool get changed => addedEntryIds.isNotEmpty || removedEntries.isNotEmpty;
}

/// BUT-2522: putting a saved week template onto a week. Pure: no reads, no
/// writes; the caller has already read the week and the recipes.
class WeekTemplateApply {
  const WeekTemplateApply._();

  static bool _at(WeeklyMenuPlanEntry e, DayOfWeek day, MealSlot slot) =>
      e.day == day && e.slot == slot;

  /// Whether using [dishes] on [plan] would meet a place that already has a
  /// dish, which is when the person is asked how to apply it.
  static bool overlaps(WeeklyMenuPlan plan, List<TemplateDish> dishes) =>
      dishes.any(
        (d) =>
            d.state != TemplateDishState.missing &&
            plan.entries.any((e) => _at(e, d.entry.day, d.entry.slot)),
      );

  static WeekTemplateApplyResult apply({
    required WeeklyMenuPlan plan,
    required List<TemplateDish> dishes,
    required WeekTemplateApplyMode mode,
  }) {
    final entries = List<WeeklyMenuPlanEntry>.from(plan.entries);
    final added = <String>[];
    final removed = <WeeklyMenuPlanEntry>[];
    final cleared = <(DayOfWeek, MealSlot)>{};
    var missing = 0;

    for (final dish in dishes) {
      if (dish.state == TemplateDishState.missing) {
        missing++;
        continue;
      }
      final day = dish.entry.day;
      final slot = dish.entry.slot;
      final place = (day, slot);

      if (mode == WeekTemplateApplyMode.replace && cleared.add(place)) {
        final taken = entries.where((e) => _at(e, day, slot)).toList();
        entries.removeWhere((e) => _at(e, day, slot));
        removed.addAll(taken.where((e) => !added.contains(e.id)));
      }

      if (_occupied(entries, day, slot, dish.entry.recipeId)) continue;

      final entry = WeeklyMenuPlanEntry.create(
        day: day,
        slot: slot,
        recipeId: dish.entry.recipeId,
        recipeTitle: dish.title,
        recipeImageUrl: dish.recipe?.primaryImageUrl,
      );
      entries.add(entry);
      added.add(entry.id);
    }

    return WeekTemplateApplyResult(
      plan: plan.copyWith(entries: entries),
      addedEntryIds: added,
      removedEntries: removed,
      missingCount: missing,
    );
  }

  /// Takes [result] back off [current]: the dishes it added go, the dishes it
  /// replaced return. Edits made since are kept, so a replaced dish does not
  /// return to a place someone has filled again.
  static WeeklyMenuPlan undo(
    WeeklyMenuPlan current,
    WeekTemplateApplyResult result,
  ) {
    final addedIds = result.addedEntryIds.toSet();
    final entries = current.entries
        .where((e) => !addedIds.contains(e.id))
        .toList();
    final keptIds = entries.map((e) => e.id).toSet();
    for (final e in result.removedEntries) {
      if (keptIds.contains(e.id)) continue;
      if (_occupied(entries, e.day, e.slot, e.recipeId)) continue;
      entries.add(e);
    }
    return current.copyWith(entries: entries);
  }

  /// A place holds one dish, except övrigt, which holds several but not the
  /// same recipe twice.
  static bool _occupied(
    List<WeeklyMenuPlanEntry> entries,
    DayOfWeek day,
    MealSlot slot,
    String recipeId,
  ) => slot.isMulti
      ? entries.any((e) => _at(e, day, slot) && e.recipeId == recipeId)
      : entries.any((e) => _at(e, day, slot));
}
