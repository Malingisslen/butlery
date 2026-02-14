// lib/views/recipe_detail/handlers/recipe_management_handler.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:butlery/viewmodels/recipe_detail_viewmodel.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/theme/app_colors.dart';
import 'package:butlery/core/constants/routes.dart';
import 'package:butlery/core/utils/common_dialog_actions.dart';
import 'package:butlery/core/providers/application_provider.dart';
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
    required void Function(String message, {Color? backgroundColor})
        showSnackBar,
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
        showSnackBar(context.l10n.recipeDeleted,
            backgroundColor: AppColors.success);
        onSuccess();
      } else {
        showSnackBar(context.l10n.recipeCouldNotDelete,
            backgroundColor: AppColors.error);
      }
    }
  }

  /// Navigate to edit recipe view
  static Future<void> editRecipe(
    BuildContext context, {
    required void Function(String message, {Color? backgroundColor})
        showSnackBar,
  }) async {
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
      showSnackBar(context.l10n.recipeCouldNotOpenEditor,
          backgroundColor: AppColors.error);
    }
  }

  /// Mark recipe as cooked
  static Future<void> markAsCooked(
    BuildContext context, {
    required void Function(String message, {Color? backgroundColor})
        showSnackBar,
  }) async {
    if (!context.mounted) return;

    final viewModel = context.read<RecipeDetailViewModel>();

    try {
      await viewModel.markAsCooked();
      if (!context.mounted) return;
      showSnackBar(context.l10n.recipeMarkedAsCooked,
          backgroundColor: AppColors.success);
    } catch (e) {
      if (!context.mounted) return;
      showSnackBar(context.l10n.recipeCouldNotMarkAsCooked,
          backgroundColor: AppColors.error);
    }
  }

  /// Share recipe via share service
  static Future<void> shareRecipe(
    BuildContext context, {
    required void Function(String message, {Color? backgroundColor})
        showSnackBar,
  }) async {
    if (!context.mounted) return;

    final viewModel = context.read<RecipeDetailViewModel>();
    final shareService = ServiceLocator.get<ShareService>();

    try {
      await shareService.shareRecipe(viewModel.recipe);
      if (!context.mounted) return;
      showSnackBar(context.l10n.recipeShared,
          backgroundColor: AppColors.success);
    } catch (e) {
      if (!context.mounted) return;
      showSnackBar(context.l10n.recipeCouldNotShare,
          backgroundColor: AppColors.error);
    }
  }

  /// Toggle collaborative editing on a recipe.
  /// Shows enable dialog (friend picker) or disable confirmation based on current state.
  static Future<void> toggleCollaboration(
    BuildContext context, {
    required void Function(String message, {Color? backgroundColor})
        showSnackBar,
  }) async {
    if (!context.mounted) return;

    final viewModel = context.read<RecipeDetailViewModel>();
    final recipe = viewModel.recipe;

    if (recipe.isCollaborative) {
      await _confirmDisableCollaboration(context, recipe,
          showSnackBar: showSnackBar);
    } else {
      await _showEnableCollaborationDialog(context, recipe,
          showSnackBar: showSnackBar);
    }
  }

  /// Show dialog to select friends as collaborators, then enable collaboration
  static Future<void> _showEnableCollaborationDialog(
    BuildContext context,
    Recipe recipe, {
    required void Function(String message, {Color? backgroundColor})
        showSnackBar,
  }) async {
    final friendsService = ServiceLocator.get<UnifiedFriendsService>();
    final friends = friendsService.friendsList;

    if (friends.isEmpty) {
      showSnackBar(
        context.l10n.collaborationNoFriends,
        backgroundColor: AppColors.error,
      );
      return;
    }

    final selectedIds = <String>{};

    if (!context.mounted) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
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
                      activeColor: AppColors.forestGreen,
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
      ),
    );

    if (confirmed == true && selectedIds.isNotEmpty) {
      final recipeService = ServiceLocator.get<UnifiedRecipeService>();
      final success = await recipeService.realtime
          .enableCollaborativeEditing(recipe.id, selectedIds.toList());

      if (!context.mounted) return;
      if (success) {
        showSnackBar(
          context.l10n.collaborationEnabled,
          backgroundColor: AppColors.success,
        );
      } else {
        showSnackBar(
          context.l10n.collaborationCouldNotEnable,
          backgroundColor: AppColors.error,
        );
      }
    }
  }

  /// Show confirmation dialog and disable collaboration
  static Future<void> _confirmDisableCollaboration(
    BuildContext context,
    Recipe recipe, {
    required void Function(String message, {Color? backgroundColor})
        showSnackBar,
  }) async {
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
        showSnackBar(
          context.l10n.collaborationDeactivated,
          backgroundColor: AppColors.success,
        );
      } else {
        showSnackBar(
          context.l10n.collaborationCouldNotDeactivate,
          backgroundColor: AppColors.error,
        );
      }
    }
  }
}
