// lib/views/social/discovery_dashboard/trending_content_section.dart

import 'package:flutter/material.dart';
import 'package:butlery/viewmodels/discovery_dashboard_viewmodel.dart';
import 'package:butlery/theme/app_colors.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';

/// Trending Content Section - Shows trending recipes, menus, shopping lists
class TrendingContentSection {
  static Widget build(
    BuildContext context,
    DiscoveryDashboardViewModel viewModel,
  ) {
    final trendingRecipes = viewModel.trendingRecipes;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(
              Icons.trending_up,
              color: AppColors.success,
              size: 20,
            ),
            const SizedBox(width: AppDimensions.spacingS),
            Text(
              'Populärt just nu',
              style: AppTextStyles.titleMedium.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const Spacer(),
            TextButton(
              onPressed: () => _showAllTrending(context, viewModel),
              child: const Text('Se allt'),
            ),
          ],
        ),
        const SizedBox(height: AppDimensions.spacingM),
        
        if (trendingRecipes.isEmpty)
          _buildEmptyState()
        else
          SizedBox(
            height: 200,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: trendingRecipes.take(10).length,
              separatorBuilder: (context, index) => const SizedBox(width: AppDimensions.spacingM),
              itemBuilder: (context, index) {
                final recipe = trendingRecipes[index];
                return _buildTrendingRecipeCard(context, recipe);
              },
            ),
          ),
      ],
    );
  }

  static Widget _buildEmptyState() {
    return Container(
      height: 120,
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(AppDimensions.radiusM),
        border: Border.all(
          color: AppColors.outline.withValues(alpha: 0.2),
        ),
      ),
      child: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.trending_up,
              color: AppColors.outline,
              size: 32,
            ),
            SizedBox(height: AppDimensions.spacingS),
            Text(
              'Laddar populärt innehåll...',
              style: AppTextStyles.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }

  static Widget _buildTrendingRecipeCard(BuildContext context, dynamic recipe) {
    return GestureDetector(
      onTap: () => _openRecipe(context, recipe),
      child: Container(
        width: 160,
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppDimensions.radiusM),
          boxShadow: [
            BoxShadow(
              color: AppColors.shadow.withValues(alpha: 0.1),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Recipe image
            Container(
              height: 100,
              decoration: BoxDecoration(
                color: AppColors.primaryContainer.withValues(alpha: 0.3),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(AppDimensions.radiusM),
                  topRight: Radius.circular(AppDimensions.radiusM),
                ),
              ),
              child: recipe.imageUrls.isNotEmpty
                  ? ClipRRect(
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(AppDimensions.radiusM),
                        topRight: Radius.circular(AppDimensions.radiusM),
                      ),
                      child: Image.network(
                        recipe.imageUrls.first,
                        width: double.infinity,
                        height: 100,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => _buildImagePlaceholder(),
                      ),
                    )
                  : _buildImagePlaceholder(),
            ),
            
            // Recipe info
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(AppDimensions.spacingM),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      recipe.title,
                      style: AppTextStyles.titleSmall.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: AppDimensions.spacingS),
                    if (recipe.socialData?.ownerDisplayName != null)
                      Text(
                        'Av ${recipe.socialData!.ownerDisplayName}',
                        style: AppTextStyles.bodySmall.copyWith(
                          color: AppColors.onSurface.withValues(alpha: 0.6),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    const Spacer(),
                    Row(
                      children: [
                        const Icon(
                          Icons.people,
                          size: 14,
                          color: AppColors.success,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${(recipe.socialData?.memberPermissions?.length ?? 0) + 1}',
                          style: AppTextStyles.bodySmall.copyWith(
                            color: AppColors.success,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppDimensions.spacingS,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.success.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(AppDimensions.radiusS),
                          ),
                          child: Text(
                            'Populär',
                            style: AppTextStyles.bodySmall.copyWith(
                              color: AppColors.success,
                              fontSize: 10,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static Widget _buildImagePlaceholder() {
    return Container(
      width: double.infinity,
      height: 100,
      color: AppColors.primaryContainer.withValues(alpha: 0.3),
      child: Icon(
        Icons.restaurant,
        color: AppColors.primary.withValues(alpha: 0.6),
        size: 32,
      ),
    );
  }

  static void _openRecipe(BuildContext context, dynamic recipe) {
    Navigator.pushNamed(
      context,
      '/recipe-detail',
      arguments: {'recipeId': recipe.id},
    );
  }

  static void _showAllTrending(BuildContext context, DiscoveryDashboardViewModel viewModel) {
    // TODO: Implement show all trending page
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Visa alla populära kommer snart!'),
        backgroundColor: AppColors.info,
      ),
    );
  }
}