/// BUT-961: context-aware time formatter that codifies the three intentional
/// styles in use across the app and auto-switches to absolute date once
/// content ages past the 7-day relative-time window.
///
/// The app uses three time-rendering styles by design:
///
/// - **compact** ("2d", "5min") — tight UI surfaces (list rows,
///   notifications, cook-snap badges, conversation last-activity timestamp).
/// - **standard** ("2 days ago", "Now") — body text where readability
///   matters (comments, friend requests, shared content cards).
/// - **dateTime** ("May 22, 2026 3:45 PM") — permanent records where
///   exactness matters more than relativeness (group creation date,
///   admin reports).
///
/// Per ticket recommendation, all three styles auto-promote to absolute
/// date when the input is older than [_relativeWindow] — past that point,
/// "12 days ago" / "2v" / "Dec 12" all become equally unhelpful and the
/// full timestamp is what the user actually wants. The promoted format
/// is `yMMMd` (no time-of-day) for compact + standard; dateTime retains
/// its full `yMMMd().add_Hm()` form throughout.
///
/// Migration policy: existing TimeAgoFormatter / DateFormat call sites
/// stay as they are — they're contextually correct, just inconsistent
/// in window-promotion. New code should reach for this helper; existing
/// sites migrate as they're touched.
library;

import 'package:clock/clock.dart';
import 'package:intl/intl.dart';
import 'package:butlery/core/utils/time_ago_formatter.dart';

class ContextualTimeFormatter {
  const ContextualTimeFormatter._();

  /// After this much time has passed, relative-time formats become
  /// unhelpful and we switch to an absolute date instead.
  static const Duration _relativeWindow = Duration(days: 7);

  /// Compact form (e.g. "5min", "2d"). Past [_relativeWindow] → "May 22".
  static String compact(DateTime dateTime, {String? localeName}) {
    if (_isStale(dateTime)) {
      return DateFormat.MMMd(localeName).format(dateTime);
    }
    return TimeAgoFormatter.compact(dateTime);
  }

  /// Standard form (e.g. "5 min sedan", "2 days ago"). Past [_relativeWindow]
  /// → "May 22, 2026".
  static String standard(DateTime dateTime, {String? localeName}) {
    if (_isStale(dateTime)) {
      return DateFormat.yMMMd(localeName).format(dateTime);
    }
    return TimeAgoFormatter.standard(dateTime);
  }

  /// Always-absolute date+time form. Use for permanent records (group
  /// creation date, admin reports) where exactness matters more than
  /// "how long ago".
  static String dateTime(DateTime dateTime, {String? localeName}) {
    return DateFormat.yMMMd(localeName).add_Hm().format(dateTime);
  }

  static bool _isStale(DateTime dateTime) =>
      clock.now().difference(dateTime).abs() > _relativeWindow;
}
