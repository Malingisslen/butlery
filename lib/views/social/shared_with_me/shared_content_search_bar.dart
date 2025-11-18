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
        child: TextField(
          controller: searchController,
          decoration: InputDecoration(
            hintText: 'Sök i dina delade recept och menyer...',
            prefixIcon: const Icon(Icons.search),
            suffixIcon: viewModel.searchViewModel.hasSearchQuery
                ? IconButton(
                    onPressed: () {
                      searchController.clear();
                      viewModel.clearAllSearch();
                    },
                    icon: const Icon(Icons.clear),
                  )
                : null,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppDimensions.borderRadiusM),
            ),
          ),
          onChanged: viewModel.performUnifiedSearch,
        ),
      ),
    );
  }
}