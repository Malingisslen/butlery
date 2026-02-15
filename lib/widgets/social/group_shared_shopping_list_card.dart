// lib/widgets/social/group_shared_shopping_list_card.dart

import 'package:flutter/material.dart';
import 'package:butlery/viewmodels/group_content_viewmodel.dart';
import 'package:butlery/models/unified/unified_shopping_list.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/theme/butlery_colors_extension.dart';
import 'package:butlery/widgets/common/user_avatar.dart';
import 'package:butlery/widgets/user/user_display_models.dart';
import 'package:butlery/widgets/common/buttons/action_buttons.dart';
import 'package:butlery/utils/shopping_list_formatter.dart';
import 'package:butlery/core/extensions/localization_extension.dart';
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
      color: Theme.of(context).colorScheme.surface,
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
            color: Theme.of(context)
                .colorScheme
                .primaryContainer
                .withValues(alpha: AppDimensions.opacityMediumLight),
            borderRadius: BorderRadius.circular(AppDimensions.borderRadiusS),
          ),
          child: Icon(
            Icons.shopping_cart,
            size: AppDimensions.iconSizeM,
            color: Theme.of(context).colorScheme.onPrimaryContainer,
          ),
        ),
        const SizedBox(width: AppDimensions.spacingM),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                shoppingList.name,
                style: AppTextStyles.titleMedium,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              if (shoppingList.description != null &&
                  shoppingList.description!.isNotEmpty)
                Text(
                  shoppingList.description!,
                  style: AppTextStyles.bodySmall.copyWith(
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: AppDimensions.opacityDark),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
            ],
          ),
        ),
        _buildSharedByInfo(context, shoppingList),
      ],
    );
  }

  static Widget _buildSharedByInfo(
      BuildContext context, UnifiedShoppingList shoppingList) {
    final ownerName = shoppingList.ownerDisplayName.isNotEmpty
        ? shoppingList.ownerDisplayName
        : context.l10n.avatarUnknownUser;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        UserAvatar(
          imageUrl: null,
          displayName: ownerName,
          size: ImageSize.small,
        ),
        const SizedBox(height: AppDimensions.spacingXxs),
        Text(
          context.l10n.shoppingSharedBy(ownerName),
          style: AppTextStyles.textXs.copyWith(
            color: Theme.of(context)
                .colorScheme
                .onSurface
                .withValues(alpha: AppDimensions.opacityMediumDark),
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
        color: Theme.of(context)
            .colorScheme
            .surfaceContainerHighest
            .withValues(alpha: AppDimensions.opacityMediumLight),
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
                color: Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withValues(alpha: AppDimensions.opacityDark),
              ),
              const SizedBox(width: AppDimensions.spacingS),
              Text(
                context.l10n.shoppingShoppingList,
                style: AppTextStyles.metadataEmphasized.copyWith(
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: AppDimensions.opacityDark),
                ),
              ),
              const Spacer(),
              if (shoppingList.isCollaborative)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppDimensions.spacingS,
                    vertical: AppDimensions.spacingXxs,
                  ),
                  decoration: BoxDecoration(
                    color: context.butleryColors.info
                        .withValues(alpha: AppDimensions.opacityVeryLight),
                    borderRadius:
                        BorderRadius.circular(AppDimensions.borderRadiusS),
                  ),
                  child: Text(
                    context.l10n.shoppingCollaborative,
                    style: AppTextStyles.textXsBold.copyWith(
                      color: context.butleryColors.info,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: AppDimensions.spacingS),
          LinearProgressIndicator(
            value: totalItems > 0 ? boughtItems / totalItems : 0,
            backgroundColor: Theme.of(context)
                .colorScheme
                .outline
                .withValues(alpha: AppDimensions.opacityLight),
            valueColor: AlwaysStoppedAnimation<Color>(
              boughtItems == totalItems
                  ? context.butleryColors.success
                  : Theme.of(context).colorScheme.primary,
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
        _buildStatChip('$totalItems', context.l10n.shoppingTotal,
            Icons.format_list_numbered, Theme.of(context).colorScheme.primary),
        const SizedBox(width: AppDimensions.spacingS),
        _buildStatChip('$boughtItems', context.l10n.shoppingBought,
            Icons.check_circle, context.butleryColors.success),
        const SizedBox(width: AppDimensions.spacingS),
        _buildStatChip('$remainingItems', context.l10n.shoppingRemaining,
            Icons.shopping_cart_outlined, context.butleryColors.warning),
        const Spacer(),
        Text(
          ShoppingListFormatter.getShareTimeText(shoppingList),
          style: AppTextStyles.bodySmall.copyWith(
            color: Theme.of(context)
                .colorScheme
                .onSurface
                .withValues(alpha: AppDimensions.opacityMediumDark),
          ),
        ),
      ],
    );
  }

  static Widget _buildStatChip(
      String value, String label, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: AppDimensions.spacingS,
          vertical: AppDimensions.spacingXs),
      decoration: BoxDecoration(
        color: color.withValues(alpha: AppDimensions.opacityVeryLight),
        borderRadius: BorderRadius.circular(AppDimensions.borderRadiusS),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: AppDimensions.iconSizeXs, color: color),
          const SizedBox(width: AppDimensions.spacingXs),
          Text(
            value,
            style: AppTextStyles.labelLarge.copyWith(color: color),
          ),
          const SizedBox(width: AppDimensions.spacingXxs),
          Text(
            label,
            style: AppTextStyles.textXs.copyWith(color: color),
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
            label: context.l10n.shoppingViewList,
            icon: Icons.visibility,
            onPressed: () => GroupShoppingListActions.viewShoppingList(
                context, shoppingList),
          ),
        ),
        const SizedBox(width: AppDimensions.spacingS),
        Expanded(
          child: ActionButtons.primaryButton(
            context,
            label: context.l10n.groupImport,
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
            backgroundColor: Theme.of(context)
                .colorScheme
                .surfaceContainerHighest
                .withValues(alpha: AppDimensions.opacityHalf),
          ),
        ),
      ],
    );
  }
}
