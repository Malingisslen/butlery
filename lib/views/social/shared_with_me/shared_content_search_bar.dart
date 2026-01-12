// lib/views/social/shared_with_me/shared_content_search_bar.dart

import 'package:flutter/material.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/viewmodels/shared_content/shared_content_coordinator_viewmodel.dart';

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
                hintText: 'Sök i dina delade recept och menyer...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Filter toggle for showing/hiding imported content
                    IconButton(
                      icon: Icon(
                        viewModel.showImported
                            ? Icons.filter_alt
                            : Icons.filter_alt_outlined,
                        color: viewModel.showImported
                            ? Theme.of(context).colorScheme.primary
                            : null,
                      ),
                      tooltip: viewModel.showImported
                          ? 'Dölj importerade'
                          : 'Visa importerade',
                      onPressed: () => viewModel.toggleShowImported(),
                    ),
                    // Clear search button
                    if (viewModel.searchViewModel.hasSearchQuery)
                      IconButton(
                        onPressed: () {
                          searchController.clear();
                          viewModel.clearAllSearch();
                        },
                        icon: const Icon(Icons.clear),
                      ),
                  ],
                ),
                border: OutlineInputBorder(
                  borderRadius:
                      BorderRadius.circular(AppDimensions.borderRadiusM),
                ),
              ),
              onChanged: viewModel.performUnifiedSearch,
            ),
            // Visual chip indicator when showing imported content
            if (viewModel.showImported)
              Padding(
                padding: const EdgeInsets.only(top: AppDimensions.spacingS),
                child: Chip(
                  label: const Text('Visar importerade'),
                  deleteIcon: const Icon(Icons.close, size: AppDimensions.iconSize18),
                  onDeleted: () => viewModel.toggleShowImported(),
                  backgroundColor:
                      Theme.of(context).colorScheme.primaryContainer,
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
