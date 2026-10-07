// lib/widgets/social/friend_actions.dart

import 'package:flutter/material.dart';
import 'package:butlery/core/utils/snackbar_utils.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/models/user_profile.dart';
import 'package:butlery/viewmodels/friends_viewmodel.dart';
import 'package:butlery/core/extensions/localization_extension.dart';

/// The friend-request actions behind the search result card and the public
/// profile's friend button, so both surfaces send, accept and unblock the
/// same way and say the same thing about the outcome.
class FriendActions {
  /// Handles unblocking a user with confirmation dialog
  static Future<void> unblock(
    BuildContext context,
    UserProfile user,
    FriendsViewModel viewModel,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(context.l10n.blockedUsersUnblockTitle),
        content: Text(
          context.l10n.blockedUsersUnblockMessage(user.displayName),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(context.l10n.commonCancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.onSurface,
            ),
            child: Text(context.l10n.blockedUsersUnblock),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final success = await viewModel.unblockUser(user.uid);
      if (context.mounted) {
        if (success) {
          SnackBarUtils.showSuccess(
            context,
            context.l10n.socialUserUnblocked(user.displayName),
          );
        } else {
          SnackBarUtils.showFailure(
            context,
            what: context.l10n.socialCouldNotUnblockUser,
          );
        }
      }
    }
  }

  /// Handles sending friend request with proper feedback
  static Future<void> sendRequest(
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
          SnackBarUtils.showSuccess(
            context,
            context.l10n.socialFriendRequestSent(user.displayName),
          );
        } else {
          SnackBarUtils.showFailure(
            context,
            what:
                viewModel.error ?? context.l10n.socialCouldNotSendFriendRequest,
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        AppLogger.error('Failed to send friend request', e);
        SnackBarUtils.showFailure(
          context,
          what: context.l10n.socialCouldNotSendFriendRequest,
        );
      }
    }
  }

  /// Handles accepting friend request
  static Future<void> acceptRequest(
    BuildContext context,
    UserProfile user,
    FriendsViewModel viewModel,
  ) async {
    // Find the friend request from this user
    final incomingRequests = viewModel.incomingRequests;
    final request = incomingRequests
        .where((req) => req.fromUserId == user.uid)
        .firstOrNull;

    if (request == null) {
      if (context.mounted) {
        SnackBarUtils.showFailure(
          context,
          what: context.l10n.socialCouldNotFindFriendRequest,
        );
      }
      return;
    }

    try {
      final success = await viewModel.acceptFriendRequest(request.id);

      if (context.mounted) {
        if (success) {
          SnackBarUtils.showSuccess(
            context,
            context.l10n.socialFriendRequestAcceptedFrom(user.displayName),
          );
        } else {
          SnackBarUtils.showFailure(
            context,
            what:
                viewModel.error ??
                context.l10n.socialCouldNotAcceptFriendRequest,
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        AppLogger.error('Failed to accept friend request', e);
        SnackBarUtils.showFailure(
          context,
          what: context.l10n.socialCouldNotAcceptFriendRequest,
        );
      }
    }
  }
}
