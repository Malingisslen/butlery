// lib/views/social/discovery_dashboard/discovery_categories.dart

import 'package:flutter/material.dart';
import 'package:butlery/viewmodels/discovery_dashboard_viewmodel.dart';
import 'package:butlery/theme/app_colors.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/theme/app_shadows.dart';
import 'package:butlery/views/social/discovery_dashboard/discovery_section_header.dart';

/// Discovery Categories - Category selector for discovery dashboard
class DiscoveryCategories {
  static Widget build(
    BuildContext context,
    DiscoveryDashboardViewModel viewModel,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const DiscoverySectionHeader(
          title: 'Kategorier',
          icon: Icons.category_outlined,
        ),
        const SizedBox(height: AppDimensions.spacingM),
        SizedBox(
          height: 80,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: viewModel.discoveryCategories.length,
            separatorBuilder: (context, index) =>
                const SizedBox(width: AppDimensions.spacingS),
            itemBuilder: (context, index) {
              final category = viewModel.discoveryCategories[index];
              return _buildCategoryCard(context, viewModel, category);
            },
          ),
        ),
      ],
    );
  }

  static Widget _buildCategoryCard(
    BuildContext context,
    DiscoveryDashboardViewModel viewModel,
    Map<String, dynamic> category,
  ) {
    final isSelected = viewModel.selectedCategory == category['id'];
    final count = category['count'] as int;

    return GestureDetector(
      onTap: () => viewModel.setSelectedCategory(category['id']),
      child: Container(
        width: 100,
        padding: const EdgeInsets.all(AppDimensions.spacingM),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : AppColors.surface,
          borderRadius: BorderRadius.circular(AppDimensions.borderRadiusM),
          border: Border.all(
            color: isSelected
                ? AppColors.primary
                : AppColors.outline.withValues(alpha: AppDimensions.opacityLight),
          ),
          boxShadow: isSelected ? AppShadows.card : null,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              _getCategoryIcon(category['icon']),
              color: isSelected ? AppColors.onPrimary : AppColors.primary,
              size: AppDimensions.iconSizeL,
            ),
            const SizedBox(height: AppDimensions.spacingS),
            Text(
              category['name'],
              style: AppTextStyles.bodySmall.copyWith(
                color: isSelected ? AppColors.onPrimary : AppColors.onSurface,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            if (count > 0)
              Text(
                count.toString(),
                style: AppTextStyles.labelSmall.copyWith(
                  color: isSelected
                      ? AppColors.onPrimary.withValues(alpha: AppDimensions.opacityVeryDark)
                      : AppColors.onSurface.withValues(alpha: AppDimensions.opacityMediumDark),
                ),
              ),
          ],
        ),
      ),
    );
  }

  static IconData _getCategoryIcon(String iconName) {
    switch (iconName) {
      case 'explore':
        return Icons.explore;
      case 'restaurant':
        return Icons.restaurant;
      case 'calendar_month':
        return Icons.calendar_month;
      case 'shopping_cart':
        return Icons.shopping_cart;
      case 'people':
        return Icons.people;
      case 'trending_up':
        return Icons.trending_up;
      default:
        return Icons.category;
    }
  }
}
