// lib/views/social/shared_with_me/shared_content_actions.dart

import 'package:flutter/material.dart';
import 'package:butlery/theme/butlery_colors_extension.dart';
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
import 'package:butlery/repositories/firebase/firebase_shared_shopping_repository.dart';
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
    final recipeId =
        await viewModel.recipeViewModel.importSharedRecipe(sharedRecipe);

    if (recipeId != null && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content:
              Text(context.l10n.sharedRecipeImported(sharedRecipe.recipeTitle)),
          backgroundColor: context.butleryColors.success,
        ),
      );
    } else if (context.mounted && viewModel.recipeViewModel.hasError) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(viewModel.recipeViewModel.error ??
              context.l10n.sharedImportFailed),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.l10n
                .sharedConnectingToCollaborativeMenu(sharedMenu.menuTitle)),
            backgroundColor: Theme.of(context).colorScheme.primary,
            duration: const Duration(seconds: 2),
          ),
        );
        // Navigate to the realtime menu view
        AppRouter.navigateTo(
          context,
          Routes.realtimeMenu,
          arguments: {'menuId': result.menuId},
        );
      } else {
        // Regular menu import
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content:
                Text(context.l10n.sharedMenuImported(sharedMenu.menuTitle)),
            backgroundColor: context.butleryColors.success,
          ),
        );
      }
    } else if (context.mounted && viewModel.menuViewModel.hasError) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              viewModel.menuViewModel.error ?? context.l10n.sharedImportFailed),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
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
              sharedRecipe.recipeTitle, sharedRecipe.sharedByDisplayName),
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
      final success =
          await viewModel.recipeViewModel.dismissSharedRecipe(sharedRecipe);

      if (success && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                context.l10n.sharedContentHidden(sharedRecipe.recipeTitle)),
            backgroundColor: context.butleryColors.success,
            action: SnackBarAction(
              label: context.l10n.commonUndo,
              onPressed: () =>
                  viewModel.recipeViewModel.undismissSharedRecipe(sharedRecipe),
            ),
          ),
        );
      } else if (context.mounted && viewModel.recipeViewModel.hasError) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(viewModel.recipeViewModel.error ??
                context.l10n.sharedCouldNotHideRecipe),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
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
              sharedMenu.menuTitle, sharedMenu.sharedByDisplayName),
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
      final success =
          await viewModel.menuViewModel.dismissSharedMenu(sharedMenu);

      if (success && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content:
                Text(context.l10n.sharedContentHidden(sharedMenu.menuTitle)),
            backgroundColor: context.butleryColors.success,
            action: SnackBarAction(
              label: context.l10n.commonUndo,
              onPressed: () =>
                  viewModel.menuViewModel.undismissSharedMenu(sharedMenu),
            ),
          ),
        );
      } else if (context.mounted && viewModel.menuViewModel.hasError) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(viewModel.menuViewModel.error ??
                context.l10n.sharedCouldNotHideMenu),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content:
              Text(context.l10n.sharedJoinedList(sharedShoppingList.listName)),
          backgroundColor: context.butleryColors.success,
        ),
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
            'Failed to set active list or navigate to unified shopping: $e');

        // FALLBACK: Still try to navigate to shopping interface without setting active list
        try {
          if (context.mounted) {
            await AppRouter.navigateTo(
              context,
              Routes.shoppingList,
            );
          }

          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(context.l10n.sharedJoinedListFindInShopping(
                    sharedShoppingList.listName)),
                backgroundColor: context.butleryColors.success,
                duration: const Duration(seconds: 4),
              ),
            );
          }
        } catch (fallbackError) {
          AppLogger.error('Fallback navigation also failed: $fallbackError');

          // Show error to user since both navigation attempts failed
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(context.l10n.sharedJoinedButCouldNotNavigate),
                backgroundColor: context.butleryColors.warning,
                duration: const Duration(seconds: 5),
              ),
            );
          }
        }
      }
    } else if (collaborativeListId == null && context.mounted) {
      if (viewModel.shoppingViewModel.hasError) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(viewModel.shoppingViewModel.error ??
                context.l10n.sharedCouldNotJoinList),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.l10n.sharedCouldNotJoinListTryAgain),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
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
              sharedShoppingList.sharedByDisplayName),
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                context.l10n.sharedContentHidden(sharedShoppingList.listName)),
            backgroundColor: context.butleryColors.success,
            action: SnackBarAction(
              label: context.l10n.commonUndo,
              onPressed: () => viewModel.shoppingViewModel
                  .undismissSharedShoppingList(sharedShoppingList),
            ),
          ),
        );
      } else if (context.mounted && viewModel.shoppingViewModel.hasError) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(viewModel.shoppingViewModel.error ??
                context.l10n.sharedCouldNotHideShoppingList),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
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
      final success =
          await coordinator.unshareRecipe(sharedRecipe.originalRecipeId);

      if (!context.mounted) return;

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content:
                Text(context.l10n.unshareSuccess(sharedRecipe.recipeTitle)),
            backgroundColor: context.butleryColors.success,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.l10n.unshareFailed),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    } catch (e) {
      AppLogger.error('Failed to unshare recipe', e);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.l10n.unshareFailed),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.l10n.unshareSuccess(sharedMenu.menuTitle)),
          backgroundColor: context.butleryColors.success,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.l10n.unshareFailed),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    }
  }

  /// Unshare a shopping list - deletes the shared shopping list document
  static Future<void> unshareShoppingList(
    BuildContext context,
    SharedShoppingList sharedShoppingList,
  ) async {
    final confirmed = await CommonDialogActions.showActionConfirmation(
      context: context,
      title: context.l10n.unshareShoppingListTitle,
      message:
          context.l10n.unshareShoppingListConfirm(sharedShoppingList.listName),
      confirmText: context.l10n.unshareButton,
      icon: Icons.link_off,
      isDangerous: true,
    );

    if (confirmed != true || !context.mounted) return;

    try {
      final repo = ServiceLocator.get<FirebaseSharedShoppingRepository>();
      await repo.deleteSharedContent(sharedShoppingList.id);

      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content:
              Text(context.l10n.unshareSuccess(sharedShoppingList.listName)),
          backgroundColor: context.butleryColors.success,
        ),
      );
    } catch (e) {
      AppLogger.error('Failed to unshare shopping list', e);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.l10n.unshareFailed),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }
}
