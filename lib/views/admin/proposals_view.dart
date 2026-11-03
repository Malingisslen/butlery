import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/core/utils/captured_snackbars.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/l10n/app_localizations.dart';
import 'package:butlery/models/tagging/ingredient_change_request.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/viewmodels/admin/pending_proposals_viewmodel.dart';
import 'package:butlery/views/admin/ingredient_proposal_labels.dart';
import 'package:butlery/views/admin/widgets/admin_tab_header.dart';
import 'package:butlery/widgets/common/buttons/action_buttons.dart';
import 'package:butlery/widgets/common/buttons/butlery_text_button.dart';
import 'package:butlery/widgets/common/dialogs/confirmation_dialogs.dart';
import 'package:butlery/widgets/common/icons/butlery_icons.dart';
import 'package:butlery/widgets/common/indicators/status_pill.dart';
import 'package:butlery/widgets/common/state_widget.dart';

/// Admin "Förslag" tab: the proposal queue by stage, old value to new per
/// field, a way to withdraw open ones, and the button that creates the review.
class ProposalsView extends StatefulWidget {
  const ProposalsView({super.key, this.viewModel});

  /// Injected by tests; the tab builds its own otherwise.
  final PendingProposalsViewModel? viewModel;

  @override
  State<ProposalsView> createState() => _ProposalsViewState();
}

class _ProposalsViewState extends State<ProposalsView> {
  late final PendingProposalsViewModel _vm;

  @override
  void initState() {
    super.initState();
    _vm = widget.viewModel ?? PendingProposalsViewModel();
    _vm.start();
  }

  @override
  void dispose() {
    _vm.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<PendingProposalsViewModel>.value(
      value: _vm,
      child: Consumer<PendingProposalsViewModel>(
        builder: (context, vm, _) {
          final l10n = context.l10n;
          return AdminTabPage(
            title: l10n.adminProposalsTitle,
            actions: [
              AppIconButton(
                icon: ButleryIcons.refreshCw,
                semanticLabel: l10n.adminRefresh,
                onPressed: vm.retry,
              ),
            ],
            body: _body(context, vm),
          );
        },
      ),
    );
  }

  Widget _body(BuildContext context, PendingProposalsViewModel vm) {
    final l10n = context.l10n;
    if (!vm.hasLoaded) {
      return StateWidget.loading(message: l10n.adminIngredientsLoading);
    }
    if (vm.error != null && vm.proposals.isEmpty) {
      return StateWidget.error(
        message: vm.error!,
        actionLabel: l10n.adminRefresh,
        onAction: vm.retry,
      );
    }
    if (vm.isEmpty) {
      return StateWidget.empty(title: l10n.adminProposalsEmpty);
    }
    void withdraw(String id) => _withdraw(context, vm, id);
    return ListView(
      children: [
        if (vm.mayHaveMore)
          Padding(
            key: const ValueKey('proposals-more-waiting'),
            padding: const EdgeInsets.all(AppDimensions.space16),
            child: Text(l10n.adminProposalsMoreWaiting(vm.proposals.length)),
          ),
        _ReviewBar(vm: vm, onCreate: () => _createReview(context, vm)),
        _section(
          l10n.adminProposalSectionPending,
          vm.pending,
          withdraw: withdraw,
        ),
        _section(
          l10n.adminProposalSectionInReview,
          vm.inReview,
          withdraw: withdraw,
        ),
        _section(
          l10n.adminProposalSectionConflict,
          vm.conflicts,
          withdraw: withdraw,
        ),
        _section(l10n.adminProposalSectionRejected, vm.rejected),
        if (vm.decidedFailed)
          Padding(
            padding: const EdgeInsets.all(AppDimensions.space16),
            child: Text(l10n.adminProposalDecidedLoadFailed),
          ),
        _section(l10n.adminProposalSectionApplied, vm.applied),
      ],
    );
  }

  Widget _section(
    String title,
    List<IngredientChangeRequest> items, {
    void Function(String id)? withdraw,
  }) {
    if (items.isEmpty) return const SizedBox.shrink();
    return Column(
      key: ValueKey('section-$title'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppDimensions.space16,
            AppDimensions.space16,
            AppDimensions.space16,
            AppDimensions.space4,
          ),
          child: Text(
            '$title (${items.length})',
            style: AppTextStyles.titleMedium,
          ),
        ),
        for (final p in items)
          ProposalCard(
            key: ValueKey(p.id),
            proposal: p,
            onWithdraw: withdraw == null ? null : () => withdraw(p.id),
          ),
      ],
    );
  }

  Future<void> _createReview(
    BuildContext context,
    PendingProposalsViewModel vm,
  ) async {
    final l10n = context.l10n;
    final confirmed = await ConfirmationDialogs.showConfirmationDialog(
      context,
      title: l10n.adminProposalCreateReviewTitle,
      message: l10n.adminProposalCreateReviewMessage(vm.waitingCount),
      confirmText: l10n.adminProposalCreateReview,
    );
    if (!confirmed) return;
    await vm.createReview();
  }

  Future<void> _withdraw(
    BuildContext context,
    PendingProposalsViewModel vm,
    String id,
  ) async {
    final l10n = context.l10n;
    final snackBars = CapturedSnackBars.capture(context);
    if (await vm.withdraw(id)) {
      snackBars.showConfirmation(l10n.adminProposalWithdrawn);
    } else if (vm.error != null) {
      snackBars.showFailure(what: vm.error!);
    }
  }
}

class ProposalCard extends StatelessWidget {
  const ProposalCard({
    required this.proposal,
    this.onWithdraw,
    super.key,
  });

  final IngredientChangeRequest proposal;

  /// Null where a withdrawal is no longer possible (rejected, applied).
  final VoidCallback? onWithdraw;

  static String _date(DateTime d) {
    final l = d.toLocal();
    return '${l.year}-${l.month.toString().padLeft(2, '0')}-'
        '${l.day.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final cs = Theme.of(context).colorScheme;
    final created = proposal.createdAt;
    return Container(
      padding: const EdgeInsets.all(AppDimensions.space16),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: cs.outlineVariant)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  proposal.ingredientId,
                  style: AppTextStyles.titleSmall,
                ),
              ),
              if (proposal.affectsAllergens)
                StatusPill(
                  key: const ValueKey('allergen-mark'),
                  label: l10n.adminProposalAffectsAllergens,
                ),
              if (onWithdraw != null)
                ButleryTextButton(
                  key: const ValueKey('withdraw'),
                  label: l10n.adminProposalWithdraw,
                  tone: ButleryTextButtonTone.warning,
                  onPressed: onWithdraw,
                ),
            ],
          ),
          if (created != null)
            Text(
              l10n.adminProposalWhen(_date(created)),
              style: AppTextStyles.bodySmall.copyWith(
                color: cs.onSurfaceVariant,
              ),
            ),
          if (proposal.batchId != null)
            Text(l10n.adminProposalBatchMark, style: AppTextStyles.bodySmall),
          if (proposal.status == IngredientChangeStatus.inReview)
            _PullRequestLink(number: proposal.prNumber),
          if (proposal.status == IngredientChangeStatus.conflict ||
              proposal.status == IngredientChangeStatus.rejected)
            Padding(
              padding: const EdgeInsets.only(top: AppDimensions.space4),
              child: Text(
                key: const ValueKey('proposal-reason'),
                proposalReasonText(l10n, proposal.reason),
                style: AppTextStyles.bodySmall,
              ),
            ),
          for (final c in proposal.changes)
            proposal.status == IngredientChangeStatus.conflict
                ? _conflictLines(l10n, c)
                : _line(l10n, c),
          if (proposal.note.isNotEmpty)
            Text(proposal.note, style: AppTextStyles.bodySmall),
        ],
      ),
    );
  }

  Widget _line(AppLocalizations l10n, IngredientFieldChange c) => Padding(
    padding: const EdgeInsets.only(top: AppDimensions.space4),
    child: SelectableText(
      l10n.adminProposalChangeLine(
        ingredientColumnLabel(l10n, c.column),
        ingredientValueText(l10n, c.oldValue),
        ingredientValueText(l10n, c.newValue),
      ),
    ),
  );

  Widget _conflictLines(AppLocalizations l10n, IngredientFieldChange c) {
    final csv = proposal.csvValue;
    final hasCsv = csv != null && csv.containsKey(c.column.csvName);
    return Padding(
      padding: const EdgeInsets.only(top: AppDimensions.space8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            ingredientColumnLabel(l10n, c.column),
            style: AppTextStyles.labelLarge,
          ),
          if (hasCsv)
            SelectableText(
              l10n.adminProposalConflictCsv(
                ingredientValueText(l10n, csv[c.column.csvName]),
              ),
            ),
          SelectableText(
            l10n.adminProposalConflictOld(
              ingredientValueText(l10n, c.oldValue),
            ),
          ),
          SelectableText(
            l10n.adminProposalConflictNew(
              ingredientValueText(l10n, c.newValue),
            ),
          ),
        ],
      ),
    );
  }
}

const String kButleryPullRequestBase =
    'https://github.com/Malingisslen/butlery/pull/';

/// Only an https link on github.com is opened; the URL comes from a callable
/// response, so it is checked before it reaches the browser.
@visibleForTesting
bool isTrustedGithubUrl(String url) {
  final uri = Uri.tryParse(url);
  return uri != null && uri.scheme == 'https' && uri.host == 'github.com';
}

Future<void> _openUrl(String url) async {
  if (!isTrustedGithubUrl(url)) return;
  try {
    await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
  } catch (e) {
    AppLogger.warning('Could not open $url: $e');
  }
}

class _PullRequestLink extends StatelessWidget {
  const _PullRequestLink({required this.number, this.url});

  final int? number;
  final String? url;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final target = (url != null && isTrustedGithubUrl(url!))
        ? url
        : (number == null ? null : '$kButleryPullRequestBase$number');
    if (target == null) return const SizedBox.shrink();
    return Row(
      children: [
        if (number != null && number! > 0)
          Text(
            l10n.adminProposalPullRequest(number!),
            style: AppTextStyles.bodySmall,
          ),
        ButleryTextButton(
          key: const ValueKey('open-github'),
          label: l10n.adminProposalOpenOnGithub,
          onPressed: () => _openUrl(target),
        ),
      ],
    );
  }
}

class _ReviewBar extends StatelessWidget {
  const _ReviewBar({required this.vm, required this.onCreate});

  final PendingProposalsViewModel vm;
  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final result = vm.lastReview;
    return Padding(
      padding: const EdgeInsets.all(AppDimensions.space16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ActionButtons.primaryButton(
            context,
            key: const ValueKey('create-review'),
            label: l10n.adminProposalCreateReview,
            isLoading: vm.isCreatingReview,
            onPressed: vm.canCreateReview ? onCreate : null,
          ),
          if (result != null) ...[
            const SizedBox(height: AppDimensions.space8),
            Text(
              key: const ValueKey('review-created'),
              l10n.adminProposalReviewCreated(
                result.applied,
                result.conflicts,
              ),
            ),
            _PullRequestLink(number: result.prNumber, url: result.prUrl),
          ],
          if (vm.reviewError != null) ...[
            const SizedBox(height: AppDimensions.space8),
            Text(
              key: const ValueKey('review-error'),
              vm.reviewError!,
              style: AppTextStyles.bodySmall.copyWith(
                color: Theme.of(context).colorScheme.error,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
