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

/// SharedContentActions - Action methods for shared content
///
/// Handles import, dismiss, and other actions for shared content.
class SharedContentActions {
  /// Import a shared recipe
  static Future<void> importRecipe(
    BuildContext context,
    SharedContentCoordinatorViewModel viewModel,
    SharedRecipe sharedRecipe,
  ) async {
    final recipeId = await viewModel.recipeViewModel.importSharedRecipe(sharedRecipe);

    if (recipeId != null && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              '✅ Recept "${sharedRecipe.recipeSnapshot.title}" importerat!'),
          backgroundColor: AppColors.success,
        ),
      );
    } else if (context.mounted && viewModel.recipeViewModel.hasError) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(viewModel.recipeViewModel.error ?? 'Import misslyckades'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  /// Import a shared menu
  static Future<void> importMenu(
    BuildContext context,
    SharedContentCoordinatorViewModel viewModel,
    SharedMenu sharedMenu,
  ) async {
    final menuId = await viewModel.menuViewModel.importSharedMenu(sharedMenu);

    if (menuId != null && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✅ Meny "${sharedMenu.menuTitle}" importerad!'),
          backgroundColor: AppColors.success,
        ),
      );
    } else if (context.mounted && viewModel.menuViewModel.hasError) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(viewModel.menuViewModel.error ?? 'Import misslyckades'),
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
        title: const Text('Dölj recept'),
        content: Text(
          'Vill du dölja "${sharedRecipe.recipeSnapshot.title}" från din lista?\n\n'
          'Du kan fortfarande komma åt receptet genom att söka eller be '
          '${sharedRecipe.sharedByDisplayName} att dela det igen.',
        ),
        actions: [
          ActionButtons.secondaryButton(
            context,
            label: 'Avbryt',
            onPressed: () => Navigator.pop(context, false),
          ),
          ActionButtons.primaryButton(
            context,
            label: 'Dölj',
            onPressed: () => Navigator.pop(context, true),
          ),
        ],
      ),
    );

    if (shouldDismiss == true) {
      final success = await viewModel.recipeViewModel.dismissSharedRecipe(sharedRecipe);

      if (success && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                '✅ "${sharedRecipe.recipeSnapshot.title}" dolt från din lista'),
            backgroundColor: AppColors.success,
            action: SnackBarAction(
              label: 'Ångra',
              onPressed: () => viewModel.recipeViewModel.undismissSharedRecipe(sharedRecipe),
            ),
          ),
        );
      } else if (context.mounted && viewModel.recipeViewModel.hasError) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(viewModel.recipeViewModel.error ?? 'Kunde inte dölja recept'),
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
        title: const Text('Dölj meny'),
        content: Text(
          'Vill du dölja "${sharedMenu.menuTitle}" från din lista?\n\n'
          'Du kan fortfarande komma åt menyn genom att be '
          '${sharedMenu.sharedByDisplayName} att dela den igen.',
        ),
        actions: [
          ActionButtons.secondaryButton(
            context,
            label: 'Avbryt',
            onPressed: () => Navigator.pop(context, false),
          ),
          ActionButtons.primaryButton(
            context,
            label: 'Dölj',
            onPressed: () => Navigator.pop(context, true),
          ),
        ],
      ),
    );

    if (shouldDismiss == true) {
      final success = await viewModel.menuViewModel.dismissSharedMenu(sharedMenu);

      if (success && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ "${sharedMenu.menuTitle}" dold från din lista'),
            backgroundColor: AppColors.success,
            action: SnackBarAction(
              label: 'Ångra',
              onPressed: () => viewModel.menuViewModel.undismissSharedMenu(sharedMenu),
            ),
          ),
        );
      } else if (context.mounted && viewModel.menuViewModel.hasError) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(viewModel.menuViewModel.error ?? 'Kunde inte dölja meny'),
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
    AppLogger.info('🚀 AUTO-NAV DEBUG: Starting SharedContentActions.joinShoppingList');
    AppLogger.info('🚀 AUTO-NAV DEBUG: Joining shared list: "${sharedShoppingList.listName}"');

    final collaborativeListId = await viewModel.shoppingViewModel.joinSharedShoppingList(sharedShoppingList);
    AppLogger.info('🔄 AUTO-NAV DEBUG: joinSharedShoppingList returned: $collaborativeListId');

    if (collaborativeListId != null && context.mounted) {
      AppLogger.success('✅ AUTO-NAV DEBUG: Got valid collaborative list ID, proceeding with navigation');
      
      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              '✅ Du är nu medlem i "${sharedShoppingList.listName}"!'),
          backgroundColor: AppColors.success,
        ),
      );

      // AUTO-NAVIGATION: Set collaborative list as active and navigate to unified interface  
      AppLogger.info('🚀 AUTO-NAV DEBUG: ULTRATHINK FIX - Using unified shopping interface for collaborative list: $collaborativeListId');
      
      // ULTRATHINK FIX: Set collaborative list as active and navigate to main shopping interface
      AppLogger.info('🔄 AUTO-NAV DEBUG: Setting collaborative list as active before navigation');
      
      try {
        // First, set the collaborative list as the active list in the shopping service
        final shoppingService = ServiceLocator.get<UnifiedShoppingService>();
        await shoppingService.setActiveList(collaborativeListId);
        AppLogger.success('✅ AUTO-NAV DEBUG: Successfully set collaborative list as active: $collaborativeListId');
        
        // Navigate to the main unified shopping interface instead of separate collaborative view
        if (context.mounted) {
          await AppRouter.navigateTo(
            context,
            Routes.inkopslista, // Use main shopping interface for collaborative lists
          );
        }
        AppLogger.success('✅ AUTO-NAV DEBUG: Successfully navigated to unified shopping interface with collaborative list active');
      } catch (e) {
        AppLogger.error('❌ AUTO-NAV DEBUG: Failed to set active list or navigate to unified shopping: $e');
        
        // FALLBACK: Still try to navigate to shopping interface without setting active list
        AppLogger.info('🔄 AUTO-NAV DEBUG: Attempting fallback navigation to unified shopping view');
        try {
          if (context.mounted) {
            await AppRouter.navigateTo(
              context,
              Routes.inkopslista,
            );
          }
          AppLogger.success('✅ AUTO-NAV DEBUG: Fallback navigation to unified shopping view succeeded');
          
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('✅ Du är nu medlem i "${sharedShoppingList.listName}"! Hitta den delade listan i inköpslistor.'),
                backgroundColor: AppColors.success,
                duration: const Duration(seconds: 4),
              ),
            );
          }
        } catch (fallbackError) {
          AppLogger.error('❌ AUTO-NAV DEBUG: Fallback navigation also failed: $fallbackError');
          
          // Show error to user since both navigation attempts failed
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('⚠️ Du är nu medlem i listan, men kunde inte navigera dit automatiskt. Hitta listan i "Inköpslistor".'),
                backgroundColor: AppColors.warning,
                duration: Duration(seconds: 5),
              ),
            );
          }
        }
      }
    } else if (collaborativeListId == null && context.mounted) {
      AppLogger.error('❌ AUTO-NAV DEBUG: joinSharedShoppingList returned null - join failed');

      if (viewModel.shoppingViewModel.hasError) {
        AppLogger.error('❌ AUTO-NAV DEBUG: ViewModel has error: ${viewModel.shoppingViewModel.error}');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(viewModel.shoppingViewModel.error ?? 'Kunde inte gå med i listan'),
            backgroundColor: AppColors.error,
          ),
        );
      } else {
        AppLogger.error('❌ AUTO-NAV DEBUG: No specific error in ViewModel - showing generic message');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Kunde inte gå med i listan. Försök igen.'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } else if (!context.mounted) {
      AppLogger.warning('⚠️ AUTO-NAV DEBUG: Context not mounted, skipping UI updates');
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
        title: const Text('Dölj inköpslista'),
        content: Text(
          'Vill du dölja "${sharedShoppingList.listName}" från din lista?\n\n'
          'Du kan fortfarande komma åt listan genom att be '
          '${sharedShoppingList.sharedByDisplayName} att dela den igen.',
        ),
        actions: [
          ActionButtons.secondaryButton(
            context,
            label: 'Avbryt',
            onPressed: () => Navigator.pop(context, false),
          ),
          ActionButtons.primaryButton(
            context,
            label: 'Dölj',
            onPressed: () => Navigator.pop(context, true),
          ),
        ],
      ),
    );

    if (shouldDismiss == true) {
      final success = await viewModel.shoppingViewModel.dismissSharedShoppingList(sharedShoppingList);

      if (success && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ "${sharedShoppingList.listName}" dold från din lista'),
            backgroundColor: AppColors.success,
            action: SnackBarAction(
              label: 'Ångra',
              onPressed: () => viewModel.shoppingViewModel.undismissSharedShoppingList(sharedShoppingList),
            ),
          ),
        );
      } else if (context.mounted && viewModel.shoppingViewModel.hasError) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(viewModel.shoppingViewModel.error ?? 'Kunde inte dölja inköpslista'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }
}