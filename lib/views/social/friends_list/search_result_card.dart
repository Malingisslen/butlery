// lib/views/social/friends_list/search_result_card.dart

import 'package:flutter/material.dart';
import 'package:butlery/models/user_profile.dart';
import 'package:butlery/viewmodels/friends_viewmodel.dart';
import 'package:butlery/widgets/common/content_card.dart';
import 'package:butlery/widgets/common/buttons/action_buttons.dart';
import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/widgets/common/icons/butlery_icons.dart';
import 'package:butlery/widgets/social/friend_actions.dart';

/// SearchResultCard - Enhanced search result card component with explicit action buttons
/// Displays search result user with clear friendship status and action buttons.
/// Provides visual clarity about available actions based on current relationship status.
class SearchResultCard {
  static Widget build(
    BuildContext context,
    UserProfile user,
    FriendsViewModel viewModel,
  ) {
    return RepaintBoundary(
      child: ContentCard.friend(
        user: user,
        onTap: null, // Remove generic onTap to prevent confusion
        trailing: _buildActionButton(context, user, viewModel),
      ),
    );
  }

  /// Builds action button based on current friendship status with user
  static Widget _buildActionButton(
    BuildContext context,
    UserProfile user,
    FriendsViewModel viewModel,
  ) {
    // Blocked wins over every other state, asked separately (BUT-2022).
    // `getFriendshipStatus` answers `friends` before it answers `blocked`,
    // so a block whose cleanup is still in flight would draw "Vänner" — and
    // offer the ordinary friend actions — for someone already blocked.
    if (viewModel.isBlocked(user.uid)) {
      return _buildBlockedButton(context, user, viewModel);
    }

    final friendshipStatus = viewModel.getFriendshipStatus(user.uid);

    switch (friendshipStatus) {
      case FriendshipStatus.none:
        return _buildSendRequestButton(context, user, viewModel);
      case FriendshipStatus.requestSent:
        return _buildRequestSentButton(context);
      case FriendshipStatus.friends:
        return _buildAlreadyFriendsButton(context);
      case FriendshipStatus.requestReceived:
        return _buildAcceptRequestButton(context, user, viewModel);
      case FriendshipStatus.blocked:
        return _buildBlockedButton(context, user, viewModel);
    }
  }

  /// Build primary action button to send friend request
  static Widget _buildSendRequestButton(
    BuildContext context,
    UserProfile user,
    FriendsViewModel viewModel,
  ) {
    return ActionButtons.primaryButton(
      context,
      label: context.l10n.socialSendFriendRequest,
      onPressed: () => FriendActions.sendRequest(context, user, viewModel),
    );
  }

  /// Build disabled button showing request already sent
  static Widget _buildRequestSentButton(BuildContext context) {
    return ActionButtons.outlinedButton(
      context,
      label: context.l10n.socialRequestSent,
      icon: ButleryIcons.clock,
      onPressed: null, // Disabled
    );
  }

  /// Build disabled button showing already friends status
  static Widget _buildAlreadyFriendsButton(BuildContext context) {
    return ActionButtons.outlinedButton(
      context,
      label: context.l10n.socialFriends,
      icon: ButleryIcons.circleCheck,
      onPressed: null, // Disabled
    );
  }

  /// Build accept button for incoming friend requests
  static Widget _buildAcceptRequestButton(
    BuildContext context,
    UserProfile user,
    FriendsViewModel viewModel,
  ) {
    return ActionButtons.primaryButton(
      context,
      label: context.l10n.commonAccept,
      onPressed: () => FriendActions.acceptRequest(context, user, viewModel),
    );
  }

  /// Build unblock button for blocked users
  static Widget _buildBlockedButton(
    BuildContext context,
    UserProfile user,
    FriendsViewModel viewModel,
  ) {
    return ActionButtons.outlinedButton(
      context,
      label: context.l10n.blockedUsersUnblock,
      icon: ButleryIcons.block,
      onPressed: () => FriendActions.unblock(context, user, viewModel),
    );
  }
}
