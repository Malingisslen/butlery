// lib/views/social/friends_list/friend_card.dart

import 'package:flutter/material.dart';
import '../../../models/user_profile.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_dimensions.dart';
import '../../../theme/app_text_styles.dart';

/// FriendCard - Individual friend card component
///
/// Displays friend information with profile and remove actions.
class FriendCard {
  static Widget build(
    BuildContext context,
    UserProfile friend,
  ) {
    return Card(
      margin: EdgeInsets.symmetric(
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
          decoration: BoxDecoration(
            color: AppColors.primaryBlue,
            shape: BoxShape.circle,
          ),
          child: Icon(
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