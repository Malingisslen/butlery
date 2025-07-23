// lib/views/social/friends_list/friend_request_card.dart

import 'package:flutter/material.dart';
import '../../../models/friend_request.dart';
import '../../../viewmodels/friends_viewmodel.dart';
import '../../../widgets/common/content_card.dart';
import '../../../theme/app_dimensions.dart';
import '../../../theme/app_colors.dart';
import '../../../core/utils/snackbar_utils.dart';

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
      request: request,
      showFullDetails: true,
      trailing: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: AppDimensions.buttonWidth, // Fixed width for consistent button sizes
            child: FilledButton.icon(
              onPressed: viewModel.isLoading
                  ? null
                  : () => _acceptRequest(context, request, viewModel),
              icon: Icon(Icons.check, size: AppDimensions.iconSizeS),
              label: const Text('Acceptera'),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.accent,
                padding: EdgeInsets.symmetric(
                  horizontal: AppDimensions.spacingS,
                  vertical: AppDimensions.spacingXs,
                ),
              ),
            ),
          ),
          SizedBox(height: AppDimensions.spacingXs),
          SizedBox(
            width: AppDimensions.buttonWidth, // Match width for consistency
            child: OutlinedButton.icon(
              onPressed: viewModel.isLoading
                  ? null
                  : () => _rejectRequest(context, request, viewModel),
              icon: Icon(Icons.close, size: AppDimensions.iconSizeS),
              label: const Text('Avböj'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.error,
                side: BorderSide(color: AppColors.error),
                padding: EdgeInsets.symmetric(
                  horizontal: AppDimensions.spacingS,
                  vertical: AppDimensions.spacingXs,
                ),
              ),
            ),
          ),
        ],
      ),
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