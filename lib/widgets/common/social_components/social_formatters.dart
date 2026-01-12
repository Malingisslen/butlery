// lib/widgets/common/social_components/social_formatters.dart

import 'package:flutter/material.dart';
import 'package:butlery/models/invitations/invitation_target.dart';
import 'package:butlery/theme/app_colors.dart';
import 'package:butlery/widgets/common/social/social_facade.dart';
import 'package:butlery/theme/app_dimensions.dart';

/// Social formatting utilities for display names, numbers, and time.
class SocialFormatters {
  /// Format user display name
  static String formatUserDisplayName(dynamic user) {
    return user?.displayName ?? user?.email ?? 'Unknown User';
  }

  /// Check if user is online
  static bool isUserOnline(dynamic user) {
    return user?.isOnline ?? false;
  }

  /// Get user avatar URL
  static String? getUserAvatarUrl(dynamic user) {
    return user?.avatarUrl;
  }

  /// Format invitation target display name (delegates to SocialFacade)
  static String formatInvitationTargetDisplayName(InvitationTarget target) {
    return SocialFacade.formatInvitationTargetDisplayName(target);
  }

  /// Format relative time for display (Swedish)
  static String formatRelativeTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inMinutes < 1) {
      return 'just nu';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes} min sedan';
    } else if (difference.inHours < 24) {
      return '${difference.inHours} timmar sedan';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} dagar sedan';
    } else {
      return '${(difference.inDays / 7).floor()} veckor sedan';
    }
  }

  /// Format number with abbreviation (k, M)
  static String formatNumberWithAbbreviation(int number) {
    if (number < 1000) {
      return number.toString();
    } else if (number < 1000000) {
      return '${(number / 1000).toStringAsFixed(number % 1000 == 0 ? 0 : 1)}k';
    } else {
      return '${(number / 1000000).toStringAsFixed(number % 1000000 == 0 ? 0 : 1)}M';
    }
  }

  /// Get social color scheme
  static Map<String, Color> getSocialColorScheme() {
    return {
      'primary': AppColors.primaryBlue,
      'secondary': AppColors.primaryBlue
          .withValues(alpha: AppDimensions.opacityVeryLight),
      'success': AppColors.primaryBlue,
      'warning': AppColors.textMedium,
      'danger': AppColors.error,
      'info':
          AppColors.primaryBlue.withValues(alpha: AppDimensions.opacityDark),
      'muted': AppColors.textMedium,
    };
  }
}
