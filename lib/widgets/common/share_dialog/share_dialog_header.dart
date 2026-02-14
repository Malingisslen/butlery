// lib/widgets/common/share_dialog/share_dialog_header.dart

import 'package:flutter/material.dart';
import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/models/unified/unified_shopping_list.dart';
import 'package:butlery/widgets/common/universal_share_dialog.dart';

class ShareDialogHeader {
  static Widget build(
    BuildContext context,
    ShareContentType contentType,
    dynamic content,
  ) {
    final (title, subtitle, icon) =
        _getHeaderInfo(context, contentType, content);

    return Container(
      padding: const EdgeInsets.all(AppDimensions.paddingL),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(AppDimensions.borderRadiusL),
          topRight: Radius.circular(AppDimensions.borderRadiusL),
        ),
      ),
      child: Row(
        children: [
          Icon(
            icon,
            color: Theme.of(context).colorScheme.onPrimaryContainer,
            size: AppDimensions.iconSizeAction,
          ),
          const SizedBox(width: AppDimensions.spacingM),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppTextStyles.titleBold.copyWith(
                    color: Theme.of(context).colorScheme.onPrimaryContainer,
                  ),
                ),
                Text(
                  subtitle,
                  style: AppTextStyles.bodySmall.copyWith(
                    color: Theme.of(context)
                        .colorScheme
                        .onPrimaryContainer
                        .withValues(alpha: AppDimensions.opacityVeryDark),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: Icon(
              Icons.close,
              color: Theme.of(context).colorScheme.onPrimaryContainer,
            ),
          ),
        ],
      ),
    );
  }

  static (String, String, IconData) _getHeaderInfo(
    BuildContext context,
    ShareContentType contentType,
    dynamic content,
  ) {
    switch (contentType) {
      case ShareContentType.recipe:
        final recipe = content as Recipe;
        return (
          context.l10n.shareRecipeWithFriends,
          recipe.title,
          Icons.restaurant_menu,
        );
      case ShareContentType.menu:
        final menu = content as Map<String, List<Recipe>>;
        final totalRecipes =
            menu.values.fold(0, (sum, recipes) => sum + recipes.length);
        return (
          context.l10n.shareMenuWithFriends,
          context.l10n.shareRecipesInCategories(totalRecipes, menu.length),
          Icons.restaurant,
        );
      case ShareContentType.shoppingList:
        final shoppingList = content as UnifiedShoppingList;
        return (
          context.l10n.shareShoppingListTitle,
          shoppingList.name,
          Icons.shopping_cart_outlined,
        );
    }
  }
}
