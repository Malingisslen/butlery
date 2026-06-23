// lib/widgets/common/search_filter/quick_filter_chips.dart
//
// UI Redesign: Quick filter chips for fast recipe filtering

import 'package:flutter/material.dart';
import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/core/utils/animation_utils.dart';
import 'package:butlery/services/tagging/config/allergen_config.dart';
import 'package:butlery/widgets/common/search_filter/filter_models.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';

/// Quick filter chip data model.
class QuickFilterOption {
  final String id;
  final String label;
  final IconData? icon;

  const QuickFilterOption({
    required this.id,
    required this.label,
    this.icon,
  });
}

/// Horizontal scrolling quick filter chips row.
///
/// Provides fast access to common filters without opening the filter panel.
/// Per UI redesign mockup: Alla, Favoriter, Under 30 min, Vegetariskt.
class QuickFilterChips extends StatelessWidget {
  const QuickFilterChips({
    required this.options,
    required this.selectedIds,
    required this.onFilterToggle,
    this.showAllOption = true,
    this.allOptionLabel,
    this.trailing,
    super.key,
  });

  /// Available filter options.
  final List<QuickFilterOption> options;

  /// Currently selected filter IDs. Empty means "Alla" is selected.
  final Set<String> selectedIds;

  /// Called when a filter is toggled.
  final void Function(String filterId) onFilterToggle;

  /// Whether to show the "Alla" (All) option.
  final bool showAllOption;

  /// Label for the "All" option. Defaults to localized "All" if not provided.
  final String? allOptionLabel;

  /// Optional trailing widget at the end of the chips row (e.g. sort button).
  final Widget? trailing;

  /// Default recipe quick filters for the recipe list view.
  static List<QuickFilterOption> getDefaultRecipeFilters(
    BuildContext context,
  ) => [
    QuickFilterOption(
      id: RecipeFilters.filterFavorites,
      label: context.l10n.filterFavorites,
    ),
    QuickFilterOption(
      id: RecipeFilters.filterQuick,
      label: context.l10n.filterUnder30Min,
    ),
    QuickFilterOption(
      id: RecipeFilters.filterVegetarian,
      label: context.l10n.filterVegetarianQuick,
    ),
    QuickFilterOption(
      id: RecipeFilters.filterPantry,
      label: context.l10n.filterWithMyIngredients,
      icon: Icons.kitchen_outlined,
    ),
    QuickFilterOption(
      id: RecipeFilters.filterIngredientSearch,
      label: context.l10n.ingredientSearchChip,
      icon: Icons.search_outlined,
    ),
  ];

  /// Dynamic allergen quick-filter chips based on user's tracked allergens.
  /// Uses RecipeFilters.allergenKeyToFilterId as single source of truth.
  static List<QuickFilterOption> getAllergenFilters(
    Set<String> trackedAllergens,
  ) {
    final mapping = RecipeFilters.allergenKeyToFilterId;

    return trackedAllergens.where((key) => mapping.containsKey(key)).map((key) {
      final entry = AllergenConfig.getByKey(key);
      final label = entry?.freeTag ?? '${key}fri';
      return QuickFilterOption(
        id: mapping[key]!,
        label: label,
        icon: Icons.check_circle_outline,
      );
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final isAllSelected = selectedIds.isEmpty;
    final resolvedAllLabel = allOptionLabel ?? context.l10n.filterAll;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimensions.spacingMd,
        vertical: AppDimensions.spacingSm,
      ),
      child: Row(
        children: [
          // "Alla" chip (selected when no filters active)
          if (showAllOption)
            _QuickChip(
              label: resolvedAllLabel,
              isSelected: isAllSelected,
              onTap: isAllSelected
                  ? null
                  : () {
                      // Clear all filters
                      for (final id in selectedIds.toList()) {
                        onFilterToggle(id);
                      }
                    },
            ),

          // Individual filter chips
          ...options.map(
            (option) => Padding(
              padding: const EdgeInsetsDirectional.only(
                start: AppDimensions.spacingSm,
              ),
              child: _QuickChip(
                label: option.label,
                icon: option.icon,
                isSelected: selectedIds.contains(option.id),
                onTap: () => onFilterToggle(option.id),
              ),
            ),
          ),

          // Trailing widget (e.g. sort button)
          if (trailing != null)
            Padding(
              padding: const EdgeInsetsDirectional.only(
                start: AppDimensions.spacingSm,
              ),
              child: trailing!,
            ),
        ],
      ),
    );
  }
}

/// Individual quick filter chip with selection state.
class _QuickChip extends StatelessWidget {
  const _QuickChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
    this.icon,
  });

  final String label;
  final IconData? icon;
  final bool isSelected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Material(
      color: Colors.transparent,
      child: Semantics(
        label: isSelected
            ? context.l10n.a11yQuickFilterSelected(label)
            : context.l10n.a11yQuickFilter(label),
        button: true,
        selected: isSelected,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppDimensions.borderRadius20),
          child: AnimatedContainer(
            duration: AnimationUtils.getDuration(
              context,
              AppDimensions.animationDurationFast,
            ),
            padding: const EdgeInsets.symmetric(
              horizontal: AppDimensions.spacingMd,
              vertical: AppDimensions.spacingSm,
            ),
            decoration: BoxDecoration(
              color: isSelected ? cs.primary : cs.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(AppDimensions.borderRadius20),
              border: Border.all(
                color: isSelected ? cs.primary : cs.outlineVariant,
                width: 1.5,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (icon != null) ...[
                  Icon(
                    icon,
                    size: AppDimensions.iconSizeS,
                    color: isSelected
                        ? cs.surfaceContainerHighest
                        : cs.onSurfaceVariant,
                  ),
                  const SizedBox(width: AppDimensions.spacingXs),
                ],
                Text(
                  label,
                  style: AppTextStyles.labelMedium.copyWith(
                    color: isSelected
                        ? cs.surfaceContainerHighest
                        : cs.onSurface,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
