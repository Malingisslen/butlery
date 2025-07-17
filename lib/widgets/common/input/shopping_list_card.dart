// lib/widgets/common/input/shopping_list_card.dart

import 'package:flutter/material.dart';
import '../../../theme/app_theme.dart';
import '../../../models/unified/unified_shopping_list.dart';
import '../../../viewmodels/unified_shopping_viewmodel.dart';
import 'shopping_list_actions.dart';

/// Shopping list card widget
///
/// This module provides display components for shopping lists including
/// cards, badges, and status indicators.
class ShoppingListCard extends StatelessWidget {
  final UnifiedShoppingList list;
  final UnifiedShoppingViewModel viewModel;
  final bool isSelected;
  final VoidCallback? onTap;
  final bool showActions;

  const ShoppingListCard({
    super.key,
    required this.list,
    required this.viewModel,
    required this.isSelected,
    this.onTap,
    this.showActions = true,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.symmetric(
        horizontal: AppTheme.spacingMd,
        vertical: AppTheme.spacingXs,
      ),
      color: isSelected ? AppTheme.primaryColor.withValues(alpha: 0.1) : null,
      shape: RoundedRectangleBorder(
        borderRadius: AppTheme.largeRadius,
        side: BorderSide(
          color: isSelected ? AppTheme.primaryColor : AppTheme.dividerColor,
          width: isSelected ? 2 : 1,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: AppTheme.largeRadius,
        child: Padding(
          padding: AppTheme.cardPadding,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildListHeader(context),
              AppTheme.smallGap,
              _buildListMetadata(context),
              if (list.itemCount > 0) ...[
                AppTheme.smallGap,
                _buildListPreview(context),
              ],
            ],
          ),
        ),
      ),
    );
  }

  /// Build list header with name and actions
  Widget _buildListHeader(BuildContext context) {
    return Row(
      children: [
        // List icon
        Container(
          padding: EdgeInsets.all(AppTheme.spacingXs),
          decoration: BoxDecoration(
            color: _getListTypeColor().withValues(alpha: 0.1),
            borderRadius: AppTheme.smallRadius,
          ),
          child: Icon(
            _getListTypeIcon(),
            size: AppTheme.iconSizeAction,
            color: _getListTypeColor(),
          ),
        ),
        AppTheme.smallHorizontalGap,

        // List name
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                list.name,
                style: AppTheme.cardTitleStyle.copyWith(
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              if (list.description?.isNotEmpty == true) ...[
                const SizedBox(height: 2),
                Text(
                  list.description!,
                  style: AppTheme.captionStyle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ],
          ),
        ),

        // Actions menu
        if (showActions)
          ShoppingListActions.buildListActionsButton(
            context,
            list,
            viewModel,
          ),
      ],
    );
  }

  /// Build list metadata (items count, type, etc.)
  Widget _buildListMetadata(BuildContext context) {
    return Wrap(
      spacing: AppTheme.spacingSm,
      runSpacing: AppTheme.spacingXs,
      children: [
        // Items count
        _buildMetadataBadge(
          context,
          Icons.shopping_cart,
          '${list.itemCount} artiklar',
          AppTheme.textSecondary,
        ),

        // List type
        _buildMetadataBadge(
          context,
          _getListTypeIcon(),
          _getListTypeLabel(),
          _getListTypeColor(),
        ),

        // Collaboration info
        if (list.isCollaborative) ...[
          _buildMetadataBadge(
            context,
            Icons.people,
            '${list.memberCount} medlemmar',
            AppTheme.accentColor,
          ),
        ],

        // Recent activity
        if (list.hasRecentActivity) ...[
          _buildMetadataBadge(
            context,
            Icons.access_time,
            'Aktiv',
            AppTheme.warningColor,
          ),
        ],
      ],
    );
  }

  /// Build list preview showing first few items
  Widget _buildListPreview(BuildContext context) {
    final previewItems = list.items.take(3).toList();
    
    return Container(
      padding: EdgeInsets.all(AppTheme.spacingSm),
      decoration: BoxDecoration(
        color: AppTheme.backgroundColor,
        borderRadius: AppTheme.smallRadius,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Senaste artiklar:',
            style: AppTheme.captionStyle,
          ),
          AppTheme.tinyGap,
          ...previewItems.map((item) => Padding(
            padding: EdgeInsets.only(bottom: AppTheme.spacingXxs),
            child: Row(
              children: [
                Icon(
                  item.isCompleted ? Icons.check_circle : Icons.radio_button_unchecked,
                  size: AppTheme.iconSizeInfo,
                  color: item.isCompleted ? AppTheme.successColor : AppTheme.textSecondary,
                ),
                AppTheme.tinyGap,
                Expanded(
                  child: Text(
                    item.name,
                    style: AppTheme.captionStyle.copyWith(
                      decoration: item.isCompleted ? TextDecoration.lineThrough : null,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          )),
          if (list.itemCount > 3) ...[
            AppTheme.tinyGap,
            Text(
              '... och ${list.itemCount - 3} till',
              style: AppTheme.captionStyle.copyWith(
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// Build metadata badge
  Widget _buildMetadataBadge(
    BuildContext context,
    IconData icon,
    String label,
    Color color,
  ) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: AppTheme.spacingXs,
        vertical: AppTheme.spacingXxs,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: AppTheme.chipRadius,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: AppTheme.iconSizeInfo,
            color: color,
          ),
          AppTheme.tinyGap,
          Text(
            label,
            style: AppTheme.captionStyle.copyWith(
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  /// Get list type icon
  IconData _getListTypeIcon() {
    switch (list.type) {
      case ShoppingListType.personal:
        return Icons.person;
      case ShoppingListType.collaborative:
        return Icons.people;
      case ShoppingListType.template:
        return Icons.bookmark;
    }
  }

  /// Get list type label
  String _getListTypeLabel() {
    switch (list.type) {
      case ShoppingListType.personal:
        return 'Personlig';
      case ShoppingListType.collaborative:
        return 'Delad';
      case ShoppingListType.template:
        return 'Mall';
    }
  }

  /// Get list type color
  Color _getListTypeColor() {
    switch (list.type) {
      case ShoppingListType.personal:
        return AppTheme.primaryColor;
      case ShoppingListType.collaborative:
        return AppTheme.accentColor;
      case ShoppingListType.template:
        return AppTheme.warningColor;
    }
  }
}

/// Empty state widget for when no lists are available
class ShoppingListEmptyState extends StatelessWidget {
  final VoidCallback? onCreateList;

  const ShoppingListEmptyState({
    super.key,
    this.onCreateList,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(AppTheme.spacingXl),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.shopping_cart_outlined,
            size: AppTheme.iconSizeEmptyState,
            color: AppTheme.textTertiary,
          ),
          AppTheme.mediumGap,
          Text(
            'Inga handlistor än',
            style: AppTheme.sectionTitleStyle.copyWith(
              color: AppTheme.textTertiary,
            ),
          ),
          AppTheme.smallGap,
          Text(
            'Skapa din första handlista för att komma igång',
            style: AppTheme.subtitleStyle,
            textAlign: TextAlign.center,
          ),
          if (onCreateList != null) ...[
            AppTheme.mediumGap,
            FilledButton.icon(
              onPressed: onCreateList,
              icon: Icon(Icons.add),
              label: Text('Skapa lista'),
            ),
          ],
        ],
      ),
    );
  }
}