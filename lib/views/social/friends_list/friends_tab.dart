// lib/views/social/friends_list/friends_tab.dart

import 'package:flutter/material.dart';
import '../../../viewmodels/friends_viewmodel.dart';
import '../../../models/user_profile.dart';
import '../../../widgets/common/loading_state_builder.dart';
import '../../../theme/app_dimensions.dart';
import 'friend_card.dart';

/// FriendsTab - Friends list tab component
///
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
      emptySubtitle: 'Lägg till vänner för att komma igång med social funktionalitet.',
      emptyIcon: Icons.people_outline,
      builder: (context, friends) => RefreshIndicator(
        onRefresh: () async {
          await viewModel.refresh();
        },
        child: ListView.separated(
          padding: EdgeInsets.all(AppDimensions.spacingL),
          itemCount: friends.length,
          separatorBuilder: (context, index) =>
              SizedBox(height: AppDimensions.spacingS),
          itemBuilder: (context, index) {
            final friend = friends[index];
            return FriendCard.build(context, friend);
          },
        ),
      ),
    );
  }
}