// lib/views/social/friends_list/requests_tab.dart

import 'package:flutter/material.dart';
import '../../../viewmodels/friends_viewmodel.dart';
import '../../../models/friend_request.dart';
import '../../../widgets/common/loading_state_builder.dart';
import '../../../theme/app_dimensions.dart';
import 'friend_request_card.dart';

/// RequestsTab - Friend requests tab component
///
/// Displays incoming friend requests with accept/reject actions.
class RequestsTab {
  static Widget build(
    BuildContext context,
    FriendsViewModel viewModel,
  ) {
    return LoadingStateBuilder<List<FriendRequest>>(
      isLoading: viewModel.isLoading,
      error: viewModel.error,
      data: viewModel.incomingRequests,
      loadingMessage: 'Laddar förfrågningar...',
      emptyTitle: 'Inga vänskapsförfrågningar',
      emptySubtitle: 'När någon skickar dig en vänskapsförfrågning visas den här.',
      emptyIcon: Icons.notifications_none,
      builder: (context, requests) => RefreshIndicator(
        onRefresh: () async {
          await viewModel.refresh();
        },
        child: ListView.separated(
          padding: EdgeInsets.all(AppDimensions.spacingL),
          itemCount: requests.length,
          separatorBuilder: (context, index) =>
              SizedBox(height: AppDimensions.spacingS),
          itemBuilder: (context, index) {
            final request = requests[index];
            return FriendRequestCard.build(context, request, viewModel);
          },
        ),
      ),
    );
  }
}