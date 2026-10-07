// lib/widgets/common/share_dialog/share_dialog_header.dart

import 'package:flutter/material.dart';
import 'package:butlery/core/extensions/default_value_extensions.dart';
import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/models/unified/unified_shopping_list.dart';
import 'package:butlery/widgets/common/icons/butlery_glyph.dart';
import 'package:butlery/widgets/common/icons/butlery_icons.dart';
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

    // The header stands on the sheet's own surface with the title in 14/700,
    // as the share sheet draws it (Skarmar v12 del 3 'Dela-ark'); the
    // subtitle is text.secondary, not the title colour at a lower opacity
    // (tokens.json:40-53).
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(
        AppDimensions.paddingL,
        AppDimensions.spacingSm,
        AppDimensions.paddingL,
        AppDimensions.spacingSm,
      ),
      child: Row(
        children: [
          ButleryIcon(
            icon,
            color: cs.onSurface,
            size: AppDimensions.iconSizeAction,
          ),
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
        // A bulk share hands over the recipes still to share (BUT-2152).
        final subtitle = content is List<Recipe>
            ? content.map((recipe) => recipe.title).join(', ')
            : (content as Recipe).title;
        return (
          context.l10n.shareRecipeWithFriends,
          subtitle,
          ButleryIcons.utensils,
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
          ButleryIcons.utensils,
        );
      case ShareContentType.shoppingList:
        final shoppingList = content as UnifiedShoppingList;
        return (
          context.l10n.shareShoppingListTitle,
          shoppingList.name,
          ButleryIcons.shoppingCart,
        );
      case ShareContentType.personalTag:
        final tagData = content as Map<String, String>;
        return (
          'Dela tagg med vanner',
          tagData['tagName'].orEmpty(),
          ButleryIcons.tag,
        );
    }
  }
}
