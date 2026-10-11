import 'package:flutter/material.dart';

import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/models/social/content_report.dart';
import 'package:butlery/models/social/moderation_motivation.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/widgets/social/decision_labels.dart';
import 'package:butlery/widgets/common/dialogs/dialog_cancel_button.dart';
import 'package:butlery/widgets/common/sheets/butlery_sheet.dart';

/// "Stäng och meddela": the moderator picks one ready-made motivation for
/// [decision]. Resolves to the chosen key, or null when dismissed.
Future<ModerationMotivation?> showModeratorCloseSheet(
  BuildContext context, {
  required ModeratorDecision decision,
}) => showButlerySheet<ModerationMotivation>(
  context: context,
  builder: (_) => ModeratorCloseSheet(decision: decision),
);

class ModeratorCloseSheet extends StatefulWidget {
  const ModeratorCloseSheet({required this.decision, super.key});

  final ModeratorDecision decision;

  @override
  State<ModeratorCloseSheet> createState() => _ModeratorCloseSheetState();
}

class _ModeratorCloseSheetState extends State<ModeratorCloseSheet> {
  late ModerationMotivation _selected = ModerationMotivation.defaultFor(
    widget.decision,
  );

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final cs = Theme.of(context).colorScheme;
    final headline = decisionHeadline(l10n, widget.decision);
    final choices = ModerationMotivation.choicesFor(widget.decision);
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        AppDimensions.space12,
        0,
        AppDimensions.space12,
        AppDimensions.space12 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(l10n.moderatorCloseSheetTitle, style: AppTextStyles.titleMedium),
          const SizedBox(height: AppDimensions.space4),
          Text(
            l10n.moderatorCloseSheetDecision(headline),
            style: AppTextStyles.bodySmall.copyWith(
              color: cs.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: AppDimensions.space8),
          Text(l10n.moderatorCloseChoose, style: AppTextStyles.overline),
          RadioGroup<ModerationMotivation>(
            groupValue: _selected,
            onChanged: (value) {
              if (value != null) setState(() => _selected = value);
            },
            child: Column(
              children: [
                for (final m in choices)
                  RadioListTile<ModerationMotivation>(
                    key: ValueKey('motivation-${m.wireName}'),
                    value: m,
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      motivationText(l10n, m),
                      style: AppTextStyles.bodyMedium,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: AppDimensions.space8),
          Container(
            padding: const EdgeInsets.all(AppDimensions.space12),
            color: cs.secondaryContainer,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.moderatorClosePreviewTitle,
                  style: AppTextStyles.titleSmall,
                ),
                Text(
                  l10n.moderatorClosePreviewReporter(headline),
                  style: AppTextStyles.bodySmall,
                ),
                Text(
                  widget.decision == ModeratorDecision.noAction
                      ? l10n.moderatorClosePreviewOwnerNone
                      : l10n.moderatorClosePreviewOwner(headline),
                  style: AppTextStyles.bodySmall,
                ),
              ],
            ),
          ),
          const SizedBox(height: AppDimensions.space16),
          FilledButton(
            onPressed: () => Navigator.pop(context, _selected),
            child: Text(l10n.moderatorCloseSheetTitle),
          ),
          const DialogCancelButton(),
        ],
      ),
    );
  }
}
