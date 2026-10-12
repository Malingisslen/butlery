import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/material.dart';
import 'package:butlery/core/keyboard/app_actions.dart'
    show mainTabSwitchRequest;
import 'package:butlery/widgets/common/buttons/hero_button.dart';
import 'package:butlery/core/utils/snackbar_utils.dart'
    show SnackBarConfig, SnackBarUtils;
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_mode_colors.dart';
import 'package:butlery/viewmodels/unified_shopping_viewmodel.dart';
import 'package:butlery/models/unified/unified_shopping_item.dart';
import 'package:butlery/widgets/common/list/section_band.dart';
import 'package:butlery/widgets/common/state_widget.dart';
import 'package:butlery/views/unified_shopping/widgets/shopping_item_tiles.dart';
import 'package:butlery/views/unified_shopping/widgets/category_picker_sheet.dart';
import 'package:butlery/core/extensions/localization_extension.dart';

/// Main content area for shopping list.
///
/// **UI Redesign:** Category headers with collapse/expand.
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
    VoidCallback onClearCompleted,
  ) {
    return ShoppingListContentWidget(
      viewModel: viewModel,
      onItemTap: onItemTap,
      onEditItem: onEditItem,
      onDeleteItem: onDeleteItem,
      onCreateList: onCreateList,
      onAddItem: onAddItem,
      onClearCompleted: onClearCompleted,
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
  final VoidCallback onClearCompleted;

  const ShoppingListContentWidget({
    super.key,
    required this.viewModel,
    required this.onItemTap,
    required this.onEditItem,
    required this.onDeleteItem,
    required this.onCreateList,
    required this.onAddItem,
    required this.onClearCompleted,
  });

  /// The receipt after an item moved to [category].
  ///
  /// A category move is class 3 (produktregler.md:133): no Ångra. The row
  /// leaves the user's view, into a section that may be collapsed, so the
  /// receipt stays, and a snackbar with no possible follow-up action gets
  /// `Stäng` (content-style-guide.md:96-97). With an action Flutter would keep
  /// it until tapped, so for most users [SnackBar.persist] is false and it
  /// closes on its own after the app's normal snackbar time
  /// ([SnackBarConfig.normalDuration]). Under assistive navigation it stays
  /// until `Stäng`: the action must be a real focusable target
  /// (tillganglighetshandoff:172), and Flutter's timeout does not pause while
  /// a screen reader reads it (Grafisk manual v6:647).
  static void showCategoryMoveReceipt(BuildContext context, String category) {
    SnackBarUtils.showInfo(
      context,
      context.l10n.shoppingItemMoved(ShoppingCategory.displayName(category)),
      duration: SnackBarConfig.normalDuration,
    );
  }

  /// Get category-specific color from ModeColors (public for reuse).
  static Color getCategoryColor(BuildContext context, String category) {
    final bc = context.modeColors;
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
    final orderChanged =
        _lastCategoryOrder == null ||
        !listEquals(_lastCategoryOrder, categoryOrder);

    if (itemsHash == _lastItemsHash && !orderChanged) return;
    _lastItemsHash = itemsHash;
    _lastCategoryOrder = List.of(categoryOrder);

    // Compute category progress
    final progress = <String, ({int total, int completed})>{};
    for (final item in viewModel.items) {
      final category = item.category.isEmpty
          ? ShoppingCategory.other
          : item.category;
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
      final category = item.category.isEmpty
          ? ShoppingCategory.other
          : item.category;
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
      return StateWidget.loading(message: context.l10n.loadingShoppingList);
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
      //
      // Skarmar v12 del 2 #tominkop: "Inget att handla", a line on sending
      // the week's dishes here, "Från veckomenyn" as the one saffron action
      // and an outlined "Lägg till vara" beside it (Komponentark v1:843-844).
      return StateWidget(
        type: StateType.empty,
        title: context.l10n.shoppingEmptyTitle,
        subtitle: context.l10n.shoppingEmptyBody,
        customAction: Wrap(
          alignment: WrapAlignment.center,
          spacing: AppDimensions.space8,
          runSpacing: AppDimensions.space8,
          children: [
            HeroButton(
              key: const ValueKey('shopping-empty-from-week-menu'),
              label: context.l10n.shoppingFromWeekMenu,
              // Opens the Meny tab in the shell the user is already in (the
              // same bridge as Ctrl/Cmd+2, app_actions.dart), never a second
              // shell on top. #tominkop draws only the label; sending the
              // week's dishes to the list is done from Veckomeny's own
              // "Till inköpslista".
              onPressed: () {
                mainTabSwitchRequest.value = 1;
                Navigator.of(context).popUntil((route) => route.isFirst);
              },
            ),
            OutlinedButton(
              key: const ValueKey('shopping-empty-add-item'),
              onPressed: widget.onAddItem,
              child: Text(context.l10n.shoppingAddItem),
            ),
          ],
        ),
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

    // BUT-403: running counter so every item gets a unique `item-toggle-{n}`
    // regardless of category, in visual order (pending first, then completed).
    var runningIndex = 0;
    final pendingSections = <Widget>[];
    for (final key in pendingKeys) {
      final items = pendingMap[key]!;
      pendingSections.add(
        _buildCategorySection(
          context,
          key,
          items,
          progress: categoryProgress[key]!,
          startingIndex: runningIndex,
        ),
      );
      runningIndex += items.length;
    }

    // The bought rows sit in one list under "Köpt (N)", as #inkop draws
    // them, in the order of the categories they came from.
    final boughtRows = <Widget>[
      for (final key in completedKeys)
        for (final item in completedMap[key]!)
          _itemRow(context, item, true, runningIndex++),
    ];

    final widgets = <Widget>[
      // Pending items by category
      ...pendingSections,

      // Completed items section
      if (viewModel.boughtItems > 0) ...[
        const SizedBox(height: AppDimensions.space24),
        _buildCompletedItemsHeader(context, viewModel),
        const SizedBox(height: AppDimensions.space8),
        ...boughtRows,
      ],

      const SizedBox(
        height: AppDimensions.buttonHeight + AppDimensions.space24,
      ),
    ];

    return ListView.builder(
      padding: const EdgeInsets.all(AppDimensions.space16),
      itemCount: widgets.length,
      itemBuilder: (context, index) => widgets[index],
    );
  }

  Widget _buildCategorySection(
    BuildContext context,
    String category,
    List<UnifiedShoppingItem> items, {
    required ({int total, int completed}) progress,
    int startingIndex = 0,
  }) {
    final isCollapsed = _collapsedCategories.contains(category);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // #inkop: a plated band, the name in capitals and "N av M" at the
        // right. Min 48px keeps the collapse toggle a full tap target.
        KeyedSubtree(
          key: ValueKey('shopping-category-header-$category'),
          child: SectionBand(
            title: ShoppingCategory.displayName(category),
            count: context.l10n.shoppingCategoryProgress(
              progress.completed,
              progress.total,
            ),
            expanded: !isCollapsed,
            semanticLabel: context.l10n.a11yToggleShoppingCategory,
            onTap: () => setState(() {
              if (isCollapsed) {
                _collapsedCategories.remove(category);
              } else {
                _collapsedCategories.add(category);
              }
            }),
          ),
        ),

        // Items in category (hidden when collapsed). `startingIndex` keeps
        // the `item-toggle-{n}` identifier globally unique across sections.
        if (!isCollapsed)
          for (final (i, item) in items.indexed)
            _itemRow(context, item, false, startingIndex + i),

        const SizedBox(height: AppDimensions.space16),
      ],
    );
  }

  Widget _itemRow(
    BuildContext context,
    UnifiedShoppingItem item,
    bool isCompleted,
    int visualIndex,
  ) {
    return ShoppingItemTiles.buildItemTile(
      context,
      item,
      isCompleted,
      widget.onItemTap,
      widget.onEditItem,
      widget.onDeleteItem,
      onMoveToCategory: widget.viewModel.canEditActiveList
          ? () => _showCategoryPicker(context, item)
          : null,
      visualIndex: visualIndex,
    );
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
      final moved = await widget.viewModel.moveItemToCategory(
        item.id,
        selected,
      );
      if (moved && context.mounted) {
        ShoppingListContentWidget.showCategoryMoveReceipt(context, selected);
      }
    }
  }

  /// "Köpt (N)" heading with the right-aligned "Rensa köpta" text action
  /// (Grafisk manual v6:524; Skarmar v12 del 2 #inkop :915-916 light,
  /// :1020-1021 dark). No icon, no subtitle line — the count lives in the
  /// heading itself, per the facit.
  Widget _buildCompletedItemsHeader(
    BuildContext context,
    UnifiedShoppingViewModel viewModel,
  ) {
    final cs = Theme.of(context).colorScheme;

    return Row(
      children: [
        Expanded(
          child: Text(
            context.l10n.shoppingBoughtCount(viewModel.boughtItems),
            // Nearest role to the facit's 12/700: labelSmall is 11/700,
            // the closest surviving weight-and-size match in the scale.
            style: AppTextStyles.labelSmall.copyWith(
              color: cs.onSurfaceVariant,
            ),
          ),
        ),
        TextButton(
          key: const ValueKey('shopping-clear-bought'),
          onPressed: widget.onClearCompleted,
          child: Text(
            context.l10n.shoppingClearBought,
            // Nearest role to the facit's 10.5/600: labelMedium is
            // 12.5/600, the closest surviving weight match (overline is
            // 10.5/700 — exact size, wrong weight; the facit's weight
            // matters more for a tappable action than 2px does).
            style: AppTextStyles.labelMedium.copyWith(
              color: context.modeColors.textAccent,
            ),
          ),
        ),
      ],
    );
  }
}
