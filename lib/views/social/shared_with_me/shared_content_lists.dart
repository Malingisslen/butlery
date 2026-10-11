// lib/views/social/shared_with_me/shared_content_lists.dart

import 'package:flutter/material.dart';
import 'package:butlery/models/shared_menu.dart';
import 'package:butlery/models/shared_recipe.dart';
import 'package:butlery/models/shared_shopping_list.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/viewmodels/shared_content/shared_content_coordinator_viewmodel.dart';
import 'package:butlery/views/social/shared_with_me/shared_content_filter_chips.dart';
import 'package:butlery/views/social/shared_with_me/shared_menu_card.dart';
import 'package:butlery/views/social/shared_with_me/shared_recipe_card.dart';
import 'package:butlery/views/social/shared_with_me/shared_shopping_list_card.dart';
import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/widgets/common/icons/butlery_glyph.dart';
import 'package:butlery/widgets/common/icons/butlery_icons.dart';
import 'package:butlery/widgets/common/indicators/plate_line.dart';

/// One shared item of any kind, ordered by when it was shared.
class SharedContentEntry {
  const SharedContentEntry(this.id, this.sharedAt, this.card);

  final String id;
  final DateTime sharedAt;
  final Widget Function(
    BuildContext context,
    SharedContentCoordinatorViewModel viewModel,
  )
  card;
}

/// Builds the list for the selected filter chip. "Allt" mixes the three card
/// kinds newest first; the other chips show one kind.
class SharedContentLists {
  static List<SharedContentEntry> entriesFor(
    SharedContentCoordinatorViewModel viewModel,
    SharedContentFilter filter,
  ) {
    final all = filter == SharedContentFilter.all;
    final entries = <SharedContentEntry>[
      if (all || filter == SharedContentFilter.recipes)
        for (final SharedRecipe r in viewModel.recipeViewModel.filteredContent)
          SharedContentEntry(
            'recipe_${r.id}',
            r.sharedAt,
            (context, vm) => SharedRecipeCard.build(context, vm, r),
          ),
      if (all || filter == SharedContentFilter.menus)
        for (final SharedMenu m in viewModel.menuViewModel.filteredContent)
          SharedContentEntry(
            'menu_${m.id}',
            m.sharedAt,
            (context, vm) => SharedMenuCard.build(context, vm, m),
          ),
      if (all || filter == SharedContentFilter.shoppingLists)
        for (final SharedShoppingList s
            in viewModel.shoppingViewModel.filteredContent)
          SharedContentEntry(
            'list_${s.id}',
            s.sharedAt,
            (context, vm) => SharedShoppingListCard.build(context, vm, s),
          ),
    ];
    if (all) {
      entries.sort((a, b) => b.sharedAt.compareTo(a.sharedAt));
    }
    return entries;
  }

  static bool hasMore(
    SharedContentCoordinatorViewModel viewModel,
    SharedContentFilter filter,
  ) {
    final all = filter == SharedContentFilter.all;
    return (all || filter == SharedContentFilter.recipes) &&
            viewModel.recipeViewModel.hasMoreContent ||
        (all || filter == SharedContentFilter.menus) &&
            viewModel.menuViewModel.hasMoreContent ||
        (all || filter == SharedContentFilter.shoppingLists) &&
            viewModel.shoppingViewModel.hasMoreContent;
  }

  static bool isLoadingMore(
    SharedContentCoordinatorViewModel viewModel,
    SharedContentFilter filter,
  ) {
    final all = filter == SharedContentFilter.all;
    return (all || filter == SharedContentFilter.recipes) &&
            viewModel.recipeViewModel.isLoadingMore ||
        (all || filter == SharedContentFilter.menus) &&
            viewModel.menuViewModel.isLoadingMore ||
        (all || filter == SharedContentFilter.shoppingLists) &&
            viewModel.shoppingViewModel.isLoadingMore;
  }

  static void loadMore(
    SharedContentCoordinatorViewModel viewModel,
    SharedContentFilter filter,
  ) {
    final all = filter == SharedContentFilter.all;
    if ((all || filter == SharedContentFilter.recipes) &&
        viewModel.recipeViewModel.hasMoreContent) {
      viewModel.recipeViewModel.loadMoreContent();
    }
    if ((all || filter == SharedContentFilter.menus) &&
        viewModel.menuViewModel.hasMoreContent) {
      viewModel.menuViewModel.loadMoreContent();
    }
    if ((all || filter == SharedContentFilter.shoppingLists) &&
        viewModel.shoppingViewModel.hasMoreContent) {
      viewModel.shoppingViewModel.loadMoreContent();
    }
  }

  static Widget build(
    BuildContext context,
    SharedContentCoordinatorViewModel viewModel,
    SharedContentFilter filter,
    List<SharedContentEntry> entries,
  ) {
    final showMore = hasMore(viewModel, filter);
    final itemCount = entries.length + (showMore ? 1 : 0);

    return RefreshIndicator(
      onRefresh: viewModel.refreshAllContent,
      child: ListView.separated(
        padding: AppDimensions.screenPadding,
        itemCount: itemCount,
        separatorBuilder: (context, index) =>
            const SizedBox(height: AppDimensions.space4),
        itemBuilder: (context, index) {
          if (index == entries.length) {
            return _buildLoadMoreButton(
              context,
              isLoading: isLoadingMore(viewModel, filter),
              onPressed: () => loadMore(viewModel, filter),
            );
          }
          final entry = entries[index];
          return KeyedSubtree(
            key: ValueKey(entry.id),
            child: entry.card(context, viewModel),
          );
        },
      ),
    );
  }

  static Widget _buildLoadMoreButton(
    BuildContext context, {
    required bool isLoading,
    required VoidCallback onPressed,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppDimensions.spacingM),
      child: Center(
        // Loading the next page: the plate line with what is fetched.
        child: isLoading
            ? PlateLineMessage(message: context.l10n.loadingGeneric)
            : ElevatedButton.icon(
                onPressed: onPressed,
                icon: const ButleryIcon(ButleryIcons.chevronDown),
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
