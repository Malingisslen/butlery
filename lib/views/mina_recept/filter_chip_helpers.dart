/// Filter-chip + sort-chip helpers extracted from `mina_recept_view.dart`
/// per BUT-441. Three pure helpers:
///   - [getMinaReceptQuickFilterIds] — builds the active-filter ID set
///     used by the chip row.
///   - [handleMinaReceptQuickFilterToggle] — routes a chip tap to the
///     correct VM mutation (allergen / time / dietary / favorites /
///     pantry / ingredient-search navigation).
///   - [MinaReceptSortChip] — chip-styled popup-menu wrapper around
///     `SortMenuBuilder`, positioned in the chip row trailing slot.
library;

import 'package:flutter/material.dart';

import 'package:butlery/core/constants/routes.dart';
import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/services/search_service.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/viewmodels/recipe_list_viewmodel.dart';
import 'package:butlery/widgets/common/menus/sort_menu_builder.dart';
import 'package:butlery/widgets/common/search_filter/filter_models.dart';

/// Set of currently-active quick-filter chip IDs (time / dietary /
/// favorites / pantry / allergen).
Set<String> getMinaReceptQuickFilterIds(RecipeListViewModel viewModel) {
  final ids = <String>{};
  if (viewModel.activeTimeFilters.contains(RecipeFilters.filterQuick)) {
    ids.add(RecipeFilters.filterQuick);
  }
  if (viewModel.activeDietaryFilters.contains(RecipeFilters.filterVegetarian)) {
    ids.add(RecipeFilters.filterVegetarian);
  }
  if (viewModel.favoritesOnly) {
    ids.add(RecipeFilters.filterFavorites);
  }
  if (viewModel.pantryOnly) {
    ids.add(RecipeFilters.filterPantry);
  }
  ids.addAll(viewModel.activeAllergenFilters);
  return ids;
}

/// Routes a quick-filter chip toggle to the correct VM mutation, or
/// navigates to ingredient search for that special chip.
void handleMinaReceptQuickFilterToggle(
  BuildContext context,
  RecipeListViewModel viewModel,
  String filterId,
) {
  if (RecipeFilters.allergenFilterIds.contains(filterId)) {
    viewModel.toggleAllergenFilter(filterId);
    return;
  }
  switch (filterId) {
    case RecipeFilters.filterQuick:
      viewModel.toggleTimeFilter(RecipeFilters.filterQuick);
      return;
    case RecipeFilters.filterVegetarian:
      viewModel.toggleDietaryFilter(RecipeFilters.filterVegetarian);
      return;
    case RecipeFilters.filterFavorites:
      viewModel.toggleFavoritesFilter();
      return;
    case RecipeFilters.filterPantry:
      viewModel.togglePantryFilter();
      return;
    case RecipeFilters.filterIngredientSearch:
      Navigator.pushNamed(context, Routes.ingredientSearch);
      return;
  }
}

/// Chip-styled sort button for the filter chips row trailing slot.
/// Defers VM mutation to the next frame so the popup menu can fully tear
/// down before rebuild — avoids "PopupMenu disposed during build" asserts.
class MinaReceptSortChip extends StatelessWidget {
  const MinaReceptSortChip({super.key, required this.viewModel});

  final RecipeListViewModel viewModel;

  void _onSortChanged(BuildContext context, SortCriteria? criteria) {
    if (criteria == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!context.mounted) return;
      viewModel.updateSort(criteria);
    });
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return PopupMenuButton<SortCriteria>(
      onSelected: (criteria) => _onSortChanged(context, criteria),
      itemBuilder: (context) => SortMenuBuilder.buildItems(
        context: context,
        currentSort: viewModel.sortCriteria,
        sortAscending: viewModel.sortAscending,
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppDimensions.spacingMd,
          vertical: AppDimensions.spacingSm,
        ),
        decoration: BoxDecoration(
          color: cs.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(AppDimensions.borderRadius20),
          border: Border.all(
            color: cs.outlineVariant,
            width: 1.5,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.sort,
              size: AppDimensions.iconSizeS,
              color: cs.onSurfaceVariant,
            ),
            const SizedBox(width: AppDimensions.spacingXs),
            Text(
              context.l10n.commonSort,
              style: AppTextStyles.labelMedium.copyWith(
                color: cs.onSurface,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
