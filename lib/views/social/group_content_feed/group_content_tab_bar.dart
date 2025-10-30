// lib/views/social/group_content_feed/group_content_tab_bar.dart

import 'package:flutter/material.dart';
import 'package:butlery/viewmodels/group_content_viewmodel.dart';
import 'package:butlery/theme/app_colors.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';

/// Group Content Tab Bar - Styled tab bar for group content categories
class GroupContentTabBar {
  static Widget build(
    BuildContext context,
    GroupContentViewModel viewModel,
    TabController tabController,
  ) {
    return SliverToBoxAdapter(
      child: ColoredBox(
        color: AppColors.surface,
        child: Column(
          children: [
            _buildTabBar(context, viewModel, tabController),
            _buildTabStats(context, viewModel),
          ],
        ),
      ),
    );
  }

  static Widget _buildTabBar(
    BuildContext context,
    GroupContentViewModel viewModel,
    TabController tabController,
  ) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: AppDimensions.spacingL),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(AppDimensions.borderRadiusM),
      ),
      child: TabBar(
        controller: tabController,
        tabs: [
          _buildTab(
            'Recept',
            Icons.restaurant,
            viewModel.totalGroupRecipes,
          ),
          _buildTab(
            'Menyer',
            Icons.calendar_month,
            viewModel.totalGroupMenus,
          ),
          _buildTab(
            'Listor',
            Icons.shopping_cart,
            viewModel.totalGroupShoppingLists,
          ),
          _buildTab(
            'Aktivitet',
            Icons.timeline,
            viewModel.groupActivityFeed.length,
          ),
        ],
        labelColor: Theme.of(context).colorScheme.primary,
        unselectedLabelColor: Theme.of(context).colorScheme.onSurfaceVariant,
        labelStyle: AppTextStyles.bodyMedium.copyWith(
          fontWeight: FontWeight.w600,
        ),
        unselectedLabelStyle: AppTextStyles.bodyMedium,
        indicator: BoxDecoration(
          color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(AppDimensions.borderRadiusS),
        ),
        indicatorSize: TabBarIndicatorSize.tab,
        dividerColor: Colors.transparent,
        overlayColor: WidgetStateProperty.all(
          AppColors.primary.withValues(alpha: 0.05),
        ),
      ),
    );
  }

  static Widget _buildTab(String label, IconData icon, int count) {
    return Tab(
      height: 56,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              Icon(icon, size: AppDimensions.iconSizeM),
              if (count > 0)
                Positioned(
                  right: -8,
                  top: -8,
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      color: AppColors.error,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    constraints: const BoxConstraints(
                      minWidth: 16,
                      minHeight: 16,
                    ),
                    child: Text(
                      count > 99 ? '99+' : count.toString(),
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.onError,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: AppTextStyles.bodySmall,
          ),
        ],
      ),
    );
  }

  static Widget _buildTabStats(
    BuildContext context,
    GroupContentViewModel viewModel,
  ) {
    final stats = viewModel.groupContentStats;
    
    return Container(
      padding: const EdgeInsets.all(AppDimensions.spacingM),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildStatItem(
            'Totalt innehåll',
            '${stats['totalContent']}',
            Icons.folder_outlined,
          ),
          _buildStatItem(
            'Gruppmedlemmar',
            '${stats['groupMembers']}',
            Icons.people_outlined,
          ),
          _buildStatItem(
            'Senaste aktivitet',
            '${stats['recentActivity']}',
            Icons.access_time,
          ),
        ],
      ),
    );
  }

  static Widget _buildStatItem(String label, String value, IconData icon) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          icon,
          size: AppDimensions.iconSizeS,
          color: AppColors.primary.withValues(alpha: 0.7),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: AppTextStyles.titleSmall.copyWith(
            color: AppColors.primary,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: AppTextStyles.bodySmall.copyWith(
            color: AppColors.onSurface.withValues(alpha: 0.6),
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}