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

  /// A date as content-style-guide.md:25 writes it: "9 juli", with the year
  /// only when it is not this year.
  static String dateLabel(AppLocalizations l, DateTime at, DateTime now) {
    final local = at.toLocal();
    return local.year == now.toLocal().year
        ? DateFormat.MMMMd(l.localeName).format(local)
        : DateFormat.yMMMMd(l.localeName).format(local);
  }
}
