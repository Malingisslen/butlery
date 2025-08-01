// lib/views/social/friends_list/search_tab.dart

import 'package:flutter/material.dart';
import 'package:butlery/viewmodels/friends_viewmodel.dart';
import 'package:butlery/widgets/common/state_widget.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/views/social/friends_list/search_result_card.dart';

/// SearchTab - Friend search tab component
///
/// Displays search results for finding new friends.
class SearchTab {
  static Widget build(
    BuildContext context,
    FriendsViewModel viewModel,
    String searchQuery, {
    bool isGroupsSearch = false,
  }) {
    if (searchQuery.isEmpty) {
      return StateWidget.empty(
        title: 'Sök efter nya vänner',
        subtitle: 'Skriv ett namn eller användarnamn i sökfältet ovan för att hitta nya vänner.',
        icon: Icons.search,
      );
    }

    if (viewModel.isSearching) {
      return StateWidget.loading(message: 'Söker användare...');
    }

    if (viewModel.searchResults.isEmpty) {
      return isGroupsSearch 
          ? StateWidget.noGroupsSearchResults()
          : StateWidget.noFriendsSearchResults();
    }

    return ListView.separated(
      padding: const EdgeInsets.all(AppDimensions.spacingL),
      itemCount: viewModel.searchResults.length,
      separatorBuilder: (context, index) =>
          const SizedBox(height: AppDimensions.spacingS),
      itemBuilder: (context, index) {
        final user = viewModel.searchResults[index];
        return SearchResultCard.build(context, user, viewModel);
      },
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