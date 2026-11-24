/// The week as a grid: a header naming the meals, then one row per day with
/// the day's name and date and a cell for lunch, middag and övrigt.
///
/// It knows no plan and no view model: the caller builds each cell. The
/// household's week menu, the group's and the placement mode all draw their
/// week through it, so the three share one layout (Malin 2026-10-11: the
/// design system is as modular as it can be).
library;

import 'package:flutter/material.dart';

import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/models/menu/weekly_menu_plan.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/widgets/common/icons/butlery_glyph.dart';
import 'package:butlery/widgets/common/icons/butlery_icons.dart';
import 'package:butlery/widgets/common/press_fill.dart';
import 'package:butlery/widgets/common/section_heading.dart';
import 'package:butlery/widgets/menu/calendar/calendar_slot_cells.dart';

typedef CalendarCellBuilder =
    Widget Function(BuildContext context, DayOfWeek day, MealSlot slot);

/// The column of day names. It follows the text scale up to 1.6 so "I DAG"
/// is never cut, and no further, so the cells keep their room.
double _dayColumnWidth(BuildContext context) {
  final scale = MediaQuery.textScalerOf(context).scale(1).clamp(1.0, 1.6);
  return AppDimensions.space16 * 3 * scale;
}

class CalendarWeekGrid extends StatelessWidget {
  const CalendarWeekGrid({
    super.key,
    required this.weekStart,
    required this.todayIndex,
    required this.cellBuilder,
    this.footer,
    this.onTapDay,
    this.markedDays = const {},
  });

  final DateTime weekStart;

  /// -1 when the shown week is not the current one.
  final int todayIndex;
  final CalendarCellBuilder cellBuilder;
  final Widget? footer;

  /// A tap on a day's name, or null where the days are not tappable.
  final void Function(DayOfWeek day)? onTapDay;

  /// Days a saved weekly rule governs (BUT-2490), drawn with a small mark.
  final Set<DayOfWeek> markedDays;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final dayColumn = _dayColumnWidth(context);
        final cellWidth =
            (constraints.maxWidth -
                dayColumn -
                AppDimensions.space4 * MealSlot.values.length) /
            MealSlot.values.length;
        return CalendarCellWidth(
          width: cellWidth,
          child: _grid(context, dayColumn),
        );
      },
    );
  }

  Widget _grid(BuildContext context, double dayColumn) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _MealHeaderRow(),
        for (final day in DayOfWeek.values)
          Padding(
            padding: const EdgeInsets.only(bottom: AppDimensions.space4),
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                spacing: AppDimensions.space4,
                children: [
                  SizedBox(
                    width: dayColumn,
                    child: _DayLabel(
                      day: day,
                      date: weekStart.add(Duration(days: day.index)),
                      isToday: day.index == todayIndex,
                      hasRule: markedDays.contains(day),
                      onTap: onTapDay == null ? null : () => onTapDay!(day),
                    ),
                  ),
                  for (final slot in MealSlot.values)
                    Expanded(child: cellBuilder(context, day, slot)),
                ],
              ),
            ),
          ),
        ?footer,
      ],
    );
  }
}

class _MealHeaderRow extends StatelessWidget {
  const _MealHeaderRow();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppDimensions.space4),
      child: Row(
        children: [
          SizedBox(width: _dayColumnWidth(context) + AppDimensions.space4),
          for (final slot in MealSlot.values)
            Expanded(
              child: Padding(
                padding: const EdgeInsetsDirectional.only(
                  start: AppDimensions.space8,
                ),
                // One word on one line, scaled down to its column rather
                // than broken in two ("LUNC" / "H").
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: AlignmentDirectional.centerStart,
                  child: SectionHeading(slot.displayLabel),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _DayLabel extends StatelessWidget {
  const _DayLabel({
    required this.day,
    required this.date,
    required this.isToday,
    required this.hasRule,
    required this.onTap,
  });

  final DayOfWeek day;
  final DateTime date;
  final bool isToday;
  final bool hasRule;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final color = isToday ? cs.onSurface : cs.onSurfaceVariant;
    final style = AppTextStyles.overline.copyWith(
      color: color,
      letterSpacing: 1,
    );
    final label = Padding(
      padding: const EdgeInsets.only(top: AppDimensions.space8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(day.displayLabel.toUpperCase(), style: style),
          // The mark sits by the date: the name column is too narrow to share
          // a line between the name and a glyph.
          Row(
            mainAxisSize: MainAxisSize.min,
            spacing: AppDimensions.space4,
            children: [
              Text('${date.day}', style: style.copyWith(letterSpacing: 0)),
              if (hasRule)
                ButleryIcon(
                  ButleryIcons.refreshCw,
                  size: AppDimensions.space12,
                  color: color,
                  semanticLabel: context.l10n.recurringRuleMarkLabel,
                ),
            ],
          ),
          if (isToday)
            Text(
              context.l10n.weeklyMenuTodayBadge.toUpperCase(),
              style: style.copyWith(color: cs.onSecondaryContainer),
            ),
        ],
      ),
    );
    if (onTap == null) return label;
    return Semantics(
      button: true,
      label: context.l10n.recurringRuleMakeFixed,
      child: PressFill(
        surface: PressSurface.base,
        child: InkWell(onTap: onTap, child: label),
      ),
    );
  }
}
