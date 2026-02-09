/// Shared time formatting utility for cooking durations.
///
/// Used by recipe cards and recipe detail metadata
/// for consistent time display with hours conversion.
class TimeFormatUtils {
  TimeFormatUtils._();

  /// Formats cooking time in minutes to a human-readable string.
  /// Returns "X min" for under 60 minutes, "X h" for exact hours,
  /// or "X h Y min" for mixed.
  static String formatCookingTime(int minutes) {
    if (minutes < 60) return '$minutes min';
    final h = minutes ~/ 60;
    final m = minutes % 60;
    return m == 0 ? '$h h' : '$h h $m min';
  }
}
