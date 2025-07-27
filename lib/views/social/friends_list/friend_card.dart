// lib/views/social/friends_list/friend_card.dart

import 'package:flutter/material.dart';
import 'package:butlery/models/user_profile.dart';
import 'package:butlery/theme/app_colors.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';

/// FriendCard - Individual friend card component
///
/// Displays friend information with profile and remove actions.
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
          '/friend-profile',
          arguments: friend,
        ),
        leading: Container(
          width: 56,
          height: 56,
          decoration: const BoxDecoration(
            color: AppColors.primaryBlue,
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.person,
            color: AppColors.cardWhite,
            size: 32,
          ),
        ),
        title: Text(
          friend.displayName,
          style: AppTextStyles.titleMedium,
        ),
      ),
    );
  }

}