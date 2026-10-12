// lib/views/social/shared_with_me/shared_content_tabs.dart

import 'package:flutter/material.dart';
import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/viewmodels/shared_content/shared_content_coordinator_viewmodel.dart';
import 'package:butlery/widgets/common/navigation/underline_tabs.dart';

enum SharedContentFilter { recipes, menus, shoppingLists }

/// "Recept · 4 / Menyer · 1 / Listor · 2": the kinds of shared content, each
/// with how many of it there are under the current search.
class SharedContentTabs extends StatelessWidget {
  const SharedContentTabs({
    required this.viewModel,
    required this.selected,
    required this.onSelected,
    super.key,
  });

  final SharedContentCoordinatorViewModel viewModel;
  final SharedContentFilter selected;
  final ValueChanged<SharedContentFilter> onSelected;

  int _count(SharedContentFilter filter) => switch (filter) {
    SharedContentFilter.recipes =>
      viewModel.recipeViewModel.filteredContent.length,
    SharedContentFilter.menus => viewModel.menuViewModel.filteredContent.length,
    SharedContentFilter.shoppingLists =>
      viewModel.shoppingViewModel.filteredContent.length,
  };

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return UnderlineTabs<SharedContentFilter>(
      values: SharedContentFilter.values,
      selected: selected,
      onChanged: onSelected,
      labelOf: (filter) => switch (filter) {
        SharedContentFilter.recipes => l10n.sharedTabRecipes(_count(filter)),
        SharedContentFilter.menus => l10n.sharedTabMenus(_count(filter)),
        SharedContentFilter.shoppingLists => l10n.sharedTabShoppingLists(
          _count(filter),
        ),
      },
    );
  }
}
