/// ISO 8601 week date utilities for the weekly menu plan feature.
///
/// Used to compute Monday-anchored week starts and deterministic
/// per-week document IDs for `WeeklyMenuPlan` storage.
abstract final class IsoWeekUtils {
  /// Returns the Monday 00:00 local-time start of the ISO week containing [date].
  static DateTime weekStartOf(DateTime date) {
    final daysFromMonday = date.weekday - DateTime.monday;
    final monday = DateTime(date.year, date.month, date.day)
        .subtract(Duration(days: daysFromMonday));
    return monday;
  }

  /// ISO 8601 week number for [date] (1..53).
  ///
  /// ISO weeks: Monday is the first day, week 1 contains the first Thursday
  /// of the year. Implemented via the standard ordinal-day formula, with
  /// day-of-year computed via UTC `inDays` to stay DST-safe (local-time
  /// difference would lose an hour across the spring-forward boundary).
  static int isoWeekNumber(DateTime date) {
    final dayOfYear = _dayOfYear(date);
    final weekday = date.weekday; // 1=Mon..7=Sun
    final weekNumber = ((dayOfYear - weekday + 10) / 7).floor();

    if (weekNumber < 1) {
      // Belongs to the last week of previous year.
      return isoWeekNumber(DateTime(date.year - 1, 12, 31));
    }
    if (weekNumber == 53) {
      // Verify week 53 actually exists this ISO year.
      final jan1Weekday = DateTime(date.year, 1, 1).weekday;
      final isLeap = _isLeapYear(date.year);
      final hasWeek53 = jan1Weekday == DateTime.thursday ||
          (isLeap && jan1Weekday == DateTime.wednesday);
      if (!hasWeek53) return 1;
    }
    return weekNumber;
  }

  /// ISO week year for [date]. Note this can differ from `date.year` near
  /// year boundaries (e.g. 2025-12-29 is ISO week 1 of 2026).
  static int isoWeekYear(DateTime date) {
    final week = isoWeekNumber(date);
    if (week == 1 && date.month == 12) return date.year + 1;
    if (week >= 52 && date.month == 1) return date.year - 1;
    return date.year;
  }

  /// Canonical user-independent week key: `{YYYY}-W{WW}` (zero-padded),
  /// e.g. `2026-W24`. Used as the `generatedForWeek` marker on shopping
  /// lists generated from the weekly menu (BUT-1234) and as the suffix of
  /// [weekIdFor].
  static String weekKeyOf(DateTime date) {
    final year = isoWeekYear(date);
    final week = isoWeekNumber(date);
    return '$year-W${week.toString().padLeft(2, '0')}';
  }

  /// Deterministic Firestore document ID: `{userId}_{YYYY}-W{WW}` (zero-padded).
  ///
  /// Example: `abc123_2026-W15`. Same `(userId, week)` always returns the
  /// same ID — used as the upsert key for `WeeklyMenuPlan` so generation
  /// re-runs overwrite the same doc rather than creating duplicates.
  static String weekIdFor(String userId, DateTime date) {
    return '${userId}_${weekKeyOf(date)}';
  }

  static bool _isLeapYear(int year) {
    return (year % 4 == 0 && year % 100 != 0) || year % 400 == 0;
  }

  /// Day-of-year (1..366) computed via UTC to avoid DST hour drift.
  static int _dayOfYear(DateTime date) {
    final start = DateTime.utc(date.year, 1, 1);
    final dayOnly = DateTime.utc(date.year, date.month, date.day);
    return dayOnly.difference(start).inDays + 1;
  }
}
