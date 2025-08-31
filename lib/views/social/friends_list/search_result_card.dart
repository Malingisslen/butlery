// lib/views/social/friends_list/search_result_card.dart

import 'package:flutter/material.dart';
import 'package:butlery/models/user_profile.dart';
import 'package:butlery/viewmodels/friends_viewmodel.dart';
import 'package:butlery/widgets/common/content_card.dart';
import 'package:butlery/theme/app_colors.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/theme/app_dimensions.dart';

/// SearchResultCard - Enhanced search result card component with explicit action buttons
///
/// Displays search result user with clear friendship status and action buttons.
/// Provides visual clarity about available actions based on current relationship status.
class SearchResultCard {
  static Widget build(
    BuildContext context,
    UserProfile user,
    FriendsViewModel viewModel,
  ) {
    return ContentCard.friend(
      user: user,
      onTap: null, // Remove generic onTap to prevent confusion
      trailing: _buildActionButton(context, user, viewModel),
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
        return _buildBlockedButton(context);
    }
  }

  /// Build primary action button to send friend request
  static Widget _buildSendRequestButton(
    BuildContext context,
    UserProfile user,
    FriendsViewModel viewModel,
  ) {
    return ElevatedButton(
      onPressed: () => _handleSendFriendRequest(context, user, viewModel),
      style: ElevatedButton.styleFrom(
        backgroundColor: Theme.of(context).colorScheme.primary,
        padding: const EdgeInsets.symmetric(
          horizontal: AppDimensions.paddingM,
          vertical: AppDimensions.paddingS,
        ),
      ),
      child: Text(
        'Skicka vänförfrågan',
        style: AppTextStyles.labelMedium.copyWith(
          color: Theme.of(context).colorScheme.onPrimary,
        ),
      ),
    );
  }

  /// Build disabled button showing request already sent
  static Widget _buildRequestSentButton(BuildContext context) {
    return OutlinedButton(
      onPressed: null, // Disabled
      style: OutlinedButton.styleFrom(
        side: const BorderSide(color: AppColors.textLight),
        padding: const EdgeInsets.symmetric(
          horizontal: AppDimensions.paddingM,
          vertical: AppDimensions.paddingS,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.schedule,
            size: AppDimensions.iconSizeS,
            color: AppColors.textMedium,
          ),
          const SizedBox(width: AppDimensions.spacingXs),
          Text(
            'Förfrågan skickad',
            style: AppTextStyles.labelMedium.copyWith(
              color: AppColors.textMedium,
            ),
          ),
        ],
      ),
    );
  }

  /// Build disabled button showing already friends status
  static Widget _buildAlreadyFriendsButton(BuildContext context) {
    return OutlinedButton(
      onPressed: null, // Disabled
      style: OutlinedButton.styleFrom(
        side: const BorderSide(color: AppColors.success),
        padding: const EdgeInsets.symmetric(
          horizontal: AppDimensions.paddingM,
          vertical: AppDimensions.paddingS,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.check_circle,
            size: AppDimensions.iconSizeS,
            color: AppColors.success,
          ),
          const SizedBox(width: AppDimensions.spacingXs),
          Text(
            'Vänner',
            style: AppTextStyles.labelMedium.copyWith(
              color: AppColors.success,
            ),
          ),
        ],
      ),
    );
  }

  /// Build accept button for incoming friend requests
  static Widget _buildAcceptRequestButton(
    BuildContext context,
    UserProfile user,
    FriendsViewModel viewModel,
  ) {
    return ElevatedButton(
      onPressed: () => _handleAcceptFriendRequest(context, user, viewModel),
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.success,
        padding: const EdgeInsets.symmetric(
          horizontal: AppDimensions.paddingM,
          vertical: AppDimensions.paddingS,
        ),
      ),
      child: Text(
        'Acceptera',
        style: AppTextStyles.labelMedium.copyWith(
          color: Theme.of(context).colorScheme.onPrimary,
        ),
      ),
    );
  }

  /// Build disabled button for blocked users
  static Widget _buildBlockedButton(BuildContext context) {
    return OutlinedButton(
      onPressed: null, // Disabled
      style: OutlinedButton.styleFrom(
        side: const BorderSide(color: AppColors.error),
        padding: const EdgeInsets.symmetric(
          horizontal: AppDimensions.paddingM,
          vertical: AppDimensions.paddingS,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.block,
            size: AppDimensions.iconSizeS,
            color: AppColors.error,
          ),
          const SizedBox(width: AppDimensions.spacingXs),
          Text(
            'Blockerad',
            style: AppTextStyles.labelMedium.copyWith(
              color: AppColors.error,
            ),
          ),
        ],
      ),
    );
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
        message: 'Hej! Skulle vi kunna bli vänner?',
      );

      if (context.mounted) {
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Vänförfrågan skickad till ${user.displayName}! 📨'),
              backgroundColor: AppColors.success,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(viewModel.error ?? 'Kunde inte skicka vänförfrågan'),
              backgroundColor: AppColors.error,
            ),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ett fel uppstod: $e'),
            backgroundColor: AppColors.error,
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
    final request = incomingRequests
        .where((req) => req.fromUserId == user.uid)
        .firstOrNull;

    if (request == null) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Kunde inte hitta vänskapsförfrågan'),
            backgroundColor: AppColors.error,
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
              content: Text('Vänskapsförfrågan från ${user.displayName} accepterad! 🎉'),
              backgroundColor: AppColors.success,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(viewModel.error ?? 'Kunde inte acceptera vänskapsförfrågan'),
              backgroundColor: AppColors.error,
            ),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ett fel uppstod: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }
}