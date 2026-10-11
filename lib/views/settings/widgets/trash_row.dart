import 'package:clock/clock.dart';
import 'package:flutter/material.dart';

import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/models/trash_item.dart';
import 'package:butlery/theme/app_mode_colors.dart';
import 'package:butlery/viewmodels/trash_viewmodel.dart';
import 'package:butlery/widgets/common/icons/butlery_glyph.dart';
import 'package:butlery/widgets/common/icons/butlery_icons.dart';
import 'package:butlery/widgets/common/list/butlery_list.dart';

/// One trashed recipe as a list row: its title and the days it has left. The
/// row's text already says the days; the warning mark only adds urgency.
class TrashRow extends StatelessWidget {
  const TrashRow({required this.item, required this.onTap, super.key});

  /// Under this many days left the row carries the warning mark.
  static const int warnBelowDays = 3;

  final TrashItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final days = TrashViewModel.daysLeft(item, clock.now());
    final urgent = days < warnBelowDays;
    return ButleryListRow(
      label: item.title,
      subtitle: context.l10n.trashDaysLeft(days),
      onTap: onTap,
      trailing: urgent
          ? ButleryIcon(
              ButleryIcons.clock,
              key: const ValueKey('trashUrgentMark'),
              color: AppModeColors.textWarning(
                Theme.of(context).colorScheme.brightness,
              ),
            )
          : null,
    );
  }
}
