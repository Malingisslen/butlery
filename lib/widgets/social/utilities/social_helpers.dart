// lib/widgets/social/utilities/social_helpers.dart

import 'package:flutter/material.dart';
import '../../../models/user_profile.dart';
import '../../user/user_display_widgets.dart';

/// Social utility helper methods
///
/// This module provides utility methods for social features including
/// data conversions, initials generation, and common calculations.
class SocialHelpers {
  /// Generate initials from display name
  static String getInitials(String displayName) {
    return UserDisplayWidgets.getInitials(displayName);
  }

  /// Convert UserProfile to UserDisplayData
  static UserDisplayData userProfileToDisplayData(UserProfile user) {
    return UserDisplayData.fromUserProfile(user);
  }

  /// Convert list of UserProfile to UserDisplayData
  static List<UserDisplayData> userProfilesToDisplayData(
      List<UserProfile> users) {
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