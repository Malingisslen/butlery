import 'package:flutter/material.dart';
import 'package:butlery/models/user_profile.dart';
import 'package:butlery/models/invitations/invitation_target.dart';
import 'package:butlery/widgets/user/user_display_widgets.dart';

/// Consolidated social helper functions.
class SocialHelpers {
  /// Format user display name.
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

  /// Generate initials from display name.
  static String getInitials(String displayName) {
    return UserDisplayWidgets.getInitials(displayName);
  }

  /// Convert UserProfile to UserDisplayData
  static UserDisplayData userProfileToDisplayData(UserProfile user) {
    return UserDisplayData.fromUserProfile(user);
  }

  /// Convert list of UserProfile to UserDisplayData
  static List<UserDisplayData> userProfilesToDisplayData(List<UserProfile> users) {
    return users.map((user) => UserDisplayData.fromUserProfile(user)).toList();
  }

  /// Convert size to ImageSize enum
  static ImageSize sizeToImageSize(double size) {
    if (size <= 32) return ImageSize.small;
    if (size <= 48) return ImageSize.medium;
    if (size <= 80) return ImageSize.large;
    return ImageSize.extraLarge;
  }
}

/// Data class for social statistics
class SocialStat {
  final IconData icon;
  final String value;
  final String label;
  final Color color;

  const SocialStat({
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
  });
}