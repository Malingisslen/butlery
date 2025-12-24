// lib/widgets/social/group_shared_shopping_list_card.dart

import 'package:flutter/material.dart';
import 'package:butlery/viewmodels/group_content_viewmodel.dart';
import 'package:butlery/models/unified/unified_shopping_list.dart';
import 'package:butlery/theme/app_colors.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/widgets/common/user_avatar.dart';
import 'package:butlery/widgets/user/user_display_models.dart';
import 'package:butlery/widgets/common/buttons/action_buttons.dart';
import 'package:butlery/utils/shopping_list_formatter.dart';
import 'package:butlery/widgets/social/group_shopping_list_actions.dart';

/// Group Shared Shopping List Card - Card widget for shopping lists shared to groups
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
    return Material(
      elevation: AppDimensions.elevationMedium,
      borderRadius: BorderRadius.circular(AppDimensions.borderRadiusM),
      color: AppColors.surface,
      child: Padding(
        padding: const EdgeInsets.all(AppDimensions.spacingM),
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
      ),
    );
  }

  static Widget _buildHeader(
      BuildContext context, UnifiedShoppingList shoppingList) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(AppDimensions.spacingS),
          decoration: BoxDecoration(
            color: AppColors.primaryContainer.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(AppDimensions.borderRadiusS),
          ),
          child: const Icon(
            Icons.shopping_cart,
            size: AppDimensions.iconSizeM,
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
              if (shoppingList.description != null &&
                  shoppingList.description!.isNotEmpty)
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
        _buildSharedByInfo(shoppingList),
      ],
    );
  }

  static Widget _buildSharedByInfo(UnifiedShoppingList shoppingList) {
    final ownerName = shoppingList.ownerDisplayName.isNotEmpty
        ? shoppingList.ownerDisplayName
        : 'Okand anvandare';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        UserAvatar(
          imageUrl: null,
          displayName: ownerName,
          size: ImageSize.small,
        ),
        const SizedBox(height: 2),
        Text(
          'Delad av $ownerName',
          style: AppTextStyles.bodySmall.copyWith(
            color: AppColors.onSurface.withValues(alpha: 0.6),
            fontSize: 10,
          ),
        ),
      ],
    );
  }

  static Widget _buildContent(
      BuildContext context, UnifiedShoppingList shoppingList) {
    final totalItems = shoppingList.items.length;
    final boughtItems = shoppingList.items.where((item) => item.bought).length;

    return Container(
      padding: const EdgeInsets.all(AppDimensions.spacingM),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(AppDimensions.borderRadiusS),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.list_alt,
                size: AppDimensions.iconSizeS,
                color: AppColors.onSurface.withValues(alpha: 0.7),
              ),
              const SizedBox(width: AppDimensions.spacingS),
              Text(
                'Inkopslista',
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
                    borderRadius:
                        BorderRadius.circular(AppDimensions.borderRadiusS),
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

  static Widget _buildStats(
      BuildContext context, UnifiedShoppingList shoppingList) {
    final totalItems = shoppingList.items.length;
    final boughtItems = shoppingList.items.where((item) => item.bought).length;
    final remainingItems = totalItems - boughtItems;

    return Row(
      children: [
        _buildStatChip('$totalItems', 'totalt', Icons.format_list_numbered,
            AppColors.primary),
        const SizedBox(width: AppDimensions.spacingS),
        _buildStatChip(
            '$boughtItems', 'kopta', Icons.check_circle, AppColors.success),
        const SizedBox(width: AppDimensions.spacingS),
        _buildStatChip('$remainingItems', 'kvar', Icons.shopping_cart_outlined,
            AppColors.warning),
        const Spacer(),
        Text(
          ShoppingListFormatter.getShareTimeText(shoppingList),
          style: AppTextStyles.bodySmall.copyWith(
            color: AppColors.onSurface.withValues(alpha: 0.6),
          ),
        ),
      ],
    );
  }

  static Widget _buildStatChip(
      String value, String label, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: AppDimensions.spacingS, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppDimensions.borderRadiusS),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: AppDimensions.iconSizeXs, color: color),
          const SizedBox(width: 4),
          Text(
            value,
            style: AppTextStyles.bodySmall
                .copyWith(color: color, fontWeight: FontWeight.w600),
          ),
          const SizedBox(width: 2),
          Text(
            label,
            style: AppTextStyles.bodySmall.copyWith(color: color, fontSize: 10),
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
          child: ActionButtons.secondaryButton(
            context,
            label: 'Visa lista',
            icon: Icons.visibility,
            onPressed: () => GroupShoppingListActions.viewShoppingList(
                context, shoppingList),
          ),
        ),
        const SizedBox(width: AppDimensions.spacingS),
        Expanded(
          child: ActionButtons.primaryButton(
            context,
            label: 'Importera',
            icon: Icons.download,
            onPressed: () => GroupShoppingListActions.importShoppingList(
                context, viewModel, shoppingList),
          ),
        ),
        const SizedBox(width: AppDimensions.spacingS),
        IconButton(
          onPressed: () => GroupShoppingListActions.showMoreActions(
              context, viewModel, shoppingList),
          icon: const Icon(Icons.more_vert),
          style: IconButton.styleFrom(
            backgroundColor: AppColors.surfaceVariant.withValues(alpha: 0.5),
          ),
        ),
      ],
    );
  }
}
