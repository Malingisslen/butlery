// lib/views/recipe_detail/handlers/recipe_shopping_handler.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:butlery/viewmodels/recipe_detail_viewmodel.dart';
import 'package:butlery/core/constants/routes.dart';
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/services/unified/unified_shopping_service.dart';
import 'package:butlery/utils/text/shopping_list_generator.dart';
import 'package:butlery/widgets/common/dialogs/recipe_add_to_list_dialog.dart';
import 'package:butlery/services/permission_service.dart';
import 'package:butlery/core/exceptions/permission_exceptions.dart';
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

  /// FAB / button entry: the same single dialog as [generateShoppingListFromRecipe].
  /// Kept as its own name because the callers distinguish the button from the
  /// menu entry.
  static Future<void> showAddToCartConfirmation(
    BuildContext context, {
    required int currentPortions,
    List<PantryItem>? pantry,
  }) => generateShoppingListFromRecipe(
    context,
    currentPortions: currentPortions,
    pantry: pantry,
  );

  /// One dialog with the ingredients and the list choice (BUT-2308), then the
  /// add itself, then a snackbar with a "Visa" action. The most recently used
  /// list is preselected; the user never has to pass a second dialog.
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
        // Everything is at home: nothing is added, and the user is told so.
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

      // Not dismissible by a stray tap outside: that closed the old list
      // dialog with nothing added and no feedback.
      final choice = await showDialog<RecipeListChoice>(
        context: context,
        barrierDismissible: false,
        builder: (_) => RecipeAddToListDialog(
          recipeTitle: recipe.title,
          items: shoppingItems,
          pantryCheck: check,
          shoppingService: shoppingService,
        ),
      );

      if (choice == null || !context.mounted) return;

      final String? targetListId;
      final String? targetListName;
      if (choice.newListName != null) {
        targetListName = choice.newListName;
        targetListId = await shoppingService.createPersonalList(
          choice.newListName!,
        );
      } else {
        targetListId = choice.listId;
        targetListName = choice.listName;
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
        final navigator = Navigator.of(context);
        SnackBarUtils.showSuccessWithAction(
          context,
          context.l10n.shoppingItemsAddedToListSnack(
            shoppingItems.length,
            targetListName ?? context.l10n.shoppingYourList,
          ),
          actionLabel: context.l10n.commonView,
          onAction: () => navigator.pushNamed(Routes.shoppingList),
        );
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
