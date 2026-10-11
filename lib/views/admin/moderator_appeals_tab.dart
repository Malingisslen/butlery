import 'package:butlery/widgets/styled/styled_card.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/core/utils/snackbar_utils.dart';
import 'package:butlery/models/social/content_report.dart';
import 'package:butlery/models/social/moderation_outcome.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/viewmodels/admin/moderator_appeals_viewmodel.dart';
import 'package:butlery/widgets/common/state_widget.dart';
import 'package:butlery/widgets/social/decision_labels.dart';
import 'package:butlery/widgets/social/report_reason_labels.dart';

/// The "Överklaganden" tab: open appeals with the text the person wrote and
/// a "Svara" button.
class ModeratorAppealsTab extends StatelessWidget {
  const ModeratorAppealsTab({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final vm = context.watch<ModeratorAppealsViewModel>();
    if (vm.isLoading && vm.appeals.isEmpty) {
      return StateWidget.loading(message: l10n.loadingReports);
    }
    if (vm.hasError) {
      return StateWidget.error(
        message: l10n.moderatorAppealsLoadFailed,
        onAction: vm.load,
      );
    }
    if (vm.appeals.isEmpty) {
      return Center(
        child: Text(
          l10n.moderatorAppealsEmpty,
          style: AppTextStyles.bodyMedium,
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.all(AppDimensions.paddingM),
      itemCount: vm.appeals.length,
      separatorBuilder: (_, __) => const SizedBox(height: AppDimensions.space4),
      itemBuilder: (_, i) => _AppealCard(appeal: vm.appeals[i]),
    );
  }
}

class _AppealCard extends StatelessWidget {
  const _AppealCard({required this.appeal});

  final OpenAppeal appeal;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final muted = AppTextStyles.bodySmall.copyWith(
      color: Theme.of(context).colorScheme.onSurfaceVariant,
    );
    final type = appeal.contentType;
    final reason = appeal.reason;
    final meta = [
      if (type != null) type.wireName.toUpperCase(),
      if (appeal.contentId != null) appeal.contentId!,
      if (reason != null)
        '${l10n.moderatorReasonLabel}: ${reportReasonDisplay(l10n, reason)}',
    ].join(' · ');
    final decidedAt = appeal.decidedAt;
    final createdAt = appeal.createdAt;
    return StyledCard(
      padding: const EdgeInsets.all(AppDimensions.paddingM),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            appeal.role == AppealRole.owner
                ? l10n.moderatorAppealFromOwner
                : l10n.moderatorAppealFromReporter,
            style: AppTextStyles.bodyMedium,
          ),
          if (meta.isNotEmpty) Text(meta, style: muted),
          Text(
            decidedAt == null
                ? decisionHeadline(l10n, appeal.decision)
                : l10n.moderatorAppealDecisionLine(
                    formatDecisionDate(l10n, decidedAt),
                    decisionHeadline(l10n, appeal.decision),
                  ),
            style: muted,
          ),
          const SizedBox(height: AppDimensions.spacingXs),
          // Untrusted user text: plain Text only.
          Text(appeal.text, style: AppTextStyles.bodyMedium),
          if (createdAt != null)
            Text(
              l10n.moderatorAppealReceived(
                formatDecisionDate(l10n, createdAt),
              ),
              style: muted,
            ),
          const SizedBox(height: AppDimensions.spacingSm),
          OutlinedButton(
            onPressed: () => _answer(context),
            child: Text(l10n.moderatorAppealAnswerButton),
          ),
        ],
      ),
    );
  }

  Future<void> _answer(BuildContext context) async {
    final vm = context.read<ModeratorAppealsViewModel>();
    final outcome = await showModalBottomSheet<AppealStatus>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      builder: (_) => AppealAnswerSheet(appeal: appeal),
    );
    if (outcome == null || !context.mounted) return;
    final l10n = context.l10n;
    final result = await vm.answer(appeal, outcome);
    if (!context.mounted) return;
    switch (result) {
      case AppealAnswerOutcome.answered:
        SnackBarUtils.showSuccess(context, l10n.moderatorAnswerSent);
        return;
      case AppealAnswerOutcome.alreadyAnswered:
        SnackBarUtils.showInfo(context, l10n.moderatorAppealAlreadyAnswered);
        return;
      case AppealAnswerOutcome.failed:
        break;
    }
    SnackBarUtils.showFailure(
      context,
      what: l10n.moderatorAnswerFailed,
      preserved: l10n.moderatorAnswerUnchanged,
      action: FailureAction.retry(() => _answer(context)),
    );
  }
}

/// "Svara på överklagan": upheld or reversed, with the fixed answer text.
class AppealAnswerSheet extends StatefulWidget {
  const AppealAnswerSheet({required this.appeal, super.key});

  final OpenAppeal appeal;

  @override
  State<AppealAnswerSheet> createState() => _AppealAnswerSheetState();
}

class _AppealAnswerSheetState extends State<AppealAnswerSheet> {
  AppealStatus _choice = AppealStatus.upheld;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final cs = Theme.of(context).colorScheme;
    final removed =
        widget.appeal.role == AppealRole.owner &&
        widget.appeal.decision == ModeratorDecision.contentRemoved;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(
        AppDimensions.paddingM,
        0,
        AppDimensions.paddingM,
        AppDimensions.paddingM,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(l10n.moderatorAnswerTitle, style: AppTextStyles.titleMedium),
          RadioGroup<AppealStatus>(
            groupValue: _choice,
            onChanged: (v) {
              if (v != null) setState(() => _choice = v);
            },
            child: Column(
              children: [
                _option(
                  AppealStatus.upheld,
                  l10n.appealAnswerUpheldHeadline,
                  l10n.appealAnswerUpheldBody,
                ),
                _option(
                  AppealStatus.reversed,
                  l10n.appealAnswerReversedHeadline,
                  l10n.appealAnswerReversedBody,
                ),
              ],
            ),
          ),
          if (_choice == AppealStatus.reversed && removed)
            Container(
              padding: const EdgeInsets.all(AppDimensions.paddingM),
              color: cs.secondaryContainer,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.moderatorAnswerNoteTitle,
                    style: AppTextStyles.titleSmall,
                  ),
                  Text(
                    l10n.moderatorAnswerNoteBody,
                    style: AppTextStyles.bodySmall,
                  ),
                ],
              ),
            ),
          const SizedBox(height: AppDimensions.spacingMd),
          FilledButton(
            onPressed: () => Navigator.pop(context, _choice),
            child: Text(l10n.moderatorAnswerSubmit),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.commonCancel),
          ),
        ],
      ),
    );
  }

  Widget _option(AppealStatus value, String title, String body) =>
      RadioListTile<AppealStatus>(
        key: ValueKey('answer-${value.wireName}'),
        value: value,
        contentPadding: EdgeInsets.zero,
        title: Text(title, style: AppTextStyles.titleSmall),
        subtitle: Text(body, style: AppTextStyles.bodySmall),
      );
}
