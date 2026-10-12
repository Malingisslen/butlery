import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

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
    final l10n = context.l10n;
    final locale = l10n.localeName;
    final now = clock.now();
    final left = l10n.trashDaysLeft(days);
    final deleted = item.deletedAt.toLocal();
    final today =
        deleted.year == now.year &&
        deleted.month == now.month &&
        deleted.day == now.day;
    return ButleryListRow(
      emphasis: true,
      label: item.title,
      subtitle: urgent
          ? days == 0
                ? l10n.trashUrgentToday(left)
                : l10n.trashUrgentLeft(
                    left,
                    DateFormat.EEEE(locale).format(item.expireAt.toLocal()),
                  )
          : l10n.trashRowDeleted(
              today
                  ? l10n.trashDeletedToday
                  : DateFormat.MMMd(locale).format(deleted),
              left,
            ),
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
