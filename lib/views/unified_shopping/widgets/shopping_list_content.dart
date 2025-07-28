// lib/views/unified_shopping/widgets/shopping_list_content.dart

import 'package:flutter/material.dart';
import 'package:butlery/theme/app_colors.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/viewmodels/unified_shopping_viewmodel.dart';
import 'package:butlery/models/unified/unified_shopping_item.dart';
import 'package:butlery/widgets/common/state_widget.dart';
import 'package:butlery/views/unified_shopping/widgets/shopping_item_tiles.dart';

/// Main content area for shopping list
class ShoppingListContent {
  static Widget build(
    BuildContext context,
    UnifiedShoppingViewModel viewModel,
    Function(UnifiedShoppingItem) onItemTap,
    Function(UnifiedShoppingItem) onEditItem,
    Function(UnifiedShoppingItem) onDeleteItem,
  ) {
    if (viewModel.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (viewModel.hasError) {
      return StateWidget.error(
        message: viewModel.error ?? 'Okänt fel',
        onAction: () => viewModel.initialize(),
      );
    }

    if (viewModel.activeList == null) {
      return StateWidget.noShoppingList(
        actionLabel: 'Skapa lista',
        onAction: () {},
      );
    }

    if (!viewModel.hasItems) {
      return StateWidget.noShoppingList(
        actionLabel: 'Lägg till vara',
        onAction: () {},
      );
    }

    return _buildShoppingList(context, viewModel, onItemTap, onEditItem, onDeleteItem);
  }

  static Widget _buildShoppingList(
    BuildContext context,
    UnifiedShoppingViewModel viewModel,
    Function(UnifiedShoppingItem) onItemTap,
    Function(UnifiedShoppingItem) onEditItem,
    Function(UnifiedShoppingItem) onDeleteItem,
  ) {
    return ListView(
      padding: const EdgeInsets.all(AppDimensions.paddingL),
      children: [
        // Pending items by category
        ..._buildPendingItemsByCategory(context, viewModel, onItemTap, onEditItem, onDeleteItem),

        // Completed items section
        if (viewModel.boughtItems > 0) ...[
          const SizedBox(height: 24),
          _buildCompletedItemsHeader(viewModel),
          const SizedBox(height: 8),
          ..._buildCompletedItems(context, viewModel, onItemTap, onEditItem, onDeleteItem),
        ],

        // Bottom spacing
        const SizedBox(height: 80),
      ],
    );
  }

  static List<Widget> _buildPendingItemsByCategory(
    BuildContext context,
    UnifiedShoppingViewModel viewModel,
    Function(UnifiedShoppingItem) onItemTap,
    Function(UnifiedShoppingItem) onEditItem,
    Function(UnifiedShoppingItem) onDeleteItem,
  ) {
    final pendingItems = viewModel.items.where((item) => !item.isCompleted).toList();
    if (pendingItems.isEmpty) return [];

    final categorizedItems = <String, List<UnifiedShoppingItem>>{};
    for (final item in pendingItems) {
      final category = item.category.isEmpty ? 'Övrigt' : item.category;
      categorizedItems.putIfAbsent(category, () => []).add(item);
    }

    return categorizedItems.entries.map((entry) {
      return _buildCategorySection(
        context,
        entry.key,
        entry.value,
        false,
        onItemTap,
        onEditItem,
        onDeleteItem,
      );
    }).toList();
  }

  static List<Widget> _buildCompletedItems(
    BuildContext context,
    UnifiedShoppingViewModel viewModel,
    Function(UnifiedShoppingItem) onItemTap,
    Function(UnifiedShoppingItem) onEditItem,
    Function(UnifiedShoppingItem) onDeleteItem,
  ) {
    final completedItems = viewModel.items.where((item) => item.isCompleted).toList();
    if (completedItems.isEmpty) return [];

    final categorizedItems = <String, List<UnifiedShoppingItem>>{};
    for (final item in completedItems) {
      final category = item.category.isEmpty ? 'Övrigt' : item.category;
      categorizedItems.putIfAbsent(category, () => []).add(item);
    }

    return categorizedItems.entries.map((entry) {
      return _buildCategorySection(
        context,
        entry.key,
        entry.value,
        true,
        onItemTap,
        onEditItem,
        onDeleteItem,
      );
    }).toList();
  }

  static Widget _buildCategorySection(
    BuildContext context,
    String category,
    List<UnifiedShoppingItem> items,
    bool isCompleted,
    Function(UnifiedShoppingItem) onItemTap,
    Function(UnifiedShoppingItem) onEditItem,
    Function(UnifiedShoppingItem) onDeleteItem,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Category header
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          margin: const EdgeInsets.only(bottom: 8),
          decoration: BoxDecoration(
            color: (isCompleted ? AppColors.neutralMedium : AppColors.primaryBlue)
                .withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              _getCategoryIcon(category, isCompleted),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  category,
                  style: TextStyle(
                    fontSize: AppTextStyles.bodyLarge.fontSize,
                    fontWeight: FontWeight.w600,
                    color: isCompleted
                        ? AppColors.neutralMedium
                        : AppColors.primaryBlue,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: (isCompleted ? AppColors.neutralMedium : AppColors.primaryBlue)
                      .withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${items.length}',
                  style: TextStyle(
                    fontSize: AppTextStyles.bodySmall.fontSize,
                    fontWeight: FontWeight.w500,
                    color: isCompleted
                        ? AppColors.neutralMedium
                        : AppColors.primaryBlue,
                  ),
                ),
              ),
            ],
          ),
        ),

        // Items in category
        ...items.map((item) => ShoppingItemTiles.buildItemTile(
          context,
          item,
          isCompleted,
          onItemTap,
          onEditItem,
          onDeleteItem,
        )),

        const SizedBox(height: 8),
      ],
    );
  }

  static Widget _getCategoryIcon(String category, bool isCompleted) {
    IconData iconData;
    switch (category.toLowerCase()) {
      case 'frukt & grönt':
        iconData = Icons.eco;
        break;
      case 'mejeri':
        iconData = Icons.local_drink;
        break;
      case 'kött & fisk':
        iconData = Icons.set_meal;
        break;
      case 'bröd':
        iconData = Icons.bakery_dining;
        break;
      case 'skafferi':
        iconData = Icons.kitchen;
        break;
      case 'fryst':
        iconData = Icons.ac_unit;
        break;
      case 'dryck':
        iconData = Icons.local_cafe;
        break;
      case 'snacks & godis':
        iconData = Icons.cookie;
        break;
      case 'städ & hygien':
        iconData = Icons.cleaning_services;
        break;
      default:
        iconData = Icons.shopping_basket;
    }

    return Icon(
      iconData,
      size: 18,
      color: isCompleted ? AppColors.neutralMedium : AppColors.primaryBlue,
    );
  }

  static Widget _buildCompletedItemsHeader(UnifiedShoppingViewModel viewModel) {
    return Row(
      children: [
        const Icon(
          Icons.check_circle,
          size: 20,
          color: AppColors.success,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Inhandlat',
                style: AppTextStyles.bodyLarge.copyWith(
                  fontWeight: FontWeight.w600,
                  color: AppColors.success,
                ),
              ),
              Text(
                '${viewModel.boughtItems} av ${viewModel.totalItems} varor',
                style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.success.withValues(alpha: 0.8),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}