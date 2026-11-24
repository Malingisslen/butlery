/// Cooked food kept as boxes in the fridge or freezer (BUT-2486, part 5).
library;

import 'dart:math' as math;

import 'package:butlery/core/utils/serialization_utils.dart';
import 'package:butlery/models/menu/lunchbox_plan.dart';
import 'package:butlery/models/menu/weekly_menu_plan.dart';

enum MealBoxLocation {
  fridge,
  freezer;

  static MealBoxLocation fromName(String name) =>
      SerializationUtils.safeEnumByName(
        MealBoxLocation.values,
        name,
        MealBoxLocation.fridge,
      );
}

/// One dish in the fridge or freezer, stored at `users/{uid}/meal_boxes/{id}`.
///
/// One box is one portion. [count] is what the user put in or corrected to;
/// [takes] holds one entry per planned lunch that takes from it, keyed by the
/// lunch's date, so choosing, changing or removing a lunch sets or deletes a
/// single key and a repeated save cannot take twice.
class MealBox {
  /// Largest [count] the rules accept, and the stepper's ceiling.
  static const int maxCount = 99;

  /// Most planned lunches one box may carry at once; the rules hold the same.
  static const int maxTakes = 60;

  static const int maxTitleLength = 200;

  final String id;
  final String? recipeId;

  /// Kept on the box: the recipe can be deleted while the food is still there.
  final String recipeTitle;
  final MealBoxLocation location;

  /// When the food was cooked or frozen.
  final DateTime storedOn;
  final int count;
  final Map<String, int> takes;
  final DateTime? updatedAt;

  const MealBox({
    required this.id,
    this.recipeId,
    required this.recipeTitle,
    required this.location,
    required this.storedOn,
    this.count = 0,
    this.takes = const {},
    this.updatedAt,
  });

  int get taken => takes.values.fold(0, (total, n) => total + n);

  /// Boxes not yet planned for a lunch. Never below 0 on screen, even when a
  /// correction lowered [count] under what lunches already take.
  int get remaining => math.max(0, count - taken);

  /// The take keys whose lunch date is before [today]: that food is eaten.
  Iterable<String> pastTakeKeys(DateTime today) {
    final cutoff = dateKey(today);
    return takes.keys.where((k) => k.compareTo(cutoff) < 0);
  }

  factory MealBox.fromMap(String id, Map<String, dynamic> data) {
    final rawTakes = data['takes'];
    return MealBox(
      id: id,
      recipeId: SerializationUtils.safeNullableString(data, 'recipeId'),
      recipeTitle: SerializationUtils.safeString(data, 'recipeTitle'),
      location: MealBoxLocation.fromName(
        SerializationUtils.safeString(data, 'location'),
      ),
      storedOn: SerializationUtils.safeRequiredDateTime(data, 'storedOn'),
      count: math.max(0, SerializationUtils.safeInt(data, 'count')),
      takes: {
        if (rawTakes is Map)
          for (final e in rawTakes.entries)
            if (e.key is String && e.value is int && (e.value as int) > 0)
              e.key as String: e.value as int,
      },
      updatedAt: SerializationUtils.safeDateTime(data, 'updatedAt'),
    );
  }

  /// `yyyy-mm-dd`, which sorts as a date.
  static String dateKey(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';

  static final RegExp _idPattern = RegExp(r'^[A-Za-z0-9_-]{1,128}$');

  /// A box id read back from a week, whose lunchbox map the rules leave
  /// unchecked, is used as a document id only when it is a plain id.
  static bool isValidId(String? id) => id != null && _idPattern.hasMatch(id);

  static String clampTitle(String title) => title.length > maxTitleLength
      ? title.substring(0, maxTitleLength)
      : title;
}

/// One change to a box's [MealBox.takes]: [portions] taken for the lunch on
/// [key], or the take removed when null. Carries the box's identity so the
/// write succeeds, recreating the box, even when its document is gone.
class MealBoxTake {
  final String boxId;
  final String key;
  final int? portions;
  final String? recipeId;
  final String recipeTitle;
  final MealBoxLocation location;
  final DateTime storedOn;

  const MealBoxTake({
    required this.boxId,
    required this.key,
    required this.portions,
    required this.recipeId,
    required this.recipeTitle,
    required this.location,
    required this.storedOn,
  });

  /// The box takes that turn [before]'s lunchboxes into [after]'s. Empty when
  /// nothing about a box from stock changed, so an ordinary week save writes
  /// nothing extra.
  static List<MealBoxTake> between(
    WeeklyMenuPlan? before,
    WeeklyMenuPlan after,
  ) {
    final result = <MealBoxTake>[];
    for (final day in DayOfWeek.values) {
      final old = before?.lunchboxes[day];
      final now = after.lunchboxes[day];
      final oldStock = old != null && old.isFromStock ? old : null;
      final newStock = now != null && now.isFromStock ? now : null;
      if (oldStock == null && newStock == null) continue;
      final key = MealBox.dateKey(
        after.weekStartDate.add(Duration(days: day.index)),
      );
      final sameBox = oldStock?.mealBoxId == newStock?.mealBoxId;
      if (oldStock != null && !sameBox) {
        result.add(_of(oldStock, key, null));
      }
      if (newStock != null &&
          (!sameBox || oldStock!.portions != newStock.portions)) {
        result.add(_of(newStock, key, newStock.portions));
      }
    }
    return result;
  }

  static MealBoxTake _of(Lunchbox box, String key, int? portions) =>
      MealBoxTake(
        boxId: box.mealBoxId!,
        key: key,
        portions: portions,
        recipeId: box.recipeId,
        recipeTitle: MealBox.clampTitle(box.recipeTitle!),
        location: box.mealBoxLocation ?? MealBoxLocation.fridge,
        storedOn: box.mealBoxStoredOn!,
      );
}
