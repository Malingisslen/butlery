// lib/views/social/shared_with_me/shared_content_actions.dart

import 'package:flutter/material.dart';
import 'package:butlery/theme/app_colors.dart';
import 'package:butlery/viewmodels/shared_content/shared_content_coordinator_viewmodel.dart';
import 'package:butlery/models/shared_recipe.dart';
import 'package:butlery/models/shared_menu.dart';
import 'package:butlery/models/shared_shopping_list.dart';
import 'package:butlery/core/router/app_router.dart';
import 'package:butlery/core/constants/routes.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/services/unified/unified_shopping_service.dart';
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
          backgroundColor: AppColors.success,
        ),
      );
    } else if (context.mounted && viewModel.recipeViewModel.hasError) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(viewModel.recipeViewModel.error ??
              context.l10n.sharedImportFailed),
          backgroundColor: AppColors.error,
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
            backgroundColor: AppColors.primary,
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
            backgroundColor: AppColors.success,
          ),
        );
      }
    } else if (context.mounted && viewModel.menuViewModel.hasError) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              viewModel.menuViewModel.error ?? context.l10n.sharedImportFailed),
          backgroundColor: AppColors.error,
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
            backgroundColor: AppColors.success,
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
            backgroundColor: AppColors.error,
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
            backgroundColor: AppColors.success,
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
            backgroundColor: AppColors.error,
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
          backgroundColor: AppColors.success,
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
                .inkopslista, // Use main shopping interface for collaborative lists
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
              Routes.inkopslista,
            );
          }

          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(context.l10n.sharedJoinedListFindInShopping(
                    sharedShoppingList.listName)),
                backgroundColor: AppColors.success,
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
                backgroundColor: AppColors.warning,
                duration: Duration(seconds: 5),
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
            backgroundColor: AppColors.error,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.l10n.sharedCouldNotJoinListTryAgain),
            backgroundColor: AppColors.error,
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
            backgroundColor: AppColors.success,
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
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }
}
