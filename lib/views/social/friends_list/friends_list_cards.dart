// lib/views/social/friends_list/friends_list_cards.dart

import 'package:flutter/material.dart';
import 'package:butlery/models/user_profile.dart';
import 'package:butlery/models/friend_request.dart';
import 'package:butlery/models/friend_category.dart';
import 'package:butlery/viewmodels/friends_viewmodel.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/widgets/common/social_components.dart';
import 'package:butlery/widgets/common/content_card.dart';
import 'package:butlery/core/constants/routes.dart';
import 'package:butlery/core/utils/snackbar_utils.dart';
import 'package:butlery/views/social/group_detail_view.dart';
import 'package:butlery/core/extensions/localization_extension.dart';

/// Consolidated friends list card components
/// This file contains card components for the friends list view:
/// - FriendCard: Individual friend card with profile navigation
/// - FriendRequestCard: Friend request card with accept/reject actions
/// - GroupCard: Group card with navigation to group detail
/// **Consolidation**: Merged from 3 separate files (~151 LOC) for better maintainability

/// Individual friend card with profile and remove actions.
class FriendCard {
  static Widget build(
    BuildContext context,
    UserProfile friend,
  ) {
    return Card(
      margin: const EdgeInsets.symmetric(
        horizontal: AppDimensions.spacingL,
        vertical: AppDimensions.spacingXs,
      ),
      child: ListTile(
        onTap: () => Navigator.pushNamed(
          context,
          Routes.friendProfile,
          arguments: friend,
        ),
        leading: SocialAvatarComponents.avatar(
          user: friend,
          size: ImageSize.medium,
        ),
        title: Text(
          friend.displayName,
          style: AppTextStyles.titleMedium,
        ),
      ),
    );
  }
}

/// Friend request card with accept/reject actions.
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
      SnackBarUtils.showSuccess(
          context, context.l10n.socialFriendRequestAccepted);
    }
  }

  static Future<void> _rejectRequest(
    BuildContext context,
    FriendRequest request,
    FriendsViewModel viewModel,
  ) async {
    final success = await viewModel.rejectFriendRequest(request.id);
    if (success && context.mounted) {
      SnackBarUtils.showWarning(
          context, context.l10n.socialFriendRequestDeclined);
    }
  }
}

/// Group card with navigation to group detail.
class GroupCard {
  static Widget build(
    BuildContext context,
    FriendCategory group,
  ) {
    return Card(
      child: ListTile(
        onTap: () => _navigateToGroupDetail(context, group),
        leading: CircleAvatar(
          backgroundColor: Theme.of(context)
              .colorScheme
              .primary
              .withValues(alpha: AppDimensions.opacityVeryLight),
          child: Text(
            group.emoji ?? '👥',
            style: AppTextStyles.headlineMedium,
          ),
        ),
        title: Text(
          group.name,
          style: AppTextStyles.titleMedium,
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (group.description?.isNotEmpty == true)
              Text(
                group.description!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.bodySmall,
              ),
            const SizedBox(height: AppDimensions.spacingXs),
            Text(
              group.summary,
              style: AppTextStyles.bodySmall.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
        trailing: Icon(
          Icons.arrow_forward_ios,
          size: AppDimensions.iconSizeS,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }

  static void _navigateToGroupDetail(
      BuildContext context, FriendCategory group) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => GroupDetailView(groupId: group.id),
      ),
    );
  }
}
