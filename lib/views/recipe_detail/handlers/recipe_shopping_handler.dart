// lib/views/recipe_detail/handlers/recipe_shopping_handler.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:butlery/viewmodels/recipe_detail_viewmodel.dart';
import 'package:butlery/theme/app_colors.dart';
import 'package:butlery/core/constants/routes.dart';
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/services/unified/unified_shopping_service.dart';
import 'package:butlery/utils/text/shopping_list_generator.dart';
import 'package:butlery/widgets/common/dialogs/shopping_list_selection_dialog.dart';
import 'package:butlery/services/permission_service.dart';
import 'package:butlery/core/exceptions/permission_exceptions.dart';
import 'package:butlery/widgets/common/buttons/action_buttons.dart';
import 'package:butlery/core/extensions/localization_extension.dart';

/// Recipe shopping list action handler
/// Handles shopping list generation from recipe ingredients with portion scaling.
class RecipeShoppingHandler {
  /// Show confirmation dialog with ingredient preview before adding to shopping list.
  /// UI Redesign: FAB triggers this dialog first to show what will be added.
  static Future<void> showAddToCartConfirmation(
    BuildContext context, {
    required int currentPortions,
    required void Function(String message, {Color? backgroundColor})
        showSnackBar,
  }) async {
    if (!context.mounted) return;

    final viewModel = context.read<RecipeDetailViewModel>();
    final recipe = viewModel.recipe;

    // Generate shopping items from recipe
    final shoppingItems = ShoppingListGenerator.generateShoppingItemsFromRecipe(
      recipe,
      portions: currentPortions,
    );

    if (shoppingItems.isEmpty) {
      showSnackBar(
        context.l10n.shoppingNoIngredientsToAdd,
        backgroundColor: AppColors.warning,
      );
      return;
    }

    // Show confirmation dialog with ingredient list
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(context.l10n.shoppingAddToShoppingList),
        content: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                context.l10n.shoppingIngredientsFromRecipe(
                    shoppingItems.length, recipe.title),
                style: const TextStyle(fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 12),
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 300),
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: shoppingItems.length,
                  itemBuilder: (context, index) {
                    final item = shoppingItems[index];
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: AppColors.forestGreen,
                              borderRadius: BorderRadius.circular(0),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              item.name,
                              style: const TextStyle(fontSize: 14),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(context.l10n.commonCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.forestGreen,
            ),
            child: Text(context.l10n.commonAdd),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;

    // Proceed with shopping list selection
    await generateShoppingListFromRecipe(
      context,
      currentPortions: currentPortions,
      showSnackBar: showSnackBar,
    );
  }

  /// Generate shopping list from current recipe with portion scaling and Swedish categorization.
  /// This method creates a shopping list from the recipe's ingredients, allowing users to
  /// select an existing shopping list or create a new one. It leverages Swedish ingredient
  /// parsing and intelligent categorization for optimal shopping organization.
  /// **Process Flow:**
  /// 1. Generate UnifiedShoppingItem objects from recipe ingredients
  /// 2. Show shopping list selection dialog (existing lists + create new option)
  /// 3. Add items to selected shopping list using batch operations
  /// 4. Provide success feedback with navigation option to shopping view
  /// 5. Handle errors gracefully with user feedback
  /// **Features:**
  /// - Portion scaling based on current recipe portions
  /// - Swedish ingredient categorization (Mejeri, Kött & Fisk, etc.)
  /// - Batch addition for optimal performance
  /// - User-friendly shopping list selection
  /// - Success feedback with navigation option
  static Future<void> generateShoppingListFromRecipe(
    BuildContext context, {
    required int currentPortions,
    required void Function(String message, {Color? backgroundColor})
        showSnackBar,
  }) async {
    if (!context.mounted) return;

    try {
      final viewModel = context.read<RecipeDetailViewModel>();
      final shoppingService = ServiceLocator.get<UnifiedShoppingService>();
      final recipe = viewModel.recipe;

      // Generate shopping items from recipe using current portions
      final shoppingItems =
          ShoppingListGenerator.generateShoppingItemsFromRecipe(
        recipe,
        portions: currentPortions,
      );

      if (shoppingItems.isEmpty) {
        if (!context.mounted) return;
        showSnackBar(
          context.l10n.shoppingNoIngredientsToAdd,
          backgroundColor: AppColors.warning,
        );
        return;
      }

      // Show shopping list selection dialog
      if (!context.mounted) return;
      final selectedListResult = await showDialog<Map<String, dynamic>>(
        context: context,
        builder: (context) => ShoppingListSelectionDialog(
          title: context.l10n.shoppingSelectList,
          subtitle: context.l10n.shoppingAddIngredientsFrom(recipe.title),
          shoppingService: shoppingService,
        ),
      );

      if (selectedListResult == null || !context.mounted) return;

      // Handle the selection result
      String? targetListId;
      String? targetListName;

      if (selectedListResult['action'] == 'create_new') {
        // Create new shopping list with recipe name
        final newListName = selectedListResult['name'] as String? ??
            '${recipe.title} - Ingredienser';
        targetListId = await shoppingService.createPersonalList(newListName);
        targetListName = newListName;
      } else if (selectedListResult['action'] == 'select_existing') {
        // Use existing list
        targetListId = selectedListResult['listId'] as String?;
        targetListName = selectedListResult['listName'] as String?;
      }

      if (targetListId == null) {
        if (context.mounted) {
          showSnackBar(
            context.l10n.shoppingCouldNotCreateOrSelectList,
            backgroundColor: AppColors.error,
          );
        }
        return;
      }

      if (!context.mounted) return;

      // Set the target list as active and validate permissions
      await shoppingService.setActiveList(targetListId);

      // Pre-validate edit permissions for better user feedback
      final permissionService = ServiceLocator.get<PermissionService>();
      if (!permissionService.canEditShoppingList(targetListId)) {
        if (context.mounted) {
          showSnackBar(
            context.l10n.shoppingNoEditPermission,
            backgroundColor: AppColors.error,
          );
        }
        return;
      }

      final success = await shoppingService.addItemsBatch(shoppingItems);

      if (!context.mounted) return;
      if (success) {
        // Success feedback with navigation option
        final shouldNavigate = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(context.l10n.shoppingListCreated(
                targetListName ?? context.l10n.shoppingYourList)),
            content: Text(
              context.l10n.shoppingIngredientsAddedToList(shoppingItems.length,
                  targetListName ?? context.l10n.shoppingYourList),
            ),
            actions: [
              ActionButtons.secondaryButton(
                context,
                label: context.l10n.commonLater,
                onPressed: () => Navigator.pop(context, false),
              ),
              ActionButtons.primaryButton(
                context,
                label: context.l10n.shoppingViewList,
                onPressed: () => Navigator.pop(context, true),
              ),
            ],
          ),
        );

        if (shouldNavigate == true && context.mounted) {
          // Navigate to shopping view
          Navigator.pushNamed(context, Routes.inkopslista);
        }
      } else {
        showSnackBar(
          context.l10n.shoppingCouldNotAddIngredients,
          backgroundColor: AppColors.error,
        );
      }
    } catch (e) {
      if (!context.mounted) return;

      // Handle specific permission errors with clear Swedish messages
      if (e is PermissionDeniedException) {
        showSnackBar(
          context.l10n.shoppingNoEditPermissionShared,
          backgroundColor: AppColors.error,
        );
      } else {
        showSnackBar(
          context.l10n.errorOccurredWithDetails(e.toString()),
          backgroundColor: AppColors.error,
        );
      }
    }
  }
}
