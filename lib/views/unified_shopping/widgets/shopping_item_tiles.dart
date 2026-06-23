// lib/views/unified_shopping/widgets/shopping_item_tiles.dart
//
// UI Redesign: Square checkboxes (22px, 2px green border)
// Animated check-off: scale pulse on checkbox, smooth fill transition

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:butlery/core/utils/reduced_motion.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/theme_constants.dart';
import 'package:butlery/models/unified/unified_shopping_item.dart';
import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/viewmodels/shopping/shopping_selection_manager.dart';
import 'package:butlery/widgets/common/buttons/action_buttons.dart';

/// Static API surface for shopping item tiles.
///
/// Delegates to [ShoppingItemTile] for animated item rendering.
///
/// BUT-403 identifier scheme:
///  - `item-toggle-{index}` on each item row for browser a11y queries
///  - `test-shopping-item-{index}` ValueKey for Flutter widget tests
class ShoppingItemTiles {
  /// BUT-948: the whole-tile long-press drag was replaced by a per-row grip
  /// handle inside [ShoppingItemTile] (so long-press is free for multi-select).
  /// This now just delegates to [buildItemTile]; the drag lives on the handle.
  static Widget buildDraggableItemTile(
    BuildContext context,
    UnifiedShoppingItem item,
    bool isCompleted,
    Function(UnifiedShoppingItem) onItemTap,
    Function(UnifiedShoppingItem) onEditItem,
    Function(UnifiedShoppingItem) onDeleteItem, {
    VoidCallback? onMoveToCategory,
    int? visualIndex,
  }) {
    return buildItemTile(
      context,
      item,
      isCompleted,
      onItemTap,
      onEditItem,
      onDeleteItem,
      onMoveToCategory: onMoveToCategory,
      visualIndex: visualIndex,
    );
  }

  /// Builds an item tile with animated check-off transitions.
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
          Icon(
            icon,
            size: 64,
            color: cs.onSurfaceVariant,
          ),
          const SizedBox(height: AppDimensions.spacingMd),
          Text(
            title,
            style: AppTextStyles.titleMedium.copyWith(
              color: cs.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppDimensions.spacingSm),
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

/// Animated shopping item tile with check-off transitions.
///
/// Provides a scale pulse on the checkbox and smooth fill-color
/// transition when toggling between checked/unchecked states.
class ShoppingItemTile extends StatefulWidget {
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
  State<ShoppingItemTile> createState() => _ShoppingItemTileState();
}

class _ShoppingItemTileState extends State<ShoppingItemTile>
    with SingleTickerProviderStateMixin {
  static const double _checkboxSize = 22.0;
  static const double _checkboxBorderWidth = 2.0;
  static const double _checkIconSize = 14.0;
  static const double _pulseScale = 1.2;
  static const double _priorityDotSize = 8.0;

  late final AnimationController _pulseController;
  late final Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: ThemeConstants.durationFast,
    );
    _pulseAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(
          begin: 1.0,
          end: _pulseScale,
        ).chain(CurveTween(curve: ThemeConstants.standardCurve)),
        weight: 50,
      ),
      TweenSequenceItem(
        tween: Tween(
          begin: _pulseScale,
          end: 1.0,
        ).chain(CurveTween(curve: ThemeConstants.standardCurve)),
        weight: 50,
      ),
    ]).animate(_pulseController);
  }

  @override
  void didUpdateWidget(ShoppingItemTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isCompleted != widget.isCompleted) {
      // Skip the decorative scale-pulse when the user has reduced motion on.
      // The fill-color change still happens (informational), just instantly.
      if (!isReducedMotion(context)) {
        _pulseController.forward(from: 0);
      }
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    // Nullable: a tile rendered outside a selection context (e.g. in isolation
    // tests) simply isn't selectable — it degrades to the plain check-off tile.
    final selection = context.watch<ShoppingSelectionManager?>();
    final selectionMode = selection?.isSelectionMode ?? false;
    final selected = selection?.isSelected(widget.item.id) ?? false;

    return RepaintBoundary(
      child: Container(
        margin: const EdgeInsets.only(bottom: AppDimensions.spacingXxs),
        decoration: BoxDecoration(
          color: selected
              ? cs.primary.withValues(alpha: 0.12)
              : cs.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(AppDimensions.borderRadiusS),
          border: Border.all(
            color: selected ? cs.primary : cs.outlineVariant,
            width: AppDimensions.borderWidthStandard,
          ),
        ),
        child: Semantics(
          identifier: widget.visualIndex != null
              ? 'item-toggle-${widget.visualIndex}'
              : null,
          label: selectionMode
              ? context.l10n.a11yShoppingSelectItem(widget.item.displayText)
              : (widget.isCompleted
                    ? context.l10n.a11yShoppingItemChecked(
                        widget.item.displayText,
                      )
                    : context.l10n.a11yShoppingItemUnchecked(
                        widget.item.displayText,
                      )),
          button: true,
          selected: selectionMode ? selected : null,
          enabled: true,
          child: Material(
            type: MaterialType.transparency,
            child: InkWell(
              key: widget.visualIndex != null
                  ? ValueKey('test-shopping-item-${widget.visualIndex}')
                  : null,
              // BUT-948: in selection mode tap toggles selection; otherwise tap
              // checks the item off and long-press enters selection.
              onTap: selectionMode
                  ? () => selection!.toggleSelection(widget.item.id)
                  : () => widget.onItemTap(widget.item),
              onLongPress: (selection == null || selectionMode)
                  ? null
                  : () => selection.enterSelectionMode(widget.item.id),
              borderRadius: BorderRadius.circular(AppDimensions.borderRadiusS),
              child: Padding(
                padding: const EdgeInsets.all(AppDimensions.paddingM),
                child: Row(
                  children: [
                    if (selectionMode) ...[
                      Icon(
                        selected ? Icons.check_circle : Icons.circle_outlined,
                        color: selected ? cs.primary : cs.onSurfaceVariant,
                        size: AppDimensions.iconSizeM,
                      ),
                      const SizedBox(width: AppDimensions.paddingM),
                    ],
                    _buildAnimatedCheckbox(cs),
                    const SizedBox(width: AppDimensions.paddingM),
                    _buildItemDetails(cs),
                    if (widget.item.priority > 3) _buildPriorityIndicator(cs),
                    if (!selectionMode) _buildActionButtons(context, cs),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAnimatedCheckbox(ColorScheme cs) {
    return ScaleTransition(
      scale: _pulseAnimation,
      child: AnimatedContainer(
        duration: ThemeConstants.durationStandard.respectingMotion(context),
        curve: ThemeConstants.standardCurve,
        width: _checkboxSize,
        height: _checkboxSize,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppDimensions.borderRadiusXs),
          border: Border.all(
            color: cs.primary,
            width: _checkboxBorderWidth,
          ),
          color: widget.isCompleted ? cs.primary : cs.surfaceContainerHighest,
        ),
        child: AnimatedSwitcher(
          duration: ThemeConstants.durationFast.respectingMotion(context),
          switchInCurve: ThemeConstants.standardCurve,
          switchOutCurve: ThemeConstants.standardCurve,
          child: widget.isCompleted
              ? Icon(
                  Icons.check,
                  key: const ValueKey('check-icon'),
                  size: _checkIconSize,
                  color: cs.surfaceContainerHighest,
                )
              : const SizedBox.shrink(key: ValueKey('empty-icon')),
        ),
      ),
    );
  }

  Widget _buildItemDetails(ColorScheme cs) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.item.displayText,
            style: AppTextStyles.contentTitle.copyWith(
              color: widget.isCompleted ? cs.onSurfaceVariant : cs.onSurface,
              decoration: widget.isCompleted
                  ? TextDecoration.lineThrough
                  : TextDecoration.none,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          if (widget.item.note?.isNotEmpty == true) ...[
            const SizedBox(height: AppDimensions.spacingXs),
            Text(
              widget.item.note!,
              style: AppTextStyles.bodySmall.copyWith(
                color: widget.isCompleted
                    ? cs.onSurfaceVariant.withValues(
                        alpha: AppDimensions.opacityVeryDark,
                      )
                    : cs.onSurfaceVariant,
                decoration: widget.isCompleted
                    ? TextDecoration.lineThrough
                    : TextDecoration.none,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPriorityIndicator(ColorScheme cs) {
    return Container(
      width: _priorityDotSize,
      height: _priorityDotSize,
      margin: const EdgeInsetsDirectional.only(start: 8),
      decoration: BoxDecoration(
        color: _getPriorityColor(cs, widget.item.priority),
        shape: BoxShape.circle,
      ),
    );
  }

  Widget _buildActionButtons(BuildContext context, ColorScheme cs) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // BUT-948: the drag-to-move shortcut now lives on this grip handle
        // (long-press is reserved for multi-select). Category-move is also still
        // available via the move-to-category button below.
        if (widget.onMoveToCategory != null && !widget.isCompleted)
          _buildDragHandle(context, cs),
        if (widget.onMoveToCategory != null && !widget.isCompleted)
          AppIconButton(
            icon: Icons.drive_file_move_outline,
            onPressed: widget.onMoveToCategory,
            semanticLabel: context.l10n.shoppingMoveToCategory,
            color: cs.onSurfaceVariant,
            iconSize: AppDimensions.iconSizeS,
          ),
        AppIconButton(
          icon: Icons.edit,
          onPressed: () => widget.onEditItem(widget.item),
          semanticLabel: context.l10n.a11yEditItem(widget.item.name),
          color: cs.onSurfaceVariant,
          iconSize: AppDimensions.iconSizeS,
        ),
        AppIconButton(
          icon: Icons.delete,
          onPressed: () => widget.onDeleteItem(widget.item),
          semanticLabel: context.l10n.a11yDeleteItem(widget.item.name),
          color: cs.onSurfaceVariant.withValues(
            alpha: AppDimensions.opacityDark,
          ),
          iconSize: AppDimensions.iconSizeS,
        ),
      ],
    );
  }

  /// BUT-948: grip handle that initiates the category-move drag (replaces the
  /// old whole-tile long-press drag). The existing category DragTarget accepts
  /// the dragged [UnifiedShoppingItem] unchanged.
  Widget _buildDragHandle(BuildContext context, ColorScheme cs) {
    return Draggable<UnifiedShoppingItem>(
      data: widget.item,
      feedback: Material(
        elevation: 4,
        borderRadius: BorderRadius.circular(AppDimensions.borderRadiusS),
        child: Container(
          width: MediaQuery.of(context).size.width * 0.8,
          padding: const EdgeInsets.all(AppDimensions.paddingM),
          decoration: BoxDecoration(
            color: cs.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(AppDimensions.borderRadiusS),
            border: Border.all(color: cs.primary, width: 2),
          ),
          child: Text(
            widget.item.displayText,
            style: AppTextStyles.contentTitle.copyWith(color: cs.onSurface),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ),
      childWhenDragging: const SizedBox.shrink(),
      child: Semantics(
        // Drag-only affordance: announce what it is, but NOT as a button —
        // it doesn't respond to a screen-reader activate/tap (the accessible
        // path is the move-to-category button). `button: true` was misleading.
        label: context.l10n.a11yShoppingReorderHandle(widget.item.name),
        child: Icon(
          Icons.drag_handle,
          color: cs.onSurfaceVariant,
          size: AppDimensions.iconSizeS,
        ),
      ),
    );
  }

  static Color _getPriorityColor(ColorScheme cs, int priority) {
    switch (priority) {
      case 4:
      case 5:
        return cs.primary;
      default:
        return cs.onSurfaceVariant;
    }
  }
}
