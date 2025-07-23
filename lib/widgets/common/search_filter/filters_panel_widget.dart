// lib/widgets/common/search_filter/filters_panel_widget.dart

import 'package:flutter/material.dart';
import '../../../theme/app_dimensions.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_text_styles.dart';
import 'filter_models.dart';
import 'filter_chips_widget.dart';

/// Animated filters panel with all filter groups
class FiltersPanelWidget extends StatelessWidget {
  final bool showFilters;
  final Set<String> activeTimeFilters;
  final Set<String> activeMealTypeFilters;
  final Set<String> activeRatingFilters;
  final Function(String) onTimeFilterToggle;
  final Function(String) onMealTypeFilterToggle;
  final Function(String) onRatingFilterToggle;
  final bool hasActiveFilters;
  final VoidCallback? onClearAllFilters;

  const FiltersPanelWidget({
    super.key,
    required this.showFilters,
    required this.activeTimeFilters,
    required this.activeMealTypeFilters,
    required this.activeRatingFilters,
    required this.onTimeFilterToggle,
    required this.onMealTypeFilterToggle,
    required this.onRatingFilterToggle,
    required this.hasActiveFilters,
    this.onClearAllFilters,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedSize(
      duration: AppDimensions.animationDurationMedium,
      curve: Curves.easeInOut,
      child: showFilters
          ? Container(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                boxShadow: [
                  BoxShadow(
                    color: AppColors.neutralDark.withValues(alpha: 0.05),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Time filters
                  FilterChipsWidget(
                    title: 'Tillagningstid',
                    options: RecipeFilters.timeFilters,
                    activeFilters: activeTimeFilters,
                    onToggle: onTimeFilterToggle,
                  ),

                  // Meal type filters
                  FilterChipsWidget(
                    title: 'Måltidstyp',
                    options: RecipeFilters.mealTypeFilters,
                    activeFilters: activeMealTypeFilters,
                    onToggle: onMealTypeFilterToggle,
                  ),

                  // Rating filters
                  FilterChipsWidget(
                    title: 'Betyg',
                    options: RecipeFilters.ratingFilters,
                    activeFilters: activeRatingFilters,
                    onToggle: onRatingFilterToggle,
                  ),

                  // Clear all filters button
                  if (hasActiveFilters && onClearAllFilters != null) ...[
                    const SizedBox(height: AppDimensions.spacingM),
                    Center(
                      child: TextButton.icon(
                        onPressed: onClearAllFilters,
                        icon: Icon(
                          Icons.clear_all,
                          size: AppDimensions.iconSizeAction,
                        ),
                        label: Text(
                          'Rensa alla filter',
                          style: AppTextStyles.labelLarge,
                        ),
                        style: TextButton.styleFrom(
                          foregroundColor: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ),
                  ],

                  const SizedBox(height: AppDimensions.spacingM),
                ],
              ),
            )
          : const SizedBox.shrink(),
    );
  }
}