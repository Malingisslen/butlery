// lib/views/recipe_detail/handlers/recipe_shopping_handler.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:butlery/core/extensions/default_value_extensions.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/viewmodels/recipe_detail_viewmodel.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/core/constants/routes.dart';
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/services/unified/unified_shopping_service.dart';
import 'package:butlery/utils/text/shopping_list_generator.dart';
import 'package:butlery/widgets/common/dialogs/shopping_list_selection_dialog.dart';
import 'package:butlery/services/permission_service.dart';
import 'package:butlery/core/exceptions/permission_exceptions.dart';
import 'package:butlery/widgets/common/buttons/action_buttons.dart';
import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/core/utils/snackbar_utils.dart';
import 'package:butlery/models/pantry/pantry_item.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/models/unified/unified_shopping_item.dart';
import 'package:butlery/services/shopping/recipe_pantry_check.dart';

/// Recipe shopping list action handler
/// Handles shopping list generation from recipe ingredients with portion scaling.
class RecipeShoppingHandler {
  /// Q4-03 = A (produktbeslut 2026-09-24): the recipe at [portions]
  /// against a known [pantry] ([RecipePantryCheck.check]): what the button
  /// adds, and what the pantry covered or lessened, so the dialog can show
  /// that a deduction happened (produktregler.md:233). Null with no known
  /// pantry: every ingredient is then added, as before, since nothing is
  /// left off on a guess.
  static RecipePantryResult? pantryCheck(
    Recipe recipe, {
    required int portions,
    List<PantryItem>? pantry,
  }) {
    if (pantry == null) return null;
    return RecipePantryCheck.check(
      ShoppingListGenerator.generateShoppingItemsFromRecipe(
        recipe,
        portions: portions,
      ),
      pantry,
    );
  }

  /// Q4-03: the items the button adds, at [portions]. With a known
  /// [pantry], what it covers is left off or lessened and marked rows carry
  /// their mark; when it covers everything, this is empty and nothing is
  /// added (produktregler.md:228). The button's count is its length.
  static List<UnifiedShoppingItem> itemsToAdd(
    Recipe recipe, {
    required int portions,
    List<PantryItem>? pantry,
  }) =>
      pantryCheck(recipe, portions: portions, pantry: pantry)?.toBuy ??
      ShoppingListGenerator.generateShoppingItemsFromRecipe(
        recipe,
        portions: portions,
      );

  /// Q6-09 = C (produktbeslut 2026-09-27b): whether the known pantry covers
  /// every ingredient at [portions], so nothing would be added
  /// (produktregler.md:228). The recipe then says "Allt finns hemma" in
  /// place of its add-to-shopping-list button. False while the pantry is not
  /// known.
  static bool coversEverything(
    Recipe recipe, {
    required int portions,
    List<PantryItem>? pantry,
  }) {
    final check = pantryCheck(recipe, portions: portions, pantry: pantry);
    return check != null &&
        check.toBuy.isEmpty &&
        check.coveredAtHome.isNotEmpty;
  }

  /// Q4-03: how many items the button adds, or null when the pantry is not
  /// known or covers everything (the button then says "Lägg i
  /// inköpslistan"; when it covers everything the button is replaced,
  /// [coversEverything]).
  static int? countToBuy(
    Recipe recipe, {
    required int portions,
    List<PantryItem>? pantry,
  }) {
    final count = pantryCheck(
      recipe,
      portions: portions,
      pantry: pantry,
    )?.toBuy.length;
    return count == 0 ? null : count;
  }

  /// Show confirmation dialog with ingredient preview before adding to shopping list.
  /// UI Redesign: FAB triggers this dialog first to show what will be added.
  static Future<void> showAddToCartConfirmation(
    BuildContext context, {
    required int currentPortions,
    List<PantryItem>? pantry,
  }) async {
    if (!context.mounted) return;

    final viewModel = context.read<RecipeDetailViewModel>();
    final recipe = viewModel.recipe;

    // The items the button counted (Q4-03), and what the pantry took.
    final check = pantryCheck(
      recipe,
      portions: currentPortions,
      pantry: pantry,
    );
    final shoppingItems =
        check?.toBuy ??
        ShoppingListGenerator.generateShoppingItemsFromRecipe(
          recipe,
          portions: currentPortions,
        );

    if (shoppingItems.isEmpty && (check?.coveredAtHome.isNotEmpty ?? false)) {
      // Everything is at home: nothing is added, and the user is told so
      // (produktregler.md:228, 233).
      SnackBarUtils.showInfo(
        context,
        context.l10n.recipePantryAllAtHome(check!.coveredAtHome.join(', ')),
      );
      return;
    }

    if (shoppingItems.isEmpty) {
      SnackBarUtils.showWarning(
        context,
        context.l10n.shoppingNoIngredientsToAdd,
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
                  shoppingItems.length,
                  recipe.title,
                ),
                style: const TextStyle(fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: AppDimensions.spacingL),
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 300),
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: shoppingItems.length,
                  itemBuilder: (context, index) {
                    final item = shoppingItems[index];
                    final note = item.note.orEmpty();
                    return Padding(
                      padding: AppDimensions.paddingVertical4,
                      child: Row(
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.onSurface,
                            ),
                          ),
                          const SizedBox(width: AppDimensions.spacingL),
                          // The amount to buy, and the pantry's mark
                          // (Q4-03, produktregler.md:229-233).
                          Expanded(
                            child: Text(
                              note.isEmpty
                                  ? item.displayText
                                  : '${item.displayText} · $note',
                              style: AppTextStyles.bodyMedium,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
              if (check != null && check.coveredAtHome.isNotEmpty) ...[
                const SizedBox(height: AppDimensions.spacingL),
                Text(
                  context.l10n.shoppingMergePantryCovered(
                    check.coveredAtHome.join(', '),
                  ),
                  key: const ValueKey('recipePantryCovered'),
                  style: AppTextStyles.bodyMedium,
                ),
              ],
              if (check != null && check.lessened.isNotEmpty) ...[
                const SizedBox(height: AppDimensions.spacingSm),
                Text(
                  context.l10n.recipePantryLessened(
                    check.lessened.join(', '),
                  ),
                  key: const ValueKey('recipePantryLessened'),
                  style: AppTextStyles.bodyMedium,
                ),
              ],
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
              backgroundColor: Theme.of(context).colorScheme.primary,
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
      pantry: pantry,
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
    List<PantryItem>? pantry,
  }) async {
    if (!context.mounted) return;

    try {
      final viewModel = context.read<RecipeDetailViewModel>();
      final shoppingService = ServiceLocator.get<UnifiedShoppingService>();
      final recipe = viewModel.recipe;

      // The items the button counted (Q4-03), at the current portions.
      final shoppingItems = itemsToAdd(
        recipe,
        portions: currentPortions,
        pantry: pantry,
      );

      if (shoppingItems.isEmpty) {
        if (!context.mounted) return;
        SnackBarUtils.showWarning(
          context,
          context.l10n.shoppingNoIngredientsToAdd,
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
        final newListName =
            selectedListResult['name'] as String? ??
            context.l10n.shoppingNewListNameTemplate(recipe.title);
        targetListId = await shoppingService.createPersonalList(newListName);
        targetListName = newListName;
      } else if (selectedListResult['action'] == 'select_existing') {
        // Use existing list
        targetListId = selectedListResult['listId'] as String?;
        targetListName = selectedListResult['listName'] as String?;
      }

      if (targetListId == null) {
        if (context.mounted) {
          SnackBarUtils.showFailure(
            context,
            what: context.l10n.shoppingCouldNotCreateOrSelectList,
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
          SnackBarUtils.showFailure(
            context,
            what: context.l10n.shoppingNoEditPermission,
          );
        }
        return;
      }

      final success = await shoppingService.addItemsBatch(
        shoppingItems,
        source: 'recipe',
      );

      if (!context.mounted) return;
      if (success) {
        // Success feedback with navigation option
        final shouldNavigate = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(
              context.l10n.shoppingListCreated(
                targetListName ?? context.l10n.shoppingYourList,
              ),
            ),
            content: Text(
              context.l10n.shoppingIngredientsAddedToList(
                shoppingItems.length,
                targetListName ?? context.l10n.shoppingYourList,
              ),
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
          Navigator.pushNamed(context, Routes.shoppingList);
        }
      } else {
        SnackBarUtils.showFailure(
          context,
          what: context.l10n.shoppingCouldNotAddIngredients,
        );
      }
    } catch (e) {
      if (!context.mounted) return;

      // Handle specific permission errors with clear Swedish messages
      if (e is PermissionDeniedException) {
        SnackBarUtils.showFailure(
          context,
          what: context.l10n.shoppingNoEditPermissionShared,
        );
      } else {
        SnackBarUtils.showFailure(
          context,
          what: context.l10n.errorOccurredWithDetails(
            SnackBarUtils.userFriendlyMessage(context, e),
          ),
        );
      }
    }
  }
}
