// lib/widgets/common/content_cards/shopping_list_card.dart

import 'package:flutter/material.dart';
import 'package:butlery/theme/app_colors.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/models/unified/unified_shopping_list.dart';
import 'package:butlery/models/unified/unified_shopping_item.dart';

/// Focused module for shopping list card components
/// 
/// This module handles ONLY shopping list card display responsibilities:
/// - Shopping list card rendering with list-specific data
/// - Shopping list metadata display (item count, completion status)
/// - Shopping list sharing status and collaborative indicators
/// - Shopping list-specific styling and theming
/// - Shopping list preview with item list
/// 
/// ❌ DOES NOT CONTAIN: Recipe cards, friend cards, menu cards, generic content logic
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
    return Container(
      margin: margin ?? _getDefaultMargin(),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          onLongPress: onLongPress,
          borderRadius: BorderRadius.circular(AppDimensions.borderRadiusM),
          child: Container(
            padding: padding ?? _getDefaultPadding(),
            decoration: BoxDecoration(
              color: AppColors.backgroundLight,
              borderRadius: BorderRadius.circular(AppDimensions.borderRadiusM),
              border: Border.all(color: AppColors.textLight, width: AppDimensions.borderWidthThin),
            ),
            child: _buildContent(context),
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
    final title = _getListTitle();
    return Row(
      children: [
        const Icon(
          Icons.shopping_cart,
          size: 20,
          color: AppColors.textMedium,
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
      metadata.add('$totalItems föremål');
    }
    if (completedItems > 0) {
      metadata.add('$completedItems slutförda');
    }
    if (createdDate != null) {
      metadata.add(_formatDate(createdDate));
    }

    if (metadata.isEmpty) {
      return const SizedBox.shrink();
    }

    return Text(
      metadata.join(' • '),
      style: AppTextStyles.bodySmall.copyWith(color: AppColors.textMedium),
    );
  }

  Widget _buildListPreview(BuildContext context) {
    final items = _getListItems();
    
    if (items.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(AppDimensions.spacingM),
        decoration: BoxDecoration(
          color: AppColors.backgroundTint,
          borderRadius: BorderRadius.circular(AppDimensions.borderRadiusS),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.info_outline,
              size: 16,
              color: AppColors.textMedium,
            ),
            const SizedBox(width: AppDimensions.spacingS),
            Text(
              'Inga föremål i listan',
              style: AppTextStyles.bodySmall.copyWith(color: AppColors.textMedium),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Föremål på listan:',
          style: AppTextStyles.labelMedium.copyWith(color: AppColors.textMedium),
        ),
        const SizedBox(height: AppDimensions.spacingS),
        ...items.take(4).map((item) => Padding(
          padding: const EdgeInsets.only(bottom: AppDimensions.spacingXs),
          child: Row(
            children: [
              Icon(
                _isItemCompleted(item) ? Icons.check_circle : Icons.radio_button_unchecked,
                size: 16,
                color: _isItemCompleted(item) ? Colors.green : AppColors.textMedium,
              ),
              const SizedBox(width: AppDimensions.spacingS),
              Expanded(
                child: Text(
                  _getItemTitle(item),
                  style: AppTextStyles.bodySmall.copyWith(
                    decoration: _isItemCompleted(item) ? TextDecoration.lineThrough : null,
                    color: _isItemCompleted(item) ? AppColors.textMedium : AppColors.textDark,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        )),
        if (items.length > 4)
          Padding(
            padding: const EdgeInsets.only(top: AppDimensions.spacingXs),
            child: Text(
              '+ ${items.length - 4} fler föremål',
              style: AppTextStyles.bodySmall.copyWith(color: AppColors.textMedium),
            ),
          ),
      ],
    );
  }

  Widget _buildSharingStatus(BuildContext context) {
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
        color: Colors.blue.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppDimensions.borderRadiusS),
        border: Border.all(
          color: Colors.blue.withValues(alpha: 0.3),
          width: AppDimensions.borderWidthThin,
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.people,
            size: 16,
            color: Colors.blue[700],
          ),
          const SizedBox(width: AppDimensions.spacingS),
          Text(
            memberCount > 0 
                ? 'Delad med $memberCount personer'
                : 'Delad lista',
            style: AppTextStyles.bodySmall.copyWith(color: Colors.blue[700]),
          ),
        ],
      ),
    );
  }

  Widget _buildSharingIndicator(BuildContext context) {
    final isShared = _isListShared();
    
    if (!isShared) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.all(AppDimensions.spacingXs),
      decoration: const BoxDecoration(
        color: Colors.blue,
        shape: BoxShape.circle,
      ),
      child: const Icon(
        Icons.people,  
        size: 16,
        color: Colors.white,
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

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimensions.spacingS,
        vertical: AppDimensions.spacingXs,
      ),
      decoration: BoxDecoration(
        color: isComplete ? Colors.green.shade100 : Colors.orange.shade100,
        borderRadius: BorderRadius.circular(AppDimensions.borderRadiusS),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isComplete ? Icons.check_circle : Icons.hourglass_empty,
            size: 14,
            color: isComplete ? Colors.green[700] : Colors.orange[700],
          ),
          const SizedBox(width: AppDimensions.spacingXs),
          Text(
            isComplete 
                ? 'Klar' 
                : '${(completionPercentage * 100).round()}%',
            style: AppTextStyles.labelSmall.copyWith(
              color: isComplete ? Colors.green[700] : Colors.orange[700],
            ),
          ),
        ],
      ),
    );
  }

  // Helper methods to extract data from the shopping list object
  // These will need to be updated when the actual shopping list model is available
  
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

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);
    
    if (difference.inDays == 0) {
      return 'Idag';
    } else if (difference.inDays == 1) {
      return 'Igår';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} dagar sedan';
    } else if (difference.inDays < 30) {
      return '${(difference.inDays / 7).round()} veckor sedan';
    } else {
      return '${(difference.inDays / 30).round()} månader sedan';
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
  detailed,  // Full visning med alla detaljer
  compact,   // Kompakt visning för listor
  grid,      // För grid-layout
}