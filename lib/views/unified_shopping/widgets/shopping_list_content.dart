import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/material.dart';
import 'package:butlery/core/utils/reduced_motion.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/butlery_colors_extension.dart';
import 'package:butlery/theme/theme_constants.dart';
import 'package:butlery/viewmodels/unified_shopping_viewmodel.dart';
import 'package:butlery/models/unified/unified_shopping_item.dart';
import 'package:butlery/widgets/common/state_widget.dart';
import 'package:butlery/views/unified_shopping/widgets/shopping_item_tiles.dart';
import 'package:butlery/views/unified_shopping/widgets/category_picker_sheet.dart';
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

  /// Get category-specific color from ButleryColors (public for reuse).
  static Color getCategoryColor(BuildContext context, String category) {
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
      case ShoppingCategory.spices:
        return bc.categoryDryGoods;
      case ShoppingCategory.canned:
        return bc.categoryCanned;
      case ShoppingCategory.drinks:
        return bc.categoryDrinks;
      case ShoppingCategory.snacks:
        return bc.categorySnacks;
      case ShoppingCategory.cleaning:
        return bc.categoryCleaning;
      default:
        return bc.categoryOther;
    }
  }

  @override
  State<ShoppingListContentWidget> createState() =>
      _ShoppingListContentWidgetState();
}

class _ShoppingListContentWidgetState extends State<ShoppingListContentWidget> {
  final Set<String> _collapsedCategories = {};
  String? _dragOverCategory;
  bool _showEmptyCategories = false;

  /// Cached categorized pending items — invalidated when items change
  Map<String, List<UnifiedShoppingItem>>? _pendingByCategory;
  List<String>? _pendingSortedKeys;

  /// Cached categorized completed items — invalidated when items change
  Map<String, List<UnifiedShoppingItem>>? _completedByCategory;
  List<String>? _completedSortedKeys;

  /// Cached category progress
  Map<String, ({int total, int completed})>? _categoryProgressCache;

  /// Cache invalidation keys
  int _lastItemsHash = 0;
  List<String>? _lastCategoryOrder;

  void _invalidateCaches() {
    _pendingByCategory = null;
    _pendingSortedKeys = null;
    _completedByCategory = null;
    _completedSortedKeys = null;
    _categoryProgressCache = null;
    _lastItemsHash = 0;
    _lastCategoryOrder = null;
  }

  void _ensureCaches(UnifiedShoppingViewModel viewModel) {
    final items = viewModel.items;
    final categoryOrder = viewModel.categoryOrder;

    // Hash that captures item count, categories, and completion state
    final itemsHash = Object.hashAll(
      items.map((i) => Object.hash(i.id, i.category, i.isCompleted)),
    );
    final orderChanged = _lastCategoryOrder == null ||
        !listEquals(_lastCategoryOrder, categoryOrder);

    if (itemsHash == _lastItemsHash && !orderChanged) return;
    _lastItemsHash = itemsHash;
    _lastCategoryOrder = List.of(categoryOrder);

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
    final compare = ShoppingCategory.orderComparator(categoryOrder);
    _pendingSortedKeys = pendingMap.keys.toList()..sort(compare);
    _completedByCategory = completedMap;
    _completedSortedKeys = completedMap.keys.toList()..sort(compare);
  }

  @override
  void didUpdateWidget(ShoppingListContentWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.viewModel != widget.viewModel) {
      _invalidateCaches();
    }
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = widget.viewModel;

    if (viewModel.isLoading) {
      return StateWidget.loading();
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
      // A list exists but is empty — distinct from "no list at all" above, so
      // the copy must say "list is empty", not "no list to derive from".
      return StateWidget.empty(
        title: context.l10n.shoppingListEmpty,
        subtitle: context.l10n.shoppingListEmptyHint,
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

    // Determine which categories have no pending items (for empty drop targets)
    final allCategories = viewModel.categoryOrder;
    final emptyCategories =
        allCategories.where((cat) => !pendingKeys.contains(cat)).toList();

    // BUT-403: running counter so every item gets a unique `item-toggle-{n}`
    // regardless of category, in visual order (pending first, then completed).
    var runningIndex = 0;
    final pendingSections = <Widget>[];
    for (final key in pendingKeys) {
      final items = pendingMap[key]!;
      pendingSections.add(_buildCategorySection(
        context,
        key,
        items,
        false,
        progress: categoryProgress[key],
        startingIndex: runningIndex,
      ));
      runningIndex += items.length;
    }

    final completedSections = <Widget>[];
    for (final key in completedKeys) {
      final items = completedMap[key]!;
      completedSections.add(_buildCategorySection(
        context,
        key,
        items,
        true,
        startingIndex: runningIndex,
      ));
      runningIndex += items.length;
    }

    final widgets = <Widget>[
      // Pending items by category
      ...pendingSections,

      // Empty categories toggle (collapsed by default)
      if (emptyCategories.isNotEmpty) ...[
        const SizedBox(height: AppDimensions.spacingSm),
        _buildEmptyCategoriesToggle(context, emptyCategories),
      ],

      // Completed items section
      if (viewModel.boughtItems > 0) ...[
        const SizedBox(height: AppDimensions.spacingLg),
        _buildCompletedItemsHeader(context, viewModel),
        const SizedBox(height: AppDimensions.spacingSm),
        ...completedSections,
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
    int startingIndex = 0,
  }) {
    final cs = Theme.of(context).colorScheme;
    final categoryColor = isCompleted
        ? cs.onSurfaceVariant
        : ShoppingListContentWidget.getCategoryColor(context, category);

    final isCollapsed = _collapsedCategories.contains(category);
    final isDragOver = _dragOverCategory == category;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Category header: tappable + drag target for item drops
        DragTarget<UnifiedShoppingItem>(
          onWillAcceptWithDetails: (details) {
            if (details.data.category == category) return false;
            setState(() => _dragOverCategory = category);
            return true;
          },
          onLeave: (_) {
            setState(() {
              if (_dragOverCategory == category) _dragOverCategory = null;
            });
          },
          onAcceptWithDetails: (details) {
            setState(() => _dragOverCategory = null);
            _handleItemDrop(details.data.id, category);
          },
          builder: (context, candidateData, rejectedData) {
            return Semantics(
              label: context.l10n.a11yToggleShoppingCategory(
                  ShoppingCategory.displayName(category)),
              button: true,
              toggled: !isCollapsed,
              child: GestureDetector(
                onTap: () {
                  setState(() {
                    if (isCollapsed) {
                      _collapsedCategories.remove(category);
                    } else {
                      _collapsedCategories.add(category);
                    }
                  });
                },
                child: AnimatedContainer(
                  duration:
                      ThemeConstants.durationFast.respectingMotion(context),
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppDimensions.spacingMd,
                    vertical: AppDimensions.spacingSm + AppDimensions.spacingXs,
                  ),
                  margin:
                      const EdgeInsets.only(bottom: AppDimensions.spacingSm),
                  decoration: BoxDecoration(
                    color: categoryColor,
                    borderRadius:
                        BorderRadius.circular(AppDimensions.borderRadiusS),
                    border: isDragOver
                        ? Border.all(color: cs.onPrimary, width: 2)
                        : null,
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
                            // Outer Semantics on the GestureDetector announces
                            // this row as a toggle button; nesting `header:
                            // true` here would make TalkBack stutter through
                            // both roles. The button-with-toggled state is
                            // more informative for the actionable case.
                            child: Text(
                              ShoppingCategory.displayName(category)
                                  .toUpperCase(),
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
                              borderRadius: BorderRadius.circular(
                                  AppDimensions.borderRadiusS),
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
                          borderRadius: BorderRadius.circular(
                              AppDimensions.borderRadiusS),
                          child: LinearProgressIndicator(
                            value: progress.completed / progress.total,
                            minHeight: 3,
                            backgroundColor:
                                cs.onPrimary.withValues(alpha: 0.2),
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
            );
          },
        ),

        // Items in category (hidden when collapsed). `startingIndex` keeps
        // the `item-toggle-{n}` identifier globally unique across sections.
        if (!isCollapsed)
          ...items.asMap().entries.map((entry) {
            final localIdx = entry.key;
            final item = entry.value;
            return ShoppingItemTiles.buildDraggableItemTile(
              context,
              item,
              isCompleted,
              widget.onItemTap,
              widget.onEditItem,
              widget.onDeleteItem,
              onMoveToCategory: widget.viewModel.canEditActiveList
                  ? () => _showCategoryPicker(context, item)
                  : null,
              visualIndex: startingIndex + localIdx,
            );
          }),

        const SizedBox(height: AppDimensions.spacingMd),
      ],
    );
  }

  Future<void> _handleItemDrop(String itemId, String category) async {
    final moved = await widget.viewModel.moveItemToCategory(itemId, category);
    if (moved && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.l10n
              .shoppingItemMoved(ShoppingCategory.displayName(category))),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _showCategoryPicker(
    BuildContext context,
    UnifiedShoppingItem item,
  ) async {
    final selected = await CategoryPickerSheet.show(
      context,
      currentCategory: item.category,
    );
    if (selected != null && context.mounted) {
      await widget.viewModel.moveItemToCategory(item.id, selected);
      if (context.mounted) {
        final displayName = ShoppingCategory.displayName(selected);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.l10n.shoppingItemMoved(displayName)),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  Widget _buildEmptyCategoriesToggle(
    BuildContext context,
    List<String> emptyCategories,
  ) {
    final cs = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          label: context.l10n.a11yToggleEmptyCategories,
          button: true,
          toggled: _showEmptyCategories,
          child: GestureDetector(
            onTap: () => setState(() {
              _showEmptyCategories = !_showEmptyCategories;
            }),
            child: Row(
              children: [
                Icon(
                  _showEmptyCategories ? Icons.expand_less : Icons.expand_more,
                  color: cs.onSurfaceVariant,
                  size: AppDimensions.iconSizeM,
                ),
                const SizedBox(width: AppDimensions.spacingSm),
                Text(
                  context.l10n.shoppingOtherCategories,
                  style: AppTextStyles.labelMedium.copyWith(
                    color: cs.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
        if (_showEmptyCategories) ...[
          const SizedBox(height: AppDimensions.spacingSm),
          ...emptyCategories.map((category) => _buildEmptyCategoryDropTarget(
                context,
                category,
              )),
        ],
      ],
    );
  }

  Widget _buildEmptyCategoryDropTarget(
    BuildContext context,
    String category,
  ) {
    final cs = Theme.of(context).colorScheme;
    final categoryColor =
        ShoppingListContentWidget.getCategoryColor(context, category);
    final isDragOver = _dragOverCategory == category;

    return DragTarget<UnifiedShoppingItem>(
      onWillAcceptWithDetails: (details) {
        if (details.data.category == category) return false;
        setState(() => _dragOverCategory = category);
        return true;
      },
      onLeave: (_) {
        setState(() {
          if (_dragOverCategory == category) _dragOverCategory = null;
        });
      },
      onAcceptWithDetails: (details) {
        setState(() => _dragOverCategory = null);
        _handleItemDrop(details.data.id, category);
      },
      builder: (context, candidateData, rejectedData) {
        return AnimatedContainer(
          duration: ThemeConstants.durationFast.respectingMotion(context),
          width: double.infinity,
          // Min 48px so the empty drop zone is a comfortable drag target
          // (touch-accessibility) rather than a thin, hard-to-hit strip.
          constraints: const BoxConstraints(
            minHeight: AppDimensions.minTouchTarget,
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: AppDimensions.spacingMd,
            vertical: AppDimensions.spacingSm,
          ),
          margin: const EdgeInsets.only(bottom: AppDimensions.spacingXs),
          decoration: BoxDecoration(
            color: isDragOver
                ? categoryColor.withValues(alpha: 0.3)
                : cs.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(AppDimensions.borderRadiusS),
            border: Border.all(
              color: isDragOver ? categoryColor : cs.outlineVariant,
              width: isDragOver ? 2 : 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 16,
                height: 16,
                decoration: BoxDecoration(
                  color: categoryColor,
                  borderRadius:
                      BorderRadius.circular(AppDimensions.borderRadiusS),
                ),
              ),
              const SizedBox(width: AppDimensions.spacingSm),
              Text(
                ShoppingCategory.displayName(category),
                style: AppTextStyles.labelSmall.copyWith(
                  color: cs.onSurfaceVariant,
                ),
              ),
            ],
          ),
        );
      },
    );
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
