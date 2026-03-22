// lib/views/unified_shopping/widgets/shopping_list_content.dart
//
// UI Redesign: Color-coded category headers with collapse/expand and progress

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
/// **UI Redesign:** Category headers with collapse/expand, progress indicators,
/// and category-specific colors from ButleryColors.category* constants.
///
/// Kept as static class for backward compatibility. Use [ShoppingListContent.build]
/// for the static variant, or [ShoppingListContentWidget] for the stateful version
/// with collapse/expand support.
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
    return ShoppingListContentWidget(
      viewModel: viewModel,
      onItemTap: onItemTap,
      onEditItem: onEditItem,
      onDeleteItem: onDeleteItem,
      onCreateList: onCreateList,
      onAddItem: onAddItem,
    );
  }
}

/// Stateful widget with collapse/expand per category and progress indicators.
class ShoppingListContentWidget extends StatefulWidget {
  final UnifiedShoppingViewModel viewModel;
  final Function(UnifiedShoppingItem) onItemTap;
  final Function(UnifiedShoppingItem) onEditItem;
  final Function(UnifiedShoppingItem) onDeleteItem;
  final VoidCallback onCreateList;
  final VoidCallback onAddItem;

  const ShoppingListContentWidget({
    super.key,
    required this.viewModel,
    required this.onItemTap,
    required this.onEditItem,
    required this.onDeleteItem,
    required this.onCreateList,
    required this.onAddItem,
  });

  @override
  State<ShoppingListContentWidget> createState() =>
      _ShoppingListContentWidgetState();
}

class _ShoppingListContentWidgetState extends State<ShoppingListContentWidget> {
  final Set<String> _collapsedCategories = {};

  /// Cached categorized pending items — invalidated when items change
  Map<String, List<UnifiedShoppingItem>>? _pendingByCategory;
  List<String>? _pendingSortedKeys;

  /// Cached categorized completed items — invalidated when items change
  Map<String, List<UnifiedShoppingItem>>? _completedByCategory;
  List<String>? _completedSortedKeys;

  /// Cached category progress
  Map<String, ({int total, int completed})>? _categoryProgressCache;

  /// Last items snapshot for cache invalidation
  int _lastItemCount = -1;
  int _lastCompletedCount = -1;

  void _invalidateCaches() {
    _pendingByCategory = null;
    _pendingSortedKeys = null;
    _completedByCategory = null;
    _completedSortedKeys = null;
    _categoryProgressCache = null;
    _lastItemCount = -1;
    _lastCompletedCount = -1;
  }

  void _ensureCaches(UnifiedShoppingViewModel viewModel) {
    final items = viewModel.items;
    final completedCount = items.where((i) => i.isCompleted).length;
    if (items.length == _lastItemCount &&
        completedCount == _lastCompletedCount) {
      return;
    }
    _lastItemCount = items.length;
    _lastCompletedCount = completedCount;

    // Compute category progress
    final progress = <String, ({int total, int completed})>{};
    for (final item in viewModel.items) {
      final category =
          item.category.isEmpty ? ShoppingCategory.other : item.category;
      final existing = progress[category] ?? (total: 0, completed: 0);
      progress[category] = (
        total: existing.total + 1,
        completed: existing.completed + (item.isCompleted ? 1 : 0),
      );
    }
    _categoryProgressCache = progress;

    // Compute pending items by category
    final pendingMap = <String, List<UnifiedShoppingItem>>{};
    final completedMap = <String, List<UnifiedShoppingItem>>{};
    for (final item in viewModel.items) {
      final category =
          item.category.isEmpty ? ShoppingCategory.other : item.category;
      if (item.isCompleted) {
        completedMap.putIfAbsent(category, () => []).add(item);
      } else {
        pendingMap.putIfAbsent(category, () => []).add(item);
      }
    }
    _pendingByCategory = pendingMap;
    _pendingSortedKeys = pendingMap.keys.toList()..sort();
    _completedByCategory = completedMap;
    _completedSortedKeys = completedMap.keys.toList()..sort();
  }

  @override
  void didUpdateWidget(ShoppingListContentWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.viewModel != widget.viewModel) {
      _invalidateCaches();
    }
  }

  /// Translate language-neutral category constant to localized display name.
  String _categoryDisplayName(BuildContext context, String category) {
    switch (category) {
      case ShoppingCategory.fruitVeg:
        return context.l10n.categoryFruitVeg;
      case ShoppingCategory.dairy:
        return context.l10n.categoryDairy;
      case ShoppingCategory.meatFish:
        return context.l10n.categoryMeatFish;
      case ShoppingCategory.breadGrain:
        return context.l10n.categoryBread;
      case ShoppingCategory.pantry:
        return context.l10n.categoryPantry;
      case ShoppingCategory.frozen:
        return context.l10n.categoryFrozen;
      case ShoppingCategory.drinks:
        return context.l10n.categoryBeverage;
      case ShoppingCategory.snacks:
        return context.l10n.categorySnacks;
      case ShoppingCategory.cleaning:
        return context.l10n.categoryHygiene;
      case ShoppingCategory.spices:
        return context.l10n.categorySpices;
      case ShoppingCategory.canned:
        return context.l10n.categoryCanned;
      case ShoppingCategory.dryGoods:
        return context.l10n.categoryDryGoods;
      case ShoppingCategory.other:
        return context.l10n.categoryOther;
      default:
        return category;
    }
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = widget.viewModel;

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
        onAction: widget.onCreateList,
      );
    }

    if (!viewModel.hasItems) {
      return StateWidget.noShoppingList(
        actionLabel: context.l10n.shoppingAddItem,
        onAction: widget.onAddItem,
      );
    }

    return _buildShoppingList(context, viewModel);
  }

  Widget _buildShoppingList(
    BuildContext context,
    UnifiedShoppingViewModel viewModel,
  ) {
    _ensureCaches(viewModel);

    final categoryProgress = _categoryProgressCache!;
    final pendingKeys = _pendingSortedKeys!;
    final pendingMap = _pendingByCategory!;
    final completedKeys = _completedSortedKeys!;
    final completedMap = _completedByCategory!;

    final widgets = <Widget>[
      // Pending items by category
      ...pendingKeys.map((key) {
        return _buildCategorySection(
          context,
          key,
          pendingMap[key]!,
          false,
          progress: categoryProgress[key],
        );
      }),

      // Completed items section
      if (viewModel.boughtItems > 0) ...[
        const SizedBox(height: AppDimensions.spacingLg),
        _buildCompletedItemsHeader(context, viewModel),
        const SizedBox(height: AppDimensions.spacingSm),
        ...completedKeys.map((key) {
          return _buildCategorySection(
            context,
            key,
            completedMap[key]!,
            true,
          );
        }),
      ],

      const SizedBox(height: AppDimensions.spacingHuge),
    ];

    return ListView.builder(
      padding: const EdgeInsets.all(AppDimensions.paddingL),
      itemCount: widgets.length,
      itemBuilder: (context, index) => widgets[index],
    );
  }

  Widget _buildCategorySection(
    BuildContext context,
    String category,
    List<UnifiedShoppingItem> items,
    bool isCompleted, {
    ({int total, int completed})? progress,
  }) {
    final cs = Theme.of(context).colorScheme;
    final categoryColor = isCompleted
        ? cs.onSurfaceVariant
        : _getCategoryColor(context, category);

    final isCollapsed = _collapsedCategories.contains(category);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Tappable category header with collapse/expand
        GestureDetector(
          onTap: () {
            setState(() {
              if (isCollapsed) {
                _collapsedCategories.remove(category);
              } else {
                _collapsedCategories.add(category);
              }
            });
          },
          child: Container(
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
            child: Column(
              children: [
                Row(
                  children: [
                    // Chevron icon
                    Icon(
                      isCollapsed ? Icons.expand_more : Icons.expand_less,
                      color: cs.onPrimary,
                      size: AppDimensions.iconSizeM,
                    ),
                    const SizedBox(width: AppDimensions.spacingSm),
                    Expanded(
                      child: Text(
                        _categoryDisplayName(context, category).toUpperCase(),
                        style: AppTextStyles.labelMedium.copyWith(
                          color: cs.onPrimary,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 2,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    // Progress badge: X/Y format
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppDimensions.spacingSm,
                        vertical: AppDimensions.spacingXxs,
                      ),
                      decoration: BoxDecoration(
                        color: cs.onPrimary.withValues(alpha: 0.2),
                        borderRadius:
                            BorderRadius.circular(AppDimensions.borderRadiusS),
                      ),
                      child: Text(
                        progress != null
                            ? '${progress.completed}/${progress.total}'
                            : '${items.length}',
                        style: AppTextStyles.labelSmall.copyWith(
                          color: cs.onPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                // Progress indicator
                if (progress != null && progress.total > 0) ...[
                  const SizedBox(height: AppDimensions.spacingXs),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(2),
                    child: LinearProgressIndicator(
                      value: progress.completed / progress.total,
                      minHeight: 3,
                      backgroundColor: cs.onPrimary.withValues(alpha: 0.2),
                      valueColor: AlwaysStoppedAnimation<Color>(
                        cs.onPrimary.withValues(alpha: 0.7),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),

        // Items in category (hidden when collapsed)
        if (!isCollapsed)
          ...items.map((item) => ShoppingItemTiles.buildItemTile(
                context,
                item,
                isCompleted,
                widget.onItemTap,
                widget.onEditItem,
                widget.onDeleteItem,
              )),

        const SizedBox(height: AppDimensions.spacingMd),
      ],
    );
  }

  /// Get category-specific color from ButleryColors.
  static Color _getCategoryColor(BuildContext context, String category) {
    final bc = context.butleryColors;
    switch (category) {
      case ShoppingCategory.meatFish:
        return bc.categoryMeatFish;
      case ShoppingCategory.dairy:
        return bc.categoryDairy;
      case ShoppingCategory.fruitVeg:
        return bc.categoryVegetables;
      case ShoppingCategory.breadGrain:
        return bc.categoryBreadGrains;
      case ShoppingCategory.frozen:
        return bc.categoryFrozen;
      case ShoppingCategory.pantry:
      case ShoppingCategory.dryGoods:
        return bc.categoryDryGoods;
      case ShoppingCategory.spices:
        return bc.categoryDryGoods;
      case ShoppingCategory.canned:
        return bc.categoryOther;
      case ShoppingCategory.drinks:
        return bc.categoryOther;
      case ShoppingCategory.snacks:
        return bc.categoryOther;
      case ShoppingCategory.cleaning:
        return bc.categoryOther;
      default:
        return bc.categoryOther;
    }
  }

  Widget _buildCompletedItemsHeader(
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
