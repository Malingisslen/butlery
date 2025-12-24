import 'package:flutter/material.dart';
import 'package:butlery/viewmodels/discovery_dashboard_viewmodel.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_colors.dart';
import 'package:butlery/theme/component_themes.dart';

/// Popular with friends section showing trending recipes among user's friends.
class PopularWithFriendsSection {
  static Widget build(BuildContext context, DiscoveryDashboardViewModel viewModel) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildHeader(),
        const SizedBox(height: AppDimensions.spacingM),
        Text(
          'Innehåll som dina vänner gillar och delar',
          style: AppTextStyles.bodySmall.copyWith(
            color: AppColors.onSurface.withValues(alpha: 0.7),
          ),
        ),
        const SizedBox(height: AppDimensions.spacingM),
        if (viewModel.trendingRecipes.isNotEmpty)
          _buildRecipeList(viewModel)
        else
          _buildEmptyState(),
      ],
    );
  }

  static Widget _buildHeader() {
    return Row(
      children: [
        const Icon(
          Icons.people,
          color: AppColors.primary,
          size: AppDimensions.iconSizeM,
        ),
        const SizedBox(width: AppDimensions.spacingS),
        Text(
          'Populärt bland vänner',
          style: AppTextStyles.titleMedium.copyWith(fontWeight: FontWeight.w600),
        ),
      ],
    );
  }

  static Widget _buildRecipeList(DiscoveryDashboardViewModel viewModel) {
    return SizedBox(
      height: 120,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: viewModel.trendingRecipes.length,
        itemBuilder: (context, index) {
          final recipe = viewModel.trendingRecipes[index];
          return Container(
            width: 200,
            margin: const EdgeInsets.only(right: AppDimensions.spacingM),
            padding: const EdgeInsets.all(AppDimensions.spacingM),
            decoration: ComponentThemes.trendingRecipeCardDecoration,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  recipe.title,
                  style: AppTextStyles.titleSmall,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const Spacer(),
                Text(
                  '${recipe.mealType} • ${recipe.portions ?? 0} portioner',
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.onSurface.withValues(alpha: 0.7),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  static Widget _buildEmptyState() {
    return Container(
      height: 120,
      decoration: ComponentThemes.emptyStateContainerDecoration,
      child: const Center(
        child: Text('Inga populära recept än'),
      ),
    );
  }
}
