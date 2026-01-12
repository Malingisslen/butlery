// lib/widgets/common/search_filter/filters_panel_widget.dart

import 'package:flutter/material.dart';
import 'package:butlery/models/tagging/personal_tag.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_colors.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/widgets/common/search_filter/filter_models.dart';
import 'package:butlery/widgets/common/search_filter/filter_chips_widget.dart';
import 'package:butlery/widgets/common/search_filter/personal_tag_filter_chips.dart';

/// Animated filters panel with all filter groups
class FiltersPanelWidget extends StatelessWidget {
  final bool showFilters;
  final Set<String> activeTimeFilters;
  final Set<String> activeMealTypeFilters;
  final Set<String> activeRatingFilters;
  final Set<String> activeAllergenFilters;
  final Set<String> activeDietaryFilters;
  final Function(String) onTimeFilterToggle;
  final Function(String) onMealTypeFilterToggle;
  final Function(String) onRatingFilterToggle;
  final Function(String)? onAllergenFilterToggle;
  final Function(String)? onDietaryFilterToggle;
  final bool hasActiveFilters;
  final VoidCallback? onClearAllFilters;

  /// Personal tags available for filtering.
  final List<PersonalTag>? personalTagIds;

  /// Currently selected personal tag IDs.
  final Set<String>? activePersonalTagFilters;

  /// Callback when a personal tag is toggled.
  final Function(String)? onPersonalTagFilterToggle;

  /// Callback to navigate to personal tag management.
  final VoidCallback? onManagePersonalTags;

  const FiltersPanelWidget({
    super.key,
    required this.showFilters,
    required this.activeTimeFilters,
    required this.activeMealTypeFilters,
    required this.activeRatingFilters,
    this.activeAllergenFilters = const {},
    this.activeDietaryFilters = const {},
    required this.onTimeFilterToggle,
    required this.onMealTypeFilterToggle,
    required this.onRatingFilterToggle,
    this.onAllergenFilterToggle,
    this.onDietaryFilterToggle,
    required this.hasActiveFilters,
    this.onClearAllFilters,
    this.personalTagIds,
    this.activePersonalTagFilters,
    this.onPersonalTagFilterToggle,
    this.onManagePersonalTags,
  });

  @override
  Widget build(BuildContext context) {
    // Calculate max height based on screen size (leave room for header, search, nav)
    final screenHeight = MediaQuery.of(context).size.height;
    final maxFilterHeight = screenHeight * 0.5; // Max 50% of screen height

    return AnimatedSize(
      duration: AppDimensions.animationDurationMedium,
      curve: Curves.easeInOut,
      child: showFilters
          ? DecoratedBox(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                boxShadow: [
                  BoxShadow(
                    color: AppColors.neutralDark.withValues(alpha: AppDimensions.opacityExtraVeryLight),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: ConstrainedBox(
                constraints: BoxConstraints(maxHeight: maxFilterHeight),
                child: SingleChildScrollView(
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

                      // Allergen-free filters
                      if (onAllergenFilterToggle != null)
                        FilterChipsWidget(
                          title: 'Allergenfri',
                          options: RecipeFilters.allergenFreeFilters,
                          activeFilters: activeAllergenFilters,
                          onToggle: onAllergenFilterToggle!,
                        ),

                      // Dietary filters
                      if (onDietaryFilterToggle != null)
                        FilterChipsWidget(
                          title: 'Specialkost',
                          options: RecipeFilters.dietaryFilters,
                          activeFilters: activeDietaryFilters,
                          onToggle: onDietaryFilterToggle!,
                        ),

                      // Personal tags filters
                      if (onPersonalTagFilterToggle != null)
                        PersonalTagFilterChipsWidget(
                          tags: personalTagIds ?? [],
                          selectedTagIds: activePersonalTagFilters ?? {},
                          onToggle: onPersonalTagFilterToggle!,
                          onManageTags: onManagePersonalTags,
                        ),

                      // Clear all filters button
                      if (hasActiveFilters && onClearAllFilters != null) ...[
                        const SizedBox(height: AppDimensions.spacingM),
                        Center(
                          child: TextButton.icon(
                            onPressed: onClearAllFilters,
                            icon: const Icon(
                              Icons.clear_all,
                              size: AppDimensions.iconSizeAction,
                            ),
                            label: Text(
                              'Rensa alla filter',
                              style: AppTextStyles.labelLarge,
                            ),
                            style: TextButton.styleFrom(
                              foregroundColor:
                                  Theme.of(context).colorScheme.error,
                            ),
                          ),
                        ),
                      ],

                      const SizedBox(height: AppDimensions.spacingM),
                    ],
                  ),
                ),
              ),
            )
          : const SizedBox.shrink(),
    );
  }
}
