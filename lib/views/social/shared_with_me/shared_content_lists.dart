// lib/views/social/shared_with_me/shared_content_lists.dart

import 'package:flutter/material.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/viewmodels/shared_content/shared_content_coordinator_viewmodel.dart';
import 'package:butlery/widgets/common/state_widget.dart';
import 'package:butlery/views/social/shared_with_me/shared_recipe_card.dart';
import 'package:butlery/views/social/shared_with_me/shared_menu_card.dart';
import 'package:butlery/views/social/shared_with_me/shared_shopping_list_card.dart';
import 'package:butlery/core/extensions/localization_extension.dart';

/// SharedContentLists - List builders for shared content
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
        title: context.l10n.sharedNoRecipes,
        subtitle: context.l10n.sharedNoRecipesDescription,
        icon: Icons.restaurant_outlined,
        actionLabel: context.l10n.socialFindFriends,
        onAction: () => Navigator.pushNamed(context, '/friends'),
      );
    }

    // Calculate item count: recipes + load more button (if applicable)
    final hasMoreContent = viewModel.recipeViewModel.hasMoreContent;
    final itemCount = recipes.length + (hasMoreContent ? 1 : 0);

    return RefreshIndicator(
      onRefresh: viewModel.refreshAllContent,
      child: ListView.separated(
        padding: AppDimensions.screenPadding,
        itemCount: itemCount,
        separatorBuilder: (context, index) =>
            const SizedBox(height: AppDimensions.spacingS),
        itemBuilder: (context, index) {
          // Load more button at the end
          if (index == recipes.length) {
            return _buildLoadMoreButton(
              context,
              isLoading: viewModel.recipeViewModel.isLoadingMore,
              onPressed: () => viewModel.recipeViewModel.loadMoreContent(),
            );
          }

          final sharedRecipe = recipes[index];
          return KeyedSubtree(
            key: ValueKey(sharedRecipe.id),
            child: SharedRecipeCard.build(
              context,
              viewModel,
              sharedRecipe,
            ),
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
        title: context.l10n.sharedNoMenus,
        subtitle: context.l10n.sharedNoMenusDescription,
        icon: Icons.calendar_month_outlined,
        actionLabel: context.l10n.socialFindFriends,
        onAction: () => Navigator.pushNamed(context, '/friends'),
      );
    }

    // Calculate item count: menus + load more button (if applicable)
    final hasMoreContent = viewModel.menuViewModel.hasMoreContent;
    final itemCount = menus.length + (hasMoreContent ? 1 : 0);

    return RefreshIndicator(
      onRefresh: viewModel.refreshAllContent,
      child: ListView.separated(
        padding: AppDimensions.screenPadding,
        itemCount: itemCount,
        separatorBuilder: (context, index) =>
            const SizedBox(height: AppDimensions.spacingS),
        itemBuilder: (context, index) {
          // Load more button at the end
          if (index == menus.length) {
            return _buildLoadMoreButton(
              context,
              isLoading: viewModel.menuViewModel.isLoadingMore,
              onPressed: () => viewModel.menuViewModel.loadMoreContent(),
            );
          }

          final sharedMenu = menus[index];
          return KeyedSubtree(
            key: ValueKey(sharedMenu.id),
            child: SharedMenuCard.build(
              context,
              viewModel,
              sharedMenu,
            ),
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
        title: context.l10n.sharedNoShoppingLists,
        subtitle: context.l10n.sharedNoShoppingListsDescription,
        icon: Icons.shopping_cart_outlined,
        actionLabel: context.l10n.socialFindFriends,
        onAction: () => Navigator.pushNamed(context, '/friends'),
      );
    }

    // Calculate item count: shopping lists + load more button (if applicable)
    final hasMoreContent = viewModel.shoppingViewModel.hasMoreContent;
    final itemCount = sharedShoppingLists.length + (hasMoreContent ? 1 : 0);

    return RefreshIndicator(
      onRefresh: viewModel.refreshAllContent,
      child: ListView.separated(
        padding: AppDimensions.screenPadding,
        itemCount: itemCount,
        separatorBuilder: (context, index) =>
            const SizedBox(height: AppDimensions.spacingS),
        itemBuilder: (context, index) {
          // Load more button at the end
          if (index == sharedShoppingLists.length) {
            return _buildLoadMoreButton(
              context,
              isLoading: viewModel.shoppingViewModel.isLoadingMore,
              onPressed: () => viewModel.shoppingViewModel.loadMoreContent(),
            );
          }

          final sharedShoppingList = sharedShoppingLists[index];
          return KeyedSubtree(
            key: ValueKey(sharedShoppingList.id),
            child: SharedShoppingListCard.build(
              context,
              viewModel,
              sharedShoppingList,
            ),
          );
        },
      ),
    );
  }

  /// Build load more button
  static Widget _buildLoadMoreButton(
    BuildContext context, {
    required bool isLoading,
    required VoidCallback onPressed,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppDimensions.spacingM),
      child: Center(
        child: isLoading
            ? const CircularProgressIndicator()
            : ElevatedButton.icon(
                onPressed: onPressed,
                icon: const Icon(Icons.expand_more),
                label: Text(context.l10n.commonShowMore),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppDimensions.spacingL,
                    vertical: AppDimensions.spacingM,
                  ),
                ),
              ),
      ),
    );
  }
}
