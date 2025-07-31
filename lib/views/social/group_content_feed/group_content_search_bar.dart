// lib/views/social/group_content_feed/group_content_search_bar.dart

import 'package:flutter/material.dart';
import 'package:butlery/viewmodels/group_content_viewmodel.dart';
import 'package:butlery/theme/app_colors.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';

/// Group Content Search Bar - Styled search bar for group content
class GroupContentSearchBar {
  static Widget build(
    BuildContext context,
    GroupContentViewModel viewModel,
    TextEditingController searchController,
  ) {
    return SliverToBoxAdapter(
      child: Container(
        padding: const EdgeInsets.all(AppDimensions.spacingL),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSearchField(context, viewModel, searchController),
            if (viewModel.searchQuery.isNotEmpty) ...[
              const SizedBox(height: AppDimensions.spacingM),
              _buildSearchResults(context, viewModel),
            ],
          ],
        ),
      ),
    );
  }

  static Widget _buildSearchField(
    BuildContext context,
    GroupContentViewModel viewModel,
    TextEditingController searchController,
  ) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppDimensions.radiusM),
        border: Border.all(
          color: AppColors.outline.withValues(alpha: 0.2),
        ),
      ),
      child: TextField(
        controller: searchController,
        onChanged: viewModel.updateSearchQuery,
        style: AppTextStyles.bodyMedium,
        decoration: InputDecoration(
          hintText: 'Sök i gruppens innehåll...',
          hintStyle: AppTextStyles.bodyMedium.copyWith(
            color: AppColors.onSurface.withValues(alpha: 0.6),
          ),
          prefixIcon: Icon(
            Icons.search,
            color: AppColors.onSurface.withValues(alpha: 0.6),
          ),
          suffixIcon: viewModel.searchQuery.isNotEmpty
              ? IconButton(
                  icon: Icon(
                    Icons.clear,
                    color: AppColors.onSurface.withValues(alpha: 0.6),
                  ),
                  onPressed: () {
                    searchController.clear();
                    viewModel.clearSearch();
                  },
                )
              : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: AppDimensions.spacingL,
            vertical: AppDimensions.spacingM,
          ),
        ),
      ),
    );
  }

  static Widget _buildSearchResults(
    BuildContext context,
    GroupContentViewModel viewModel,
  ) {
    final filteredRecipes = viewModel.filteredGroupRecipes;
    final filteredMenus = viewModel.filteredGroupMenus;
    final filteredShoppingLists = viewModel.filteredGroupShoppingLists;
    
    final totalResults = filteredRecipes.length + 
                        filteredMenus.length + 
                        filteredShoppingLists.length;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimensions.spacingM,
        vertical: AppDimensions.spacingS,
      ),
      decoration: BoxDecoration(
        color: AppColors.secondaryContainer.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppDimensions.radiusS),
      ),
      child: Row(
        children: [
          Icon(
            Icons.filter_list,
            size: 16,
            color: AppColors.onSurface.withValues(alpha: 0.6),
          ),
          const SizedBox(width: AppDimensions.spacingS),
          Text(
            '$totalResults resultat för "${viewModel.searchQuery}"',
            style: AppTextStyles.bodySmall.copyWith(
              color: AppColors.onSurface.withValues(alpha: 0.8),
            ),
          ),
          const Spacer(),
          if (filteredRecipes.isNotEmpty) ...[
            _buildResultChip('${filteredRecipes.length} recept', Icons.restaurant),
            const SizedBox(width: AppDimensions.spacingS),
          ],
          if (filteredMenus.isNotEmpty) ...[
            _buildResultChip('${filteredMenus.length} menyer', Icons.calendar_month),
            const SizedBox(width: AppDimensions.spacingS),
          ],
          if (filteredShoppingLists.isNotEmpty) ...[
            _buildResultChip('${filteredShoppingLists.length} listor', Icons.shopping_cart),
          ],
        ],
      ),
    );
  }

  static Widget _buildResultChip(String label, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimensions.spacingS,
        vertical: 2,
      ),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppDimensions.radiusS),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 12,
            color: AppColors.primary,
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: AppTextStyles.bodySmall.copyWith(
              color: AppColors.primary,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}