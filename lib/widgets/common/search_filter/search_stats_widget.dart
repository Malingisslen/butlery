// lib/widgets/common/search_filter/search_stats_widget.dart

import 'package:flutter/material.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/core/extensions/localization_extension.dart';

/// Statistics widget showing search and filter information
class SearchStatsWidget extends StatelessWidget {
  final String searchQuery;
  final bool hasActiveFilters;
  final int? resultCount;
  final int? activeFilterCount;

  const SearchStatsWidget({
    super.key,
    required this.searchQuery,
    required this.hasActiveFilters,
    this.resultCount,
    this.activeFilterCount,
  });

  @override
  Widget build(BuildContext context) {
    if (!_shouldShowStats()) return const SizedBox.shrink();

    final statsText = _buildStatsText(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimensions.spacingL,
        vertical: AppDimensions.spacingXs,
      ),
      margin: const EdgeInsets.symmetric(horizontal: AppDimensions.spacingL),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer.withValues(
          alpha: AppDimensions.opacityMediumLight,
        ), // ✅ Back to proper AppTheme color
        borderRadius: BorderRadius.circular(AppDimensions.borderRadiusS),
        border: Border.all(
          color: Theme.of(
            context,
          ).colorScheme.primary.withValues(alpha: AppDimensions.opacityLight),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.info_outline,
            size: AppDimensions.iconSizeM,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(height: AppDimensions.spacingXs),
          Expanded(
            child: Text(
              statsText,
              style: AppTextStyles.metadataEmphasized.copyWith(
                color: Theme.of(context).colorScheme.onPrimaryContainer,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Check if stats should be shown
  bool _shouldShowStats() {
    return searchQuery.isNotEmpty || hasActiveFilters || resultCount != null;
  }

  /// Build stats text
  String _buildStatsText(BuildContext context) {
    final parts = <String>[];

    if (searchQuery.isNotEmpty) {
      parts.add('${context.l10n.searchQuery}: "$searchQuery"');
    }

    if (hasActiveFilters &&
        activeFilterCount != null &&
        activeFilterCount! > 0) {
      parts.add(context.l10n.searchFiltersActive(activeFilterCount!));
    }

    if (resultCount != null) {
      parts.add(context.l10n.searchResults(resultCount!));
    }

    return parts.join(' • ');
  }
}
