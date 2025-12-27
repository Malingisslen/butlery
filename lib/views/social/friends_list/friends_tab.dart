// lib/views/social/friends_list/friends_tab.dart

import 'package:flutter/material.dart';
import 'package:butlery/viewmodels/friends_viewmodel.dart';
import 'package:butlery/models/user_profile.dart';
import 'package:butlery/widgets/common/loading_state_builder.dart';
import 'package:butlery/widgets/common/animations/animated_list_item.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/views/social/friends_list/friends_list_cards.dart';

/// FriendsTab - Friends list tab component
/// Displays the user's friends list with search and actions.
class FriendsTab {
  static Widget build(
    BuildContext context,
    FriendsViewModel viewModel,
  ) {
    return LoadingStateBuilder<List<UserProfile>>(
      isLoading: viewModel.isLoading,
      error: viewModel.error,
      data: viewModel.friends,
      loadingMessage: 'Laddar vänner...',
      emptyTitle: 'Inga vänner än',
      emptySubtitle:
          'Lägg till vänner för att komma igång med social funktionalitet.',
      emptyIcon: Icons.people_outline,
      builder: (context, friends) => RefreshIndicator(
        onRefresh: () async {
          await viewModel.refresh();
        },
        child: ListView.separated(
          padding: const EdgeInsets.all(AppDimensions.spacingL),
          itemCount: friends.length,
          separatorBuilder: (context, index) =>
              const SizedBox(height: AppDimensions.spacingS),
          itemBuilder: (context, index) {
            final friend = friends[index];
            return AnimatedListItem(
              index: index,
              child: FriendCard.build(context, friend),
            );
          },
        ),
      ),
    );
  }
}
