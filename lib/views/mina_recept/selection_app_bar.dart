/// Selection-mode AppBar extracted from `mina_recept_view.dart` per
/// BUT-441. Active when the user is in bulk-selection mode; provides
/// close, select-all, and bulk-delete actions. Bulk-delete confirmation
/// + undo SnackBar live here (5-7s window via `commonUndo`).
library;

import 'package:flutter/material.dart';

import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/core/utils/common_dialog_actions.dart';
import 'package:butlery/core/utils/snackbar_utils.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/viewmodels/recipe_list_viewmodel.dart';

/// Builds the selection-mode AppBar. Returned as a `PreferredSizeWidget`
/// so the parent Scaffold can drop it straight in.
PreferredSizeWidget buildMinaReceptSelectionAppBar(
  BuildContext context,
  RecipeListViewModel viewModel,
) {
  final cs = Theme.of(context).colorScheme;
  return AppBar(
    backgroundColor: cs.primaryContainer,
    leading: IconButton(
      icon: const Icon(Icons.close),
      onPressed: viewModel.clearSelection,
      tooltip: context.l10n.bulkCancelSelection,
    ),
    title: Text(
      context.l10n.bulkSelectedCount(viewModel.selectedCount),
      style: AppTextStyles.titleMedium,
    ),
    actions: [
      IconButton(
        icon: const Icon(Icons.select_all),
        tooltip: context.l10n.bulkSelectAll,
        onPressed: viewModel.selectAll,
      ),
      IconButton(
        icon: const Icon(Icons.delete_outline),
        tooltip: context.l10n.bulkDelete,
        onPressed: () async {
          final count = viewModel.selectedCount;
          final confirmed = await CommonDialogActions.showDeleteConfirmation(
            context: context,
            itemName: '$count recept',
            itemType: 'recept',
            warningMessage: context.l10n.bulkDeleteConfirmMessage,
            icon: Icons.delete_sweep,
          );
          if (confirmed == true) {
            viewModel.deleteSelected();
            viewModel.clearSelection();
            if (context.mounted) {
              SnackBarUtils.showSuccessWithAction(
                context,
                context.l10n.bulkDeleteSuccess(count),
                actionLabel: context.l10n.commonUndo,
                onAction: () => viewModel.undoBulkDelete(),
                duration: const Duration(seconds: 7),
              );
            }
          }
        },
      ),
    ],
  );
}
