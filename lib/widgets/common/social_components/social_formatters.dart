// lib/widgets/common/social_components/social_formatters.dart

import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:butlery/models/invitations/invitation_target.dart';
import 'package:butlery/models/user_profile.dart';
import 'package:butlery/widgets/common/social/social_facade.dart';
import 'package:butlery/theme/app_dimensions.dart';

/// Social formatting utilities for display names, numbers, and time.
class SocialFormatters {
  /// Format user display name
  static String formatUserDisplayName(UserProfile? user) =>
      SocialFacade.formatUserDisplayName(user);

  /// Check if user is online
  static bool isUserOnline(UserProfile? user) =>
      SocialFacade.isUserOnline(user);

  /// Get user avatar URL
  static String? getUserAvatarUrl(UserProfile? user) =>
      SocialFacade.getUserAvatarUrl(user);

  /// Format invitation target display name (delegates to SocialFacade)
  static String formatInvitationTargetDisplayName(InvitationTarget target) {
    return SocialFacade.formatInvitationTargetDisplayName(target);
  }

  /// Format relative time for display (Swedish)
  static String formatRelativeTime(DateTime dateTime) {
    final now = clock.now();
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

  /// Get the social color scheme keyed by semantic role. Reads through the
  /// active theme — pass a real `BuildContext`. The legacy no-context fallback
  /// was removed in BUT-755; it had zero live callers and broke dark mode.
  static Map<String, Color> getSocialColorScheme(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return {
      'primary': cs.primary,
      'secondary': cs.primary.withValues(alpha: AppDimensions.opacityVeryLight),
      'success': cs.primary,
      'warning': cs.onSurfaceVariant,
      'danger': cs.error,
      'info': cs.primary.withValues(alpha: AppDimensions.opacityDark),
      'muted': cs.onSurfaceVariant,
    };
  }
}
