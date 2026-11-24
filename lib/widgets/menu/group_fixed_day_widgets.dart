// BUT-2490: what a group's fixed days add to the group week: the band that
// opens the rule list, and the cell that says what an empty day is meant to be.
library;

import 'package:flutter/material.dart';

import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/models/menu/recurring_day_rule.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/viewmodels/menu/group_weekly_menu_viewmodel.dart';
import 'package:butlery/viewmodels/recurring_day_rules/recurring_day_rule_store.dart';
import 'package:butlery/views/recurring_day_rules/recurring_day_rules_view.dart';
import 'package:butlery/widgets/common/icons/butlery_icons.dart';
import 'package:butlery/widgets/common/layout/word_fit.dart';
import 'package:butlery/widgets/common/list/butlery_list.dart';
import 'package:butlery/widgets/common/press_fill.dart';
import 'package:butlery/widgets/menu/calendar/calendar_slot_cells.dart';

/// The "Fasta dagar" row under the face row. A member sees it only when the
/// group has rules; an admin always, so the first one can be added.
class GroupRulesBand extends StatelessWidget {
  const GroupRulesBand({
    super.key,
    required this.vm,
    required this.chatGroupId,
    required this.groupName,
  });

  final GroupWeeklyMenuViewModel vm;
  final String chatGroupId;
  final String groupName;

  @override
  Widget build(BuildContext context) {
    final rules = vm.rules;
    if (!rules.active) return const SizedBox.shrink();
    final count = rules.rules.length;
    if (count == 0 && !rules.isGroupAdmin(vm.currentUserId)) {
      return const SizedBox.shrink();
    }
    final l = context.l10n;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppDimensions.space8),
      child: ButleryListRow(
        label: l.recurringRulesTitle,
        leading: ButleryIcons.refreshCw,
        count: count,
        countLabel: l.recurringRulesBandCount(count),
        onTap: () => Navigator.of(context).push<void>(
          MaterialPageRoute(
            builder: (_) => RecurringDayRulesView(
              scope: RecurringRuleScope.group(
                chatGroupId: chatGroupId,
                groupName: groupName,
                group: rules.group,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// "Tacos", "Snabbt" or "Tacos · snabbt": what the rule asks for.
String fixedDayKindLabel(BuildContext context, RecurringDayRule rule) {
  final l = context.l10n;
  final food = rule.food;
  if (food == null) return l.recurringRuleQuickShort;
  final name = l.recurringRuleFoodLabel(food.name);
  return rule.quick
      ? '$name · ${l.recurringRuleQuickShort.toLowerCase()}'
      : name;
}

/// An empty lunch or middag place a rule governs. Tappable only where
/// [onTap] is given; otherwise it just says what is expected.
class GroupFixedDayCell extends StatelessWidget {
  const GroupFixedDayCell({super.key, required this.rule, this.onTap});

  final RecurringDayRule rule;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final cellWidth = CalendarCellWidth.maybeOf(context);
    final text = WholeWordText(
      context.l10n.groupMenuFixedDayCell(fixedDayKindLabel(context, rule)),
      style: AppTextStyles.calendarCell.copyWith(
        color: cs.onSurfaceVariant,
        height: 1.15,
      ),
      width: cellWidth == null ? null : cellWidth - kCalendarCellChrome,
    );
    final frame = CalendarCellFrame(
      child: Align(
        alignment: AlignmentDirectional.centerStart,
        child: text,
      ),
    );
    final tap = onTap;
    if (tap == null) return frame;
    return Semantics(
      button: true,
      label: context.l10n.a11yGroupMenuPickFixedDay,
      child: Material(
        type: MaterialType.transparency,
        child: PressFill(
          surface: PressSurface.base,
          child: InkWell(
            borderRadius: BorderRadius.circular(AppDimensions.radiusControl),
            onTap: tap,
            child: frame,
          ),
        ),
      ),
    );
  }
}
