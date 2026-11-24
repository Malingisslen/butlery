/// Lunchboxes on the personal weekly menu (BUT-2486).
library;

import 'package:butlery/core/utils/serialization_utils.dart';
import 'package:butlery/models/menu/weekly_menu_plan.dart';
import 'package:butlery/models/recipe_unified.dart';

/// Where a day's lunchbox comes from.
enum LunchboxSource {
  /// Leftovers from a middag ("Rester").
  leftovers,

  /// Cooked ahead on a prep day ("Lagardag").
  prepDay,

  /// A dish the app suggested for the box.
  suggestion;

  /// An unknown name parses as [suggestion], whose recipe is stored on the
  /// box, so a box written by a newer app still names its dish.
  static LunchboxSource fromName(String name) =>
      SerializationUtils.safeEnumByName(
        LunchboxSource.values,
        name,
        LunchboxSource.suggestion,
      );
}

/// One day's lunch as a lunchbox: the dish, how many boxes and who takes one.
class Lunchbox {
  final LunchboxSource source;

  /// The dish, stored for every box except same-week leftovers. Those follow
  /// the middag on [fromDay] live, so a changed middag never leaves a box
  /// pointing at a dish nobody cooked.
  final String? recipeId;
  final String? recipeTitle;

  /// The middag the leftovers come from. Only for [LunchboxSource.leftovers].
  final DayOfWeek? fromDay;

  /// Leftovers from the previous week's middag (Sunday → Monday's lunch).
  /// That week is another document, which is never read for this, so the
  /// dish is stored on the box instead.
  final bool fromPreviousWeek;

  /// Number of boxes, at least 1.
  final int portions;

  /// Roster member ids (accounts and diner profiles, the same key space as
  /// the week's presence) of the people who take a box. Empty = not said,
  /// which the allergen check reads as the whole household.
  final List<String> takerIds;

  const Lunchbox({
    required this.source,
    this.recipeId,
    this.recipeTitle,
    this.fromDay,
    this.fromPreviousWeek = false,
    this.portions = 1,
    this.takerIds = const [],
  });

  /// Whether the dish is the middag on [fromDay] of the same week.
  bool get followsMiddag =>
      source == LunchboxSource.leftovers &&
      !fromPreviousWeek &&
      fromDay != null;

  /// The recipe this box holds in [plan], or null when it cannot be told:
  /// same-week leftovers from a day without a middag, or a box with no dish.
  String? recipeIdIn(WeeklyMenuPlan plan) {
    if (followsMiddag) return plan.entryAt(fromDay!, MealSlot.middag)?.recipeId;
    final id = recipeId;
    return id == null || id.isEmpty ? null : id;
  }

  Map<String, dynamic> toMap() => {
    'source': source.name,
    if (!followsMiddag && recipeId != null) 'recipeId': recipeId,
    if (!followsMiddag && recipeTitle != null) 'recipeTitle': recipeTitle,
    if (fromDay != null) 'fromDay': fromDay!.name,
    if (fromPreviousWeek) 'fromPreviousWeek': true,
    'portions': portions,
    'takerIds': takerIds,
  };

  factory Lunchbox.fromMap(Map<String, dynamic> data) {
    final source = LunchboxSource.fromName(
      SerializationUtils.safeString(data, 'source'),
    );
    final fromDayName = SerializationUtils.safeNullableString(data, 'fromDay');
    final fromDay = fromDayName == null
        ? null
        : DayOfWeek.values.where((d) => d.name == fromDayName).firstOrNull;
    final portions = SerializationUtils.safeInt(
      data,
      'portions',
      defaultValue: 1,
    );
    return Lunchbox(
      source: source,
      recipeId: SerializationUtils.safeNullableString(data, 'recipeId'),
      recipeTitle: SerializationUtils.safeNullableString(data, 'recipeTitle'),
      fromDay: fromDay,
      fromPreviousWeek: data['fromPreviousWeek'] == true,
      portions: portions < 1 ? 1 : portions,
      takerIds: SerializationUtils.safeStringList(data, 'takerIds'),
    );
  }

  /// Tolerant parse of the week's `lunchboxes` map. An unknown day or a
  /// malformed box is skipped rather than moved onto another day.
  static Map<DayOfWeek, Lunchbox> parseAll(dynamic raw) {
    if (raw is! Map) return const {};
    final result = <DayOfWeek, Lunchbox>{};
    raw.forEach((dayKey, value) {
      if (dayKey is! String || value is! Map) return;
      final day = DayOfWeek.values.where((d) => d.name == dayKey).firstOrNull;
      if (day == null) return;
      result[day] = Lunchbox.fromMap(Map<String, dynamic>.from(value));
    });
    return result;
  }

  static Map<String, dynamic> serializeAll(Map<DayOfWeek, Lunchbox> boxes) => {
    for (final e in boxes.entries) e.key.name: e.value.toMap(),
  };
}

/// Editing a week's lunchboxes.
extension WeeklyMenuPlanLunchboxes on WeeklyMenuPlan {
  /// This week with [box] as [day]'s lunch. A box IS that day's lunch, so a
  /// lunch dish already in `entries` on [day] is removed: the same lunch must
  /// not be planned, shopped for or checked twice.
  WeeklyMenuPlan withLunchbox(DayOfWeek day, Lunchbox box) => copyWith(
    entries: [
      for (final e in entries)
        if (!(e.day == day && e.slot == MealSlot.lunch)) e,
    ],
    lunchboxes: {...lunchboxes, day: box},
  );

  WeeklyMenuPlan withoutLunchbox(DayOfWeek day) =>
      copyWith(lunchboxes: {...lunchboxes}..remove(day));

  /// This week without the boxes whose STORED dish is [recipeId]. Same-week
  /// leftovers follow their middag, which the entry scrub already removes.
  WeeklyMenuPlan withoutLunchboxesOf(String recipeId) => copyWith(
    lunchboxes: {
      for (final e in lunchboxes.entries)
        if (e.value.followsMiddag || e.value.recipeId != recipeId)
          e.key: e.value,
    },
  );
}

/// Whether a recipe suits a lunchbox: the `meal-prep` tag the tagging rules
/// guess, unless the user corrected it on the recipe (`tagOverrides`), in
/// which case the correction wins either way.
class LunchboxSuitability {
  LunchboxSuitability._();

  static const String tag = 'meal-prep';

  static bool suits(Recipe recipe) {
    final auto = recipe.tagResult?.tags.toSet() ?? const <String>{};
    final effective = recipe.tagOverrides?.getEffectiveTags(auto) ?? auto;
    return effective.contains(tag);
  }
}
