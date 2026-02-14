import 'package:flutter/material.dart';
import 'package:butlery/viewmodels/discovery_dashboard_viewmodel.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_colors.dart';
import 'package:butlery/theme/component_themes.dart';
import 'package:butlery/views/social/discovery_dashboard/discovery_section_header.dart';
import 'package:butlery/core/extensions/localization_extension.dart';

/// Popular with friends section showing trending recipes among user's friends.
class PopularWithFriendsSection {
  static Widget build(
      BuildContext context, DiscoveryDashboardViewModel viewModel) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DiscoverySectionHeader(
          title: context.l10n.discoveryPopularWithFriends,
          icon: Icons.people,
          count: viewModel.trendingRecipes.length,
        ),
        const SizedBox(height: AppDimensions.spacingS),
        Text(
          context.l10n.discoveryPopularWithFriendsDescription,
          style: AppTextStyles.bodySmall.copyWith(
            color: AppColors.onSurface
                .withValues(alpha: AppDimensions.opacityDark),
          ),
        ),
        const SizedBox(height: AppDimensions.spacingM),
        if (viewModel.trendingRecipes.isNotEmpty)
          _buildRecipeList(viewModel)
        else
          _buildEmptyState(context),
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
            margin:
                const EdgeInsetsDirectional.only(end: AppDimensions.spacingM),
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
                  '${recipe.mealType} • ${context.l10n.discoveryPortions(recipe.portions ?? 0)}',
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.onSurface
                        .withValues(alpha: AppDimensions.opacityDark),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  static Widget _buildEmptyState(BuildContext context) {
    return Container(
      height: 120,
      decoration: ComponentThemes.emptyStateContainerDecoration,
      child: Center(
        child: Text(context.l10n.discoveryNoPopularRecipesYet),
      ),
    );
  }
}
