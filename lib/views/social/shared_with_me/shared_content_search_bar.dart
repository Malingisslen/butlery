// lib/views/social/shared_with_me/shared_content_search_bar.dart

import 'package:flutter/material.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/viewmodels/shared_content/shared_content_coordinator_viewmodel.dart';
import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/widgets/common/icons/butlery_glyph.dart';
import 'package:butlery/widgets/common/icons/butlery_icons.dart';

/// SharedContentSearchBar - Search bar for shared content
/// Handles search functionality for shared recipes and menus.
class SharedContentSearchBar {
  static Widget build(
    BuildContext context,
    SharedContentCoordinatorViewModel viewModel,
    TextEditingController searchController,
  ) {
    if (!viewModel.hasAnyContent) {
      return const SliverToBoxAdapter(child: SizedBox.shrink());
    }

    return SliverToBoxAdapter(
      child: Padding(
        padding: AppDimensions.screenPadding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: searchController,
              decoration: InputDecoration(
                hintText: context.l10n.sharedSearchHint,
                prefixIcon: const ButleryIcon(ButleryIcons.search),
                suffixIcon: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Filter toggle for showing/hiding imported content
                    IconButton(
                      icon: ButleryIcon(
                        viewModel.showImported
                            ? ButleryIcons.filter
                            : ButleryIcons.filter,
                        color: viewModel.showImported
                            ? Theme.of(context).colorScheme.onSurface
                            : null,
                      ),
                      tooltip: viewModel.showImported
                          ? context.l10n.sharedHideImported
                          : context.l10n.sharedShowImported,
                      onPressed: () => viewModel.toggleShowImported(),
                    ),
                    // Clear search button
                    if (viewModel.searchViewModel.hasSearchQuery)
                      IconButton(
                        onPressed: () {
                          searchController.clear();
                          viewModel.clearAllSearch();
                        },
                        icon: const ButleryIcon(ButleryIcons.x),
                      ),
                  ],
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(
                    AppDimensions.radiusControl,
                  ),
                ),
              ),
              onChanged: viewModel.performUnifiedSearch,
            ),
            // Visual chip indicator when showing imported content
            if (viewModel.showImported)
              Padding(
                padding: const EdgeInsets.only(top: AppDimensions.space4),
                child: Chip(
                  label: Text(context.l10n.sharedShowingImported),
                  deleteIcon: const ButleryIcon(
                    ButleryIcons.x,
                    size: AppDimensions.iconSize18,
                  ),
                  onDeleted: () => viewModel.toggleShowImported(),
                  backgroundColor: Theme.of(
                    context,
                  ).colorScheme.primaryContainer,
                  labelStyle: TextStyle(
                    color: Theme.of(context).colorScheme.onPrimaryContainer,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
