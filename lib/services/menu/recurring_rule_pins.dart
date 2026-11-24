/// Turns saved weekly rules (BUT-2490) into day pins on a parsed prompt, so
/// generation and placement steer them through the same path as a typed
/// "tacofredag". Pure: no I/O, no clock.
library;

import 'package:butlery/models/menu/parsed_menu_request.dart';
import 'package:butlery/models/menu/recurring_day_rule.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/services/menu/meal_slot_mapper.dart';

/// A generated menu plus the rules that found no recipe at all.
class MenuGenerationOutcome {
  const MenuGenerationOutcome({
    required this.menu,
    this.unmatchedRuleIds = const [],
  });

  static const MenuGenerationOutcome empty = MenuGenerationOutcome(menu: {});

  final Map<String, List<Recipe>> menu;

  /// Ids of active rule pins whose pool was empty, in pin order.
  final List<String> unmatchedRuleIds;
}

abstract final class RecurringRulePins {
  /// [parsed] with a pin for every active rule whose meal the prompt asks
  /// for and whose day and meal no typed pin already claims: what the user
  /// wrote this week wins over what they saved. A prompt asking only for
  /// lunches gets no dinner from a dinner rule.
  static ParsedMenuRequest merge(
    ParsedMenuRequest parsed,
    List<RecurringDayRule> rules,
  ) {
    if (rules.isEmpty || parsed.isEmpty) return parsed;
    final typed = [
      for (final pin in parsed.dayPins)
        if (!pin.fromRule) pin,
    ];
    String key(int weekday, String meal) => '$weekday|${menuMealKey(meal)}';
    final claimed = {
      for (final pin in typed) key(pin.weekdayIndex, pin.mealType),
    };
    final askedMeals = {
      for (final slot in parsed.slotRequests)
        if (slot.totalCount > 0) menuMealKey(slot.mealType),
      for (final pin in typed) menuMealKey(pin.mealType),
    };
    final rulePins = <DayPin>[
      for (final rule in rules)
        if (rule.isActive &&
            askedMeals.contains(rule.meal.name) &&
            !claimed.contains(key(rule.day.isoWeekday, rule.meal.name)))
          DayPin(
            weekdayIndex: rule.day.isoWeekday,
            mealType: rule.meal.name,
            constraint: rule.toConstraint(),
            fromRule: true,
            ruleId: rule.id,
          ),
    ];
    if (rulePins.isEmpty) return parsed;
    return ParsedMenuRequest(
      slotRequests: parsed.slotRequests,
      globalAllergenAvoid: parsed.globalAllergenAvoid,
      globalDietaryRequire: parsed.globalDietaryRequire,
      globalExcludedTags: parsed.globalExcludedTags,
      dayPins: [...typed, ...rulePins],
      trace: parsed.trace,
      rawPrompt: parsed.rawPrompt,
    );
  }

  /// The rules named by [ids], in that order.
  static List<RecurringDayRule> rulesFor(
    List<String> ids,
    List<RecurringDayRule> rules,
  ) => [
    for (final id in ids) ...rules.where((r) => r.id == id),
  ];
}
