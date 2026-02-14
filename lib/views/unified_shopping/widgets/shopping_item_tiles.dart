// lib/views/unified_shopping/widgets/shopping_item_tiles.dart
//
// UI Redesign: Square checkboxes (22px, 2px green border)

import 'package:flutter/material.dart';
import 'package:butlery/theme/app_colors.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/models/unified/unified_shopping_item.dart';
import 'package:butlery/core/extensions/localization_extension.dart';

/// Individual shopping item tile components.
///
/// **UI Redesign:** Uses square checkboxes (22px, 2px green border)
/// instead of circular checkboxes.
class ShoppingItemTiles {
  static Widget buildItemTile(
    BuildContext context,
    UnifiedShoppingItem item,
    bool isCompleted,
    Function(UnifiedShoppingItem) onItemTap,
    Function(UnifiedShoppingItem) onEditItem,
    Function(UnifiedShoppingItem) onDeleteItem,
  ) {
    return RepaintBoundary(
      child: Container(
        margin: const EdgeInsets.only(bottom: AppDimensions.spacingXxs),
        decoration: BoxDecoration(
          color: AppColors.cardWhite,
          borderRadius: BorderRadius.circular(AppDimensions.borderRadiusS),
          border: Border.all(
            color: AppColors.divider,
            width: AppDimensions.borderWidthStandard,
          ),
        ),
        child: Semantics(
          label: isCompleted
              ? context.l10n.a11yShoppingItemChecked(item.displayText)
              : context.l10n.a11yShoppingItemUnchecked(item.displayText),
          button: true,
          enabled: true,
          child: Material(
            type: MaterialType.transparency,
            child: InkWell(
              onTap: () => onItemTap(item),
              borderRadius: BorderRadius.circular(AppDimensions.borderRadiusS),
              child: Padding(
                padding: const EdgeInsets.all(AppDimensions.paddingM),
                child: Row(
                  children: [
                    // UI Redesign: Square checkbox (22px, 2px green border)
                    Container(
                      width: 22,
                      height: 22,
                      decoration: BoxDecoration(
                        borderRadius:
                            BorderRadius.circular(AppDimensions.borderRadiusXs),
                        border: Border.all(
                          color: AppColors.forestGreen,
                          width: 2,
                        ),
                        color: isCompleted
                            ? AppColors.forestGreen
                            : AppColors.cardWhite,
                      ),
                      child: isCompleted
                          ? const Icon(
                              Icons.check,
                              size: 14,
                              color: AppColors.cardWhite,
                            )
                          : null,
                    ),

                    const SizedBox(width: AppDimensions.paddingM),

                    // Item details
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.displayText,
                            style: AppTextStyles.contentTitle.copyWith(
                              color: isCompleted
                                  ? AppColors.textMedium
                                  : AppColors.textDark,
                              decoration: isCompleted
                                  ? TextDecoration.lineThrough
                                  : TextDecoration.none,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (item.note?.isNotEmpty == true) ...[
                            const SizedBox(height: AppDimensions.spacingXs),
                            Text(
                              item.note!,
                              style: AppTextStyles.bodySmall.copyWith(
                                color: isCompleted
                                    ? AppColors.textMedium.withValues(
                                        alpha: AppDimensions.opacityVeryDark)
                                    : AppColors.textMedium,
                                decoration: isCompleted
                                    ? TextDecoration.lineThrough
                                    : TextDecoration.none,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ],
                      ),
                    ),

                    // Priority indicator
                    if (item.priority > 3)
                      Container(
                        width: 8,
                        height: 8,
                        margin: const EdgeInsetsDirectional.only(start: 8),
                        decoration: BoxDecoration(
                          color: _getPriorityColor(item.priority),
                          shape: BoxShape.circle,
                        ),
                      ),

                    // Action buttons
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Edit button
                        Semantics(
                          label: context.l10n.a11yEditItem(item.name),
                          button: true,
                          enabled: true,
                          child: IconButton(
                            icon: const Icon(
                              Icons.edit,
                              size: AppDimensions.iconSizeS,
                              color: AppColors.textMedium,
                            ),
                            onPressed: () => onEditItem(item),
                            tooltip: context.l10n.commonEdit,
                            padding:
                                const EdgeInsets.all(AppDimensions.spacingM),
                            constraints: const BoxConstraints(
                                minWidth: AppDimensions.minTouchTarget,
                                minHeight: AppDimensions.minTouchTarget),
                          ),
                        ),

                        // Delete button
                        Semantics(
                          label: context.l10n.a11yDeleteItem(item.name),
                          button: true,
                          enabled: true,
                          child: IconButton(
                            icon: Icon(
                              Icons.delete,
                              size: AppDimensions.iconSizeS,
                              color: AppColors.textMedium
                                  .withValues(alpha: AppDimensions.opacityDark),
                            ),
                            onPressed: () => onDeleteItem(item),
                            tooltip: context.l10n.commonDelete,
                            padding:
                                const EdgeInsets.all(AppDimensions.spacingM),
                            constraints: const BoxConstraints(
                                minWidth: AppDimensions.minTouchTarget,
                                minHeight: AppDimensions.minTouchTarget),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  static Color _getPriorityColor(int priority) {
    switch (priority) {
      case 5:
        return AppColors
            .forestGreenDark; // Highest priority - strong brand color
      case 4:
        return AppColors.forestGreen; // High priority - main brand color
      default:
        return AppColors.textMedium; // Normal priority - subtle brand color
    }
  }

  static Widget buildEmptyState({
    required String title,
    required String message,
    required IconData icon,
  }) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            size: 64,
            color: AppColors.textMedium,
          ),
          const SizedBox(height: AppDimensions.spacingMd),
          Text(
            title,
            style: AppTextStyles.titleMedium.copyWith(
              color: AppColors.textMedium,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppDimensions.spacingSm),
          Text(
            message,
            style: AppTextStyles.bodySmall.copyWith(
              color: AppColors.textMedium,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
