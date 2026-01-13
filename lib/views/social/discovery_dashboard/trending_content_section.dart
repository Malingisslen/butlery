// lib/views/social/discovery_dashboard/trending_content_section.dart

import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:butlery/viewmodels/discovery_dashboard_viewmodel.dart';
import 'package:butlery/theme/app_colors.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/theme/app_shadows.dart';
import 'package:butlery/core/constants/routes.dart';
import 'package:butlery/views/social/discovery_dashboard/discovery_section_header.dart';

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
        DiscoverySectionHeader(
          title: 'Populärt just nu',
          icon: Icons.trending_up,
          iconColor: AppColors.success,
          actionLabel: 'Se allt',
          onActionPressed: () => _showAllTrending(context, viewModel),
          count: trendingRecipes.length,
        ),
        const SizedBox(height: AppDimensions.spacingM),
        if (trendingRecipes.isEmpty)
          _buildEmptyState()
        else
          SizedBox(
            height: AppDimensions.heightXLarge,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: trendingRecipes.take(10).length,
              separatorBuilder: (context, index) =>
                  const SizedBox(width: AppDimensions.spacingM),
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
      height: AppDimensions.heightLarge,
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant
            .withValues(alpha: AppDimensions.opacityMediumLight),
        borderRadius: BorderRadius.circular(AppDimensions.borderRadiusM),
        border: Border.all(
          color:
              AppColors.outline.withValues(alpha: AppDimensions.opacityLight),
        ),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.trending_up,
              color: AppColors.outline,
              size: AppDimensions.iconSizeL,
            ),
            const SizedBox(height: AppDimensions.spacingS),
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
          borderRadius: BorderRadius.circular(AppDimensions.borderRadiusM),
          boxShadow: AppShadows.card,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Recipe image
            Container(
              height: 100,
              decoration: BoxDecoration(
                color: AppColors.primaryContainer.withValues(alpha: AppDimensions.opacityMediumLight),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(AppDimensions.borderRadiusM),
                  topRight: Radius.circular(AppDimensions.borderRadiusM),
                ),
              ),
              child: recipe.imageUrls.isNotEmpty
                  ? ClipRRect(
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(AppDimensions.borderRadiusM),
                        topRight: Radius.circular(AppDimensions.borderRadiusM),
                      ),
                      child: CachedNetworkImage(
                        imageUrl: recipe.imageUrls.first,
                        width: double.infinity,
                        height: 100,
                        fit: BoxFit.contain,
                        placeholder: (context, url) => ColoredBox(
                          color:
                              AppColors.primaryContainer.withValues(alpha: AppDimensions.opacityMediumLight),
                          child: const Center(
                            child: SizedBox(
                              width: 30,
                              height: 30,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          ),
                        ),
                        errorWidget: (context, url, error) =>
                            _buildImagePlaceholder(),
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
                      style: AppTextStyles.titleMedium,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: AppDimensions.spacingS),
                    if (recipe.socialData?.ownerDisplayName != null)
                      Text(
                        'Av ${recipe.socialData!.ownerDisplayName}',
                        style: AppTextStyles.bodySmall.copyWith(
                          color: AppColors.onSurface.withValues(alpha: AppDimensions.opacityMediumDark),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    const Spacer(),
                    Row(
                      children: [
                        const Icon(
                          Icons.people,
                          size: AppDimensions.iconSizeXs,
                          color: AppColors.success,
                        ),
                        const SizedBox(width: AppDimensions.spacingXs),
                        Text(
                          '${(recipe.socialData?.memberPermissions?.length ?? 0) + 1}',
                          style: AppTextStyles.metadataEmphasized.copyWith(
                            color: AppColors.success,
                          ),
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppDimensions.spacingS,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.success.withValues(alpha: AppDimensions.opacityVeryLight),
                            borderRadius: BorderRadius.circular(
                                AppDimensions.borderRadiusS),
                          ),
                          child: Text(
                            'Populär',
                            style: AppTextStyles.labelSmall.copyWith(
                              color: AppColors.success,
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
      color: AppColors.primaryContainer.withValues(alpha: AppDimensions.opacityMediumLight),
      child: Icon(
        Icons.restaurant,
        color: AppColors.primary.withValues(alpha: AppDimensions.opacityMediumDark),
        size: AppDimensions.iconSizeL,
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

  static void _showAllTrending(
      BuildContext context, DiscoveryDashboardViewModel viewModel) {
    // Navigate to extended trending content view
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => _buildTrendingContentPage(context, viewModel),
      ),
    );
  }

  static Widget _buildTrendingContentPage(
      BuildContext context, DiscoveryDashboardViewModel viewModel) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Populärt innehåll'),
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.onPrimary,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppDimensions.spacingM),
        child: Column(
          children: [
            // Extended trending recipes section
            if (viewModel.trendingRecipes.isNotEmpty) ...[
              _buildSectionHeader(
                  'Populära recept', viewModel.trendingRecipes.length),
              const SizedBox(height: AppDimensions.spacingS),
              ...viewModel.trendingRecipes.take(20).map(
                    (recipe) => Card(
                      margin:
                          const EdgeInsets.only(bottom: AppDimensions.spacingS),
                      child: ListTile(
                        leading: const Icon(Icons.restaurant),
                        title: Text(recipe.core.title),
                        subtitle: Text(recipe.core.description),
                        trailing: const Icon(Icons.arrow_forward_ios),
                        onTap: () => Navigator.pushNamed(
                          context,
                          Routes.receptDetalj,
                          arguments: {'recipe': recipe},
                        ),
                      ),
                    ),
                  ),
              const SizedBox(height: AppDimensions.spacingL),
            ],

            // Extended trending menus section
            if (viewModel.trendingMenus.isNotEmpty) ...[
              _buildSectionHeader(
                  'Populära menyer', viewModel.trendingMenus.length),
              const SizedBox(height: AppDimensions.spacingS),
              ...viewModel.trendingMenus.take(10).map(
                    (menu) => Card(
                      margin:
                          const EdgeInsets.only(bottom: AppDimensions.spacingS),
                      child: ListTile(
                        leading: const Icon(Icons.calendar_month),
                        title: Text(menu.menuTitle),
                        subtitle: Text('${menu.totalRecipeCount} recept'),
                        trailing: const Icon(Icons.arrow_forward_ios),
                        onTap: () => Navigator.pushNamed(
                          context,
                          Routes.menuPreview,
                          arguments: {'menu': menu},
                        ),
                      ),
                    ),
                  ),
              const SizedBox(height: AppDimensions.spacingL),
            ],

            // Extended trending shopping lists section
            if (viewModel.trendingShoppingLists.isNotEmpty) ...[
              _buildSectionHeader('Populära inköpslistor',
                  viewModel.trendingShoppingLists.length),
              const SizedBox(height: AppDimensions.spacingS),
              ...viewModel.trendingShoppingLists.take(10).map(
                    (list) => Card(
                      margin:
                          const EdgeInsets.only(bottom: AppDimensions.spacingS),
                      child: ListTile(
                        leading: const Icon(Icons.shopping_cart),
                        title: Text(list.name),
                        subtitle: Text('${list.items.length} varor'),
                        trailing: const Icon(Icons.arrow_forward_ios),
                        onTap: () => Navigator.pushNamed(
                          context,
                          Routes.inkopslista,
                          arguments: {'listId': list.id},
                        ),
                      ),
                    ),
                  ),
            ],
          ],
        ),
      ),
    );
  }

  static Widget _buildSectionHeader(String title, int count) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: AppTextStyles.titleLarge,
        ),
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppDimensions.spacingS,
            vertical: 4,
          ),
          decoration: BoxDecoration(
            color: AppColors.primary,
            borderRadius: BorderRadius.circular(AppDimensions.borderRadiusL),
          ),
          child: Text(
            count.toString(),
            style: AppTextStyles.labelLarge.copyWith(
              color: AppColors.onPrimary,
            ),
          ),
        ),
      ],
    );
  }
}
