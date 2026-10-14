import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:butlery/l10n/app_localizations.dart';

/// Times and dates as content-style-guide.md:20-36 writes them, shared by every
/// surface that says when something was kept: "i dag 14:02", "i går", then
/// "9 juli" (with the year when it is not this year). "nu" and "5 min sedan"
/// are not used, because "Din version från nu" is not Swedish.
abstract final class ContentTimeLabels {
  static String whenLabel(AppLocalizations l, DateTime at, DateTime now) {
    final local = at.toLocal();
    final today = DateUtils.dateOnly(now.toLocal());
    final day = DateUtils.dateOnly(local);
    if (day == today) {
      return l.overwrittenWhenToday(DateFormat.Hm(l.localeName).format(local));
    }
    if (day == today.subtract(const Duration(days: 1))) {
      return l.overwrittenWhenYesterday;
    }
    return dateLabel(l, at, now);
  }

  /// "i dag", "i går", "2 dagar sedan" and "3 dagar sedan", then the date: relative time
  /// stops after three days because "3 veckor sedan" says less than "9 juli".
  static String relativeDayLabel(
    AppLocalizations l,
    DateTime at,
    DateTime now,
  ) {
    final nowLocal = now.toLocal();
    final atLocal = at.toLocal();
    // Calendar days, not a Duration between local midnights: that is 23 h across DST.
    final days = DateTime.utc(
      nowLocal.year,
      nowLocal.month,
      nowLocal.day,
    ).difference(DateTime.utc(atLocal.year, atLocal.month, atLocal.day)).inDays;
    if (days <= 0) return l.dateToday;
    if (days == 1) return l.dateYesterday;
    if (days <= 3) return l.dateDaysAgo(days);
    return dateLabel(l, at, now);
  }

  /// A date as content-style-guide.md:25 writes it: "9 juli", with the year
  /// only when it is not this year.
  static String dateLabel(AppLocalizations l, DateTime at, DateTime now) {
    final local = at.toLocal();
    return local.year == now.toLocal().year
        ? DateFormat.MMMMd(l.localeName).format(local)
        : DateFormat.yMMMMd(l.localeName).format(local);
  }
}
