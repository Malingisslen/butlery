// lib/widgets/common/social/social_helpers.dart

import 'package:flutter/material.dart';
import '../../../models/user_profile.dart';
import '../../../models/invitations/invitation_target.dart';

/// Helper functions for social components
class SocialHelpers {
  /// Format user display name
  static String formatUserDisplayName(UserProfile? user, {String fallback = 'Okänd användare'}) {
    if (user == null) return fallback;
    return user.displayName.isNotEmpty ? user.displayName : user.email;
  }

  /// Check if user is online
  static bool isUserOnline(UserProfile? user) {
    if (user == null) return false;
    return user.isOnline;
  }

  /// Get user avatar URL
  static String? getUserAvatarUrl(UserProfile? user) {
    if (user == null) return null;
    return user.avatarUrl;
  }

  /// Format invitation target display name
  static String formatInvitationTargetDisplayName(InvitationTarget target) {
    return target.displayName.isNotEmpty ? target.displayName : 'Unknown';
  }

  /// Get invitation target type icon
  static IconData getInvitationTargetTypeIcon(InvitationTarget target) {
    switch (target.type.toString()) {
      case 'InvitationTargetType.user':
        return Icons.person;
      case 'InvitationTargetType.group':
        return Icons.group;
      case 'InvitationTargetType.email':
        return Icons.email;
      default:
        return Icons.account_circle;
    }
  }
}