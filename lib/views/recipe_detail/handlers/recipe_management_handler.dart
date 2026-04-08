// lib/views/recipe_detail/handlers/recipe_management_handler.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:butlery/viewmodels/recipe_detail_viewmodel.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/core/constants/routes.dart';
import 'package:butlery/core/utils/common_dialog_actions.dart';
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/core/utils/snackbar_utils.dart';
import 'package:butlery/services/share_service.dart';
import 'package:butlery/services/unified/unified_recipe_service.dart';
import 'package:butlery/services/unified/unified_friends_service.dart';
import 'package:butlery/core/extensions/localization_extension.dart';

/// Recipe management action handler
/// Handles recipe CRUD operations: delete, edit, mark as cooked, and share.
class RecipeManagementHandler {
  /// Delete recipe with confirmation dialog
  static Future<void> deleteRecipe(
    BuildContext context, {
    required VoidCallback onSuccess,
    required VoidCallback popNavigation,
  }) async {
    if (!context.mounted) return;

    final viewModel = context.read<RecipeDetailViewModel>();
    final confirmed = await CommonDialogActions.showRecipeDeleteConfirmation(
      context: context,
      recipeName: viewModel.recipe.title,
    );

    if (confirmed == true) {
      if (!context.mounted) return;
      final success = await viewModel.deleteRecipe();
      if (!context.mounted) return;
      if (success) {
        popNavigation();
        SnackBarUtils.showSuccess(context, context.l10n.recipeDeleted);
        onSuccess();
      } else {
        SnackBarUtils.showError(context, context.l10n.recipeCouldNotDelete);
      }
    }
  }

  /// Navigate to edit recipe view
  static Future<void> editRecipe(BuildContext context) async {
    if (!context.mounted) return;

    final viewModel = context.read<RecipeDetailViewModel>();

    try {
      await Navigator.pushNamed(
        context,
        Routes.redigeraRecept,
        arguments: viewModel.recipe,
      );
    } catch (e) {
      if (!context.mounted) return;
      SnackBarUtils.showError(context, context.l10n.recipeCouldNotOpenEditor);
    }
  }

  /// Mark recipe as cooked
  static Future<void> markAsCooked(BuildContext context) async {
    if (!context.mounted) return;

    final viewModel = context.read<RecipeDetailViewModel>();

    try {
      await viewModel.markAsCooked();
      if (!context.mounted) return;
      SnackBarUtils.showSuccess(context, context.l10n.recipeMarkedAsCooked);
    } catch (e) {
      if (!context.mounted) return;
      SnackBarUtils.showError(context, context.l10n.recipeCouldNotMarkAsCooked);
    }
  }

  /// Share recipe via share service
  static Future<void> shareRecipe(BuildContext context) async {
    if (!context.mounted) return;

    final viewModel = context.read<RecipeDetailViewModel>();
    final shareService = ServiceLocator.get<ShareService>();

    try {
      await shareService.shareRecipe(viewModel.recipe);
      if (!context.mounted) return;
      SnackBarUtils.showSuccess(context, context.l10n.recipeShared);
    } catch (e) {
      if (!context.mounted) return;
      SnackBarUtils.showError(context, context.l10n.recipeCouldNotShare);
    }
  }

  /// Toggle collaborative editing on a recipe.
  /// Shows enable dialog (friend picker) or disable confirmation based on current state.
  static Future<void> toggleCollaboration(BuildContext context) async {
    if (!context.mounted) return;

    final viewModel = context.read<RecipeDetailViewModel>();
    final recipe = viewModel.recipe;

    if (recipe.isCollaborative) {
      await _confirmDisableCollaboration(context, recipe);
    } else {
      await _showEnableCollaborationDialog(context, recipe);
    }
  }

  /// Show dialog to select friends as collaborators, then enable collaboration
  static Future<void> _showEnableCollaborationDialog(
    BuildContext context,
    Recipe recipe,
  ) async {
    final friendsService = ServiceLocator.get<UnifiedFriendsService>();
    final friends = friendsService.friendsList;

    if (friends.isEmpty) {
      SnackBarUtils.showError(context, context.l10n.collaborationNoFriends);
      return;
    }

    final selectedIds = <String>{};

    if (!context.mounted) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final dialogCs = Theme.of(ctx).colorScheme;
        return StatefulBuilder(
          builder: (ctx, setDialogState) => AlertDialog(
            shape: const RoundedRectangleBorder(),
            title: Text(context.l10n.collaborationEnableTitle),
            content: SizedBox(
              width: double.maxFinite,
              height: 300,
              child: ListView(
                children: friends
                    .map(
                      (friend) => CheckboxListTile(
                        title: Text(friend.displayName),
                        subtitle:
                            friend.email.isNotEmpty ? Text(friend.email) : null,
                        value: selectedIds.contains(friend.uid),
                        activeColor: dialogCs.primary,
                        onChanged: (v) => setDialogState(() {
                          if (v == true) {
                            selectedIds.add(friend.uid);
                          } else {
                            selectedIds.remove(friend.uid);
                          }
                        }),
                      ),
                    )
                    .toList(),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: Text(context.l10n.commonCancel),
              ),
              TextButton(
                onPressed:
                    selectedIds.isEmpty ? null : () => Navigator.pop(ctx, true),
                child: Text(context.l10n.commonEnable),
              ),
            ],
          ),
        );
      },
    );

    if (confirmed == true && selectedIds.isNotEmpty) {
      final recipeService = ServiceLocator.get<UnifiedRecipeService>();
      final success = await recipeService.realtime
          .enableCollaborativeEditing(recipe.id, selectedIds.toList());

      if (!context.mounted) return;
      if (success) {
        SnackBarUtils.showSuccess(context, context.l10n.collaborationEnabled);
      } else {
        SnackBarUtils.showError(
            context, context.l10n.collaborationCouldNotEnable);
      }
    }
  }

  /// Show confirmation dialog and disable collaboration
  static Future<void> _confirmDisableCollaboration(
    BuildContext context,
    Recipe recipe,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: const RoundedRectangleBorder(),
        title: Text(context.l10n.collaborationDeactivateTitle),
        content: Text(context.l10n.collaborationDeactivateMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(context.l10n.commonCancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(context.l10n.commonDeactivate),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final recipeService = ServiceLocator.get<UnifiedRecipeService>();
      final success =
          await recipeService.realtime.disableCollaborativeEditing(recipe.id);

      if (!context.mounted) return;
      if (success) {
        SnackBarUtils.showSuccess(
            context, context.l10n.collaborationDeactivated);
      } else {
        SnackBarUtils.showError(
            context, context.l10n.collaborationCouldNotDeactivate);
      }
    }
  }
}
