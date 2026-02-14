// lib/views/social/discovery_dashboard/discovery_search_section.dart

import 'package:flutter/material.dart';
import 'package:butlery/viewmodels/discovery_dashboard_viewmodel.dart';
import 'package:butlery/theme/app_colors.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/theme/app_shadows.dart';
import 'package:butlery/widgets/common/buttons/action_buttons.dart';
import 'package:butlery/core/extensions/localization_extension.dart';

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
        borderRadius: BorderRadius.circular(AppDimensions.borderRadiusL),
        border: Border.all(
          color:
              AppColors.outline.withValues(alpha: AppDimensions.opacityLight),
        ),
        boxShadow: AppShadows.card,
      ),
      child: TextField(
        controller: searchController,
        onChanged: viewModel.updateSearchQuery,
        style: AppTextStyles.bodyMedium,
        decoration: InputDecoration(
          hintText: context.l10n.discoverySearchHint,
          hintStyle: AppTextStyles.bodyMedium.copyWith(
            color: AppColors.onSurface
                .withValues(alpha: AppDimensions.opacityMediumDark),
          ),
          prefixIcon: const Icon(
            Icons.search,
            color: AppColors.primary,
            size: AppDimensions.iconSizeL,
          ),
          suffixIcon: viewModel.searchQuery.isNotEmpty
              ? Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: Icon(
                        Icons.tune,
                        color: AppColors.primary
                            .withValues(alpha: AppDimensions.opacityDark),
                      ),
                      onPressed: () => _showSearchFilters(context, viewModel),
                      tooltip: context.l10n.discoverySearchFilters,
                    ),
                    IconButton(
                      icon: Icon(
                        Icons.clear,
                        color: AppColors.onSurface
                            .withValues(alpha: AppDimensions.opacityMediumDark),
                      ),
                      onPressed: () {
                        searchController.clear();
                        viewModel.clearSearch();
                      },
                      tooltip: context.l10n.commonClearSearch,
                    ),
                  ],
                )
              : IconButton(
                  icon: Icon(
                    Icons.mic,
                    color: AppColors.onSurface
                        .withValues(alpha: AppDimensions.opacityMedium),
                  ),
                  onPressed: () => _startVoiceSearch(context),
                  tooltip: context.l10n.discoveryVoiceSearch,
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
        color: AppColors.primaryContainer
            .withValues(alpha: AppDimensions.opacityVeryLight),
        borderRadius: BorderRadius.circular(AppDimensions.borderRadiusM),
        border: Border.all(
          color:
              AppColors.primary.withValues(alpha: AppDimensions.opacityLight),
        ),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.search,
            size: AppDimensions.iconSizeS,
            color: AppColors.primary,
          ),
          const SizedBox(width: AppDimensions.spacingS),
          Expanded(
            child: Text(
              context.l10n
                  .discoverySearchResultsFor(searchResults.length, query),
              style: AppTextStyles.metadataEmphasized.copyWith(
                color: AppColors.primary,
              ),
            ),
          ),
          if (searchResults.isNotEmpty) ...[
            _buildSearchResultTypeChip(context.l10n.discoveryRecipes,
                searchResults.where((r) => r['type'] == 'recipe').length),
            const SizedBox(width: AppDimensions.spacingXs),
            _buildSearchResultTypeChip(context.l10n.discoveryMenus,
                searchResults.where((r) => r['type'] == 'menu').length),
            const SizedBox(width: AppDimensions.spacingXs),
            _buildSearchResultTypeChip(
                context.l10n.discoveryLists,
                searchResults
                    .where((r) => r['type'] == 'shopping_list')
                    .length),
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
        color:
            AppColors.primary.withValues(alpha: AppDimensions.opacityVeryLight),
        borderRadius: BorderRadius.circular(AppDimensions.borderRadiusS),
      ),
      child: Text(
        '$count $label',
        style: AppTextStyles.labelSmall.copyWith(
          color: AppColors.primary,
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
                  Icons.tune,
                  color: AppColors.primary,
                ),
                const SizedBox(width: AppDimensions.spacingS),
                Text(
                  context.l10n.discoverySearchFilters,
                  style: AppTextStyles.titleMedium,
                ),
                const Spacer(),
                ActionButtons.textButton(
                  context,
                  label: context.l10n.commonClose,
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: AppDimensions.spacingL),
            Text(
              context.l10n.discoveryContentType,
              style: AppTextStyles.titleSmall,
            ),
            const SizedBox(height: AppDimensions.spacingM),
            Wrap(
              spacing: AppDimensions.spacingS,
              children: [
                FilterChip(
                  label: Text(context.l10n.discoveryRecipes),
                  selected: viewModel.recipesFilterEnabled,
                  onSelected: (selected) {
                    viewModel.toggleContentTypeFilter('recipes');
                  },
                ),
                FilterChip(
                  label: Text(context.l10n.discoveryMenus),
                  selected: viewModel.menusFilterEnabled,
                  onSelected: (selected) {
                    viewModel.toggleContentTypeFilter('menus');
                  },
                ),
                FilterChip(
                  label: Text(context.l10n.discoveryShoppingLists),
                  selected: viewModel.shoppingListsFilterEnabled,
                  onSelected: (selected) {
                    viewModel.toggleContentTypeFilter('shopping_lists');
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
    // Show voice search dialog with microphone animation
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => AlertDialog(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: AppDimensions.spacingL),
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppColors.primary
                    .withValues(alpha: AppDimensions.opacityVeryLight),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.mic,
                size: AppDimensions.iconSizeXl,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: AppDimensions.spacingL),
            Text(
              context.l10n.discoveryVoiceSearchPrompt,
              style: AppTextStyles.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppDimensions.spacingS),
            Text(
              context.l10n.discoveryVoiceSearchInstruction,
              style: AppTextStyles.bodySmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppDimensions.spacingL),
          ],
        ),
        actions: [
          ActionButtons.secondaryButton(
            context,
            label: context.l10n.commonCancel,
            onPressed: () => Navigator.pop(context),
          ),
          ActionButtons.primaryButton(
            context,
            label: context.l10n.commonStart,
            icon: Icons.mic,
            onPressed: () {
              Navigator.pop(context);
              // Simulate voice input for now
              _simulateVoiceInput(context);
            },
          ),
        ],
      ),
    );
  }

  /// Simulate voice search input (placeholder implementation)
  static void _simulateVoiceInput(BuildContext context) {
    // Show processing state
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            const SizedBox(width: AppDimensions.spacingM),
            Text(context.l10n.discoveryListening),
          ],
        ),
        backgroundColor: AppColors.info,
        duration: const Duration(seconds: 2),
      ),
    );

    // Simulate speech-to-text result after 2 seconds
    Future.delayed(const Duration(seconds: 2), () {
      if (context.mounted) {
        // Simulate detected speech and trigger search
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.l10n.discoveryVoiceSearchResult),
            backgroundColor: AppColors.success,
            action: SnackBarAction(
              label: context.l10n.commonSearch,
              onPressed: () {
                // This would trigger the actual search with the detected text
                // For now, just show the search was initiated
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(context.l10n.discoveryVoiceSearchPreview),
                    backgroundColor: AppColors.info,
                  ),
                );
              },
            ),
          ),
        );
      }
    });
  }
}
