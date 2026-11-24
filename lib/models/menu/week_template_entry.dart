import 'package:butlery/models/menu/weekly_menu_plan.dart';

/// One dish of a saved week template (BUT-2522): where it sat in the week and
/// which recipe it was. The title is kept so a recipe deleted since can still
/// be named; a recipe that still exists is shown by its current title.
class WeekTemplateEntry {
  final DayOfWeek day;
  final MealSlot slot;
  final String recipeId;
  final String recipeTitle;

  const WeekTemplateEntry({
    required this.day,
    required this.slot,
    required this.recipeId,
    required this.recipeTitle,
  });

  /// The `menus` rules bound nothing on this field, so a stored list is read
  /// as untrusted: these caps decide what a template may hold.
  static const int maxEntries = 60;
  static const int maxRecipeIdLength = 128;
  static const int maxTitleLength = 200;

  static WeekTemplateEntry fromPlanEntry(WeeklyMenuPlanEntry entry) =>
      WeekTemplateEntry(
        day: entry.day,
        slot: entry.slot,
        recipeId: entry.recipeId,
        recipeTitle: _capTitle(entry.recipeTitle),
      );

  /// The entries of [plan] in week order, as a template stores them. Entries
  /// whose recipe id could not be stored are left out.
  static List<WeekTemplateEntry> fromPlan(WeeklyMenuPlan plan) {
    final entries = [
      for (final e in plan.entries)
        if (isStorableRecipeId(e.recipeId)) fromPlanEntry(e),
    ]..sort(_byPlace);
    return entries.take(maxEntries).toList();
  }

  static int _byPlace(WeekTemplateEntry a, WeekTemplateEntry b) {
    final byDay = a.day.index.compareTo(b.day.index);
    return byDay != 0 ? byDay : a.slot.index.compareTo(b.slot.index);
  }

  /// A recipe id is later used as a document id, so a separator or an empty
  /// id would name some other path.
  static bool isStorableRecipeId(String id) =>
      id.isNotEmpty &&
      id.length <= maxRecipeIdLength &&
      !id.contains('/') &&
      id != '.' &&
      id != '..';

  static String _capTitle(String title) => title.length > maxTitleLength
      ? title.substring(0, maxTitleLength)
      : title;

  Map<String, dynamic> toMap() => {
    'day': day.name,
    'slot': slot.name,
    'recipeId': recipeId,
    'recipeTitle': recipeTitle,
  };

  /// Null for anything that is not a well-formed entry; the caller drops it.
  static WeekTemplateEntry? tryParse(Object? raw) {
    if (raw is! Map) return null;
    final day = DayOfWeek.values.where((d) => d.name == raw['day']).firstOrNull;
    final slot = MealSlot.values
        .where((s) => s.name == raw['slot'])
        .firstOrNull;
    final recipeId = raw['recipeId'];
    final title = raw['recipeTitle'];
    if (day == null || slot == null) return null;
    if (recipeId is! String || !isStorableRecipeId(recipeId)) return null;
    return WeekTemplateEntry(
      day: day,
      slot: slot,
      recipeId: recipeId,
      recipeTitle: _capTitle(title is String ? title : ''),
    );
  }

  static List<WeekTemplateEntry> listFrom(Object? raw) {
    if (raw is! List) return const [];
    return [
      for (final item in raw.take(maxEntries)) ?tryParse(item),
    ];
  }

  @override
  bool operator ==(Object other) =>
      other is WeekTemplateEntry &&
      other.day == day &&
      other.slot == slot &&
      other.recipeId == recipeId &&
      other.recipeTitle == recipeTitle;

  @override
  int get hashCode => Object.hash(day, slot, recipeId, recipeTitle);
}
