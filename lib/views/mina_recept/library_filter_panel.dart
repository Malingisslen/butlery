import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:butlery/core/constants/routes.dart';
import 'package:butlery/viewmodels/personal_tag_viewmodel.dart';
import 'package:butlery/viewmodels/recipe_list_viewmodel.dart';
import 'package:butlery/widgets/common/search_filter/filters_panel_widget.dart';

/// The library's filter panel as a list item: it scrolls away with the cards
/// instead of being pinned, so an open panel cannot cover them at large text.
class MinaReceptFilterPanel extends StatelessWidget {
  const MinaReceptFilterPanel({
    super.key,
    required this.viewModel,
    required this.show,
  });

  final RecipeListViewModel viewModel;
  final bool show;

  @override
  Widget build(BuildContext context) {
    final tags = context.watch<PersonalTagViewModel>();
    return FiltersPanelWidget(
      showFilters: show,
      scrollsInternally: false,
      activeTimeFilters: viewModel.activeTimeFilters,
      activeMealTypeFilters: viewModel.activeMealTypeFilters,
      activeRatingFilters: viewModel.activeRatingFilters,
      activeAllergenFilters: viewModel.activeAllergenFilters,
      activeDietaryFilters: viewModel.activeDietaryFilters,
      onTimeFilterToggle: viewModel.toggleTimeFilter,
      onMealTypeFilterToggle: viewModel.toggleMealTypeFilter,
      onRatingFilterToggle: viewModel.toggleRatingFilter,
      onAllergenFilterToggle: viewModel.toggleAllergenFilter,
      onDietaryFilterToggle: viewModel.toggleDietaryFilter,
      // BUT-987: deep-link to the allergen/dietary preferences, which drive
      // the allergen and dietary filters above.
      onManageFoodPreferences: () =>
          Navigator.of(context).pushNamed(Routes.settingsAllergens),
      hasActiveFilters: viewModel.hasActiveFilters,
      onClearAllFilters: viewModel.clearAllFilters,
      personalTagIds: tags.tags,
      activePersonalTagFilters: viewModel.activePersonalTagFilters,
      excludedPersonalTagFilters: viewModel.excludedPersonalTagFilters,
      onPersonalTagFilterToggle: viewModel.togglePersonalTagFilter,
      onExcludedPersonalTagFilterToggle:
          viewModel.toggleExcludedPersonalTagFilter,
      onManagePersonalTags: () =>
          Navigator.pushNamed(context, Routes.settingsPersonalTags),
      personalTagsLoading: tags.isLoading,
    );
  }
}
