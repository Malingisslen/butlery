// lib/views/social/shared_with_me/shared_content_tab_bar.dart

import 'package:flutter/material.dart';
import 'package:butlery/theme/app_colors.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/viewmodels/shared_content_viewmodel.dart';

/// SharedContentTabBar - Tab bar for shared content view
///
/// Handles tab navigation between recipes and menus with unread counts.
class SharedContentTabBar {
  static Widget build(
    BuildContext context,
    SharedContentViewModel viewModel,
    TabController tabController,
  ) {
    if (!viewModel.hasSharedContent) {
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
          tabs: [
            Tab(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.restaurant, size: 20),
                  const SizedBox(width: AppDimensions.spacingXs),
                  Text('Recept (${viewModel.totalSharedRecipes})'),
                  if (viewModel.unreadRecipesCount > 0) ...[
                    const SizedBox(width: AppDimensions.spacingXs),
                    _buildUnreadBadge(
                      context,
                      viewModel.unreadRecipesCount,
                    ),
                  ],
                ],
              ),
            ),
            Tab(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.calendar_month, size: 20),
                  const SizedBox(width: AppDimensions.spacingXs),
                  Text('Menyer (${viewModel.totalSharedMenus})'),
                  if (viewModel.unreadMenusCount > 0) ...[
                    const SizedBox(width: AppDimensions.spacingXs),
                    _buildUnreadBadge(
                      context,
                      viewModel.unreadMenusCount,
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
          dividerColor: Colors.transparent,
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
        style: TextStyle(
          color: AppColors.neutralLight,
          fontSize: AppTextStyles.labelSmall.fontSize,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
  @override
  void dispose() {
    // Cancel all timers
    // Cancel all stream subscriptions  
    // Dispose of resources
    disposeStreams(); // From StreamManagementMixin
    super.dispose();
  }
}