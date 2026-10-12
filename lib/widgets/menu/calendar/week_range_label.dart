/// "13 apr–19 apr": the date range under a week's number.
library;

import 'package:flutter/widgets.dart';

import 'package:butlery/core/extensions/localization_extension.dart';

const List<String> _months = [
  'jan',
  'feb',
  'mar',
  'apr',
  'maj',
  'jun',
  'jul',
  'aug',
  'sep',
  'okt',
  'nov',
  'dec',
];

String _dayMonth(DateTime date) => '${date.day} ${_months[date.month - 1]}';

String formatWeekRange(BuildContext context, DateTime weekStart) {
  final weekEnd = weekStart.add(const Duration(days: 6));
  return context.l10n.weeklyMenuWeekRange(
    _dayMonth(weekStart),
    _dayMonth(weekEnd),
  );
}
