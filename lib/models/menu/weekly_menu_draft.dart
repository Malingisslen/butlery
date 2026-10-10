import 'package:clock/clock.dart';
import 'package:flutter/foundation.dart';

/// BUT-2157: the latest generated, unsaved week suggestion, kept on this
/// device so a restart, an OS kill or an automatic sign-out does not lose it.
///
/// produktregler.md: a week generation's local draft lives on the
/// device only, 30 days since its last change (ux-beslut.json D-01). Dishes
/// are kept by id and resolved again on restore through the allergen-safe
/// pool, so a recipe deleted or made unsafe in the meantime does not come
/// back. One slot per account; the owner is the store key, not a field.
@immutable
class WeeklyMenuDraft {
  const WeeklyMenuDraft({
    required this.prompt,
    required this.recipeIdsByMealType,
    required this.requestedByMealType,
    required this.lastModifiedAt,
    this.recipeNames = const {},
  });

  /// "Ett påbörjat utkast är återupptagbart i 30 dagar sedan senaste
  /// ändring" (ux-beslut.json D-01).
  static const Duration lifetime = Duration(days: 30);

  /// What the user asked for, so a restored menu re-rolls and places with the
  /// same constraints.
  final String prompt;

  /// Recipe ids per meal type as the menu keyed them, in menu order.
  final Map<String, List<String>> recipeIdsByMealType;

  /// Dishes the prompt asked for per meal type, so a restore that lost dishes
  /// reads as a partial result (produktregler.md).
  final Map<String, int> requestedByMealType;

  final DateTime lastModifiedAt;

  /// Dish names by recipe id as they were when the draft was written, so the
  /// resume card can show the week without reading the library. Display
  /// only: a restore still resolves every id through the safe pool.
  final Map<String, String> recipeNames;

  int get recipeCount =>
      recipeIdsByMealType.values.fold(0, (sum, ids) => sum + ids.length);

  bool get isEmpty => recipeCount == 0;

  DateTime get expiresAt => lastModifiedAt.add(lifetime);

  /// How long the draft is still kept; zero once it has expired.
  Duration get timeLeft {
    final left = expiresAt.difference(clock.now());
    return left.isNegative ? Duration.zero : left;
  }

  bool get isExpired => clock.now().difference(lastModifiedAt) > lifetime;

  Map<String, Object?> toJson() => {
    'prompt': prompt,
    'meals': [
      for (final entry in recipeIdsByMealType.entries)
        {'mealType': entry.key, 'recipeIds': entry.value},
    ],
    'requested': requestedByMealType,
    'lastModifiedAt': lastModifiedAt.toIso8601String(),
    'names': recipeNames,
  };

  /// Null when [json] is not a draft this version can read. Meal types are a
  /// list rather than a map so their order survives any JSON codec.
  static WeeklyMenuDraft? fromJson(Object? json) {
    if (json is! Map) return null;
    final at = DateTime.tryParse('${json['lastModifiedAt']}');
    final meals = json['meals'];
    if (at == null || meals is! List) return null;
    final byMealType = <String, List<String>>{};
    for (final meal in meals) {
      if (meal is! Map) continue;
      final type = meal['mealType'];
      final ids = meal['recipeIds'];
      if (type is! String || type.isEmpty || ids is! List) continue;
      final kept = [
        for (final id in ids)
          if (id is String && id.isNotEmpty) id,
      ];
      if (kept.isEmpty) continue;
      (byMealType[type] ??= []).addAll(kept);
    }
    final requested = json['requested'];
    final prompt = json['prompt'];
    final names = json['names'];
    return WeeklyMenuDraft(
      prompt: prompt is String ? prompt : '',
      recipeIdsByMealType: byMealType,
      requestedByMealType: {
        if (requested is Map)
          for (final e in requested.entries)
            if (e.value is int && (e.value as int) > 0)
              '${e.key}': e.value as int,
      },
      lastModifiedAt: at,
      recipeNames: {
        if (names is Map)
          for (final e in names.entries)
            if (e.value is String && (e.value as String).isNotEmpty)
              '${e.key}': e.value as String,
      },
    );
  }
}
