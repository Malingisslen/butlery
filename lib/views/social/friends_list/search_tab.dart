// lib/views/social/friends_list/search_tab.dart

import 'package:flutter/material.dart';
import 'package:butlery/viewmodels/friends_viewmodel.dart';
import 'package:butlery/widgets/common/state_widget.dart';
import 'package:butlery/widgets/common/animations/animated_list_item.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/views/social/friends_list/search_result_card.dart';
import 'package:butlery/core/extensions/localization_extension.dart';

/// SearchTab - Friend search tab component
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
        title: context.l10n.socialSearchForNewFriends,
        subtitle: context.l10n.socialSearchForNewFriendsDescription,
        icon: Icons.search,
      );
    }

    if (viewModel.isSearching) {
      return StateWidget.loading(message: context.l10n.socialSearchingUsers);
    }

    if (viewModel.searchResults.isEmpty) {
      // BUT-1442: distinguish a backend outage from a legitimately-empty
      // search — show "search unavailable", not "no users found".
      if (viewModel.searchDegraded && !isGroupsSearch) {
        return StateWidget.error(
          message:
              viewModel.searchError ?? context.l10n.socialSearchUnavailable,
        );
      }
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
        return AnimatedListItem(
          key: ValueKey(user.uid),
          index: index,
          child: SearchResultCard.build(context, user, viewModel),
        );
      },
    );
  }
}
