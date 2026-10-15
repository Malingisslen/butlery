/// The dishes of one place in the group's week, opened from a tap on its
/// cell: who proposed each, who voted it in, and, for an editor, its removal.
///
/// The grid shows only the name. The voters' names are one tap away here, which
/// is what Malin's Art. 15 decision to export other members' voter uids rests
/// on (BUT-1971): the app must actually show them.
library;

import 'package:flutter/material.dart';
import 'package:butlery/widgets/common/buttons/butlery_text_button.dart';

import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/models/menu/group_weekly_menu_plan.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/viewmodels/menu/group_weekly_menu_viewmodel.dart';
import 'package:butlery/widgets/common/icons/butlery_glyph.dart';
import 'package:butlery/widgets/common/icons/butlery_icons.dart';
import 'package:butlery/widgets/common/sheets/butlery_sheet.dart';

Future<void> showGroupDishSheet({
  required BuildContext context,
  required GroupWeeklyMenuViewModel vm,
  required DayOfWeek day,
  required MealSlot slot,
  required Future<void> Function(String entryId) onRemove,
}) {
  return showButlerySheet<void>(
    context: context,
    builder: (sheetContext) => SafeArea(
      child: ListenableBuilder(
        listenable: vm,
        builder: (_, _) {
          final entries = [
            for (final e in vm.entriesFor(day))
              if (e.slot == slot) e,
          ];
          return ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.fromLTRB(
              AppDimensions.space16,
              0,
              AppDimensions.space16,
              AppDimensions.space16,
            ),
            children: [
              for (final entry in entries)
                _DishBlock(
                  vm: vm,
                  entry: entry,
                  day: day,
                  onRemove: (id) async {
                    Navigator.of(sheetContext).pop();
                    await onRemove(id);
                  },
                ),
            ],
          );
        },
      ),
    ),
  );
}

class _DishBlock extends StatelessWidget {
  const _DishBlock({
    required this.vm,
    required this.entry,
    required this.day,
    required this.onRemove,
  });

  final GroupWeeklyMenuViewModel vm;
  final WeeklyMenuPlanEntry entry;
  final DayOfWeek day;
  final Future<void> Function(String entryId) onRemove;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final cs = Theme.of(context).colorScheme;
    final muted = AppTextStyles.bodySmall.copyWith(color: cs.onSurfaceVariant);
    final proposer = entry.proposedBy == null
        ? null
        : vm.displayNameFor(entry.proposedBy!);
    final voters = entry.votedInBy;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppDimensions.space16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            entry.recipeTitle,
            style: AppTextStyles.titleBold.copyWith(color: cs.onSurface),
          ),
          Text(
            '${day.displayLabel} · ${entry.slot.displayLabel}',
            style: muted,
          ),
          // A uid is never rendered; an unresolved profile drops the half it
          // names, the vote count is still true.
          if (proposer != null && proposer.trim().isNotEmpty)
            Text(l10n.groupMenuProposedBy(proposer), style: muted),
          if (voters.isNotEmpty) ...[
            const SizedBox(height: AppDimensions.space8),
            Text(
              l10n.groupMenuVotersTitle,
              style: AppTextStyles.labelLargeBold,
            ),
            for (final voter in voters)
              Padding(
                key: ValueKey(voter),
                padding: const EdgeInsets.symmetric(
                  vertical: AppDimensions.space4,
                ),
                child: Row(
                  children: [
                    const ButleryIcon(ButleryIcons.vote),
                    const SizedBox(width: AppDimensions.space8),
                    Expanded(
                      child: Text(
                        _voterName(l10n.groupMenuUnknownVoter, voter),
                        style: AppTextStyles.bodyMedium,
                      ),
                    ),
                  ],
                ),
              ),
          ],
          if (vm.canEdit)
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: ButleryTextButton(
                key: ValueKey('group-menu-remove-${entry.id}'),
                label: l10n.commonRemove,
                icon: ButleryIcons.x,
                onPressed: () => onRemove(entry.id),
              ),
            ),
        ],
      ),
    );
  }

  String _voterName(String fallback, String voter) {
    final name = vm.displayNameFor(voter);
    return name == null || name.trim().isEmpty ? fallback : name;
  }
}
