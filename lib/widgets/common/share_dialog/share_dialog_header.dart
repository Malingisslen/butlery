// lib/widgets/common/share_dialog/share_dialog_header.dart

import 'package:flutter/material.dart';
import 'package:butlery/core/extensions/default_value_extensions.dart';
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
    final (title, subtitle, icon) = _getHeaderInfo(
      context,
      contentType,
      content,
    );

    // The share surface opens as a dialog, so it has X at the top right and
    // no handle (Komponentark v1:99: "Ark: 12 px överkant + handtag i
    // border-control. Dialog: X uppe till höger i stället"). The header
    // stands on the dialog's own surface with the title in 14/700, as the
    // share sheet draws it (Skarmar v12 del 3 'Dela-ark'); the subtitle is
    // text.secondary, not the title colour at a lower opacity
    // (tokens.json:40-53).
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(
        AppDimensions.paddingL,
        AppDimensions.paddingL,
        AppDimensions.spacingSm,
        AppDimensions.spacingSm,
      ),
      child: Row(
        children: [
          Icon(icon, color: cs.onSurface, size: AppDimensions.iconSizeAction),
          const SizedBox(width: AppDimensions.spacingM),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Semantics(
                  header: true,
                  child: Text(
                    title,
                    style: AppTextStyles.subpageTitle.copyWith(
                      color: cs.onSurface,
                    ),
                  ),
                ),
                Text(
                  subtitle,
                  style: AppTextStyles.bodySmall.copyWith(
                    color: cs.onSurfaceVariant,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () => Navigator.pop(context),
            tooltip: context.l10n.commonClose,
            icon: Icon(Icons.close, color: cs.onSurface),
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
        final totalRecipes = menu.values.fold(
          0,
          (sum, recipes) => sum + recipes.length,
        );
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
      case ShareContentType.personalTag:
        final tagData = content as Map<String, String>;
        return (
          'Dela tagg med vanner',
          tagData['tagName'].orEmpty(),
          Icons.label_outline,
        );
    }
  }
}
