// lib/services/menu/stock_lunch_planner.dart

import 'package:butlery/models/menu/lunchbox_plan.dart';
import 'package:butlery/models/menu/meal_box.dart';
import 'package:butlery/models/menu/weekly_menu_plan.dart';

/// Picks fridge and freezer boxes for the lunch days a person asked for when
/// the week is suggested (BUT-2486 part 6). Pure: the boxes and the safety
/// verdict come from the caller.
class StockLunchPlanner {
  StockLunchPlanner._();

  /// A fridge box older than this on the day it would be eaten is left for
  /// the person to choose by hand (Malin 2026-11-25).
  static const int maxFridgeAgeDays = 5;

  /// The days of [days] from [today] on whose lunch in [week] is still
  /// empty: no lunchbox and no lunch dish. Only these are ever filled.
  static List<DayOfWeek> openDays({
    required WeeklyMenuPlan week,
    required Set<DayOfWeek> days,
    required DateTime today,
  }) {
    final todayDate = _dateOnly(today);
    return [
      for (final day in DayOfWeek.values)
        if (days.contains(day) &&
            !_dateOf(week, day).isBefore(todayDate) &&
            !week.lunchboxes.containsKey(day) &&
            week.entryAt(day, MealSlot.lunch) == null)
          day,
    ];
  }

  /// One box per open day, in weekday order. Fridge boxes come before
  /// freezer boxes, the oldest first within each, so what keeps the shortest
  /// is eaten first. A box [isSafe] rejects for a day is not used that day.
  static Map<DayOfWeek, Lunchbox> plan({
    required WeeklyMenuPlan week,
    required Iterable<MealBox> boxes,
    required Set<DayOfWeek> days,
    required DateTime today,
    required bool Function(MealBox box, DayOfWeek day) isSafe,
  }) {
    final candidates = boxes.where((b) => b.remaining > 0).toList()
      ..sort(_eatFirst);
    final left = {for (final b in candidates) b.id: b.remaining};
    final placed = <DayOfWeek, Lunchbox>{};
    for (final day in openDays(week: week, days: days, today: today)) {
      final date = _dateOf(week, day);
      for (final box in candidates) {
        if ((left[box.id] ?? 0) < 1) continue;
        if (!_freshEnough(box, date)) continue;
        if (!isSafe(box, day)) continue;
        left[box.id] = left[box.id]! - 1;
        placed[day] = Lunchbox.fromStock(box);
        break;
      }
    }
    return placed;
  }

  static DateTime _dateOf(WeeklyMenuPlan week, DayOfWeek day) =>
      _dateOnly(week.weekStartDate.add(Duration(days: day.index)));

  static int _eatFirst(MealBox a, MealBox b) {
    if (a.location != b.location) {
      return a.location == MealBoxLocation.fridge ? -1 : 1;
    }
    final byDate = a.storedOn.compareTo(b.storedOn);
    return byDate != 0 ? byDate : a.id.compareTo(b.id);
  }

  static bool _freshEnough(MealBox box, DateTime lunchDate) {
    if (box.location != MealBoxLocation.fridge) return true;
    final age = lunchDate.difference(_dateOnly(box.storedOn)).inDays;
    return age <= maxFridgeAgeDays;
  }

  static DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);
}
