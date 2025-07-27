// lib/widgets/common/input/shopping_list_card.dart

import 'package:flutter/material.dart';
import 'package:butlery/theme/app_colors.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/models/unified/unified_shopping_list.dart';
import 'package:butlery/viewmodels/unified_shopping_viewmodel.dart';
import 'package:butlery/widgets/common/input/shopping_list_actions.dart';

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
      margin: const EdgeInsets.symmetric(
        horizontal: AppDimensions.spacingL,
        vertical: AppDimensions.spacingXs,
      ),
      color: isSelected ? AppColors.primaryBlue.withValues(alpha: 0.1) : null,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(AppDimensions.paddingL),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildListHeader(context),
              const SizedBox(height: AppDimensions.spacingM),
              _buildListMetadata(context),
              if (list.itemCount > 0) ...[
                const SizedBox(height: AppDimensions.spacingM),
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
          padding: const EdgeInsets.all(AppDimensions.spacingXs),
          decoration: BoxDecoration(
            color: _getListTypeColor().withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(AppDimensions.borderRadiusM),
          ),
          child: Icon(
            _getListTypeIcon(),
            size: AppDimensions.iconSizeAction,
            color: _getListTypeColor(),
          ),
        ),
        const SizedBox(width: AppDimensions.spacingM),

        // List name
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                list.name,
                style: AppTextStyles.titleMedium.copyWith(
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              if (list.description?.isNotEmpty == true) ...[
                const SizedBox(height: 2),
                Text(
                  list.description!,
                  style: AppTextStyles.bodySmall,
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
      spacing: AppDimensions.spacingS,
      runSpacing: AppDimensions.spacingXs,
      children: [
        // Items count
        _buildMetadataBadge(
          context,
          Icons.shopping_cart,
          '${list.itemCount} artiklar',
          AppColors.textMedium,
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
            AppColors.secondaryPurple,
          ),
        ],

        // Recent activity
        if (list.hasRecentActivity) ...[
          _buildMetadataBadge(
            context,
            Icons.access_time,
            'Aktiv',
            AppColors.warning,
          ),
        ],
      ],
    );
  }

  /// Build list preview showing first few items
  Widget _buildListPreview(BuildContext context) {
    final previewItems = list.items.take(3).toList();
    
    return Container(
      padding: const EdgeInsets.all(AppDimensions.spacingS),
      decoration: BoxDecoration(
        color: AppColors.backgroundLight,
        borderRadius: BorderRadius.circular(AppDimensions.borderRadiusM),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Senaste artiklar:',
            style: AppTextStyles.bodySmall,
          ),
          const SizedBox(height: AppDimensions.spacingXs),
          ...previewItems.map((item) => Padding(
            padding: const EdgeInsets.only(bottom: AppDimensions.spacingXxs),
            child: Row(
              children: [
                Icon(
                  item.isCompleted ? Icons.check_circle : Icons.radio_button_unchecked,
                  size: AppDimensions.iconSizeM,
                  color: item.isCompleted ? AppColors.success : AppColors.textMedium,
                ),
                const SizedBox(height: AppDimensions.spacingXs),
                Expanded(
                  child: Text(
                    item.name,
                    style: AppTextStyles.bodySmall.copyWith(
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
            const SizedBox(height: AppDimensions.spacingXs),
            Text(
              '... och ${list.itemCount - 3} till',
              style: AppTextStyles.bodySmall.copyWith(
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
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimensions.spacingXs,
        vertical: AppDimensions.spacingXxs,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppDimensions.borderRadiusM),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: AppDimensions.iconSizeM,
            color: color,
          ),
          const SizedBox(height: AppDimensions.spacingXs),
          Text(
            label,
            style: AppTextStyles.bodySmall.copyWith(
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
        return AppColors.primaryBlue;
      case ShoppingListType.collaborative:
        return AppColors.secondaryPurple;
      case ShoppingListType.template:
        return AppColors.warning;
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
      padding: const EdgeInsets.all(AppDimensions.spacingXl),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.shopping_cart_outlined,
            size: 64,
            color: AppColors.textLight,
          ),
          const SizedBox(height: AppDimensions.spacingXl),
          Text(
            'Inga handlistor än',
            style: AppTextStyles.titleLarge.copyWith(
              color: AppColors.textLight,
            ),
          ),
          const SizedBox(height: AppDimensions.spacingM),
          const Text(
            'Skapa din första handlista för att komma igång',
            style: AppTextStyles.titleMedium,
            textAlign: TextAlign.center,
          ),
          if (onCreateList != null) ...[
            const SizedBox(height: AppDimensions.spacingXl),
            FilledButton.icon(
              onPressed: onCreateList,
              icon: const Icon(Icons.add),
              label: const Text('Skapa lista'),
            ),
          ],
        ],
      ),
    );
  }
}