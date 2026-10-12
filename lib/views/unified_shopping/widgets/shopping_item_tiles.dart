// lib/views/unified_shopping/widgets/shopping_item_tiles.dart
//
// The personal list's rows: ShoppingRow with the item's actions in its menu.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/models/unified/unified_shopping_item.dart';
import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/viewmodels/shopping/shopping_selection_manager.dart';
import 'package:butlery/widgets/common/icons/butlery_glyph.dart';
import 'package:butlery/widgets/common/icons/butlery_icons.dart';
import 'package:butlery/widgets/shopping/shopping_row.dart';

/// Static API surface for shopping item tiles.
///
/// Delegates to [ShoppingItemTile], one [ShoppingRow] per item.
///
/// BUT-403 identifier scheme:
///  - `item-toggle-{index}` on each item row for browser a11y queries
///  - `test-shopping-item-{index}` ValueKey for Flutter widget tests
class ShoppingItemTiles {
  /// Builds the row for [item].
  static Widget buildItemTile(
    BuildContext context,
    UnifiedShoppingItem item,
    bool isCompleted,
    Function(UnifiedShoppingItem) onItemTap,
    Function(UnifiedShoppingItem) onEditItem,
    Function(UnifiedShoppingItem) onDeleteItem, {
    VoidCallback? onMoveToCategory,
    int? visualIndex,
  }) {
    return ShoppingItemTile(
      key: ValueKey('shopping-item-${item.id}'),
      item: item,
      isCompleted: isCompleted,
      onItemTap: onItemTap,
      onEditItem: onEditItem,
      onDeleteItem: onDeleteItem,
      onMoveToCategory: onMoveToCategory,
      visualIndex: visualIndex,
    );
  }

  static Widget buildEmptyState({
    required BuildContext context,
    required String title,
    required String message,
    required IconData icon,
  }) {
    final cs = Theme.of(context).colorScheme;

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          ButleryIcon(
            icon,
            size: AppDimensions.iconSizeXXXl,
            color: cs.onSurfaceVariant,
          ),
          const SizedBox(height: AppDimensions.space16),
          Text(
            title,
            style: AppTextStyles.titleMedium.copyWith(
              color: cs.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppDimensions.space8),
          Text(
            message,
            style: AppTextStyles.bodySmall.copyWith(
              color: cs.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

/// One item of the personal list: the shared row, with the item's own
/// actions behind its menu and the long-press that starts a selection.
class ShoppingItemTile extends StatelessWidget {
  const ShoppingItemTile({
    super.key,
    required this.item,
    required this.isCompleted,
    required this.onItemTap,
    required this.onEditItem,
    required this.onDeleteItem,
    this.onMoveToCategory,
    this.visualIndex,
  });

  final UnifiedShoppingItem item;
  final bool isCompleted;
  final Function(UnifiedShoppingItem) onItemTap;
  final Function(UnifiedShoppingItem) onEditItem;
  final Function(UnifiedShoppingItem) onDeleteItem;
  final VoidCallback? onMoveToCategory;

  /// BUT-403 — 0-based row index within the visible list, used to build
  /// stable a11y identifiers (`item-toggle-{index}`).
  final int? visualIndex;

  @override
  Widget build(BuildContext context) {
    // Nullable: a tile rendered outside a selection context (e.g. in isolation
    // tests) simply isn't selectable — it degrades to the plain check-off tile.
    final selection = context.watch<ShoppingSelectionManager?>();
    final selectionMode = selection?.isSelectionMode ?? false;
    final selected = selection?.isSelected(item.id) ?? false;
    final l10n = context.l10n;

    return ShoppingRow(
      name: item.name,
      amount: item.quantityText,
      note: item.note,
      checked: isCompleted,
      selectionMode: selectionMode,
      selected: selected,
      semanticIdentifier: visualIndex != null
          ? 'item-toggle-$visualIndex'
          : null,
      tapKey: visualIndex != null
          ? ValueKey('test-shopping-item-$visualIndex')
          : null,
      // BUT-948: in selection mode tap toggles selection; otherwise tap
      // checks the item off and long-press enters selection.
      onTap: selectionMode
          ? () => selection!.toggleSelection(item.id)
          : () => onItemTap(item),
      onLongPress: (selection == null || selectionMode)
          ? null
          : () => selection.enterSelectionMode(item.id),
      trailing: selectionMode
          ? null
          : Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (item.priority > 3) _PriorityDot(priority: item.priority),
                ShoppingRowMenu(
                  itemName: item.name,
                  actions: [
                    ShoppingRowAction(
                      label: l10n.commonEdit,
                      icon: ButleryIcons.pencil,
                      onSelected: () => onEditItem(item),
                    ),
                    if (onMoveToCategory != null && !isCompleted)
                      ShoppingRowAction(
                        label: l10n.shoppingMoveToCategory,
                        icon: ButleryIcons.move,
                        onSelected: onMoveToCategory!,
                      ),
                    ShoppingRowAction(
                      label: l10n.commonDelete,
                      icon: ButleryIcons.trash2,
                      onSelected: () => onDeleteItem(item),
                    ),
                  ],
                ),
              ],
            ),
    );
  }
}

class _PriorityDot extends StatelessWidget {
  const _PriorityDot({required this.priority});

  final int priority;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      width: 8,
      height: 8,
      margin: const EdgeInsetsDirectional.only(end: AppDimensions.space4),
      decoration: BoxDecoration(
        color: priority >= 4 ? cs.onSurface : cs.onSurfaceVariant,
        shape: BoxShape.circle,
      ),
    );
  }
}
