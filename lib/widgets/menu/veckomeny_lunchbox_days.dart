import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/models/menu/weekly_menu_plan.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/widgets/common/chips/butlery_filter_chip.dart';
import 'package:butlery/widgets/common/section_heading.dart';

/// BUT-2486 part 6: the weekdays the suggested week fills with fridge and
/// freezer boxes, in the week menu's empty state beside the wishes.
class VeckomenyLunchboxDays extends StatelessWidget {
  const VeckomenyLunchboxDays({
    required this.selected,
    required this.onToggle,
    super.key,
  });

  final Set<DayOfWeek> selected;
  final ValueChanged<DayOfWeek> onToggle;

  /// A Monday, so day.index days later is that weekday.
  static final DateTime _aMonday = DateTime(2024, 1, 1);

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final locale = Localizations.localeOf(context).toString();
    final short = DateFormat.E(locale);
    final long = DateFormat.EEEE(locale);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeading(l10n.menuLunchboxDaysTitle),
        Wrap(
          spacing: AppDimensions.space8,
          runSpacing: AppDimensions.space8,
          children: [
            for (final day in DayOfWeek.values)
              Semantics(
                // The chip shows the short name; a screen reader gets the
                // whole weekday, once, on the node that takes the tap.
                label: long.format(_aMonday.add(Duration(days: day.index))),
                button: true,
                selected: selected.contains(day),
                onTap: () => onToggle(day),
                excludeSemantics: true,
                child: ButleryFilterChip(
                  key: ValueKey('lunchbox-day-${day.name}'),
                  label: short.format(_aMonday.add(Duration(days: day.index))),
                  selected: selected.contains(day),
                  onSelected: (_) => onToggle(day),
                ),
              ),
          ],
        ),
        const SizedBox(height: AppDimensions.space8),
        Text(
          l10n.menuLunchboxDaysHint,
          style: AppTextStyles.bodySmall.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}
