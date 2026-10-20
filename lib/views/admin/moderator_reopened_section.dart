import 'package:flutter/material.dart';

import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/core/utils/captured_snackbars.dart';
import 'package:butlery/core/utils/snackbar_utils.dart';
import 'package:butlery/l10n/app_localizations.dart';
import 'package:butlery/models/social/content_report.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/viewmodels/admin/moderator_review_viewmodel.dart';
import 'package:butlery/views/admin/moderator_labels.dart';
import 'package:butlery/widgets/common/badges/unified_badge.dart';
import 'package:butlery/widgets/common/buttons/action_buttons.dart';
import 'package:butlery/widgets/common/dialogs/confirmation_dialogs.dart';

/// "Öppnad igen" on a queue card.
class ReopenedPill extends StatelessWidget {
  const ReopenedPill({super.key});

  @override
  Widget build(BuildContext context) => UnifiedBadge.status(
    label: context.l10n.moderatorReopenedPill,
    tone: BadgeTone.warning,
  );
}

/// "Tidigare beslut: Profilen dold": the decision that stands until the
/// moderator decides again.
class PreviousDecisionLine extends StatelessWidget {
  const PreviousDecisionLine({
    required this.decision,
    super.key,
  });

  final ModeratorDecision decision;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Padding(
      padding: const EdgeInsets.only(top: AppDimensions.space4),
      child: Text(
        l10n.moderatorPreviousDecision(moderatorDecisionLabel(l10n, decision)),
        style: AppTextStyles.bodyMedium.copyWith(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

/// "Behåll beslutet" and "Ändra till Ingen åtgärd" for a reopened report
/// whose action still stands.
class ReopenedActions extends StatelessWidget {
  const ReopenedActions({
    required this.report,
    required this.vm,
    super.key,
  });

  final ContentReport report;
  final ModeratorReviewViewModel vm;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: AppDimensions.space8,
      children: [
        ActionButtons.primaryButton(
          context,
          key: const ValueKey('reopened-keep'),
          label: l10n.moderatorKeepDecision,
          isExpanded: true,
          onPressed: () => _keep(context),
        ),
        ActionButtons.outlinedButton(
          context,
          key: const ValueKey('reopened-change'),
          label: l10n.moderatorChangeToNoAction,
          isExpanded: true,
          onPressed: () => _confirmChange(context),
        ),
      ],
    );
  }

  // The snackbars are captured before the write: closing the report takes
  // its card off the queue, and the card's context with it.
  Future<void> _keep(BuildContext context) async {
    if (!context.mounted) return;
    final snacks = CapturedSnackBars.capture(context);
    final l10n = context.l10n;
    if (await vm.keepDecision(report)) {
      snacks.showConfirmation(l10n.moderatorDecisionKept);
      return;
    }
    _failed(snacks, l10n, () => _keep(context));
  }

  Future<void> _confirmChange(BuildContext context) async {
    final l10n = context.l10n;
    final removed = report.moderatorAction == ModeratorDecision.contentRemoved;
    final confirmed = await ConfirmationDialogs.showConfirmationDialog(
      context,
      title: l10n.moderatorChangeConfirmTitle,
      message: removed
          ? l10n.moderatorChangeConfirmBodyRemoved
          : l10n.moderatorChangeConfirmBodyProfile,
      confirmText: l10n.moderatorChangeConfirm,
      cancelText: l10n.commonCancel,
    );
    if (!confirmed || !context.mounted) return;
    await _change(context);
  }

  Future<void> _change(BuildContext context) async {
    if (!context.mounted) return;
    final snacks = CapturedSnackBars.capture(context);
    final l10n = context.l10n;
    if (await vm.changeToNoAction(report)) {
      snacks.showConfirmation(l10n.moderatorDecisionChanged);
      return;
    }
    _failed(snacks, l10n, () => _change(context));
  }

  void _failed(
    CapturedSnackBars snacks,
    AppLocalizations l10n,
    VoidCallback retry,
  ) {
    snacks.showFailure(
      what: l10n.moderatorCloseFailed,
      preserved: l10n.moderatorReportUnchanged,
      action: FailureAction.retry(retry),
    );
  }
}
