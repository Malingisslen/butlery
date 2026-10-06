// lib/widgets/common/search_filter/quick_filter_chips.dart
//
// UI Redesign: Quick filter chips for fast recipe filtering

import 'package:flutter/material.dart';
import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/core/utils/animation_utils.dart';
import 'package:butlery/services/tagging/config/allergen_config.dart';
import 'package:butlery/widgets/common/icons/butlery_glyph.dart';
import 'package:butlery/widgets/common/icons/butlery_icons.dart';
import 'package:butlery/widgets/common/search_filter/filter_models.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/widgets/common/butlery_control_focus.dart';
import 'package:butlery/widgets/common/press_fill.dart';
import 'package:butlery/theme/app_motion.dart';

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
      icon: ButleryIcons.search,
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
        icon: ButleryIcons.circleCheck,
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
        vertical: AppDimensions.space4,
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
class _QuickChip extends StatefulWidget {
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
  State<_QuickChip> createState() => _QuickChipState();
}

class _QuickChipState extends State<_QuickChip> {
  bool _pressed = false;
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final label = widget.label;
    final icon = widget.icon;
    final isSelected = widget.isSelected;
    final cs = Theme.of(context).colorScheme;
    // The InkWell covers the 48 dp grip, wider than the pill, so the pill
    // itself takes the pressed fill of its surface and the grip paints none.
    final rest = isSelected ? cs.primary : cs.surfaceContainerHighest;
    final fill = _pressed || _hovered
        ? PressFill.fillFor(
            context,
            isSelected ? PressSurface.ink : PressSurface.raised,
          )
        : rest;
    // The shared grip (Grafisk manual v6:381): the InkWell fills a 48 dp box
    // around the visible chip, and the focus ring goes around that box.
    return ButleryControlFocus(
      borderRadius: BorderRadius.circular(AppDimensions.radiusPill),
      child: Material(
        color: Colors.transparent,
        child: Semantics(
          label: isSelected
              ? context.l10n.a11yQuickFilterSelected(label)
              : context.l10n.a11yQuickFilter(label),
          button: true,
          selected: isSelected,
          child: InkWell(
            onTap: widget.onTap,
            onHighlightChanged: (value) => setState(() => _pressed = value),
            onHover: (value) => setState(() => _hovered = value),
            overlayColor: const WidgetStatePropertyAll(Colors.transparent),
            borderRadius: BorderRadius.circular(AppDimensions.radiusPill),
            child: ButleryControlFocus.box(
              child: AnimatedContainer(
                duration: AnimationUtils.getDuration(
                  context,
                  AppMotion.micro,
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: AppDimensions.spacingMd,
                  vertical: AppDimensions.spacingSm,
                ),
                decoration: BoxDecoration(
                  color: fill,
                  borderRadius: BorderRadius.circular(
                    AppDimensions.radiusPill,
                  ),
                  border: Border.all(
                    color: isSelected ? cs.onSurface : cs.outlineVariant,
                    width: 1.5,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (icon != null) ...[
                      ButleryIcon(
                        icon,
                        size: AppDimensions.iconSizeS,
                        color: isSelected ? cs.onPrimary : cs.onSurfaceVariant,
                      ),
                      const SizedBox(width: AppDimensions.spacingXs),
                    ],
                    Text(
                      label,
                      style: AppTextStyles.labelMedium.copyWith(
                        color: isSelected ? cs.onPrimary : cs.onSurface,
                        fontWeight: isSelected
                            ? FontWeight.w600
                            : FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
