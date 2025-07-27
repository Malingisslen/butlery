// lib/views/social/friends_list/friend_request_card.dart

import 'package:flutter/material.dart';
import 'package:butlery/models/friend_request.dart';
import 'package:butlery/viewmodels/friends_viewmodel.dart';
import 'package:butlery/widgets/common/content_card.dart';
import 'package:butlery/core/utils/snackbar_utils.dart';

/// FriendRequestCard - Friend request card component
///
/// Displays individual friend request with accept/reject actions.
class FriendRequestCard {
  static Widget build(
    BuildContext context,
    FriendRequest request,
    FriendsViewModel viewModel,
  ) {
    return ContentCard.friendRequest(
      friendRequest: request,
      onAccept: () => _acceptRequest(context, request, viewModel),
      onDecline: () => _rejectRequest(context, request, viewModel),
    );
  }

  static Future<void> _acceptRequest(
    BuildContext context,
    FriendRequest request,
    FriendsViewModel viewModel,
  ) async {
    final success = await viewModel.acceptFriendRequest(request.id);
    if (success && context.mounted) {
      SnackBarUtils.showSuccess(context, 'Vänskapsförfrågan accepterad! 🎉');
    }
  }

  static Future<void> _rejectRequest(
    BuildContext context,
    FriendRequest request,
    FriendsViewModel viewModel,
  ) async {
    final success = await viewModel.rejectFriendRequest(request.id);
    if (success && context.mounted) {
      SnackBarUtils.showWarning(context, 'Vänskapsförfrågan avböjd');
    }
  }
}