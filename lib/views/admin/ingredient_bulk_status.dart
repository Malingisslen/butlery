import 'package:flutter/material.dart';

import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/core/utils/captured_snackbars.dart';
import 'package:butlery/services/tagging/ingredient_change_validator.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/viewmodels/admin/bulk_status_proposal_viewmodel.dart';
import 'package:butlery/viewmodels/admin/ingredient_review_viewmodel.dart';
import 'package:butlery/widgets/common/buttons/butlery_text_button.dart';
import 'package:butlery/widgets/common/dialogs/confirmation_dialogs.dart';
import 'package:butlery/widgets/common/menus/butlery_menu.dart';

/// Shown over the list while rows are selected: count, clear, and the status
/// to propose for all of them.
class IngredientBulkBar extends StatelessWidget {
  const IngredientBulkBar({
    required this.vm,
    this.bulkFactory = _defaultFactory,
    super.key,
  });

  final IngredientReviewViewModel vm;

  /// Tests pass a ViewModel with a fake repository.
  final BulkStatusProposalViewModel Function(IngredientReviewViewModel vm)
  bulkFactory;

  static BulkStatusProposalViewModel _defaultFactory(
    IngredientReviewViewModel vm,
  ) => BulkStatusProposalViewModel(selected: vm.selectedIngredients);

  static const _none = '';

  Future<void> _pick(BuildContext context, String status) async {
    if (status == _none) return;
    final l10n = context.l10n;
    final snackBars = CapturedSnackBars.capture(context);
    final bulk = bulkFactory(vm);
    try {
      if (bulk.exceedsLimit) {
        snackBars.showFailure(
          what: l10n.adminBulkTooMany('${BulkStatusProposalViewModel.maxRows}'),
        );
        return;
      }
      final changed = bulk.rowsChangedBy(status);
      if (changed == 0) {
        snackBars.showFailure(what: l10n.adminBulkNothingToChange);
        return;
      }
      final distribution = [
        for (final e in bulk.statusDistribution.entries) '${e.key}: ${e.value}',
      ].join(', ');
      final ok = await ConfirmationDialogs.showConfirmationDialog(
        context,
        title: l10n.adminBulkConfirmTitle(status),
        message: l10n.adminBulkConfirmMessage(
          '$changed',
          '${bulk.selected.length}',
          distribution,
        ),
        confirmText: l10n.adminBulkConfirm,
        cancelText: l10n.commonCancel,
      );
      if (!ok) return;
      if (await bulk.submit(status)) {
        vm.clearSelection();
        snackBars.showConfirmation(l10n.adminProposalSaved);
      } else if (bulk.error != null) {
        snackBars.showFailure(what: bulk.error!);
      }
    } finally {
      bulk.dispose();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final count = vm.selectedIds.length;
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimensions.space16,
        vertical: AppDimensions.space8,
      ),
      child: Wrap(
        spacing: AppDimensions.space16,
        runSpacing: AppDimensions.space8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Text(l10n.adminBulkSelectedCount('$count')),
          SizedBox(
            width: 240,
            child: ButleryDropdown<String>(
              key: const ValueKey('bulk-status'),
              dense: true,
              semanticLabel: l10n.adminBulkSetStatus,
              hint: l10n.adminBulkSetStatus,
              value: _none,
              onChanged: (v) => _pick(context, v),
              options: [
                ButleryDropdownOption<String>(
                  value: _none,
                  label: l10n.adminBulkSetStatus,
                ),
                for (final s in kProposableStatuses)
                  ButleryDropdownOption<String>(value: s, label: s),
              ],
            ),
          ),
          ButleryTextButton(
            key: const ValueKey('bulk-clear'),
            label: l10n.adminBulkClear,
            onPressed: vm.clearSelection,
          ),
        ],
      ),
    );
  }
}
