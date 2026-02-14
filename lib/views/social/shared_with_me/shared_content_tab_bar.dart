// lib/views/social/shared_with_me/shared_content_tab_bar.dart

import 'package:flutter/material.dart';
import 'package:butlery/theme/app_colors.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/viewmodels/shared_content/shared_content_coordinator_viewmodel.dart';
import 'package:butlery/core/extensions/localization_extension.dart';

/// SharedContentTabBar - Tab bar for shared content view
/// Handles tab navigation between recipes, menus, and shared shopping lists with unread counts.
class SharedContentTabBar {
  static Widget build(
    BuildContext context,
    SharedContentCoordinatorViewModel viewModel,
    TabController tabController,
  ) {
    if (!viewModel.hasAnyContent) {
      return const SliverToBoxAdapter(child: SizedBox.shrink());
    }

    return SliverToBoxAdapter(
      child: Container(
        margin: AppDimensions.screenPadding,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainer,
          borderRadius: BorderRadius.circular(AppDimensions.borderRadiusM),
        ),
        child: TabBar(
          controller: tabController,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          tabs: [
            Tab(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.restaurant, size: AppDimensions.iconSizeM),
                  const SizedBox(width: AppDimensions.spacingXs),
                  Text(context.l10n
                      .sharedTabRecipes(viewModel.recipeViewModel.totalCount)),
                  if (viewModel.recipeViewModel.unreadCount > 0) ...[
                    const SizedBox(width: AppDimensions.spacingXs),
                    _buildUnreadBadge(
                      context,
                      viewModel.recipeViewModel.unreadCount,
                    ),
                  ],
                ],
              ),
            ),
            Tab(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.calendar_month,
                      size: AppDimensions.iconSizeM),
                  const SizedBox(width: AppDimensions.spacingXs),
                  Text(context.l10n
                      .sharedTabMenus(viewModel.menuViewModel.totalCount)),
                  if (viewModel.menuViewModel.unreadCount > 0) ...[
                    const SizedBox(width: AppDimensions.spacingXs),
                    _buildUnreadBadge(
                      context,
                      viewModel.menuViewModel.unreadCount,
                    ),
                  ],
                ],
              ),
            ),
            Tab(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.shopping_cart,
                      size: AppDimensions.iconSizeM),
                  const SizedBox(width: AppDimensions.spacingXs),
                  Text(context.l10n.sharedTabShoppingLists(
                      viewModel.shoppingViewModel.totalCount)),
                  if (viewModel.shoppingViewModel.unreadCount > 0) ...[
                    const SizedBox(width: AppDimensions.spacingXs),
                    _buildUnreadBadge(
                      context,
                      viewModel.shoppingViewModel.unreadCount,
                    ),
                  ],
                ],
              ),
            ),
          ],
          indicator: BoxDecoration(
            color: Theme.of(context).colorScheme.primary,
            borderRadius: BorderRadius.circular(AppDimensions.borderRadiusM),
          ),
          labelColor: Theme.of(context).colorScheme.onPrimary,
          unselectedLabelColor: Theme.of(context).colorScheme.onSurfaceVariant,
          dividerColor: AppColors.transparent,
        ),
      ),
    );
  }

  static Widget _buildUnreadBadge(BuildContext context, int count) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.error,
        borderRadius: BorderRadius.circular(AppDimensions.borderRadius10),
      ),
      child: Text(
        '$count',
        style: AppTextStyles.labelLarge.copyWith(
          color: AppColors.neutralLight,
        ),
      ),
    );
  }
}
