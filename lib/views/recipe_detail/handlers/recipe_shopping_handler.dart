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

/// Recipe shopping list action handler
///
/// Handles shopping list generation from recipe ingredients with portion scaling.
class RecipeShoppingHandler {
  /// Generate shopping list from current recipe with portion scaling and Swedish categorization.
  ///
  /// This method creates a shopping list from the recipe's ingredients, allowing users to
  /// select an existing shopping list or create a new one. It leverages Swedish ingredient
  /// parsing and intelligent categorization for optimal shopping organization.
  ///
  /// **Process Flow:**
  /// 1. Generate UnifiedShoppingItem objects from recipe ingredients
  /// 2. Show shopping list selection dialog (existing lists + create new option)
  /// 3. Add items to selected shopping list using batch operations
  /// 4. Provide success feedback with navigation option to shopping view
  /// 5. Handle errors gracefully with user feedback
  ///
  /// **Features:**
  /// - Portion scaling based on current recipe portions
  /// - Swedish ingredient categorization (Mejeri, Kött & Fisk, etc.)
  /// - Batch addition for optimal performance
  /// - User-friendly shopping list selection
  /// - Success feedback with navigation option
  static Future<void> generateShoppingListFromRecipe(
    BuildContext context, {
    required int currentPortions,
    required void Function(String message, {Color? backgroundColor}) showSnackBar,
  }) async {
    if (!context.mounted) return;

    try {
      final viewModel = context.read<RecipeDetailViewModel>();
      final shoppingService = ServiceLocator.get<UnifiedShoppingService>();
      final recipe = viewModel.recipe;

      // Generate shopping items from recipe using current portions
      final shoppingItems = ShoppingListGenerator.generateShoppingItemsFromRecipe(
        recipe,
        portions: currentPortions,
      );

      if (shoppingItems.isEmpty) {
        if (!context.mounted) return;
        showSnackBar(
          'Receptet har inga ingredienser att lägga till',
          backgroundColor: AppColors.warning,
        );
        return;
      }

      // Show shopping list selection dialog
      if (!context.mounted) return;
      final selectedListResult = await showDialog<Map<String, dynamic>>(
        context: context,
        builder: (context) => ShoppingListSelectionDialog(
          title: 'Välj inköpslista',
          subtitle: 'Lägg till ingredienser från "${recipe.title}"',
          shoppingService: shoppingService,
        ),
      );

      if (selectedListResult == null || !context.mounted) return;

      // Handle the selection result
      String? targetListId;
      String? targetListName;

      if (selectedListResult['action'] == 'create_new') {
        // Create new shopping list with recipe name
        final newListName = selectedListResult['name'] as String? ?? '${recipe.title} - Ingredienser';
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
            'Kunde inte skapa eller välja inköpslista',
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
            'Du har inte behörighet att redigera denna inköpslista',
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
            title: const Text('Inköpslista skapad!'),
            content: Text(
              '${shoppingItems.length} ingredienser har lagts till i "${targetListName ?? 'din inköpslista'}".\n\n'
              'Vill du gå till inköpslistan nu?',
            ),
            actions: [
              ActionButtons.secondaryButton(
                context,
                label: 'Senare',
                onPressed: () => Navigator.pop(context, false),
              ),
              ActionButtons.primaryButton(
                context,
                label: 'Visa lista',
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
          'Kunde inte lägga till ingredienser i inköpslistan',
          backgroundColor: AppColors.error,
        );
      }
    } catch (e) {
      if (!context.mounted) return;

      // Handle specific permission errors with clear Swedish messages
      if (e is PermissionDeniedException) {
        showSnackBar(
          'Du har inte behörighet att redigera denna delade inköpslista',
          backgroundColor: AppColors.error,
        );
      } else {
        showSnackBar(
          'Ett fel uppstod: ${e.toString()}',
          backgroundColor: AppColors.error,
        );
      }
    }
  }
}
