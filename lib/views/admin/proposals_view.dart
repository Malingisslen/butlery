import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/core/utils/captured_snackbars.dart';
import 'package:butlery/l10n/app_localizations.dart';
import 'package:butlery/models/tagging/ingredient_change_request.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/viewmodels/admin/pending_proposals_viewmodel.dart';
import 'package:butlery/views/admin/ingredient_proposal_labels.dart';
import 'package:butlery/views/admin/widgets/admin_tab_header.dart';
import 'package:butlery/widgets/common/buttons/app_icon_button.dart';
import 'package:butlery/widgets/common/buttons/butlery_text_button.dart';
import 'package:butlery/widgets/common/icons/butlery_icons.dart';
import 'package:butlery/widgets/common/indicators/status_pill.dart';
import 'package:butlery/widgets/common/state_widget.dart';

/// Admin "Förslag" tab: pending ingredient proposals, old value to new per
/// field, with a way to withdraw each one.
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
    if (vm.proposals.isEmpty) {
      return StateWidget.empty(title: l10n.adminProposalsEmpty);
    }
    final list = ListView.builder(
      itemCount: vm.proposals.length,
      itemBuilder: (context, i) => ProposalCard(
        key: ValueKey(vm.proposals[i].id),
        proposal: vm.proposals[i],
        onWithdraw: () => _withdraw(context, vm, vm.proposals[i].id),
      ),
    );
    if (!vm.mayHaveMore) return list;
    return Column(
      children: [
        Padding(
          key: const ValueKey('proposals-more-waiting'),
          padding: const EdgeInsets.all(AppDimensions.space16),
          child: Text(l10n.adminProposalsMoreWaiting(vm.proposals.length)),
        ),
        Expanded(child: list),
      ],
    );
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
    required this.onWithdraw,
    super.key,
  });

  final IngredientChangeRequest proposal;
  final VoidCallback onWithdraw;

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
          for (final c in proposal.changes) _line(l10n, c),
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
}
