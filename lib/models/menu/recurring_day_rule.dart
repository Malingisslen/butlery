/// A saved weekly rule ("fast dag", BUT-2490): "måndag middag = fisk" steers
/// which of the user's own recipes generation picks for that day every week.
/// The rule names a kind of food or a kind of evening, never one recipe.
library;

import 'package:flutter/foundation.dart';

import 'package:butlery/core/extensions/default_value_extensions.dart';
import 'package:butlery/core/utils/serialization_utils.dart';
import 'package:butlery/models/menu/parsed_menu_request.dart';
import 'package:butlery/models/menu/weekly_menu_plan.dart';

/// How a rule's value is matched against a recipe.
enum RecurringRuleKind { tag, proteinCategory, dietary, quick }

/// The food chips the rule screen offers. Each maps onto a signal recipes
/// already carry, so a rule needs no AI and no new tagging.
enum RecurringFood {
  fisk(RecurringRuleKind.proteinCategory, 'fish'),
  tacos(RecurringRuleKind.tag, 'taco'),
  vegetariskt(RecurringRuleKind.dietary, 'vegetarisk'),
  // `pasta-dish` is derived from `pastabaserad`, which the tagger sets from
  // the ingredients; a bare `pasta` tag is never emitted.
  pasta(RecurringRuleKind.tag, 'pasta-dish'),
  soppa(RecurringRuleKind.tag, 'soppa'),
  kyckling(RecurringRuleKind.proteinCategory, 'poultry');

  const RecurringFood(this.kind, this.value);

  final RecurringRuleKind kind;
  final String value;

  static RecurringFood? of(RecurringRuleKind kind, String value) {
    for (final food in values) {
      if (food.kind == kind && food.value == value) return food;
    }
    return null;
  }
}

@immutable
class RecurringDayRule {
  /// "Snabbt" in the rule screen: the same bound as the quick week pick.
  static const int quickMaxMinutes = 30;

  const RecurringDayRule({
    required this.id,
    required this.day,
    required this.meal,
    required this.kind,
    this.value = '',
    this.quick = false,
    this.paused = false,
  });

  /// A new rule for [day] and [meal]. [food] null means an evening-type rule
  /// only, which then must be quick.
  factory RecurringDayRule.create({
    required DayOfWeek day,
    required MealSlot meal,
    RecurringFood? food,
    bool quick = false,
  }) {
    assert(food != null || quick, 'a rule needs a food or a quick evening');
    return RecurringDayRule(
      id: idFor(day, meal),
      day: day,
      meal: meal,
      kind: food?.kind ?? RecurringRuleKind.quick,
      value: (food?.value).orEmpty(),
      quick: quick || food == null,
    );
  }

  /// One rule per day and meal, so the slot itself is a stable id.
  static String idFor(DayOfWeek day, MealSlot meal) =>
      '${day.isoWeekday}-${meal.name}';

  final String id;
  final DayOfWeek day;

  /// Lunch or middag; övrigt holds many dishes and takes no rule.
  final MealSlot meal;
  final RecurringRuleKind kind;
  final String value;
  final bool quick;
  final bool paused;

  RecurringFood? get food => RecurringFood.of(kind, value);

  bool get isActive => !paused;

  RecurringDayRule copyWith({bool? paused}) => RecurringDayRule(
    id: id,
    day: day,
    meal: meal,
    kind: kind,
    value: value,
    quick: quick,
    paused: paused ?? this.paused,
  );

  /// The recipe requirement this rule puts on its day.
  RecipeConstraint toConstraint() => RecipeConstraint(
    count: 1,
    requiredTags: kind == RecurringRuleKind.tag ? {value} : const {},
    dietaryFree: kind == RecurringRuleKind.dietary ? {value} : const {},
    proteinCategory: kind == RecurringRuleKind.proteinCategory ? value : null,
    maxTimeMinutes: quick ? quickMaxMinutes : null,
  );

  Map<String, dynamic> toFirestore() => {
    'id': id,
    'weekday': day.isoWeekday,
    'meal': meal.name,
    'kind': kind.name,
    'value': value,
    'quick': quick,
    'paused': paused,
  };

  /// Null for a row this version cannot use (an unknown kind or food, a day
  /// out of range, övrigt), so one bad row never hides the others.
  static RecurringDayRule? fromFirestore(Map<String, dynamic> data) {
    final weekday = SerializationUtils.safeNullableInt(data, 'weekday');
    if (weekday == null || weekday < 1 || weekday > 7) return null;
    final mealName = SerializationUtils.safeNullableString(data, 'meal');
    final meal = switch (mealName) {
      'lunch' => MealSlot.lunch,
      'middag' => MealSlot.middag,
      _ => null,
    };
    if (meal == null) return null;
    final kindName = SerializationUtils.safeNullableString(data, 'kind');
    final kind = RecurringRuleKind.values
        .where((k) => k.name == kindName)
        .firstOrNull;
    if (kind == null) return null;
    final value = SerializationUtils.safeString(data, 'value');
    if (kind != RecurringRuleKind.quick &&
        RecurringFood.of(kind, value) == null) {
      return null;
    }
    final day = DayOfWeek.values[weekday - 1];
    return RecurringDayRule(
      id: idFor(day, meal),
      day: day,
      meal: meal,
      kind: kind,
      value: kind == RecurringRuleKind.quick ? '' : value,
      quick:
          kind == RecurringRuleKind.quick ||
          SerializationUtils.safeBool(data, 'quick'),
      paused: SerializationUtils.safeBool(data, 'paused'),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is RecurringDayRule &&
      other.id == id &&
      other.day == day &&
      other.meal == meal &&
      other.kind == kind &&
      other.value == value &&
      other.quick == quick &&
      other.paused == paused;

  @override
  int get hashCode => Object.hash(id, day, meal, kind, value, quick, paused);
}

/// The rule list: at most one rule per day and meal, at most [maxRules] in all.
abstract final class RecurringDayRules {
  /// Seven days times lunch and middag.
  static const int maxRules = 14;

  static const String field = 'recurringDayRules';

  /// Reads the stored list; the first rule for a slot wins and the list is
  /// cut at [maxRules], so a hand-written document cannot break the engine.
  static List<RecurringDayRule> fromFirestoreList(Object? raw) {
    if (raw is! List) return const [];
    final seen = <String>{};
    final rules = <RecurringDayRule>[];
    for (final row in raw) {
      if (row is! Map) continue;
      final rule = RecurringDayRule.fromFirestore(
        Map<String, dynamic>.from(row),
      );
      if (rule == null || !seen.add(rule.id)) continue;
      rules.add(rule);
      if (rules.length == maxRules) break;
    }
    return List.unmodifiable(rules);
  }

  static List<Map<String, dynamic>> toFirestoreList(
    List<RecurringDayRule> rules,
  ) => [for (final r in rules) r.toFirestore()];

  /// [rules] with [rule] saved: it replaces the rule on the same day and
  /// meal. Null when that would go past [maxRules].
  static List<RecurringDayRule>? upsert(
    List<RecurringDayRule> rules,
    RecurringDayRule rule,
  ) {
    final index = rules.indexWhere((r) => r.id == rule.id);
    if (index >= 0) {
      return List.unmodifiable([...rules]..[index] = rule);
    }
    if (rules.length >= maxRules) return null;
    return List.unmodifiable(_sorted([...rules, rule]));
  }

  static List<RecurringDayRule> remove(
    List<RecurringDayRule> rules,
    String id,
  ) => List.unmodifiable(rules.where((r) => r.id != id));

  /// The active rule on [day] and [meal], or null.
  static RecurringDayRule? activeAt(
    List<RecurringDayRule> rules,
    DayOfWeek day,
    MealSlot meal,
  ) {
    for (final r in rules) {
      if (r.isActive && r.day == day && r.meal == meal) return r;
    }
    return null;
  }

  static List<RecurringDayRule> _sorted(List<RecurringDayRule> rules) =>
      rules..sort((a, b) {
        final byDay = a.day.index.compareTo(b.day.index);
        return byDay != 0 ? byDay : a.meal.index.compareTo(b.meal.index);
      });
}
