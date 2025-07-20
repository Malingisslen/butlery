// lib/views/social/friends_list/friend_request_card.dart

import 'package:flutter/material.dart';
import '../../../models/friend_request.dart';
import '../../../viewmodels/friends_viewmodel.dart';
import '../../../widgets/common/social_components.dart';
import '../../../theme/app_dimensions.dart';
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
    return Card(
      child: Padding(
        padding: EdgeInsets.all(AppDimensions.spacingL),
        child: Column(
          children: [
            Row(
              children: [
                SocialComponents.avatar(
                  size: ImageSize.small,
                  imageUrl: viewModel.getAvatarUrlForUser(request.fromUserId),
                  displayName: viewModel.getDisplayNameForUser(request.fromUserId),
                ),
                SizedBox(width: AppDimensions.spacingL),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Vänskapsförfrågan',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      if (request.message?.isNotEmpty == true)
                        Text(
                          request.message!,
                          style: Theme.of(context).textTheme.bodySmall,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      SizedBox(height: AppDimensions.spacingXs),
                      Text(
                        'Skickat ${request.timeAgoText}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            SizedBox(height: AppDimensions.spacingL),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: viewModel.isLoading
                        ? null
                        : () => _rejectRequest(context, request, viewModel),
                    icon: const Icon(Icons.close),
                    label: const Text('Avböj'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Theme.of(context).colorScheme.error,
                      side: BorderSide(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ),
                ),
                SizedBox(width: AppDimensions.spacingL),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: viewModel.isLoading
                        ? null
                        : () => _acceptRequest(context, request, viewModel),
                    icon: const Icon(Icons.check),
                    label: const Text('Acceptera'),
                    style: FilledButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
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