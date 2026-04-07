// lib/views/social/friends_list/search_result_card.dart

import 'package:flutter/material.dart';
import 'package:butlery/models/user_profile.dart';
import 'package:butlery/viewmodels/friends_viewmodel.dart';
import 'package:butlery/widgets/common/content_card.dart';
import 'package:butlery/theme/butlery_colors_extension.dart';
import 'package:butlery/widgets/common/buttons/action_buttons.dart';
import 'package:butlery/core/extensions/localization_extension.dart';

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
      onPressed: () => _handleSendFriendRequest(context, user, viewModel),
    );
  }

  /// Build disabled button showing request already sent
  static Widget _buildRequestSentButton(BuildContext context) {
    return ActionButtons.outlinedButton(
      context,
      label: context.l10n.socialRequestSent,
      icon: Icons.schedule,
      onPressed: null, // Disabled
    );
  }

  /// Build disabled button showing already friends status
  static Widget _buildAlreadyFriendsButton(BuildContext context) {
    return ActionButtons.outlinedButton(
      context,
      label: context.l10n.socialFriends,
      icon: Icons.check_circle,
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
      onPressed: () => _handleAcceptFriendRequest(context, user, viewModel),
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
      icon: Icons.block,
      onPressed: () => _handleUnblockUser(context, user, viewModel),
    );
  }

  /// Handles unblocking a user with confirmation dialog
  static Future<void> _handleUnblockUser(
    BuildContext context,
    UserProfile user,
    FriendsViewModel viewModel,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(context.l10n.blockedUsersUnblockTitle),
        content:
            Text(context.l10n.blockedUsersUnblockMessage(user.displayName)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(context.l10n.commonCancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.primary,
            ),
            child: Text(context.l10n.blockedUsersUnblock),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final success = await viewModel.unblockUser(user.uid);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(success
                ? context.l10n.socialUserUnblocked(user.displayName)
                : context.l10n.socialCouldNotUnblockUser),
            backgroundColor: success
                ? context.butleryColors.success
                : Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  /// Handles sending friend request with proper feedback
  static Future<void> _handleSendFriendRequest(
    BuildContext context,
    UserProfile user,
    FriendsViewModel viewModel,
  ) async {
    try {
      final success = await viewModel.sendFriendRequest(
        user.uid,
        message: context.l10n.socialDefaultFriendMessage,
      );

      if (context.mounted) {
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content:
                  Text(context.l10n.socialFriendRequestSent(user.displayName)),
              backgroundColor: context.butleryColors.success,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(viewModel.error ??
                  context.l10n.socialCouldNotSendFriendRequest),
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.l10n.errorOccurredWithDetails('$e')),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  /// Handles accepting friend request
  static Future<void> _handleAcceptFriendRequest(
    BuildContext context,
    UserProfile user,
    FriendsViewModel viewModel,
  ) async {
    // Find the friend request from this user
    final incomingRequests = viewModel.incomingRequests;
    final request =
        incomingRequests.where((req) => req.fromUserId == user.uid).firstOrNull;

    if (request == null) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.l10n.socialCouldNotFindFriendRequest),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
      return;
    }

    try {
      final success = await viewModel.acceptFriendRequest(request.id);

      if (context.mounted) {
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(context.l10n
                  .socialFriendRequestAcceptedFrom(user.displayName)),
              backgroundColor: context.butleryColors.success,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(viewModel.error ??
                  context.l10n.socialCouldNotAcceptFriendRequest),
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.l10n.errorOccurredWithDetails('$e')),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }
}
