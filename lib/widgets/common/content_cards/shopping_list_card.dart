// lib/widgets/common/content_cards/shopping_list_card.dart

import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_shadows.dart';
import 'package:butlery/theme/butlery_colors_extension.dart';
import 'package:butlery/widgets/common/hoverable_card.dart';
import 'package:butlery/models/unified/unified_shopping_list.dart';
import 'package:butlery/models/unified/unified_shopping_item.dart';

/// Focused module for shopping list card components
/// This module handles ONLY shopping list card display responsibilities:
/// - Shopping list card rendering with list-specific data
/// - Shopping list metadata display (item count, completion status)
/// - Shopping list sharing status and collaborative indicators
/// - Shopping list-specific styling and theming
/// - Shopping list preview with item list
class ShoppingListCard extends StatelessWidget {
  final UnifiedShoppingList shoppingList;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final bool showPreview;
  final bool showMetadata;
  final bool showSharingStatus;
  final EdgeInsets? margin;
  final EdgeInsets? padding;
  final ShoppingListCardStyle style;

  const ShoppingListCard({
    super.key,
    required this.shoppingList,
    this.onTap,
    this.onLongPress,
    this.showPreview = true,
    this.showMetadata = true,
    this.showSharingStatus = false,
    this.margin,
    this.padding,
    this.style = ShoppingListCardStyle.detailed,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    // Reproduce the previous Material(elevation: 4) appearance as a decoration
    // so the card looks identical at rest, then let HoverableCard deepen the
    // shadow on hover (web/desktop only). Square corners are preserved.
    final restDecoration = BoxDecoration(
      color: cs.surface,
      borderRadius: BorderRadius.circular(AppDimensions.borderRadiusM),
      boxShadow: AppShadows.elevated,
    );

    return RepaintBoundary(
      child: HoverableCard(
        // Hover lift only when the card is actually tappable.
        enabled: onTap != null,
        margin: margin ?? _getDefaultMargin(),
        restDecoration: restDecoration,
        hoverDecoration: restDecoration.copyWith(
          boxShadow: AppShadows.floating,
        ),
        child: Material(
          type: MaterialType.transparency,
          child: Semantics(
            label: context.l10n.a11yShoppingList(shoppingList.name),
            button: true,
            child: InkWell(
              onTap: onTap,
              onLongPress: onLongPress,
              borderRadius: BorderRadius.circular(AppDimensions.borderRadiusM),
              child: Padding(
                padding: padding ?? _getDefaultPadding(),
                child: _buildContent(context),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context) {
    switch (style) {
      case ShoppingListCardStyle.detailed:
        return _buildDetailedContent(context);
      case ShoppingListCardStyle.compact:
        return _buildCompactContent(context);
      case ShoppingListCardStyle.grid:
        return _buildGridContent(context);
    }
  }

  Widget _buildDetailedContent(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildListHeader(context),
        if (showMetadata) ...[
          const SizedBox(height: AppDimensions.spacingS),
          _buildListMetadata(context),
        ],
        if (showPreview) ...[
          const SizedBox(height: AppDimensions.spacingM),
          _buildListPreview(context),
        ],
        if (showSharingStatus) ...[
          const SizedBox(height: AppDimensions.spacingM),
          _buildSharingStatus(context),
        ],
      ],
    );
  }

  Widget _buildCompactContent(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildListHeader(context),
              if (showMetadata) ...[
                const SizedBox(height: AppDimensions.spacingXs),
                _buildListMetadata(context),
              ],
            ],
          ),
        ),
        if (showSharingStatus) _buildSharingIndicator(context),
        _buildCompletionIndicator(context),
      ],
    );
  }

  Widget _buildGridContent(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildListHeader(context),
        if (showMetadata) ...[
          const SizedBox(height: AppDimensions.spacingXs),
          _buildListMetadata(context),
        ],
        const SizedBox(height: AppDimensions.spacingS),
        Row(
          children: [
            if (showSharingStatus) ...[
              _buildSharingIndicator(context),
              const SizedBox(width: AppDimensions.spacingS),
            ],
            _buildCompletionIndicator(context),
          ],
        ),
      ],
    );
  }

  Widget _buildListHeader(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final title = _getListTitle();
    return Row(
      children: [
        Icon(
          Icons.shopping_cart,
          size: AppDimensions.iconSizeM,
          color: cs.onSurfaceVariant,
        ),
        const SizedBox(width: AppDimensions.spacingS),
        Expanded(
          child: Text(
            title,
            style: style == ShoppingListCardStyle.compact
                ? AppTextStyles.bodyLarge
                : AppTextStyles.titleMedium,
            maxLines: style == ShoppingListCardStyle.compact ? 1 : 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _buildListMetadata(BuildContext context) {
    final totalItems = _getTotalItems();
    final completedItems = _getCompletedItems();
    final createdDate = _getCreatedDate();

    final metadata = <String>[];
    if (totalItems > 0) {
      metadata.add('$totalItems ${context.l10n.shoppingItems}');
    }
    if (completedItems > 0) {
      metadata.add(context.l10n.shoppingCardCompleted(completedItems));
    }
    if (createdDate != null) {
      metadata.add(_formatDate(context, createdDate));
    }

    if (metadata.isEmpty) {
      return const SizedBox.shrink();
    }

    return Text(
      metadata.join(' \u2022 '),
      style: AppTextStyles.metadataEmphasized,
    );
  }

  Widget _buildListPreview(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final items = _getListItems();

    if (items.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(AppDimensions.spacingM),
        decoration: BoxDecoration(
          color: cs.surfaceContainerLow,
          borderRadius: BorderRadius.circular(AppDimensions.borderRadiusS),
        ),
        child: Row(
          children: [
            Icon(
              Icons.info_outline,
              size: AppDimensions.iconSizeS,
              color: cs.onSurfaceVariant,
            ),
            const SizedBox(width: AppDimensions.spacingS),
            Text(
              context.l10n.shoppingCardNoItems,
              style: AppTextStyles.metadataEmphasized,
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.l10n.shoppingCardItemsOnList,
          style: AppTextStyles.labelMediumMuted,
        ),
        const SizedBox(height: AppDimensions.spacingS),
        ...items
            .take(4)
            .map(
              (item) => Padding(
                padding: const EdgeInsets.only(bottom: AppDimensions.spacingXs),
                child: Row(
                  children: [
                    Icon(
                      _isItemCompleted(item)
                          ? Icons.check_circle
                          : Icons.radio_button_unchecked,
                      size: AppDimensions.iconSizeS,
                      color: _isItemCompleted(item)
                          ? context.butleryColors.success
                          : cs.onSurfaceVariant,
                    ),
                    const SizedBox(width: AppDimensions.spacingS),
                    Expanded(
                      child: Text(
                        _getItemTitle(item),
                        style: AppTextStyles.bodySmall.copyWith(
                          decoration: _isItemCompleted(item)
                              ? TextDecoration.lineThrough
                              : null,
                          color: _isItemCompleted(item)
                              ? cs.onSurfaceVariant
                              : cs.onSurface,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        if (items.length > 4)
          Padding(
            padding: const EdgeInsets.only(top: AppDimensions.spacingXs),
            child: Text(
              context.l10n.shoppingCardMoreItems(items.length - 4),
              style: AppTextStyles.metadataEmphasized,
            ),
          ),
      ],
    );
  }

  Widget _buildSharingStatus(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isShared = _isListShared();
    final memberCount = _getListMemberCount();

    if (!isShared) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimensions.spacingM,
        vertical: AppDimensions.spacingS,
      ),
      decoration: BoxDecoration(
        color: cs.primary.withValues(alpha: AppDimensions.opacityVeryLight),
        borderRadius: BorderRadius.circular(AppDimensions.borderRadiusS),
        border: Border.all(
          color: cs.primary.withValues(alpha: AppDimensions.opacityMediumLight),
          width: AppDimensions.borderWidthThin,
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.people,
            size: AppDimensions.iconSizeS,
            color: cs.primary,
          ),
          const SizedBox(width: AppDimensions.spacingS),
          Text(
            memberCount > 0
                ? context.l10n.shoppingCardSharedWithCount(memberCount)
                : context.l10n.shoppingCardSharedList,
            style: AppTextStyles.linkSmall,
          ),
        ],
      ),
    );
  }

  Widget _buildSharingIndicator(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isShared = _isListShared();

    if (!isShared) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.all(AppDimensions.spacingXs),
      decoration: BoxDecoration(
        color: cs.primary,
        shape: BoxShape.circle,
      ),
      child: Icon(
        Icons.people,
        size: AppDimensions.iconSizeS,
        color: cs.surfaceContainerHighest,
      ),
    );
  }

  Widget _buildCompletionIndicator(BuildContext context) {
    final totalItems = _getTotalItems();
    final completedItems = _getCompletedItems();

    if (totalItems == 0) {
      return const SizedBox.shrink();
    }

    final completionPercentage = (completedItems / totalItems);
    final isComplete = completionPercentage == 1.0;
    final bc = context.butleryColors;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimensions.spacingS,
        vertical: AppDimensions.spacingXs,
      ),
      decoration: BoxDecoration(
        color: isComplete
            ? bc.success.withValues(alpha: AppDimensions.opacityLightSubtle)
            : bc.warning.withValues(alpha: AppDimensions.opacityLightSubtle),
        borderRadius: BorderRadius.circular(AppDimensions.borderRadiusS),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isComplete ? Icons.check_circle : Icons.hourglass_empty,
            size: AppDimensions.iconSizeS,
            color: isComplete ? bc.success : bc.warning,
          ),
          const SizedBox(width: AppDimensions.spacingXs),
          Text(
            isComplete
                ? context.l10n.shoppingCardComplete
                : '${(completionPercentage * 100).round()}%',
            style: AppTextStyles.labelSmall.copyWith(
              color: isComplete ? bc.success : bc.warning,
            ),
          ),
        ],
      ),
    );
  }

  // Helper methods

  String _getListTitle() {
    return shoppingList.name;
  }

  int _getTotalItems() {
    return shoppingList.totalItems;
  }

  int _getCompletedItems() {
    return shoppingList.boughtItems;
  }

  DateTime? _getCreatedDate() {
    return shoppingList.createdAt;
  }

  List<UnifiedShoppingItem> _getListItems() {
    return shoppingList.items;
  }

  String _getItemTitle(UnifiedShoppingItem item) {
    return item.displayText;
  }

  bool _isItemCompleted(UnifiedShoppingItem item) {
    return item.bought;
  }

  bool _isListShared() {
    return shoppingList.isCollaborative;
  }

  int _getListMemberCount() {
    return shoppingList.memberCount;
  }

  String _formatDate(BuildContext context, DateTime date) {
    final now = clock.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) {
      return context.l10n.dateToday;
    } else if (difference.inDays == 1) {
      return context.l10n.dateYesterday;
    } else if (difference.inDays < 7) {
      return context.l10n.dateDaysAgo(difference.inDays);
    } else if (difference.inDays < 30) {
      return context.l10n.dateWeeksAgo((difference.inDays / 7).round());
    } else {
      return context.l10n.dateMonthsAgo((difference.inDays / 30).round());
    }
  }

  EdgeInsets _getDefaultMargin() {
    switch (style) {
      case ShoppingListCardStyle.compact:
        return const EdgeInsets.only(bottom: AppDimensions.spacingXs);
      case ShoppingListCardStyle.grid:
        return const EdgeInsets.all(AppDimensions.spacingS);
      case ShoppingListCardStyle.detailed:
        return EdgeInsets.zero;
    }
  }

  EdgeInsets _getDefaultPadding() {
    switch (style) {
      case ShoppingListCardStyle.compact:
        return const EdgeInsets.symmetric(
          horizontal: AppDimensions.spacingS,
          vertical: AppDimensions.spacingS,
        );
      case ShoppingListCardStyle.grid:
        return const EdgeInsets.all(AppDimensions.spacingS);
      case ShoppingListCardStyle.detailed:
        return const EdgeInsets.all(AppDimensions.spacingS);
    }
  }
}

/// Shopping list card display styles
enum ShoppingListCardStyle {
  detailed, // Full visning med alla detaljer
  compact, // Kompakt visning for listor
  grid, // For grid-layout
}
