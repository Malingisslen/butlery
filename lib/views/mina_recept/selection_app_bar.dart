/// Selection-mode AppBar extracted from `mina_recept_view.dart` per
/// BUT-441. Active when the user is in bulk-selection mode; provides
/// close, select-all, and bulk-delete actions. Bulk-delete confirmation
/// + undo SnackBar live here (5-7s window via `commonUndo`).
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/core/utils/common_dialog_actions.dart';
import 'package:butlery/core/utils/snackbar_utils.dart';
import 'package:butlery/models/friend_category.dart';
import 'package:butlery/models/user_profile.dart';
import 'package:butlery/services/unified/unified_friends_service.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/viewmodels/recipe_list_viewmodel.dart';
import 'package:butlery/viewmodels/universal_share_dialog_viewmodel.dart';
import 'package:butlery/widgets/common/universal_share_dialog.dart';

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
      // BUT-933: bulk-share. The remaining bulk actions (tag, add-to-menu,
      // export) are split into follow-up tickets — see commit message.
      IconButton(
        icon: const Icon(Icons.share_outlined),
        tooltip: context.l10n.bulkShare,
        onPressed: viewModel.selectedCount == 0
            ? null
            : () => _openBulkShareDialog(context, viewModel),
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

/// BUT-933: open the bulk-share dialog with the selected recipes.
/// `UniversalShareDialog.bulkShare` already accepts a list — no Cloud
/// Function changes needed. Friends + groups are fetched best-effort
/// matching `recipe_social_handler.showSocialShareDialog`.
Future<void> _openBulkShareDialog(
  BuildContext context,
  RecipeListViewModel viewModel,
) async {
  final recipes = viewModel.selectedRecipes;
  if (recipes.isEmpty) return;

  final shareViewModel = ServiceLocator.get<UniversalShareDialogViewModel>();
  final friendsService = ServiceLocator.get<UnifiedFriendsService>();

  List<UserProfile> availableFriends = const [];
  try {
    availableFriends = friendsService.friends;
  } catch (_) {
    // Silently continue with empty friends list.
  }
  final List<FriendCategory> availableGroups = friendsService.categoriesList;

  if (!context.mounted) return;
  await showDialog<void>(
    context: context,
    builder: (dialogContext) => ChangeNotifierProvider.value(
      value: shareViewModel,
      child: UniversalShareDialog.bulkShare(
        contentItems: recipes,
        primaryContentType: ShareContentType.recipe,
        viewModel: shareViewModel,
        availableFriends: availableFriends,
        availableGroups: availableGroups,
      ),
    ),
  );
}
