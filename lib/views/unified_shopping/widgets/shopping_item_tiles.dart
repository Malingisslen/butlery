// lib/views/unified_shopping/widgets/shopping_item_tiles.dart

import 'package:flutter/material.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_text_styles.dart';
import '../../../models/unified/unified_shopping_item.dart';

/// Individual shopping item tile components
class ShoppingItemTiles {
  static Widget buildItemTile(
    BuildContext context,
    UnifiedShoppingItem item,
    bool isCompleted,
    Function(UnifiedShoppingItem) onItemTap,
    Function(UnifiedShoppingItem) onEditItem,
    Function(UnifiedShoppingItem) onDeleteItem,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 2),
      decoration: BoxDecoration(
        color: AppColors.neutralLight,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: AppColors.neutralMedium.withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => onItemTap(item),
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                // Checkbox
                Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isCompleted
                          ? AppColors.success
                          : AppColors.neutralMedium.withValues(alpha: 0.6),
                      width: 2,
                    ),
                    color: isCompleted
                        ? AppColors.success
                        : Colors.transparent,
                  ),
                  child: isCompleted
                      ? Icon(
                          Icons.check,
                          size: 16,
                          color: AppColors.neutralLight,
                        )
                      : null,
                ),

                const SizedBox(width: 12),

                // Item details
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.displayText,
                        style: AppTextStyles.bodyLarge.copyWith(
                          fontWeight: FontWeight.w500,
                          color: isCompleted
                              ? AppColors.neutralMedium
                              : AppColors.textDark,
                          decoration: isCompleted
                              ? TextDecoration.lineThrough
                              : TextDecoration.none,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      
                      if (item.note?.isNotEmpty == true) ...[
                        const SizedBox(height: 4),
                        Text(
                          item.note!,
                          style: AppTextStyles.bodySmall.copyWith(
                            color: isCompleted
                                ? AppColors.neutralMedium.withValues(alpha: 0.8)
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
                    margin: const EdgeInsets.only(left: 8),
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
                    IconButton(
                      icon: Icon(
                        Icons.edit,
                        size: 16,
                        color: AppColors.neutralMedium,
                      ),
                      onPressed: () => onEditItem(item),
                      tooltip: 'Redigera',
                      padding: const EdgeInsets.all(8),
                      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                    ),

                    // Delete button
                    IconButton(
                      icon: Icon(
                        Icons.delete,
                        size: 16,
                        color: AppColors.error.withValues(alpha: 0.7),
                      ),
                      onPressed: () => onDeleteItem(item),
                      tooltip: 'Ta bort',
                      padding: const EdgeInsets.all(8),
                      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static Color _getPriorityColor(int priority) {
    switch (priority) {
      case 5:
        return AppColors.error; // Highest priority
      case 4:
        return AppColors.warning; // High priority
      default:
        return AppColors.neutralMedium; // Normal priority
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
            color: AppColors.neutralMedium,
          ),
          const SizedBox(height: 16),
          Text(
            title,
            style: AppTextStyles.titleMedium.copyWith(
              color: AppColors.neutralMedium,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            message,
            style: AppTextStyles.bodySmall.copyWith(
              color: AppColors.neutralMedium,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}