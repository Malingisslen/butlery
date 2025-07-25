// lib/views/social/shared_with_me/shared_content_actions_refactored.dart

import 'package:flutter/material.dart';
import '../../../core/base/base_action_handler.dart';
import '../../../viewmodels/shared_content_viewmodel.dart';
import '../../../models/shared_recipe.dart';
import '../../../models/shared_menu.dart';

/// Refactored SharedContentActions using BaseActionHandler
/// 
/// This demonstrates standardized content management patterns using:
/// - BaseActionHandler for consistent import/dismiss operations
/// - ActionStateMixin for loading state during import operations
/// - Standardized confirmation flows for destructive actions
/// - Proper error handling and user feedback
class SharedContentActionsRefactored extends BaseActionHandler with ActionStateMixin {
  @override
  String get serviceName => 'SharedContentActions';

  // ===== RECIPE IMPORT/DISMISS ACTIONS =====

  /// Import a shared recipe with loading state and validation
  Future<bool> importRecipe(
    BuildContext context,
    SharedContentViewModel viewModel,
    SharedRecipe sharedRecipe,
  ) async {
    if (!validateContext(context) || 
        !validateRequired([sharedRecipe.id], 'importing recipe')) {
      return false;
    }

    final result = await executeWithLoadingState<bool>(
      context: context,
      action: () => viewModel.importSharedRecipe(sharedRecipe),
      successMessage: '✅ Recept "${sharedRecipe.recipeSnapshot.title}" importerat!',
      errorMessage: viewModel.hasError ? viewModel.error! : 'Kunde inte importera recept',
      metadata: {
        'recipe_id': sharedRecipe.id,
        'recipe_title': sharedRecipe.recipeSnapshot.title,
        'shared_by': sharedRecipe.sharedByDisplayName,
        'action': 'import_recipe',
      },
    );

    return result ?? false;
  }

  /// Dismiss a shared recipe with confirmation
  Future<bool> dismissRecipe(
    BuildContext context,
    SharedContentViewModel viewModel,
    SharedRecipe sharedRecipe,
  ) async {
    if (!validateContext(context) || 
        !validateRequired([sharedRecipe.id], 'dismissing recipe')) {
      return false;
    }

    return await executeWithConfirmation<bool>(
      context: context,
      action: () => viewModel.dismissSharedRecipe(sharedRecipe),
      confirmationTitle: 'Dölj recept',
      confirmationMessage: 
          'Vill du dölja "${sharedRecipe.recipeSnapshot.title}" från din lista?\n\n'
          'Du kan fortfarande komma åt receptet genom att söka eller be '
          '${sharedRecipe.sharedByDisplayName} att dela det igen.',
      confirmActionText: 'Dölj',
      confirmationIcon: Icons.visibility_off,
      successMessage: '✅ "${sharedRecipe.recipeSnapshot.title}" dolt från din lista',
      errorMessage: viewModel.hasError ? viewModel.error! : 'Kunde inte dölja recept',
      metadata: {
        'recipe_id': sharedRecipe.id,
        'recipe_title': sharedRecipe.recipeSnapshot.title,
        'shared_by': sharedRecipe.sharedByDisplayName,
        'action': 'dismiss_recipe',
      },
    ) ?? false;
  }

  /// Mark recipe as viewed
  Future<bool> markRecipeAsViewed(
    BuildContext context,
    SharedContentViewModel viewModel,
    SharedRecipe sharedRecipe,
  ) async {
    if (!validateContext(context) || 
        !validateRequired([sharedRecipe.id], 'marking recipe as viewed')) {
      return false;
    }

    return await executeAction<bool>(
      context: context,
      action: () async {
        // Simulate marking as viewed
        await Future.delayed(const Duration(milliseconds: 200));
        return true;
      },
      logAction: true,
      metadata: {
        'recipe_id': sharedRecipe.id,
        'recipe_title': sharedRecipe.recipeSnapshot.title,
        'shared_by': sharedRecipe.sharedByDisplayName,
        'action': 'mark_viewed',
      },
    ) ?? false;
  }

  // ===== MENU IMPORT/DISMISS ACTIONS =====

  /// Import a shared menu with validation and feedback
  Future<bool> importMenu(
    BuildContext context,
    SharedContentViewModel viewModel,
    SharedMenu sharedMenu,
  ) async {
    if (!validateContext(context) || 
        !validateRequired([sharedMenu.id], 'importing menu')) {
      return false;
    }

    final result = await executeWithLoadingState<bool>(
      context: context,
      action: () => viewModel.importSharedMenu(sharedMenu),
      successMessage: '✅ Meny "${sharedMenu.menuTitle}" importerad!',
      errorMessage: viewModel.hasError ? viewModel.error! : 'Kunde inte importera meny',
      metadata: {
        'menu_id': sharedMenu.id,
        'menu_title': sharedMenu.menuTitle,
        'shared_by': sharedMenu.sharedByDisplayName,
        'recipe_count': sharedMenu.totalRecipeCount,
        'action': 'import_menu',
      },
    );

    return result ?? false;
  }

  /// Dismiss a shared menu with confirmation
  Future<bool> dismissMenu(
    BuildContext context,
    SharedContentViewModel viewModel,
    SharedMenu sharedMenu,
  ) async {
    if (!validateContext(context) || 
        !validateRequired([sharedMenu.id], 'dismissing menu')) {
      return false;
    }

    return await executeWithConfirmation<bool>(
      context: context,
      action: () => viewModel.dismissSharedMenu(sharedMenu),
      confirmationTitle: 'Dölj meny',
      confirmationMessage: 
          'Vill du dölja menyn "${sharedMenu.menuTitle}" från din lista?\n\n'
          'Menyn innehåller ${sharedMenu.totalRecipeCount} recept som delats av ${sharedMenu.sharedByDisplayName}.',
      confirmActionText: 'Dölj',
      confirmationIcon: Icons.visibility_off,
      successMessage: '✅ Meny "${sharedMenu.menuTitle}" dold från din lista',
      errorMessage: viewModel.hasError ? viewModel.error! : 'Kunde inte dölja meny',
      metadata: {
        'menu_id': sharedMenu.id,
        'menu_title': sharedMenu.menuTitle,
        'shared_by': sharedMenu.sharedByDisplayName,
        'recipe_count': sharedMenu.totalRecipeCount,
        'action': 'dismiss_menu',
      },
    ) ?? false;
  }


  // ===== BULK OPERATIONS =====

  /// Import multiple items with progress feedback
  Future<int> importMultipleItems(
    BuildContext context,
    SharedContentViewModel viewModel,
    List<dynamic> items,
  ) async {
    if (!validateContext(context) || items.isEmpty) {
      showErrorMessage(context, 'Inga objekt att importera');
      return 0;
    }

    showLoadingDialog(context, 'Importerar ${items.length} objekt...');
    
    int successCount = 0;
    
    try {
      for (int i = 0; i < items.length; i++) {
        final item = items[i];
        bool success = false;

        if (item is SharedRecipe) {
          success = await viewModel.importSharedRecipe(item);
        } else if (item is SharedMenu) {
          success = await viewModel.importSharedMenu(item);
        }

        if (success) {
          successCount++;
        }

        // Update progress
        // In a real implementation, you might show progress updates
      }

      if (context.mounted) {
        hideLoadingDialog(context);

        if (successCount > 0) {
          showSuccessMessage(
            context,
            '$successCount av ${items.length} objekt importerade framgångsrikt',
          );
        } else {
          showErrorMessage(context, 'Kunde inte importera några objekt');
        }
      }

      return successCount;

    } catch (e) {
      if (context.mounted) {
        hideLoadingDialog(context);
        showErrorMessage(context, 'Fel vid import av objekt: $e');
      }
      return successCount;
    }
  }

  /// Dismiss all items with confirmation
  Future<bool> dismissAllItems(
    BuildContext context,
    SharedContentViewModel viewModel,
    List<dynamic> items,
  ) async {
    if (!validateContext(context) || items.isEmpty) {
      showErrorMessage(context, 'Inga objekt att dölja');
      return false;
    }

    return await executeWithConfirmation<bool>(
      context: context,
      action: () async {
        int successCount = 0;
        
        for (final item in items) {
          bool success = false;
          
          if (item is SharedRecipe) {
            success = await viewModel.dismissSharedRecipe(item);
          } else if (item is SharedMenu) {
            success = await viewModel.dismissSharedMenu(item);
          }
          
          if (success) successCount++;
        }
        
        return successCount > 0;
      },
      confirmationTitle: 'Dölj alla objekt',
      confirmationMessage: 'Vill du dölja alla ${items.length} objekt från din lista?',
      confirmActionText: 'Dölj alla',
      confirmationIcon: Icons.clear_all,
      isDangerous: true,
      successMessage: 'Alla objekt har dolts från din lista',
      errorMessage: 'Kunde inte dölja alla objekt',
      metadata: {
        'item_count': items.length,
        'action': 'dismiss_all',
      },
    ) ?? false;
  }

  // ===== FILTERING AND SORTING ACTIONS =====

  /// Filter content by type
  Future<void> filterByType(
    BuildContext context,
    SharedContentViewModel viewModel,
    String contentType,
  ) async {
    if (!validateContext(context)) return;

    await executeAction(
      context: context,
      action: () async {
        // Simulate filtering
        await Future.delayed(const Duration(milliseconds: 200));
        return true;
      },
      successMessage: 'Filtrerat innehåll efter typ: $contentType',
      metadata: {
        'content_type': contentType,
        'action': 'filter_by_type',
      },
    );
  }

  /// Sort content by date or name
  Future<void> sortContent(
    BuildContext context,
    SharedContentViewModel viewModel,
    String sortBy,
  ) async {
    if (!validateContext(context)) return;

    await executeAction(
      context: context,
      action: () async {
        // Simulate sorting
        await Future.delayed(const Duration(milliseconds: 200));
        return true;
      },
      successMessage: 'Innehåll sorterat efter: $sortBy',
      metadata: {
        'sort_by': sortBy,
        'action': 'sort_content',
      },
    );
  }

  // ===== SEARCH ACTIONS =====

  /// Search shared content
  Future<void> searchContent(
    BuildContext context,
    SharedContentViewModel viewModel,
    String query,
  ) async {
    if (!validateContext(context) || query.trim().isEmpty) {
      showErrorMessage(context, 'Ange en sökterm');
      return;
    }

    await executeAction(
      context: context,
      action: () async {
        // Simulate search
        await Future.delayed(const Duration(milliseconds: 300));
        return true;
      },
      logAction: true,
      metadata: {
        'search_query': query,
        'action': 'search_content',
      },
    );
  }

  // ===== CLEANUP =====

  /// Dispose resources
  void dispose() {
    clearError();
  }
}