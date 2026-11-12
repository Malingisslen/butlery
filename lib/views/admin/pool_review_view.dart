import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:butlery/core/extensions/default_value_extensions.dart';
import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/core/utils/snackbar_utils.dart';
import 'package:butlery/l10n/app_localizations.dart';
import 'package:butlery/models/admin/pool_inspection.dart';
import 'package:butlery/services/moderation/pool_moderation_service.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/viewmodels/admin/pool_review_viewmodel.dart';
import 'package:butlery/views/admin/widgets/admin_stat_card.dart';
import 'package:butlery/views/admin/widgets/admin_tab_header.dart';
import 'package:butlery/widgets/common/buttons/action_buttons.dart';
import 'package:butlery/widgets/common/dialogs/confirmation_dialogs.dart';
import 'package:butlery/widgets/common/feedback/inline_error.dart';
import 'package:butlery/widgets/common/input/styled_input.dart';
import 'package:butlery/widgets/common/list/butlery_item_row.dart';
import 'package:butlery/widgets/common/sheets/butlery_sheet.dart';
import 'package:butlery/widgets/common/state_widget.dart';

/// Admin "Betyg" tab (BUT-1517): the numbers behind one pooled rating and the
/// emergency stop for it. [initialPoolKey] is filled in when the tab is opened
/// from an anomaly warning, and is looked up at once.
class PoolReviewView extends StatefulWidget {
  const PoolReviewView({super.key, this.initialPoolKey, this.viewModel});

  final String? initialPoolKey;

  /// Injected by tests; the tab builds its own otherwise.
  final PoolReviewViewModel? viewModel;

  @override
  State<PoolReviewView> createState() => _PoolReviewViewState();
}

class _PoolReviewViewState extends State<PoolReviewView> {
  late final PoolReviewViewModel _vm;
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _vm =
        widget.viewModel ??
        PoolReviewViewModel(
          service: ServiceLocator.get<PoolModerationService>(),
        );
    _controller = TextEditingController(text: widget.initialPoolKey.orEmpty());
    if (widget.initialPoolKey != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _vm.load(_controller.text);
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _vm.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<PoolReviewViewModel>.value(
      value: _vm,
      child: _PoolReviewContent(controller: _controller),
    );
  }
}

class _PoolReviewContent extends StatelessWidget {
  const _PoolReviewContent({required this.controller});

  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final vm = context.watch<PoolReviewViewModel>();
    final inspection = vm.inspection;
    final failure = vm.failure;
    return AdminTabPage(
      title: l10n.adminPoolTitle,
      body: ListView(
        padding: const EdgeInsets.all(AppDimensions.space16),
        children: [
          Text(
            l10n.adminPoolIntro,
            style: AppTextStyles.bodySmall.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: AppDimensions.space12),
          StyledInput(
            controller: controller,
            label: l10n.adminPoolKeyLabel,
            errorText: failure == PoolModerationFailure.invalidKey
                ? l10n.adminPoolInvalidKey
                : null,
            autocorrect: false,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => vm.load(controller.text),
          ),
          const SizedBox(height: AppDimensions.space12),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: ActionButtons.primaryButton(
              context,
              label: l10n.adminPoolShow,
              isLoading: vm.isLoading,
              onPressed: vm.isLoading || vm.isChanging
                  ? null
                  : () => vm.load(controller.text),
            ),
          ),
          const SizedBox(height: AppDimensions.space24),
          if (vm.isLoading && inspection == null)
            StateWidget.loading(message: l10n.adminPoolLoading)
          else if (failure != null &&
              failure != PoolModerationFailure.invalidKey)
            Padding(
              padding: const EdgeInsets.only(bottom: AppDimensions.space16),
              child: InlineError(
                what: _failureText(l10n, failure, inspection != null),
              ),
            ),
          if (inspection != null) _Inspection(inspection: inspection),
        ],
      ),
    );
  }

  String _failureText(
    AppLocalizations l10n,
    PoolModerationFailure failure,
    bool afterChange,
  ) => switch (failure) {
    PoolModerationFailure.notAllowed => l10n.adminPoolNotAllowed,
    PoolModerationFailure.rateLimited => l10n.adminPoolRateLimited,
    _ => afterChange ? l10n.adminPoolChangeFailed : l10n.adminPoolLoadFailed,
  };
}

class _Inspection extends StatelessWidget {
  const _Inspection({required this.inspection});

  final PoolInspection inspection;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final vm = context.read<PoolReviewViewModel>();
    final cs = Theme.of(context).colorScheme;
    final average = inspection.average;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          inspection.quarantined
              ? l10n.adminPoolStateQuarantined
              : l10n.adminPoolStateActive,
          style: AppTextStyles.titleMedium.copyWith(
            color: inspection.quarantined ? cs.error : cs.onSurface,
          ),
        ),
        if (inspection.quarantined && inspection.reason != null)
          Text(
            l10n.adminPoolReason(_reasonLabel(l10n, inspection.reason!)),
            style: AppTextStyles.bodyMedium,
          ),
        const SizedBox(height: AppDimensions.space16),
        Wrap(
          spacing: AppDimensions.space12,
          runSpacing: AppDimensions.space12,
          children: [
            _card(l10n.adminPoolVotes, '${inspection.count}'),
            _card(
              l10n.adminPoolAverage,
              average == null ? '–' : average.toStringAsFixed(2),
            ),
            _card(l10n.adminPoolVotes24h, '${inspection.votes24h}'),
            _card(l10n.adminPoolVotes7d, '${inspection.votes7d}'),
          ],
        ),
        const SizedBox(height: AppDimensions.space16),
        Text(l10n.adminPoolDistribution, style: AppTextStyles.titleSmall),
        const SizedBox(height: AppDimensions.space8),
        for (var star = 5; star >= 1; star--)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: AppDimensions.space4),
            child: Row(
              key: ValueKey('pool-stars-$star'),
              children: [
                Expanded(
                  child: Text(
                    l10n.adminPoolStarsRow(star),
                    style: AppTextStyles.bodyMedium,
                  ),
                ),
                Text(
                  '${inspection.distribution[star - 1]}',
                  style: AppTextStyles.bodyMedium,
                ),
              ],
            ),
          ),
        const SizedBox(height: AppDimensions.space16),
        ..._shares(l10n),
        const SizedBox(height: AppDimensions.space24),
        if (inspection.quarantined)
          ActionButtons.primaryButton(
            context,
            key: const ValueKey('pool-lift'),
            label: l10n.adminPoolLift,
            isLoading: vm.isChanging,
            onPressed: vm.isChanging ? null : () => _lift(context, vm),
          )
        else
          ActionButtons.dangerButton(
            context,
            key: const ValueKey('pool-quarantine'),
            label: l10n.adminPoolQuarantine,
            onPressed: vm.isChanging ? null : () => _quarantine(context, vm),
          ),
      ],
    );
  }

  Widget _card(String label, String value) => SizedBox(
    width: 200,
    child: AdminStatCard(label: label, value: value),
  );

  List<Widget> _shares(AppLocalizations l10n) {
    final young = inspection.youngAccountShare;
    final unverified = inspection.unverifiedShare;
    if (young == null && unverified == null) {
      return [Text(l10n.adminPoolNoShares, style: AppTextStyles.bodyMedium)];
    }
    return [
      if (young != null)
        Text(
          l10n.adminPoolYoungShare(_percent(young), inspection.sampled),
          style: AppTextStyles.bodyMedium,
        ),
      if (unverified != null)
        Text(
          l10n.adminPoolUnverifiedShare(
            _percent(unverified),
            inspection.sampled,
          ),
          style: AppTextStyles.bodyMedium,
        ),
    ];
  }

  static int _percent(double share) => (share * 100).round();

  Future<void> _quarantine(
    BuildContext context,
    PoolReviewViewModel vm,
  ) async {
    final l10n = context.l10n;
    final reason = await showButlerySheet<QuarantineReason>(
      context: context,
      builder: (sheetContext) => _ReasonSheet(title: l10n.adminPoolReasonTitle),
    );
    if (reason == null || !context.mounted) return;
    final confirmed =
        await ConfirmationDialogs.showDestructiveConfirmationDialog(
          context,
          title: l10n.adminPoolQuarantineConfirmTitle,
          message: l10n.adminPoolQuarantineConfirmBody,
          confirmText: l10n.adminPoolQuarantine,
          cancelText: l10n.commonCancel,
        );
    if (!confirmed || !context.mounted) return;
    final ok = await vm.quarantine(reason);
    if (ok && context.mounted) {
      SnackBarUtils.showSuccess(context, l10n.adminPoolQuarantined);
    }
  }

  Future<void> _lift(BuildContext context, PoolReviewViewModel vm) async {
    final l10n = context.l10n;
    final confirmed = await ConfirmationDialogs.showConfirmationDialog(
      context,
      title: l10n.adminPoolLiftConfirmTitle,
      message: l10n.adminPoolLiftConfirmBody,
      confirmText: l10n.adminPoolLift,
      cancelText: l10n.commonCancel,
    );
    if (!confirmed || !context.mounted) return;
    final ok = await vm.lift();
    if (ok && context.mounted) {
      SnackBarUtils.showSuccess(context, l10n.adminPoolLifted);
    }
  }
}

String _reasonLabel(AppLocalizations l10n, QuarantineReason reason) =>
    switch (reason) {
      QuarantineReason.brigading => l10n.adminPoolReasonBrigading,
      QuarantineReason.badMerge => l10n.adminPoolReasonBadMerge,
      QuarantineReason.other => l10n.adminPoolReasonOther,
    };

class _ReasonSheet extends StatelessWidget {
  const _ReasonSheet({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.all(AppDimensions.space16),
          child: Text(title, style: AppTextStyles.titleMedium),
        ),
        for (final reason in QuarantineReason.values)
          ButleryItemRow(
            key: ValueKey('pool-reason-${reason.wireName}'),
            title: _reasonLabel(l10n, reason),
            onTap: () => Navigator.of(context).pop(reason),
          ),
        const SizedBox(height: AppDimensions.space16),
      ],
    );
  }
}
