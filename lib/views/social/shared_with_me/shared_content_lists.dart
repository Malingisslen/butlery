// lib/views/social/shared_with_me/shared_content_lists.dart

import 'package:flutter/material.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/viewmodels/shared_content_viewmodel.dart';
import 'package:butlery/widgets/common/state_widget.dart';
import 'package:butlery/views/social/shared_with_me/shared_recipe_card.dart';
import 'package:butlery/views/social/shared_with_me/shared_menu_card.dart';

/// SharedContentLists - List builders for shared content
///
/// Handles building lists of shared recipes and menus.
class SharedContentLists {
  /// Build recipes list
  static Widget buildRecipesList(
    BuildContext context,
    SharedContentViewModel viewModel,
    TextEditingController searchController,
  ) {
    final recipes = viewModel.filteredSharedRecipes;

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
      onRefresh: viewModel.refresh,
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
    SharedContentViewModel viewModel,
    TextEditingController searchController,
  ) {
    final menus = viewModel.filteredSharedMenus;

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
      onRefresh: viewModel.refresh,
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
  @override
  void dispose() {
    // Cancel all timers
    // Cancel all stream subscriptions  
    // Dispose of resources
    disposeStreams(); // From StreamManagementMixin
    super.dispose();
  }
}