import 'package:butlery/core/l10n/app_locale.dart';

/// Shared time-ago formatting utility using AppLocale for localized output.
/// Eliminates duplicated timeAgoText patterns across 6+ models.
class TimeAgoFormatter {
  /// Standard abbreviated format: 'Nu', '5 min sedan', '2 tim sedan'
  static String standard(DateTime dateTime) {
    final difference = DateTime.now().difference(dateTime);
    final l = AppLocale.current;

    if (difference.inMinutes < 1) {
      return l.timeAgoNow;
    } else if (difference.inHours < 1) {
      return l.timeAgoMinutesAbbr(difference.inMinutes);
    } else if (difference.inDays < 1) {
      return l.timeAgoHoursAbbr(difference.inHours);
    } else if (difference.inDays < 7) {
      return l.timeAgoDays(difference.inDays);
    } else {
      return l.timeAgoWeeks((difference.inDays / 7).floor());
    }
  }

  /// Verbose format used by activity feeds: 'Nyss', '5 minuter sedan'
  static String verbose(DateTime dateTime) {
    final difference = DateTime.now().difference(dateTime);
    final l = AppLocale.current;

    if (difference.inDays > 7) {
      return '${dateTime.day}/${dateTime.month}';
    } else if (difference.inDays > 0) {
      return l.timeAgoDays(difference.inDays);
    } else if (difference.inHours > 0) {
      return l.timeAgoHoursFull(difference.inHours);
    } else if (difference.inMinutes > 0) {
      return l.timeAgoMinutesFull(difference.inMinutes);
    } else {
      return l.timeAgoJustNow;
    }
  }

  /// Compact format for conversation lists: 'Nu', '5m', '2h', '3d', '1w', '2mån'
  static String compact(DateTime dateTime) {
    final difference = DateTime.now().difference(dateTime);
    final l = AppLocale.current;

    if (difference.inMinutes < 1) {
      return l.timeAgoNow;
    } else if (difference.inHours < 1) {
      return l.timeCompactMinutes(difference.inMinutes);
    } else if (difference.inDays < 1) {
      return l.timeCompactHours(difference.inHours);
    } else if (difference.inDays < 30) {
      return l.timeCompactDays(difference.inDays);
    } else {
      return l.timeCompactMonths((difference.inDays / 30).floor());
    }
  }
}
