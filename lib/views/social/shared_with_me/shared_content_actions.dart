// lib/views/social/shared_with_me/shared_content_actions.dart

import 'package:flutter/material.dart';
import 'package:butlery/core/utils/snackbar_utils.dart';
import 'package:butlery/viewmodels/shared_content/shared_content_coordinator_viewmodel.dart';
import 'package:butlery/models/shared_recipe.dart';
import 'package:butlery/models/shared_menu.dart';
import 'package:butlery/models/shared_shopping_list.dart';
import 'package:butlery/core/router/app_router.dart';
import 'package:butlery/core/constants/routes.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/core/utils/common_dialog_actions.dart';
import 'package:butlery/services/unified/unified_shopping_service.dart';
import 'package:butlery/services/unified/modules/social_recipe/social_recipe_coordinator.dart';
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/widgets/common/buttons/action_buttons.dart';
import 'package:butlery/core/extensions/localization_extension.dart';

/// SharedContentActions - Action methods for shared content
/// Handles import, dismiss, and other actions for shared content.
class SharedContentActions {
  /// Import a shared recipe
  static Future<void> importRecipe(
    BuildContext context,
    SharedContentCoordinatorViewModel viewModel,
    SharedRecipe sharedRecipe,
  ) async {
    final recipeId = await viewModel.recipeViewModel.importSharedRecipe(
      sharedRecipe,
    );

    if (recipeId != null && context.mounted) {
      SnackBarUtils.showSuccess(
        context,
        context.l10n.sharedRecipeImported(sharedRecipe.recipeTitle),
      );
    } else if (context.mounted && viewModel.recipeViewModel.hasError) {
      SnackBarUtils.showError(
        context,
        viewModel.recipeViewModel.error ?? context.l10n.sharedImportFailed,
      );
    }
  }

  /// Import a shared menu or join collaborative session
  static Future<void> importMenu(
    BuildContext context,
    SharedContentCoordinatorViewModel viewModel,
    SharedMenu sharedMenu,
  ) async {
    final result = await viewModel.menuViewModel.importSharedMenu(sharedMenu);

    if (result != null && context.mounted) {
      if (result.isCollaborative) {
        // Navigate to collaborative menu view
        SnackBarUtils.showInfo(
          context,
          context.l10n.sharedConnectingToCollaborativeMenu(
            sharedMenu.menuTitle,
          ),
          duration: const Duration(seconds: 2),
        );
        // Navigate to the realtime menu view
        AppRouter.navigateTo(
          context,
          Routes.realtimeMenu,
          arguments: {'menuId': result.menuId},
        );
      } else {
        // Regular menu import
        SnackBarUtils.showSuccess(
          context,
          context.l10n.sharedMenuImported(sharedMenu.menuTitle),
        );
      }
    } else if (context.mounted && viewModel.menuViewModel.hasError) {
      SnackBarUtils.showError(
        context,
        viewModel.menuViewModel.error ?? context.l10n.sharedImportFailed,
      );
    }
  }

  /// Dismiss a shared recipe
  static Future<void> dismissRecipe(
    BuildContext context,
    SharedContentCoordinatorViewModel viewModel,
    SharedRecipe sharedRecipe,
  ) async {
    final shouldDismiss = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.l10n.sharedHideRecipe),
        content: Text(
          context.l10n.sharedHideRecipeConfirm(
            sharedRecipe.recipeTitle,
            sharedRecipe.sharedByDisplayName,
          ),
        ),
        actions: [
          ActionButtons.secondaryButton(
            context,
            label: context.l10n.commonCancel,
            onPressed: () => Navigator.pop(context, false),
          ),
          ActionButtons.primaryButton(
            context,
            label: context.l10n.commonHide,
            onPressed: () => Navigator.pop(context, true),
          ),
        ],
      ),
    );

    if (shouldDismiss == true) {
      final success = await viewModel.recipeViewModel.dismissSharedRecipe(
        sharedRecipe,
      );

      if (success && context.mounted) {
        SnackBarUtils.showUndo(
          context,
          context.l10n.sharedContentHidden(sharedRecipe.recipeTitle),
          onUndo: () =>
              viewModel.recipeViewModel.undismissSharedRecipe(sharedRecipe),
        );
      } else if (context.mounted && viewModel.recipeViewModel.hasError) {
        SnackBarUtils.showError(
          context,
          viewModel.recipeViewModel.error ??
              context.l10n.sharedCouldNotHideRecipe,
        );
      }
    }
  }

  /// Dismiss a shared menu
  static Future<void> dismissMenu(
    BuildContext context,
    SharedContentCoordinatorViewModel viewModel,
    SharedMenu sharedMenu,
  ) async {
    final shouldDismiss = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.l10n.sharedHideMenu),
        content: Text(
          context.l10n.sharedHideMenuConfirm(
            sharedMenu.menuTitle,
            sharedMenu.sharedByDisplayName,
          ),
        ),
        actions: [
          ActionButtons.secondaryButton(
            context,
            label: context.l10n.commonCancel,
            onPressed: () => Navigator.pop(context, false),
          ),
          ActionButtons.primaryButton(
            context,
            label: context.l10n.commonHide,
            onPressed: () => Navigator.pop(context, true),
          ),
        ],
      ),
    );

    if (shouldDismiss == true) {
      final success = await viewModel.menuViewModel.dismissSharedMenu(
        sharedMenu,
      );

      if (success && context.mounted) {
        SnackBarUtils.showUndo(
          context,
          context.l10n.sharedContentHidden(sharedMenu.menuTitle),
          onUndo: () => viewModel.menuViewModel.undismissSharedMenu(sharedMenu),
        );
      } else if (context.mounted && viewModel.menuViewModel.hasError) {
        SnackBarUtils.showError(
          context,
          viewModel.menuViewModel.error ?? context.l10n.sharedCouldNotHideMenu,
        );
      }
    }
  }

  /// Join a shared shopping list
  static Future<void> joinShoppingList(
    BuildContext context,
    SharedContentCoordinatorViewModel viewModel,
    SharedShoppingList sharedShoppingList,
  ) async {
    final collaborativeListId = await viewModel.shoppingViewModel
        .joinSharedShoppingList(sharedShoppingList);

    if (collaborativeListId != null && context.mounted) {
      // Show success message
      SnackBarUtils.showSuccess(
        context,
        context.l10n.sharedJoinedList(sharedShoppingList.listName),
      );

      // AUTO-NAVIGATION: Set collaborative list as active and navigate to unified interface
      try {
        // First, set the collaborative list as the active list in the shopping service
        final shoppingService = ServiceLocator.get<UnifiedShoppingService>();
        await shoppingService.setActiveList(collaborativeListId);

        // Navigate to the main unified shopping interface instead of separate collaborative view
        if (context.mounted) {
          await AppRouter.navigateTo(
            context,
            Routes
                .shoppingList, // Use main shopping interface for collaborative lists
          );
        }
      } catch (e) {
        AppLogger.error(
          'Failed to set active list or navigate to unified shopping: $e',
        );

        // FALLBACK: Still try to navigate to shopping interface without setting active list
        try {
          if (context.mounted) {
            await AppRouter.navigateTo(
              context,
              Routes.shoppingList,
            );
          }

          if (context.mounted) {
            SnackBarUtils.showSuccess(
              context,
              context.l10n.sharedJoinedListFindInShopping(
                sharedShoppingList.listName,
              ),
              duration: const Duration(seconds: 4),
            );
          }
        } catch (fallbackError) {
          AppLogger.error('Fallback navigation also failed: $fallbackError');

          // Show error to user since both navigation attempts failed
          if (context.mounted) {
            SnackBarUtils.showWarning(
              context,
              context.l10n.sharedJoinedButCouldNotNavigate,
              duration: const Duration(seconds: 5),
            );
          }
        }
      }
    } else if (collaborativeListId == null && context.mounted) {
      if (viewModel.shoppingViewModel.hasError) {
        SnackBarUtils.showError(
          context,
          viewModel.shoppingViewModel.error ??
              context.l10n.sharedCouldNotJoinList,
        );
      } else {
        SnackBarUtils.showError(
          context,
          context.l10n.sharedCouldNotJoinListTryAgain,
        );
      }
    }
  }

  /// Dismiss a shared shopping list
  static Future<void> dismissShoppingList(
    BuildContext context,
    SharedContentCoordinatorViewModel viewModel,
    SharedShoppingList sharedShoppingList,
  ) async {
    final shouldDismiss = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.l10n.sharedHideShoppingList),
        content: Text(
          context.l10n.sharedHideShoppingListConfirm(
            sharedShoppingList.listName,
            sharedShoppingList.sharedByDisplayName,
          ),
        ),
        actions: [
          ActionButtons.secondaryButton(
            context,
            label: context.l10n.commonCancel,
            onPressed: () => Navigator.pop(context, false),
          ),
          ActionButtons.primaryButton(
            context,
            label: context.l10n.commonHide,
            onPressed: () => Navigator.pop(context, true),
          ),
        ],
      ),
    );

    if (shouldDismiss == true) {
      final success = await viewModel.shoppingViewModel
          .dismissSharedShoppingList(sharedShoppingList);

      if (success && context.mounted) {
        SnackBarUtils.showUndo(
          context,
          context.l10n.sharedContentHidden(sharedShoppingList.listName),
          onUndo: () => viewModel.shoppingViewModel.undismissSharedShoppingList(
            sharedShoppingList,
          ),
        );
      } else if (context.mounted && viewModel.shoppingViewModel.hasError) {
        SnackBarUtils.showError(
          context,
          viewModel.shoppingViewModel.error ??
              context.l10n.sharedCouldNotHideShoppingList,
        );
      }
    }
  }

  /// Unshare a recipe - removes it from all groups it was shared with
  static Future<void> unshareRecipe(
    BuildContext context,
    SharedRecipe sharedRecipe,
  ) async {
    final confirmed = await CommonDialogActions.showActionConfirmation(
      context: context,
      title: context.l10n.unshareRecipeTitle,
      message: context.l10n.unshareRecipeConfirm(sharedRecipe.recipeTitle),
      confirmText: context.l10n.unshareButton,
      icon: Icons.link_off,
      isDangerous: true,
    );

    if (confirmed != true || !context.mounted) return;

    try {
      final coordinator = ServiceLocator.get<SocialRecipeCoordinator>();
      final success = await coordinator.unshareRecipe(
        sharedRecipe.originalRecipeId,
      );

      if (!context.mounted) return;

      if (success) {
        SnackBarUtils.showSuccess(
          context,
          context.l10n.unshareSuccess(sharedRecipe.recipeTitle),
        );
      } else {
        SnackBarUtils.showError(context, context.l10n.unshareFailed);
      }
    } catch (e) {
      AppLogger.error('Failed to unshare recipe', e);
      if (context.mounted) {
        SnackBarUtils.showError(context, context.l10n.unshareFailed);
      }
    }
  }

  /// Unshare a menu — routes the delete through the menu view-model (which
  /// owns the repository call) instead of reaching into a repository here.
  static Future<void> unshareMenu(
    BuildContext context,
    SharedContentCoordinatorViewModel viewModel,
    SharedMenu sharedMenu,
  ) async {
    final confirmed = await CommonDialogActions.showActionConfirmation(
      context: context,
      title: context.l10n.unshareMenuTitle,
      message: context.l10n.unshareMenuConfirm(sharedMenu.menuTitle),
      confirmText: context.l10n.unshareButton,
      icon: Icons.link_off,
      isDangerous: true,
    );

    if (confirmed != true || !context.mounted) return;

    final ok = await viewModel.menuViewModel.unshareSharedMenu(sharedMenu);
    if (!context.mounted) return;

    if (ok) {
      SnackBarUtils.showSuccess(
        context,
        context.l10n.unshareSuccess(sharedMenu.menuTitle),
      );
    } else {
      SnackBarUtils.showError(context, context.l10n.unshareFailed);
    }
  }

  /// Unshare a shopping list — routes the delete through the shopping
  /// view-model (which owns the repository call) instead of the view.
  static Future<void> unshareShoppingList(
    BuildContext context,
    SharedContentCoordinatorViewModel viewModel,
    SharedShoppingList sharedShoppingList,
  ) async {
    final confirmed = await CommonDialogActions.showActionConfirmation(
      context: context,
      title: context.l10n.unshareShoppingListTitle,
      message: context.l10n.unshareShoppingListConfirm(
        sharedShoppingList.listName,
      ),
      confirmText: context.l10n.unshareButton,
      icon: Icons.link_off,
      isDangerous: true,
    );

    if (confirmed != true || !context.mounted) return;

    final ok = await viewModel.shoppingViewModel.unshareSharedShoppingList(
      sharedShoppingList,
    );
    if (!context.mounted) return;

    if (ok) {
      SnackBarUtils.showSuccess(
        context,
        context.l10n.unshareSuccess(sharedShoppingList.listName),
      );
    } else {
      SnackBarUtils.showError(context, context.l10n.unshareFailed);
    }
  }
}
