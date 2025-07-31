// lib/views/social/discovery_dashboard/discovery_search_section.dart

import 'package:flutter/material.dart';
import 'package:butlery/viewmodels/discovery_dashboard_viewmodel.dart';
import 'package:butlery/theme/app_colors.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';

/// Discovery Search Section - Enhanced search for discovery dashboard
class DiscoverySearchSection {
  static Widget build(
    BuildContext context,
    DiscoveryDashboardViewModel viewModel,
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
              _buildSearchStats(context, viewModel),
            ],
          ],
        ),
      ),
    );
  }

  static Widget _buildSearchField(
    BuildContext context,
    DiscoveryDashboardViewModel viewModel,
    TextEditingController searchController,
  ) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppDimensions.radiusL),
        border: Border.all(
          color: AppColors.outline.withValues(alpha: 0.2),
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.shadow.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TextField(
        controller: searchController,
        onChanged: viewModel.updateSearchQuery,
        style: AppTextStyles.bodyMedium,
        decoration: InputDecoration(
          hintText: 'Sök recept, menyer, inköpslistor...',
          hintStyle: AppTextStyles.bodyMedium.copyWith(
            color: AppColors.onSurface.withValues(alpha: 0.6),
          ),
          prefixIcon: const Icon(
            Icons.search,
            color: AppColors.primary,
            size: 24,
          ),
          suffixIcon: viewModel.searchQuery.isNotEmpty
              ? Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: Icon(
                        Icons.filter_list,
                        color: AppColors.primary.withValues(alpha: 0.7),
                      ),
                      onPressed: () => _showSearchFilters(context, viewModel),
                      tooltip: 'Sökfilter',
                    ),
                    IconButton(
                      icon: Icon(
                        Icons.clear,
                        color: AppColors.onSurface.withValues(alpha: 0.6),
                      ),
                      onPressed: () {
                        searchController.clear();
                        viewModel.clearSearch();
                      },
                      tooltip: 'Rensa sökning',
                    ),
                  ],
                )
              : IconButton(
                  icon: Icon(
                    Icons.mic,
                    color: AppColors.onSurface.withValues(alpha: 0.4),
                  ),
                  onPressed: () => _startVoiceSearch(context),
                  tooltip: 'Röstsökning',
                ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: AppDimensions.spacingL,
            vertical: AppDimensions.spacingL,
          ),
        ),
      ),
    );
  }

  static Widget _buildSearchStats(
    BuildContext context,
    DiscoveryDashboardViewModel viewModel,
  ) {
    final searchResults = viewModel.searchResults;
    final query = viewModel.searchQuery;
    
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimensions.spacingM,
        vertical: AppDimensions.spacingS,
      ),
      decoration: BoxDecoration(
        color: AppColors.primaryContainer.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppDimensions.radiusM),
        border: Border.all(
          color: AppColors.primary.withValues(alpha: 0.2),
        ),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.search,
            size: 16,
            color: AppColors.primary,
          ),
          const SizedBox(width: AppDimensions.spacingS),
          Expanded(
            child: Text(
              '${searchResults.length} resultat för "$query"',
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.primary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          if (searchResults.isNotEmpty) ...[
            _buildSearchResultTypeChip('Recept', searchResults.where((r) => r['type'] == 'recipe').length),
            const SizedBox(width: AppDimensions.spacingXs),
            _buildSearchResultTypeChip('Menyer', searchResults.where((r) => r['type'] == 'menu').length),
            const SizedBox(width: AppDimensions.spacingXs),
            _buildSearchResultTypeChip('Listor', searchResults.where((r) => r['type'] == 'shopping_list').length),
          ],
        ],
      ),
    );
  }

  static Widget _buildSearchResultTypeChip(String label, int count) {
    if (count == 0) return const SizedBox.shrink();
    
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimensions.spacingS,
        vertical: 2,
      ),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppDimensions.radiusS),
      ),
      child: Text(
        '$count $label',
        style: AppTextStyles.bodySmall.copyWith(
          color: AppColors.primary,
          fontSize: 10,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  static void _showSearchFilters(
    BuildContext context,
    DiscoveryDashboardViewModel viewModel,
  ) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(AppDimensions.spacingL),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.filter_list,
                  color: AppColors.primary,
                ),
                const SizedBox(width: AppDimensions.spacingS),
                Text(
                  'Sökfilter',
                  style: AppTextStyles.titleMedium.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Stäng'),
                ),
              ],
            ),
            const SizedBox(height: AppDimensions.spacingL),
            const Text(
              'Innehållstyp',
              style: AppTextStyles.titleSmall,
            ),
            const SizedBox(height: AppDimensions.spacingM),
            Wrap(
              spacing: AppDimensions.spacingS,
              children: [
                FilterChip(
                  label: const Text('Recept'),
                  selected: true, // TODO: Implement filter state
                  onSelected: (selected) {
                    // TODO: Implement filter logic
                    Navigator.pop(context);
                  },
                ),
                FilterChip(
                  label: const Text('Menyer'),
                  selected: true,
                  onSelected: (selected) {
                    Navigator.pop(context);
                  },
                ),
                FilterChip(
                  label: const Text('Inköpslistor'),
                  selected: true,
                  onSelected: (selected) {
                    Navigator.pop(context);
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  static void _startVoiceSearch(BuildContext context) {
    // TODO: Implement voice search
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Röstsökning kommer snart!'),
        backgroundColor: AppColors.info,
      ),
    );
  }
}