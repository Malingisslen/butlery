// lib/views/social/friends_list/search_result_card.dart

import 'package:flutter/material.dart';
import '../../../models/user_profile.dart';
import '../../../viewmodels/friends_viewmodel.dart';
import '../../../widgets/common/social_components.dart';
import '../../../theme/app_dimensions.dart';
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

    return Card(
      child: ListTile(
        leading: SocialComponents.avatar(
          size: ImageSize.small,
          imageUrl: viewModel.getAvatarUrlForUser(user.uid),
          displayName: viewModel.getDisplayNameForUser(user.uid),
        ),
        title: Text(
          user.displayName,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        subtitle: user.bio?.isNotEmpty == true
            ? Text(
                user.bio!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              )
            : null,
        trailing: _buildActionButton(
          context,
          user,
          viewModel,
          isFriend,
          hasPendingRequest,
        ),
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
          color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(AppDimensions.borderRadiusM),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.check_circle,
              color: Theme.of(context).colorScheme.primary,
              size: AppDimensions.iconSizeM,
            ),
            SizedBox(width: AppDimensions.spacingXs),
            Text(
              'Vänner',
              style: TextStyle(
                color: Theme.of(context).colorScheme.primary,
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
          color: Theme.of(context).colorScheme.tertiary.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(AppDimensions.borderRadiusM),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.schedule,
              color: Theme.of(context).colorScheme.tertiary,
              size: AppDimensions.iconSizeM,
            ),
            SizedBox(width: AppDimensions.spacingXs),
            Text(
              'Väntande',
              style: TextStyle(
                color: Theme.of(context).colorScheme.tertiary,
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
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation(
                  Theme.of(context).colorScheme.onPrimary,
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