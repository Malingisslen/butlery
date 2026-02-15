// lib/views/unified_shopping/widgets/shopping_list_content.dart
//
// UI Redesign: Color-coded category headers with full-width colored bars

import 'package:flutter/material.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/butlery_colors_extension.dart';
import 'package:butlery/viewmodels/unified_shopping_viewmodel.dart';
import 'package:butlery/models/unified/unified_shopping_item.dart';
import 'package:butlery/widgets/common/state_widget.dart';
import 'package:butlery/views/unified_shopping/widgets/shopping_item_tiles.dart';
import 'package:butlery/core/extensions/localization_extension.dart';

/// Main content area for shopping list.
///
/// **UI Redesign:** Category headers now use full-width colored bars
/// with category-specific colors from ButleryColors.category* constants.
class ShoppingListContent {
  static Widget build(
    BuildContext context,
    UnifiedShoppingViewModel viewModel,
    Function(UnifiedShoppingItem) onItemTap,
    Function(UnifiedShoppingItem) onEditItem,
    Function(UnifiedShoppingItem) onDeleteItem,
    VoidCallback onCreateList,
    VoidCallback onAddItem,
  ) {
    if (viewModel.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (viewModel.hasError) {
      return StateWidget.error(
        message: viewModel.error ?? context.l10n.commonUnknownError,
        onAction: () => viewModel.initialize(),
      );
    }

    if (viewModel.activeList == null) {
      return StateWidget.noShoppingList(
        actionLabel: context.l10n.shoppingCreateList,
        onAction: onCreateList,
      );
    }

    if (!viewModel.hasItems) {
      return StateWidget.noShoppingList(
        actionLabel: context.l10n.shoppingAddItem,
        onAction: onAddItem,
      );
    }

    return _buildShoppingList(
        context, viewModel, onItemTap, onEditItem, onDeleteItem);
  }

  static Widget _buildShoppingList(
    BuildContext context,
    UnifiedShoppingViewModel viewModel,
    Function(UnifiedShoppingItem) onItemTap,
    Function(UnifiedShoppingItem) onEditItem,
    Function(UnifiedShoppingItem) onDeleteItem,
  ) {
    // Pre-compute flat list of widgets for ListView.builder
    // This improves performance by only building visible items
    final widgets = <Widget>[
      // Pending items by category
      ..._buildPendingItemsByCategory(
          context, viewModel, onItemTap, onEditItem, onDeleteItem),

      // Completed items section
      if (viewModel.boughtItems > 0) ...[
        const SizedBox(height: AppDimensions.spacingLg),
        _buildCompletedItemsHeader(context, viewModel),
        const SizedBox(height: AppDimensions.spacingSm),
        ..._buildCompletedItems(
            context, viewModel, onItemTap, onEditItem, onDeleteItem),
      ],

      // Bottom spacing
      const SizedBox(height: AppDimensions.spacingHuge),
    ];

    return ListView.builder(
      padding: const EdgeInsets.all(AppDimensions.paddingL),
      itemCount: widgets.length,
      itemBuilder: (context, index) => widgets[index],
    );
  }

  static List<Widget> _buildPendingItemsByCategory(
    BuildContext context,
    UnifiedShoppingViewModel viewModel,
    Function(UnifiedShoppingItem) onItemTap,
    Function(UnifiedShoppingItem) onEditItem,
    Function(UnifiedShoppingItem) onDeleteItem,
  ) {
    final pendingItems =
        viewModel.items.where((item) => !item.isCompleted).toList();
    if (pendingItems.isEmpty) return [];

    final categorizedItems = <String, List<UnifiedShoppingItem>>{};
    for (final item in pendingItems) {
      final category = item.category.isEmpty
          ? context.l10n.shoppingCategoryOther
          : item.category;
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
    final completedItems =
        viewModel.items.where((item) => item.isCompleted).toList();
    if (completedItems.isEmpty) return [];

    final categorizedItems = <String, List<UnifiedShoppingItem>>{};
    for (final item in completedItems) {
      final category = item.category.isEmpty
          ? context.l10n.shoppingCategoryOther
          : item.category;
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
    final cs = Theme.of(context).colorScheme;
    // UI Redesign: Get category-specific color
    final categoryColor = isCompleted
        ? cs.onSurfaceVariant
        : _getCategoryColor(context, category);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // UI Redesign: Full-width colored category header bar
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(
            horizontal: AppDimensions.spacingMd,
            vertical: AppDimensions.spacingSm + AppDimensions.spacingXs,
          ),
          margin: const EdgeInsets.only(bottom: AppDimensions.spacingSm),
          decoration: BoxDecoration(
            color: categoryColor,
            borderRadius: BorderRadius.circular(AppDimensions.borderRadiusS),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  category.toUpperCase(),
                  style: AppTextStyles.labelMedium.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 2,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              // Count badge
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppDimensions.spacingSm,
                  vertical: AppDimensions.spacingXxs,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius:
                      BorderRadius.circular(AppDimensions.borderRadiusS),
                ),
                child: Text(
                  '${items.length}',
                  style: AppTextStyles.labelSmall.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
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

        const SizedBox(height: AppDimensions.spacingMd),
      ],
    );
  }

  /// Get category-specific color from ButleryColors.
  static Color _getCategoryColor(BuildContext context, String category) {
    final bc = context.butleryColors;
    switch (category.toLowerCase()) {
      case 'kött & fisk':
      case 'kött':
      case 'fisk':
        return bc.categoryMeatFish;
      case 'mejeri':
        return bc.categoryDairy;
      case 'frukt & grönt':
      case 'grönsaker':
      case 'frukt':
        return bc.categoryVegetables;
      case 'bröd':
      case 'bröd & spannmål':
        return bc.categoryBreadGrains;
      case 'fryst':
        return bc.categoryFrozen;
      case 'skafferi':
        return bc.categoryDryGoods;
      default:
        return bc.categoryOther;
    }
  }

  static Widget _buildCompletedItemsHeader(
      BuildContext context, UnifiedShoppingViewModel viewModel) {
    final cs = Theme.of(context).colorScheme;

    return Row(
      children: [
        Icon(
          Icons.check_circle,
          size: AppDimensions.iconSizeM,
          color: cs.primary,
        ),
        const SizedBox(width: AppDimensions.spacingSm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                context.l10n.shoppingPurchased,
                style: AppTextStyles.bodyLargeBold.copyWith(
                  color: cs.primary,
                ),
              ),
              Text(
                context.l10n.shoppingBoughtOfTotal(
                    viewModel.boughtItems, viewModel.totalItems),
                style: AppTextStyles.bodySmall.copyWith(
                  color: cs.primary
                      .withValues(alpha: AppDimensions.opacityVeryDark),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
