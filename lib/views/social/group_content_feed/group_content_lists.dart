// lib/views/social/group_content_feed/group_content_lists.dart

import 'package:flutter/material.dart';
import 'package:butlery/viewmodels/group_content_viewmodel.dart';
import 'package:butlery/viewmodels/shared_content_viewmodel.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/widgets/common/state_widget.dart';
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/widgets/common/universal_share_dialog.dart';
import 'package:butlery/viewmodels/universal_share_dialog_viewmodel.dart';
import 'package:butlery/services/unified/unified_shopping_service.dart';
import 'package:butlery/services/social_recipe_service.dart';

// Import existing shared content cards
import 'package:butlery/views/social/shared_with_me/shared_recipe_card.dart';
import 'package:butlery/views/social/shared_with_me/shared_menu_card.dart';
import 'package:butlery/widgets/social/group_shared_shopping_list_card.dart';

/// Group Content Lists - List builders for group shared content
/// 
/// Handles building lists of recipes, menus, and shopping lists
/// shared specifically to a group.
class GroupContentLists {
  /// Build group recipes list
  static Widget buildRecipesList(
    BuildContext context,
    GroupContentViewModel viewModel,
    TextEditingController searchController,
  ) {
    final recipes = viewModel.filteredGroupRecipes;

    if (recipes.isEmpty) {
      return _buildEmptyState(
        context,
        'Inga recept i gruppen',
        'Inga recept har delats till denna grupp än.',
        Icons.restaurant_outlined,
        'Dela recept',
        () => _showShareRecipeDialog(context, viewModel),
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
          return Card(
            child: SharedRecipeCard.build(
              context,
              ServiceLocator.get<SharedContentViewModel>(),
              sharedRecipe,
            ),
          );
        },
      ),
    );
  }

  /// Build group menus list
  static Widget buildMenusList(
    BuildContext context,
    GroupContentViewModel viewModel,
    TextEditingController searchController,
  ) {
    final menus = viewModel.filteredGroupMenus;

    if (menus.isEmpty) {
      return _buildEmptyState(
        context,
        'Inga menyer i gruppen',
        'Inga menyer har delats till denna grupp än.',
        Icons.calendar_month_outlined,
        'Dela meny',
        () => _showShareMenuDialog(context, viewModel),
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
          return Card(
            child: SharedMenuCard.build(
              context,
              ServiceLocator.get<SharedContentViewModel>(),
              sharedMenu,
            ),
          );
        },
      ),
    );
  }

  /// Build group shopping lists list
  static Widget buildShoppingListsList(
    BuildContext context,
    GroupContentViewModel viewModel,
    TextEditingController searchController,
  ) {
    final shoppingLists = viewModel.filteredGroupShoppingLists;

    if (shoppingLists.isEmpty) {
      return _buildEmptyState(
        context,
        'Inga inköpslistor i gruppen',
        'Inga inköpslistor har delats till denna grupp än.',
        Icons.shopping_cart_outlined,
        'Dela inköpslista',
        () => _showShareShoppingListDialog(context, viewModel),
      );
    }

    return RefreshIndicator(
      onRefresh: viewModel.refresh,
      child: ListView.separated(
        padding: AppDimensions.screenPadding,
        itemCount: shoppingLists.length,
        separatorBuilder: (context, index) =>
            const SizedBox(height: AppDimensions.spacingS),
        itemBuilder: (context, index) {
          final shoppingList = shoppingLists[index];
          return Card(
            child: GroupSharedShoppingListCard.build(
              context,
              viewModel,
              shoppingList,
            ),
          );
        },
      ),
    );
  }

  /// Build empty state widget
  static Widget _buildEmptyState(
    BuildContext context,
    String title,
    String subtitle,
    IconData icon,
    String actionLabel,
    VoidCallback onAction,
  ) {
    return StateWidget.empty(
      title: title,
      subtitle: subtitle,
      icon: icon,
      actionLabel: actionLabel,
      onAction: onAction,
    );
  }

  /// Show share recipe dialog
  static Future<void> _showShareRecipeDialog(
    BuildContext context,
    GroupContentViewModel viewModel,
  ) async {
    final sharedRecipe = viewModel.filteredGroupRecipes.first;
    final shareViewModel = UniversalShareDialogViewModel(
      socialRecipeService: ServiceLocator.get<SocialRecipeService>(),
      shoppingService: ServiceLocator.get<UnifiedShoppingService>(),
    );
    
    await showDialog(
      context: context,
      builder: (context) => UniversalShareDialog(
        content: sharedRecipe,
        contentType: ShareContentType.recipe,
        viewModel: shareViewModel,
        availableGroups: const [], // Groups would be loaded from friends service
        initialMessage: 'Dela detta recept med gruppen',
      ),
    );
  }

  /// Show share menu dialog
  static Future<void> _showShareMenuDialog(
    BuildContext context,
    GroupContentViewModel viewModel,
  ) async {
    final sharedMenu = viewModel.filteredGroupMenus.first;
    final shareViewModel = UniversalShareDialogViewModel(
      socialRecipeService: ServiceLocator.get<SocialRecipeService>(),
      shoppingService: ServiceLocator.get<UnifiedShoppingService>(),
    );
    
    await showDialog(
      context: context,
      builder: (context) => UniversalShareDialog(
        content: sharedMenu,
        contentType: ShareContentType.menu,
        viewModel: shareViewModel,
        availableGroups: const [], // Groups would be loaded from friends service
        initialMessage: 'Dela denna meny med gruppen',
      ),
    );
  }

  /// Show share shopping list dialog
  static Future<void> _showShareShoppingListDialog(
    BuildContext context,
    GroupContentViewModel viewModel,
  ) async {
    final sharedList = viewModel.filteredGroupShoppingLists.first;
    final shareViewModel = UniversalShareDialogViewModel(
      socialRecipeService: ServiceLocator.get<SocialRecipeService>(),
      shoppingService: ServiceLocator.get<UnifiedShoppingService>(),
    );
    
    await showDialog(
      context: context,
      builder: (context) => UniversalShareDialog(
        content: sharedList,
        contentType: ShareContentType.shoppingList,
        viewModel: shareViewModel,
        availableGroups: const [], // Groups would be loaded from friends service
        initialMessage: 'Dela denna inköpslista med gruppen',
      ),
    );
  }
}