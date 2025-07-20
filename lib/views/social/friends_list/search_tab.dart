// lib/views/social/friends_list/search_tab.dart

import 'package:flutter/material.dart';
import '../../../viewmodels/friends_viewmodel.dart';
import '../../../widgets/common/state_widget.dart';
import '../../../theme/app_dimensions.dart';
import 'search_result_card.dart';

/// SearchTab - Friend search tab component
///
/// Displays search results for finding new friends.
class SearchTab {
  static Widget build(
    BuildContext context,
    FriendsViewModel viewModel,
    String searchQuery,
  ) {
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
      return StateWidget.noSearchResults();
    }

    return ListView.separated(
      padding: EdgeInsets.all(AppDimensions.spacingL),
      itemCount: viewModel.searchResults.length,
      separatorBuilder: (context, index) =>
          SizedBox(height: AppDimensions.spacingS),
      itemBuilder: (context, index) {
        final user = viewModel.searchResults[index];
        return SearchResultCard.build(context, user, viewModel);
      },
    );
  }
}