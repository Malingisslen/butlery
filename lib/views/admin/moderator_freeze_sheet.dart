import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/core/utils/snackbar_utils.dart';
import 'package:butlery/models/social/report_evidence.dart';
import 'package:butlery/viewmodels/admin/freeze_result.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/views/admin/moderator_labels.dart';
import 'package:butlery/widgets/common/buttons/action_buttons.dart';
import 'package:butlery/widgets/common/dialogs/dialog_cancel_button.dart';
import 'package:butlery/widgets/common/list/butlery_radio_row.dart';
import 'package:butlery/widgets/common/sheets/butlery_sheet.dart';

/// The moderator picks why a saved copy is kept longer. Resolves to the
/// reason, or null when dismissed. [confirmLabel] names what the button does.
Future<FreezeReason?> showModeratorFreezeSheet(
  BuildContext context, {
  required String confirmLabel,
  FreezeReason? initial,
}) => showButlerySheet<FreezeReason>(
  context: context,
  builder: (_) => ModeratorFreezeSheet(
    confirmLabel: confirmLabel,
    initial: initial,
  ),
);

/// The snackbar for a freeze, extension or release; [retry] repeats the
/// action when it failed outright.
void showFreezeResult(
  BuildContext context,
  FreezeResult result, {
  required VoidCallback retry,
}) {
  final l10n = context.l10n;
  switch (result) {
    case FreezeSucceeded(:final outcome):
      final until = outcome.until;
      SnackBarUtils.showSuccess(
        context,
        until != null
            ? l10n.moderatorFreezeSaved(
                DateFormat.yMMMd(l10n.localeName).format(until.toLocal()),
              )
            : outcome.deleted
            ? l10n.moderatorFrozenReleasedDeleted
            : l10n.moderatorFrozenReleasedKept,
      );
    case FreezeBlocked(:final block):
      SnackBarUtils.showInfo(context, freezeBlockText(l10n, block));
    case FreezeFailed():
      SnackBarUtils.showFailure(
        context,
        what: l10n.moderatorFreezeFailed,
        preserved: l10n.moderatorFreezeFailedKept,
        action: FailureAction.retry(retry),
      );
  }
}

class ModeratorFreezeSheet extends StatefulWidget {
  const ModeratorFreezeSheet({
    required this.confirmLabel,
    this.initial,
    super.key,
  });

  final String confirmLabel;
  final FreezeReason? initial;

  @override
  State<ModeratorFreezeSheet> createState() => _ModeratorFreezeSheetState();
}

class _ModeratorFreezeSheetState extends State<ModeratorFreezeSheet> {
  static const _choices = [
    FreezeReason.police,
    FreezeReason.threat,
    FreezeReason.legalClaim,
  ];

  // No default: keeping a copy for a year needs a reason picked on purpose.
  late FreezeReason? _selected = _choices.contains(widget.initial)
      ? widget.initial
      : null;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final cs = Theme.of(context).colorScheme;
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
          Text(
            l10n.moderatorFreezeSheetTitle,
            style: AppTextStyles.titleMedium,
          ),
          const SizedBox(height: AppDimensions.space4),
          Text(
            l10n.moderatorFreezeSheetHelp,
            style: AppTextStyles.bodySmall.copyWith(
              color: cs.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: AppDimensions.space8),
          Text(l10n.moderatorFreezeChooseReason, style: AppTextStyles.overline),
          RadioGroup<FreezeReason>(
            groupValue: _selected,
            onChanged: (value) {
              if (value != null) setState(() => _selected = value);
            },
            child: Column(
              children: [
                for (final r in _choices)
                  ButleryRadioRow<FreezeReason>(
                    key: ValueKey('freeze-reason-${r.wireName}'),
                    value: r,
                    title: freezeReasonLabel(l10n, r),
                  ),
              ],
            ),
          ),
          const SizedBox(height: AppDimensions.space16),
          ActionButtons.primaryButton(
            context,
            key: const ValueKey('freeze-confirm'),
            label: widget.confirmLabel,
            onPressed: _selected == null
                ? null
                : () => Navigator.pop(context, _selected),
          ),
          const DialogCancelButton(),
        ],
      ),
    );
  }
}
