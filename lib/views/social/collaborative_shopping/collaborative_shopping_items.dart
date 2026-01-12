// lib/views/social/collaborative_shopping/collaborative_shopping_items.dart

import 'package:flutter/material.dart';
import 'package:butlery/viewmodels/collaborative_shopping_viewmodel.dart';
import 'package:butlery/theme/app_colors.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/widgets/common/state_widget.dart';

/// Focused widget for collaborative shopping items list
/// This widget handles ONLY items list display responsibilities:
/// - Active and completed items rendering
/// - Item cards with checkboxes and details
/// - Empty state display
/// - Items list organization and separators
/// ❌ DOES NOT CONTAIN: Item actions, header display, business logic
class CollaborativeShoppingItems extends StatelessWidget {
  final CollaborativeShoppingViewModel viewModel;
  final Function(String itemId) onToggleItem;

  const CollaborativeShoppingItems({
    super.key,
    required this.viewModel,
    required this.onToggleItem,
  });

  @override
  Widget build(BuildContext context) {
    if (viewModel.totalItems == 0) {
      return _buildEmptyState(context);
    }

    final activeItems = viewModel.activeItems;
    final completedItems = viewModel.completedItemsList;

    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: AppDimensions.spacingS),
      itemCount: activeItems.length +
          (completedItems.isNotEmpty ? completedItems.length + 1 : 0),
      itemBuilder: (context, index) {
        if (index < activeItems.length) {
          return _buildItemCard(context, activeItems[index], false);
        } else if (index == activeItems.length && completedItems.isNotEmpty) {
          return _buildCompletedSeparator(context);
        } else {
          final completedIndex = index - activeItems.length - 1;
          return _buildItemCard(context, completedItems[completedIndex], true);
        }
      },
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return StateWidget.empty(
      title: 'Inga artiklar än',
      subtitle: viewModel.canEdit
          ? 'Lägg till den första artikeln ovan'
          : 'Väntar på att andra lägger till artiklar',
      icon: Icons.shopping_cart_outlined,
    );
  }

  Widget _buildCompletedSeparator(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimensions.spacingL,
        vertical: AppDimensions.spacingS,
      ),
      child: Row(
        children: [
          Expanded(
            child: Divider(color: Theme.of(context).colorScheme.outline),
          ),
          Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: AppDimensions.spacingS),
            child: Text(
              'KLARA (${viewModel.completedItemsCount})',
              style: AppTextStyles.bodySmall.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child: Divider(color: Theme.of(context).colorScheme.outline),
          ),
        ],
      ),
    );
  }

  Widget _buildItemCard(BuildContext context, dynamic item, bool isCompleted) {
    return Card(
      key: ValueKey(item.id),
      margin: const EdgeInsets.symmetric(
        horizontal: AppDimensions.spacingL,
        vertical: AppDimensions.spacingXs,
      ),
      elevation: isCompleted ? 0 : AppDimensions.elevationLow,
      color: isCompleted
          ? Theme.of(context)
              .colorScheme
              .surfaceContainerHighest
              .withValues(alpha: AppDimensions.opacityHalf)
          : null,
      child: ListTile(
        leading: _buildItemCheckbox(context, item),
        title: _buildItemTitle(context, item),
        subtitle: _buildItemSubtitle(context, item),
        trailing: _buildItemTrailing(context, item),
        onTap: viewModel.canView ? () => onToggleItem(item.id) : null,
        dense: true,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppDimensions.paddingL,
          vertical: AppDimensions.paddingM,
        ),
      ),
    );
  }

  Widget _buildItemCheckbox(BuildContext context, dynamic item) {
    return Checkbox(
      value: item.bought,
      onChanged: viewModel.canView ? (_) => onToggleItem(item.id) : null,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppDimensions.borderRadiusS),
      ),
    );
  }

  Widget _buildItemTitle(BuildContext context, dynamic item) {
    return Text(
      item.displayText,
      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            decoration: item.bought ? TextDecoration.lineThrough : null,
            color: item.bought
                ? Theme.of(context).colorScheme.onSurfaceVariant
                : null,
            fontWeight: item.bought ? FontWeight.normal : FontWeight.w500,
          ),
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
    );
  }

  Widget? _buildItemSubtitle(BuildContext context, dynamic item) {
    final subtitle = viewModel.getItemSubtitle(item);
    return subtitle != null
        ? Text(
            subtitle,
            style:
                AppTextStyles.bodySmall.copyWith(color: AppColors.textMedium),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          )
        : null;
  }

  Widget? _buildItemTrailing(BuildContext context, dynamic item) {
    final widgets = viewModel.getItemTrailingWidgets(item);
    return widgets.isEmpty
        ? null
        : Row(mainAxisSize: MainAxisSize.min, children: widgets);
  }

  int getTotalItemCount() {
    final activeCount = viewModel.activeItems.length;
    final completedCount = viewModel.completedItemsList.length;
    return activeCount + (completedCount > 0 ? completedCount + 1 : 0);
  }

  /// Check if index represents a completed item separator
  bool isCompletedSeparatorIndex(int index) {
    return index == viewModel.activeItems.length &&
        viewModel.completedItemsList.isNotEmpty;
  }

  /// Check if index represents an active item
  bool isActiveItemIndex(int index) {
    return index < viewModel.activeItems.length;
  }

  /// Check if index represents a completed item
  bool isCompletedItemIndex(int index) {
    final activeCount = viewModel.activeItems.length;
    final hasCompletedSeparator = viewModel.completedItemsList.isNotEmpty;
    return hasCompletedSeparator && index > activeCount;
  }

  /// Get item from index, handling separator positions
  dynamic getItemFromIndex(int index) {
    if (isActiveItemIndex(index)) {
      return viewModel.activeItems[index];
    } else if (isCompletedItemIndex(index)) {
      final completedIndex = index - viewModel.activeItems.length - 1;
      return viewModel.completedItemsList[completedIndex];
    }
    return null;
  }

  /// Calculate estimated scroll position for specific item
  double getEstimatedScrollPosition(String itemId) {
    const double itemHeight = 80.0; // Approximate item card height
    const double separatorHeight = 40.0;

    double scrollPosition = 0.0;

    // Check active items
    for (final item in viewModel.activeItems) {
      if (item.id == itemId) {
        return scrollPosition;
      }
      scrollPosition += itemHeight;
    }

    // Add separator if completed items exist
    if (viewModel.completedItemsList.isNotEmpty) {
      scrollPosition += separatorHeight;
    }

    // Check completed items
    for (final item in viewModel.completedItemsList) {
      if (item.id == itemId) {
        return scrollPosition;
      }
      scrollPosition += itemHeight;
    }

    return scrollPosition;
  }

  /// Get items count for specific section
  Map<String, int> getItemsCounts() {
    return {
      'active': viewModel.activeItems.length,
      'completed': viewModel.completedItemsList.length,
      'total': viewModel.totalItems,
    };
  }
}
