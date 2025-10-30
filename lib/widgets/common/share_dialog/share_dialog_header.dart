// lib/widgets/common/share_dialog/share_dialog_header.dart

import 'package:flutter/material.dart';
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
    final (title, subtitle, icon) = _getHeaderInfo(contentType, content);
    
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
                  style: AppTextStyles.titleMedium.copyWith(
                    color: Theme.of(context).colorScheme.onPrimaryContainer,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  subtitle,
                  style: AppTextStyles.bodySmall.copyWith(
                    color: Theme.of(context)
                        .colorScheme
                        .onPrimaryContainer
                        .withValues(alpha: 0.8),
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
    ShareContentType contentType,
    dynamic content,
  ) {
    switch (contentType) {
      case ShareContentType.recipe:
        final recipe = content as Recipe;
        return (
          'Dela recept med vänner',
          recipe.title,
          Icons.restaurant_menu,
        );
      case ShareContentType.menu:
        final menu = content as Map<String, List<Recipe>>;
        final totalRecipes =
            menu.values.fold(0, (sum, recipes) => sum + recipes.length);
        return (
          'Dela veckomeny med vänner',
          '$totalRecipes recept i ${menu.length} kategorier',
          Icons.restaurant,
        );
      case ShareContentType.shoppingList:
        final shoppingList = content as UnifiedShoppingList;
        return (
          'Dela inköpslista',
          shoppingList.name,
          Icons.shopping_cart_outlined,
        );
    }
  }
}