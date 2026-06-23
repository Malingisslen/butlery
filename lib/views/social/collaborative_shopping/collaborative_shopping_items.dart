// lib/views/social/collaborative_shopping/collaborative_shopping_items.dart
//
// BUT-238: split-store collaborative shopping UI.
// - Segmented toggle: [Alla] [Min del] [Efter zon].
// - "Min del" mode: 3 sections (my / others / unassigned).
// - "Efter zon" mode: grouped by ShoppingCategory.defaultStoreOrder.
// - Tap to claim on unassigned items; tap to release on own-assigned items.
// All Firestore work routes through the ViewModel.

import 'package:flutter/material.dart';
import 'package:butlery/viewmodels/collaborative_shopping_viewmodel.dart';
import 'package:butlery/viewmodels/collaborative_shopping/shopping_item_operations_manager.dart'
    show ClaimOutcome, ClaimResult;
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/models/unified/unified_shopping_item.dart';
import 'package:butlery/widgets/common/swipe_hint_banner.dart';
import 'package:butlery/widgets/common/state_widget.dart';
import 'package:butlery/core/extensions/default_value_extensions.dart';
import 'package:butlery/core/extensions/localization_extension.dart';

/// Focused widget for collaborative shopping items list (BUT-238 redesign).
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

    return Column(
      children: [
        _ViewModeToggle(
          mode: viewModel.viewMode,
          onChanged: viewModel.setViewMode,
        ),
        // BUT-1199: first-use hint for the swipe-to-claim gesture.
        SwipeHintBanner(
          seenKey: SwipeHintBanner.shoppingClaimSeenKey,
          icon: Icons.swipe,
          message: context.l10n.shoppingClaimHintText,
        ),
        Expanded(child: _buildBody(context)),
      ],
    );
  }

  Widget _buildBody(BuildContext context) {
    switch (viewModel.viewMode) {
      case ShoppingViewMode.all:
        return _buildFlatList(context);
      case ShoppingViewMode.myPart:
        return _buildMyPartList(context);
      case ShoppingViewMode.byZone:
        return _buildByZoneList(context);
    }
  }

  // --- Mode: Alla ---------------------------------------------------------

  Widget _buildFlatList(BuildContext context) {
    final activeItems = viewModel.activeItems;
    final completedItems = viewModel.completedItemsList;

    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: AppDimensions.spacingS),
      itemCount:
          activeItems.length +
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

  // --- Mode: Min del ------------------------------------------------------

  Widget _buildMyPartList(BuildContext context) {
    final mine = viewModel.myItems;
    final others = viewModel.othersItems;
    final unassigned = viewModel.unassignedItems;
    final completed = viewModel.completedItemsList;

    return ListView(
      padding: const EdgeInsets.symmetric(vertical: AppDimensions.spacingS),
      children: [
        if (mine.isNotEmpty) ...[
          _SectionHeader(text: context.l10n.minDel, count: mine.length),
          ...mine.map((i) => _buildItemCard(context, i, false)),
        ],
        if (others.isNotEmpty) ...[
          _SectionHeader(
            text: _othersSectionTitle(context, others),
            count: others.length,
            greyed: true,
          ),
          ...others.map((i) => _buildItemCard(context, i, false, greyed: true)),
        ],
        if (unassigned.isNotEmpty) ...[
          _SectionHeader(
            text: context.l10n.otilldelat,
            count: unassigned.length,
          ),
          ...unassigned.map((i) => _buildItemCard(context, i, false)),
        ],
        if (completed.isNotEmpty) ...[
          _buildCompletedSeparator(context),
          ...completed.map((i) => _buildItemCard(context, i, true)),
        ],
      ],
    );
  }

  String _othersSectionTitle(
    BuildContext context,
    List<UnifiedShoppingItem> others,
  ) {
    // Plan: "Annas del". When >1 assignee, collapse to "Andra".
    final uniqueAssignees = <String>{
      for (final i in others)
        if (i.assignedToDisplayName != null) i.assignedToDisplayName!,
    };
    if (uniqueAssignees.length == 1) {
      return context.l10n.annasDel(uniqueAssignees.first);
    }
    return context.l10n.annasDel(
      context.l10n.commonYou == 'Du' ? 'andra' : 'others',
    );
  }

  // --- Mode: Efter zon ----------------------------------------------------

  Widget _buildByZoneList(BuildContext context) {
    final activeItems = viewModel.activeItems;
    final completed = viewModel.completedItemsList;

    final itemsByZone = <String, List<UnifiedShoppingItem>>{};
    for (final item in activeItems) {
      itemsByZone.putIfAbsent(item.category, () => []).add(item);
    }

    final orderedZones = ShoppingCategory.defaultStoreOrder
        .where(itemsByZone.containsKey)
        .toList(growable: false);

    return ListView(
      padding: const EdgeInsets.symmetric(vertical: AppDimensions.spacingS),
      children: [
        for (final zone in orderedZones) ...[
          _SectionHeader(
            text: ShoppingCategory.displayName(zone),
            count: itemsByZone[zone]!.length,
          ),
          ...itemsByZone[zone]!.map((i) => _buildItemCard(context, i, false)),
        ],
        if (completed.isNotEmpty) ...[
          _buildCompletedSeparator(context),
          ...completed.map((i) => _buildItemCard(context, i, true)),
        ],
      ],
    );
  }

  // --- Shared UI primitives ----------------------------------------------

  Widget _buildEmptyState(BuildContext context) {
    return StateWidget.empty(
      title: context.l10n.collaborativeNoItemsYet,
      subtitle: viewModel.canEdit
          ? context.l10n.collaborativeAddFirstItem
          : context.l10n.collaborativeWaitingForOthers,
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
            padding: const EdgeInsets.symmetric(
              horizontal: AppDimensions.spacingS,
            ),
            child: Text(
              '${context.l10n.collaborativeCompleted} (${viewModel.completedItemsCount})',
              style: AppTextStyles.bodyBold,
            ),
          ),
          Expanded(
            child: Divider(color: Theme.of(context).colorScheme.outline),
          ),
        ],
      ),
    );
  }

  Widget _buildItemCard(
    BuildContext context,
    UnifiedShoppingItem item,
    bool isCompleted, {
    bool greyed = false,
  }) {
    return _CollaborativeItemCard(
      key: ValueKey(item.id),
      item: item,
      isCompleted: isCompleted,
      greyed: greyed,
      viewModel: viewModel,
      onToggleItem: onToggleItem,
    );
  }

  int getTotalItemCount() {
    final activeCount = viewModel.activeItems.length;
    final completedCount = viewModel.completedItemsList.length;
    return activeCount + (completedCount > 0 ? completedCount + 1 : 0);
  }

  bool isCompletedSeparatorIndex(int index) {
    return index == viewModel.activeItems.length &&
        viewModel.completedItemsList.isNotEmpty;
  }

  bool isActiveItemIndex(int index) {
    return index < viewModel.activeItems.length;
  }

  bool isCompletedItemIndex(int index) {
    final activeCount = viewModel.activeItems.length;
    final hasCompletedSeparator = viewModel.completedItemsList.isNotEmpty;
    return hasCompletedSeparator && index > activeCount;
  }

  dynamic getItemFromIndex(int index) {
    if (isActiveItemIndex(index)) {
      return viewModel.activeItems[index];
    } else if (isCompletedItemIndex(index)) {
      final completedIndex = index - viewModel.activeItems.length - 1;
      return viewModel.completedItemsList[completedIndex];
    }
    return null;
  }

  double getEstimatedScrollPosition(String itemId) {
    const double itemHeight = 80.0;
    const double separatorHeight = 40.0;

    double scrollPosition = 0.0;
    for (final item in viewModel.activeItems) {
      if (item.id == itemId) return scrollPosition;
      scrollPosition += itemHeight;
    }
    if (viewModel.completedItemsList.isNotEmpty) {
      scrollPosition += separatorHeight;
    }
    for (final item in viewModel.completedItemsList) {
      if (item.id == itemId) return scrollPosition;
      scrollPosition += itemHeight;
    }
    return scrollPosition;
  }

  Map<String, int> getItemsCounts() {
    return {
      'active': viewModel.activeItems.length,
      'completed': viewModel.completedItemsList.length,
      'total': viewModel.totalItems,
    };
  }
}

class _ViewModeToggle extends StatelessWidget {
  final ShoppingViewMode mode;
  final ValueChanged<ShoppingViewMode> onChanged;

  const _ViewModeToggle({required this.mode, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimensions.spacingL,
        vertical: AppDimensions.spacingS,
      ),
      child: SegmentedButton<ShoppingViewMode>(
        showSelectedIcon: false,
        style: SegmentedButton.styleFrom(
          shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
        ),
        segments: [
          ButtonSegment(
            value: ShoppingViewMode.all,
            label: Text(context.l10n.alla),
          ),
          ButtonSegment(
            value: ShoppingViewMode.myPart,
            label: Text(context.l10n.minDel),
          ),
          ButtonSegment(
            value: ShoppingViewMode.byZone,
            label: Text(context.l10n.efterZon),
          ),
        ],
        selected: {mode},
        onSelectionChanged: (set) => onChanged(set.first),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String text;
  final int count;
  final bool greyed;

  const _SectionHeader({
    required this.text,
    required this.count,
    this.greyed = false,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final base = greyed ? cs.onSurfaceVariant : cs.onSurface;
    final color = greyed
        ? base.withValues(alpha: AppDimensions.opacityHalf)
        : base;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppDimensions.spacingL,
        AppDimensions.spacingM,
        AppDimensions.spacingL,
        AppDimensions.spacingXs,
      ),
      child: Text(
        '${text.toUpperCase()} ($count)',
        style: AppTextStyles.bodyBold.copyWith(
          color: color,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

class _CollaborativeItemCard extends StatelessWidget {
  final UnifiedShoppingItem item;
  final bool isCompleted;
  final bool greyed;
  final CollaborativeShoppingViewModel viewModel;
  final Function(String itemId) onToggleItem;

  const _CollaborativeItemCard({
    super.key,
    required this.item,
    required this.isCompleted,
    required this.greyed,
    required this.viewModel,
    required this.onToggleItem,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final uid = viewModel.currentUserId;
    final isMine =
        item.assignedToUserId != null &&
        item.assignedToUserId == uid &&
        !isCompleted;
    final isClaimableByMe =
        !isCompleted && item.assignedToUserId == null && viewModel.canEdit;
    final canRelease = isMine && viewModel.canEdit;

    final bodyColor = greyed
        ? cs.surfaceContainerHighest.withValues(
            alpha: AppDimensions.opacityHalf,
          )
        : (isCompleted
              ? cs.surfaceContainerHighest.withValues(
                  alpha: AppDimensions.opacityHalf,
                )
              : null);

    return Card(
      key: ValueKey('collab-item-${item.id}'),
      margin: const EdgeInsets.symmetric(
        horizontal: AppDimensions.spacingL,
        vertical: AppDimensions.spacingXs,
      ),
      elevation: (isCompleted || greyed) ? 0 : AppDimensions.elevationLow,
      color: bodyColor,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
      child: _maybeWrapSwipe(
        context: context,
        isClaimableByMe: isClaimableByMe,
        canRelease: canRelease,
        child: ListTile(
          leading: _buildCheckbox(context),
          title: _buildTitle(context),
          subtitle: _buildSubtitle(context),
          trailing: _buildTrailing(context),
          onTap: viewModel.canView ? () => onToggleItem(item.id) : null,
          dense: true,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: AppDimensions.paddingL,
            vertical: AppDimensions.paddingM,
          ),
        ),
      ),
    );
  }

  /// Wrap the tile in a Dismissible for swipe-right-to-claim on mobile.
  /// confirmDismiss returns false so the row snaps back; we trigger the
  /// claim/unclaim call via the confirm hook.
  Widget _maybeWrapSwipe({
    required BuildContext context,
    required bool isClaimableByMe,
    required bool canRelease,
    required Widget child,
  }) {
    if (!isClaimableByMe && !canRelease) return child;
    final cs = Theme.of(context).colorScheme;
    final label = canRelease ? context.l10n.lamnaTillbaka : context.l10n.tarJag;
    final background = Container(
      alignment: AlignmentDirectional.centerStart,
      padding: const EdgeInsets.symmetric(horizontal: AppDimensions.paddingL),
      color: cs.primaryContainer,
      child: Text(label, style: AppTextStyles.bodyBold),
    );
    return Dismissible(
      key: ValueKey('swipe-${item.id}'),
      direction: DismissDirection.startToEnd,
      background: background,
      confirmDismiss: (_) async {
        await _handleClaimAction(context, release: canRelease);
        return false;
      },
      child: child,
    );
  }

  Widget _buildCheckbox(BuildContext context) {
    return Checkbox(
      value: item.bought,
      onChanged: viewModel.canView ? (_) => onToggleItem(item.id) : null,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
    );
  }

  Widget _buildTitle(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final style = item.bought
        ? AppTextStyles.bodyMedium.copyWith(
            decoration: TextDecoration.lineThrough,
            color: cs.onSurfaceVariant,
          )
        : AppTextStyles.contentLabel;
    return Text(
      item.displayText,
      style: greyed
          ? style.copyWith(color: cs.onSurface.withValues(alpha: 0.5))
          : style,
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
    );
  }

  Widget? _buildSubtitle(BuildContext context) {
    final subtitle = viewModel.getItemSubtitle(item);
    return subtitle != null
        ? Text(
            subtitle,
            style: AppTextStyles.metadataEmphasized,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          )
        : null;
  }

  Widget _buildTrailing(BuildContext context) {
    final widgets = <Widget>[];
    if (item.assignedToUserId != null) {
      widgets.add(
        _AssigneeBadge(
          displayName: item.assignedToDisplayName ?? '?',
          isSelf: item.assignedToUserId == viewModel.currentUserId,
        ),
      );
      widgets.add(const SizedBox(width: AppDimensions.spacingXs));
    } else if (viewModel.canEdit && !item.bought) {
      widgets.add(
        TextButton(
          style: TextButton.styleFrom(
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.zero,
            ),
            padding: const EdgeInsets.symmetric(
              horizontal: AppDimensions.spacingS,
            ),
          ),
          onPressed: () => _handleClaimAction(context, release: false),
          child: Text(context.l10n.tarJag),
        ),
      );
    }
    widgets.addAll(viewModel.getItemTrailingWidgets(item));
    return Row(mainAxisSize: MainAxisSize.min, children: widgets);
  }

  Future<void> _handleClaimAction(
    BuildContext context, {
    required bool release,
  }) async {
    final result = release
        ? await viewModel.unclaimItem(item.id)
        : await viewModel.claimItem(item.id);
    if (!context.mounted) return;
    _maybeShowSnackBar(context, result);
  }

  void _maybeShowSnackBar(BuildContext context, ClaimResult result) {
    if (result.outcome != ClaimOutcome.conflict) return;
    final name = result.conflictingDisplayName.orEmpty();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(context.l10n.nagonAnnanTogDen(name))),
    );
  }
}

class _AssigneeBadge extends StatelessWidget {
  final String displayName;
  final bool isSelf;

  const _AssigneeBadge({required this.displayName, required this.isSelf});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final initials = _initials(displayName);
    final bg = isSelf ? cs.primary : cs.secondary;
    final fg = isSelf ? cs.onPrimary : cs.onSecondary;
    return Container(
      width: 28,
      height: 28,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: bg,
        shape: BoxShape.rectangle,
        borderRadius: BorderRadius.zero,
      ),
      child: Text(
        initials,
        style: AppTextStyles.labelSmall.copyWith(
          color: fg,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  static String _initials(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return '?';
    final parts = trimmed.split(RegExp(r'\s+'));
    if (parts.length == 1) {
      return parts.first.substring(0, 1).toUpperCase();
    }
    return (parts.first.substring(0, 1) + parts.last.substring(0, 1))
        .toUpperCase();
  }
}
