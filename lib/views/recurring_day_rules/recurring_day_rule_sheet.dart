// BUT-2490: the sheet a tapped day in the week menu opens. It only offers the
// way into "Fasta dagar"; the day is carried on so it is already chosen.
library;

import 'dart:async';

import 'package:flutter/material.dart';

import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/models/menu/weekly_menu_plan.dart';
import 'package:butlery/views/recurring_day_rules/recurring_day_rule_editor_view.dart';
import 'package:butlery/widgets/common/list/butlery_list.dart';
import 'package:butlery/widgets/common/list/butlery_list_sheet.dart';

Future<void> showRecurringDayRuleSheet(BuildContext context, DayOfWeek day) {
  final l = context.l10n;
  final navigator = Navigator.of(context);
  return showButleryListSheet<void>(
    context,
    title: l.recurringRuleSheetTitle(l.recurringRuleDayLong(day.name)),
    rows: (sheetContext) => [
      ButleryListRow(
        label: l.recurringRuleMakeFixed,
        onTap: () {
          Navigator.of(sheetContext).pop();
          unawaited(
            navigator.push<void>(
              MaterialPageRoute(
                builder: (_) => RecurringDayRuleEditorView(initialDay: day),
              ),
            ),
          );
        },
      ),
    ],
  );
}
