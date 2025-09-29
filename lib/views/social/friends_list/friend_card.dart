// lib/views/social/friends_list/friend_card.dart

import 'package:flutter/material.dart';
import 'package:butlery/models/user_profile.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/widgets/common/social_components.dart';
import 'package:butlery/core/constants/routes.dart';

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
          Routes.friendProfile,
          arguments: friend,
        ),
        leading: SocialComponents.avatar(
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