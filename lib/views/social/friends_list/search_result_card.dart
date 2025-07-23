// lib/views/social/friends_list/search_result_card.dart

import 'package:flutter/material.dart';
import '../../../models/user_profile.dart';
import '../../../viewmodels/friends_viewmodel.dart';
import '../../../widgets/common/content_card.dart';
import '../../../theme/app_dimensions.dart';
import '../../../theme/app_colors.dart';
import '../../../core/utils/snackbar_utils.dart';

/// SearchResultCard - Search result card component
///
/// Displays search result user with add friend functionality.
class SearchResultCard {
  static Widget build(
    BuildContext context,
    UserProfile user,
    FriendsViewModel viewModel,
  ) {
    final isFriend = viewModel.friends.any((friend) => friend.uid == user.uid);
    final hasPendingRequest = viewModel.sentRequests.any((req) => req.toUserId == user.uid);

    return ContentCard.friend(
      friend: user,
      showFullDetails: true,
      trailing: _buildActionButton(
        context,
        user,
        viewModel,
        isFriend,
        hasPendingRequest,
      ),
    );
  }

  static Widget _buildActionButton(
    BuildContext context,
    UserProfile user,
    FriendsViewModel viewModel,
    bool isFriend,
    bool hasPendingRequest,
  ) {
    if (isFriend) {
      return Container(
        padding: EdgeInsets.symmetric(
          horizontal: AppDimensions.spacingS,
          vertical: AppDimensions.spacingXs,
        ),
        decoration: BoxDecoration(
          color: AppColors.accent.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(AppDimensions.borderRadiusM),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.check_circle,
              color: AppColors.accent,
              size: AppDimensions.iconSizeM,
            ),
            SizedBox(width: AppDimensions.spacingXs),
            Text(
              'Vänner',
              style: TextStyle(
                color: AppColors.accent,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      );
    }

    if (hasPendingRequest) {
      return Container(
        padding: EdgeInsets.symmetric(
          horizontal: AppDimensions.spacingS,
          vertical: AppDimensions.spacingXs,
        ),
        decoration: BoxDecoration(
          color: AppColors.warning.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(AppDimensions.borderRadiusM),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.schedule,
              color: AppColors.warning,
              size: AppDimensions.iconSizeM,
            ),
            SizedBox(width: AppDimensions.spacingXs),
            Text(
              'Väntande',
              style: TextStyle(
                color: AppColors.warning,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      );
    }

    return FilledButton.icon(
      onPressed: viewModel.isLoading
          ? null
          : () => _sendFriendRequest(context, user, viewModel),
      icon: viewModel.isLoading
          ? SizedBox(
              width: AppDimensions.iconSizeS,
              height: AppDimensions.iconSizeS,
              child: CircularProgressIndicator(
                strokeWidth: AppDimensions.borderWidthThick,
                valueColor: AlwaysStoppedAnimation(
                  AppColors.cardWhite,
                ),
              ),
            )
          : const Icon(Icons.person_add),
      label: const Text('Lägg till'),
    );
  }

  static Future<void> _sendFriendRequest(
    BuildContext context,
    UserProfile user,
    FriendsViewModel viewModel,
  ) async {
    final success = await viewModel.sendFriendRequest(user.uid);
    if (success && context.mounted) {
      SnackBarUtils.showSuccess(
        context,
        'Vänskapsförfrågan skickad till ${user.displayName}! ✉️',
      );
    }
  }
}