// lib/views/social/shared_with_me/shared_content_lists.dart

import 'package:flutter/material.dart';
import 'package:butlery/widgets/common/buttons/action_buttons.dart';
import 'package:butlery/models/shared_menu.dart';
import 'package:butlery/models/shared_recipe.dart';
import 'package:butlery/models/shared_shopping_list.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/viewmodels/shared_content/shared_content_coordinator_viewmodel.dart';
import 'package:butlery/views/social/shared_with_me/shared_content_tabs.dart';
import 'package:butlery/views/social/shared_with_me/shared_menu_card.dart';
import 'package:butlery/views/social/shared_with_me/shared_recipe_card.dart';
import 'package:butlery/views/social/shared_with_me/shared_shopping_list_card.dart';
import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/widgets/common/icons/butlery_icons.dart';
import 'package:butlery/widgets/common/indicators/plate_line.dart';
import 'package:butlery/widgets/common/layout/butlery_page_body.dart';
import 'package:butlery/widgets/common/list/butlery_list.dart';

/// The rows of the selected tab, newest first as the view models hold them.
class SharedContentLists {
  static List<Widget> rowsFor(
    SharedContentCoordinatorViewModel viewModel,
    SharedContentFilter filter,
  ) {
    return switch (filter) {
      SharedContentFilter.recipes => [
        for (final SharedRecipe r in viewModel.recipeViewModel.filteredContent)
          Builder(
            key: ValueKey('recipe_${r.id}'),
            builder: (context) => SharedRecipeCard.build(context, viewModel, r),
          ),
      ],
      SharedContentFilter.menus => [
        for (final SharedMenu m in viewModel.menuViewModel.filteredContent)
          Builder(
            key: ValueKey('menu_${m.id}'),
            builder: (context) => SharedMenuCard.build(context, viewModel, m),
          ),
      ],
      SharedContentFilter.shoppingLists => [
        for (final SharedShoppingList s
            in viewModel.shoppingViewModel.filteredContent)
          Builder(
            key: ValueKey('list_${s.id}'),
            builder: (context) =>
                SharedShoppingListCard.build(context, viewModel, s),
          ),
      ],
    };
  }

  static bool hasMore(
    SharedContentCoordinatorViewModel viewModel,
    SharedContentFilter filter,
  ) => switch (filter) {
    SharedContentFilter.recipes => viewModel.recipeViewModel.hasMoreContent,
    SharedContentFilter.menus => viewModel.menuViewModel.hasMoreContent,
    SharedContentFilter.shoppingLists =>
      viewModel.shoppingViewModel.hasMoreContent,
  };

  static bool isLoadingMore(
    SharedContentCoordinatorViewModel viewModel,
    SharedContentFilter filter,
  ) => switch (filter) {
    SharedContentFilter.recipes => viewModel.recipeViewModel.isLoadingMore,
    SharedContentFilter.menus => viewModel.menuViewModel.isLoadingMore,
    SharedContentFilter.shoppingLists =>
      viewModel.shoppingViewModel.isLoadingMore,
  };

  static void loadMore(
    SharedContentCoordinatorViewModel viewModel,
    SharedContentFilter filter,
  ) {
    switch (filter) {
      case SharedContentFilter.recipes:
        viewModel.recipeViewModel.loadMoreContent();
      case SharedContentFilter.menus:
        viewModel.menuViewModel.loadMoreContent();
      case SharedContentFilter.shoppingLists:
        viewModel.shoppingViewModel.loadMoreContent();
    }
  }

  static Widget build(
    BuildContext context,
    SharedContentCoordinatorViewModel viewModel,
    SharedContentFilter filter,
    List<Widget> rows,
  ) {
    return RefreshIndicator(
      onRefresh: viewModel.refreshAllContent,
      child: ListView(
        padding: ButleryPageBody.margin(context, bottom: AppDimensions.space32),
        children: [
          ButleryListSection(rows: rows),
          if (hasMore(viewModel, filter))
            _buildLoadMoreButton(
              context,
              isLoading: isLoadingMore(viewModel, filter),
              onPressed: () => loadMore(viewModel, filter),
            ),
        ],
      ),
    );
  }

  static Widget _buildLoadMoreButton(
    BuildContext context, {
    required bool isLoading,
    required VoidCallback onPressed,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppDimensions.space8),
      child: Center(
        // Loading the next page: the plate line with what is fetched.
        child: isLoading
            ? PlateLineMessage(message: context.l10n.loadingGeneric)
            : ActionButtons.primaryButton(
                context,
                label: context.l10n.commonShowMore,
                icon: ButleryIcons.chevronDown,
                onPressed: onPressed,
              ),
      ),
    );
  }
}
