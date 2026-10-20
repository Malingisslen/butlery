import 'package:flutter/material.dart';

import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/core/utils/contextual_time_formatter.dart';
import 'package:butlery/models/social/closed_report.dart';
import 'package:butlery/models/social/content_report.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/views/admin/moderator_labels.dart';
import 'package:butlery/widgets/common/buttons/action_buttons.dart';
import 'package:butlery/widgets/common/icons/butlery_icons.dart';
import 'package:butlery/widgets/common/layout/tinted_note.dart';
import 'package:butlery/widgets/common/list/butlery_list.dart';

/// "Beslut": one decided report. Pops with true when the moderator asks to
/// open it again; the caller confirms and does it.
class ModeratorClosedSheet extends StatelessWidget {
  const ModeratorClosedSheet({required this.report, super.key});

  final ClosedReport report;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final cs = Theme.of(context).colorScheme;
    final block = report.reopenBlock;
    final type = report.contentType;
    final decidedAt = report.decidedAt;
    final band = block != null
        ? reopenBlockText(l10n, block)
        : report.decision == ModeratorDecision.contentRemoved
        ? l10n.moderatorClosedRemovedBand
        : null;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(
        AppDimensions.space16,
        0,
        AppDimensions.space16,
        AppDimensions.space16,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            l10n.moderatorClosedSheetTitle,
            style: AppTextStyles.titleMedium,
          ),
          ButleryListSection(
            rows: [
              ButleryListRow.info(
                label: l10n.moderatorClosedRowDecision,
                value: moderatorDecisionLabel(l10n, report.decision),
              ),
              if (report.rule != null)
                ButleryListRow.info(
                  label: l10n.moderatorClosedRowRule,
                  value: moderatorReasonLabel(l10n, report.rule!),
                ),
              if (type != null)
                ButleryListRow.info(
                  label: l10n.moderatorClosedRowAbout,
                  value: moderatorContentTypeLabel(l10n, type),
                ),
              if (decidedAt != null)
                ButleryListRow.info(
                  label: l10n.moderatorClosedRowDecided,
                  value: ContextualTimeFormatter.dateTime(
                    decidedAt.toLocal(),
                    localeName: l10n.localeName,
                  ),
                ),
              ButleryListRow.info(
                label: l10n.moderatorClosedRowModerator,
                value: decisionMakerLabel(l10n, report.moderator),
              ),
            ],
          ),
          if (report.history.isNotEmpty)
            ButleryListSection(
              title: l10n.moderatorClosedHistoryTitle,
              rows: [
                for (final past in report.history.reversed)
                  ButleryListRow.note(
                    label: moderatorDecisionLabel(l10n, past.decision),
                    subtitle: pastDecisionLine(l10n, past),
                    leading: ButleryIcons.history,
                  ),
              ],
            ),
          const SizedBox(height: AppDimensions.space12),
          if (block == null)
            Text(
              l10n.moderatorClosedNote,
              style: AppTextStyles.captionBase.copyWith(
                color: cs.onSurfaceVariant,
              ),
            ),
          if (band != null) ...[
            const SizedBox(height: AppDimensions.space8),
            TintedNote(
              key: const ValueKey('closed-sheet-band'),
              child: Text(band, style: TintedNote.textStyle(context)),
            ),
          ],
          const SizedBox(height: AppDimensions.space16),
          ActionButtons.primaryButton(
            context,
            key: const ValueKey('closed-sheet-reopen'),
            label: l10n.moderatorClosedReopen,
            isExpanded: true,
            onPressed: block == null
                ? () => Navigator.of(context).pop(true)
                : null,
          ),
          const SizedBox(height: AppDimensions.space8),
          ActionButtons.textButton(
            context,
            label: l10n.commonClose,
            isExpanded: true,
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }
}
