// lib/views/social/shared_with_me/shared_content_lists.dart

import 'package:flutter/material.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/viewmodels/shared_content/shared_content_coordinator_viewmodel.dart';
import 'package:butlery/widgets/common/state_widget.dart';
import 'package:butlery/views/social/shared_with_me/shared_recipe_card.dart';
import 'package:butlery/views/social/shared_with_me/shared_menu_card.dart';
import 'package:butlery/views/social/shared_with_me/shared_shopping_list_card.dart';

/// SharedContentLists - List builders for shared content
///
/// Handles building lists of shared recipes, menus, and shared shopping lists.
class SharedContentLists {
  /// Build recipes list
  static Widget buildRecipesList(
    BuildContext context,
    SharedContentCoordinatorViewModel viewModel,
    TextEditingController searchController,
  ) {
    final recipes = viewModel.recipeViewModel.filteredContent;

    if (recipes.isEmpty) {
      return StateWidget.empty(
        title: 'Inga recept',
        subtitle: 'Inga recept har delats med dig än.',
        icon: Icons.restaurant_outlined,
        actionLabel: 'Hitta vänner',
        onAction: () => Navigator.pushNamed(context, '/friends'),
      );
    }

    return RefreshIndicator(
      onRefresh: viewModel.refreshAllContent,
      child: ListView.separated(
        padding: AppDimensions.screenPadding,
        itemCount: recipes.length,
        separatorBuilder: (context, index) =>
            const SizedBox(height: AppDimensions.spacingS),
        itemBuilder: (context, index) {
          final sharedRecipe = recipes[index];
          return SharedRecipeCard.build(
            context,
            viewModel,
            sharedRecipe,
          );
        },
      ),
    );
  }

  /// Build menus list
  static Widget buildMenusList(
    BuildContext context,
    SharedContentCoordinatorViewModel viewModel,
    TextEditingController searchController,
  ) {
    final menus = viewModel.menuViewModel.filteredContent;

    if (menus.isEmpty) {
      return StateWidget.empty(
        title: 'Inga menyer',
        subtitle: 'Inga menyer har delats med dig än.',
        icon: Icons.calendar_month_outlined,
        actionLabel: 'Hitta vänner',
        onAction: () => Navigator.pushNamed(context, '/friends'),
      );
    }

    return RefreshIndicator(
      onRefresh: viewModel.refreshAllContent,
      child: ListView.separated(
        padding: AppDimensions.screenPadding,
        itemCount: menus.length,
        separatorBuilder: (context, index) =>
            const SizedBox(height: AppDimensions.spacingS),
        itemBuilder: (context, index) {
          final sharedMenu = menus[index];
          return SharedMenuCard.build(
            context,
            viewModel,
            sharedMenu,
          );
        },
      ),
    );
  }

  /// Build shared shopping lists list
  static Widget buildSharedShoppingListsList(
    BuildContext context,
    SharedContentCoordinatorViewModel viewModel,
    TextEditingController searchController,
  ) {
    final sharedShoppingLists = viewModel.shoppingViewModel.filteredContent;

    if (sharedShoppingLists.isEmpty) {
      return StateWidget.empty(
        title: 'Inga delade inköpslistor',
        subtitle: 'Inga inköpslistor har delats med dig än.',
        icon: Icons.shopping_cart_outlined,
        actionLabel: 'Hitta vänner',
        onAction: () => Navigator.pushNamed(context, '/friends'),
      );
    }

    return RefreshIndicator(
      onRefresh: viewModel.refreshAllContent,
      child: ListView.separated(
        padding: AppDimensions.screenPadding,
        itemCount: sharedShoppingLists.length,
        separatorBuilder: (context, index) =>
            const SizedBox(height: AppDimensions.spacingS),
        itemBuilder: (context, index) {
          final sharedShoppingList = sharedShoppingLists[index];
          return SharedShoppingListCard.build(
            context,
            viewModel,
            sharedShoppingList,
          );
        },
      ),
    );
  }
}