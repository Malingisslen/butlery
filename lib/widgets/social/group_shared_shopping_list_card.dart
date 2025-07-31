// lib/widgets/social/group_shared_shopping_list_card.dart

import 'package:flutter/material.dart';
import 'package:butlery/viewmodels/group_content_viewmodel.dart';
import 'package:butlery/models/unified/unified_shopping_list.dart';
import 'package:butlery/theme/app_colors.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/widgets/common/user_avatar.dart';
import 'package:butlery/widgets/user/user_display_models.dart';

/// Group Shared Shopping List Card - Card widget for shopping lists shared to groups
/// 
/// Displays shopping list information in a group context with:
/// - List name and description
/// - Item count and completion status
/// - Shared by information
/// - Group-specific actions
class GroupSharedShoppingListCard {
  static Widget build(
    BuildContext context,
    GroupContentViewModel viewModel,
    UnifiedShoppingList shoppingList,
  ) {
    return Container(
      padding: const EdgeInsets.all(AppDimensions.spacingM),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppDimensions.radiusM),
        border: Border.all(
          color: AppColors.outline.withValues(alpha: 0.2),
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.shadow.withValues(alpha: 0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(context, shoppingList),
          const SizedBox(height: AppDimensions.spacingM),
          _buildContent(context, shoppingList),
          const SizedBox(height: AppDimensions.spacingM),
          _buildStats(context, shoppingList),
          const SizedBox(height: AppDimensions.spacingM),
          _buildActions(context, viewModel, shoppingList),
        ],
      ),
    );
  }

  static Widget _buildHeader(BuildContext context, UnifiedShoppingList shoppingList) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(AppDimensions.spacingS),
          decoration: BoxDecoration(
            color: AppColors.primaryContainer.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(AppDimensions.radiusS),
          ),
          child: Icon(
            Icons.shopping_cart,
            size: 20,
            color: AppColors.onPrimaryContainer,
          ),
        ),
        const SizedBox(width: AppDimensions.spacingM),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                shoppingList.name,
                style: AppTextStyles.titleMedium.copyWith(
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              if (shoppingList.description != null && shoppingList.description!.isNotEmpty)
                Text(
                  shoppingList.description!,
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.onSurface.withValues(alpha: 0.7),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
            ],
          ),
        ),
        _buildSharedByInfo(),
      ],
    );
  }

  static Widget _buildSharedByInfo() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        const UserAvatar(
          imageUrl: null, // TODO: Get from shared content metadata
          displayName: 'Unknown User', // TODO: Get from shared content metadata
          size: ImageSize.small,
        ),
        const SizedBox(height: 2),
        Text(
          'Delad av användare', // TODO: Get from shared content metadata
          style: AppTextStyles.bodySmall.copyWith(
            color: AppColors.onSurface.withValues(alpha: 0.6),
            fontSize: 10,
          ),
        ),
      ],
    );
  }

  static Widget _buildContent(BuildContext context, UnifiedShoppingList shoppingList) {
    final totalItems = shoppingList.items.length;
    final boughtItems = shoppingList.items.where((item) => item.bought).length;
    
    return Container(
      padding: const EdgeInsets.all(AppDimensions.spacingM),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(AppDimensions.radiusS),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.list_alt,
                size: 16,
                color: AppColors.onSurface.withValues(alpha: 0.7),
              ),
              const SizedBox(width: AppDimensions.spacingS),
              Text(
                'Inköpslista',
                style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.onSurface.withValues(alpha: 0.7),
                  fontWeight: FontWeight.w500,
                ),
              ),
              const Spacer(),
              if (shoppingList.isCollaborative)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppDimensions.spacingS,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.info.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(AppDimensions.radiusS),
                  ),
                  child: Text(
                    'Kollaborativ',
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.info,
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: AppDimensions.spacingS),
          LinearProgressIndicator(
            value: totalItems > 0 ? boughtItems / totalItems : 0,
            backgroundColor: AppColors.outline.withValues(alpha: 0.2),
            valueColor: AlwaysStoppedAnimation<Color>(
              boughtItems == totalItems ? AppColors.success : AppColors.primary,
            ),
          ),
        ],
      ),
    );
  }

  static Widget _buildStats(BuildContext context, UnifiedShoppingList shoppingList) {
    final totalItems = shoppingList.items.length;
    final boughtItems = shoppingList.items.where((item) => item.bought).length;
    final remainingItems = totalItems - boughtItems;
    
    return Row(
      children: [
        _buildStatChip(
          '$totalItems',
          'totalt',
          Icons.format_list_numbered,
          AppColors.primary,
        ),
        const SizedBox(width: AppDimensions.spacingS),
        _buildStatChip(
          '$boughtItems',
          'köpta',
          Icons.check_circle,
          AppColors.success,
        ),
        const SizedBox(width: AppDimensions.spacingS),
        _buildStatChip(
          '$remainingItems',
          'kvar',
          Icons.shopping_cart_outlined,
          AppColors.warning,
        ),
        const Spacer(),
        Text(
          'Delad till grupp', // TODO: Show actual share time
          style: AppTextStyles.bodySmall.copyWith(
            color: AppColors.onSurface.withValues(alpha: 0.6),
          ),
        ),
      ],
    );
  }

  static Widget _buildStatChip(
    String value,
    String label,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimensions.spacingS,
        vertical: 4,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppDimensions.radiusS),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 12,
            color: color,
          ),
          const SizedBox(width: 4),
          Text(
            value,
            style: AppTextStyles.bodySmall.copyWith(
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: 2),
          Text(
            label,
            style: AppTextStyles.bodySmall.copyWith(
              color: color,
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }

  static Widget _buildActions(
    BuildContext context,
    GroupContentViewModel viewModel,
    UnifiedShoppingList shoppingList,
  ) {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () => _viewShoppingList(context, shoppingList),
            icon: const Icon(Icons.visibility, size: 16),
            label: const Text('Visa lista'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(
                horizontal: AppDimensions.spacingM,
                vertical: AppDimensions.spacingS,
              ),
            ),
          ),
        ),
        const SizedBox(width: AppDimensions.spacingS),
        Expanded(
          child: FilledButton.icon(
            onPressed: () => _importShoppingList(context, viewModel, shoppingList),
            icon: const Icon(Icons.download, size: 16),
            label: const Text('Importera'),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(
                horizontal: AppDimensions.spacingM,
                vertical: AppDimensions.spacingS,
              ),
            ),
          ),
        ),
        const SizedBox(width: AppDimensions.spacingS),
        IconButton(
          onPressed: () => _showMoreActions(context, viewModel, shoppingList),
          icon: const Icon(Icons.more_vert),
          style: IconButton.styleFrom(
            backgroundColor: AppColors.surfaceVariant.withValues(alpha: 0.5),
          ),
        ),
      ],
    );
  }

  static void _viewShoppingList(BuildContext context, UnifiedShoppingList shoppingList) {
    Navigator.pushNamed(
      context,
      '/shopping-list-detail',
      arguments: {'listId': shoppingList.id},
    );
  }

  static void _importShoppingList(
    BuildContext context,
    GroupContentViewModel viewModel,
    UnifiedShoppingList shoppingList,
  ) {
    // TODO: Implement import functionality
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Import av inköpslista kommer snart!'),
        backgroundColor: AppColors.success,
      ),
    );
  }

  static void _showMoreActions(
    BuildContext context,
    GroupContentViewModel viewModel,
    UnifiedShoppingList shoppingList,
  ) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(AppDimensions.spacingL),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.copy),
              title: const Text('Kopiera lista'),
              onTap: () {
                Navigator.pop(context);
                _copyShoppingList(context, shoppingList);
              },
            ),
            ListTile(
              leading: const Icon(Icons.share),
              title: const Text('Dela vidare'),
              onTap: () {
                Navigator.pop(context);
                _shareShoppingList(context, shoppingList);
              },
            ),
            ListTile(
              leading: const Icon(Icons.report),
              title: const Text('Rapportera'),
              onTap: () {
                Navigator.pop(context);
                _reportShoppingList(context, shoppingList);
              },
            ),
          ],
        ),
      ),
    );
  }

  static void _copyShoppingList(BuildContext context, UnifiedShoppingList shoppingList) {
    // TODO: Implement copy functionality
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Kopiering av inköpslista kommer snart!'),
      ),
    );
  }

  static void _shareShoppingList(BuildContext context, UnifiedShoppingList shoppingList) {
    // TODO: Implement share functionality
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Delning av inköpslista kommer snart!'),
      ),
    );
  }

  static void _reportShoppingList(BuildContext context, UnifiedShoppingList shoppingList) {
    // TODO: Implement report functionality
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Rapporteringsfunktion kommer snart!'),
      ),
    );
  }
}