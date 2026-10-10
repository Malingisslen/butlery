import 'package:flutter/material.dart';
import 'package:butlery/models/user_profile.dart';
import 'package:butlery/l10n/app_localizations.dart';
import 'package:butlery/widgets/common/icons/butlery_glyph.dart';
import 'package:butlery/widgets/common/icons/butlery_icons.dart';
import 'package:butlery/widgets/user/user_display_widgets.dart' show ImageSize;
import 'package:butlery/widgets/common/social/social_facade.dart';

/// Social avatar and user display components.
class SocialAvatarComponents {
  /// Build user avatar.
  static Widget avatar({
    UserProfile? user,
    String? imageUrl,
    String? displayName,
    ImageSize size = ImageSize.medium,
    VoidCallback? onTap,
    bool showOnlineStatus = false,
    bool isOnline = false,
    EdgeInsets? padding,
    Color? backgroundColor,
    bool showBorder = false,
    bool announceName = true,
  }) {
    return SocialFacade.avatar(
      user: user,
      imageUrl: imageUrl,
      displayName: displayName,
      size: size,
      onTap: onTap,
      showOnlineStatus: showOnlineStatus,
      isOnline: isOnline,
      padding: padding,
      showBorder: showBorder,
      announceName: announceName,
    );
  }

  /// Format user display name consistently.
  static String formatUserDisplayName(UserProfile? user) {
    return SocialFacade.formatUserDisplayName(user);
  }

  /// Check if user is currently online
  /// Returns online status for presence indicators
  static bool isUserOnline(UserProfile? user) {
    return SocialFacade.isUserOnline(user);
  }

  /// Get user avatar URL with fallbacks
  /// Returns the best available avatar URL for the user
  static String? getUserAvatarUrl(UserProfile? user) {
    return SocialFacade.getUserAvatarUrl(user);
  }

  /// Build small avatar (typically for lists).
  static Widget smallAvatar({
    UserProfile? user,
    String? imageUrl,
    String? displayName,
    VoidCallback? onTap,
    bool showOnlineStatus = false,
    bool isOnline = false,
  }) {
    return avatar(
      user: user,
      imageUrl: imageUrl,
      displayName: displayName,
      size: ImageSize.small,
      onTap: onTap,
      showOnlineStatus: showOnlineStatus,
      isOnline: isOnline,
    );
  }

  /// Build medium avatar (default size)
  static Widget mediumAvatar({
    UserProfile? user,
    String? imageUrl,
    String? displayName,
    VoidCallback? onTap,
    bool showOnlineStatus = false,
    bool isOnline = false,
  }) {
    return avatar(
      user: user,
      imageUrl: imageUrl,
      displayName: displayName,
      size: ImageSize.medium,
      onTap: onTap,
      showOnlineStatus: showOnlineStatus,
      isOnline: isOnline,
    );
  }

  /// Build large avatar (for profiles and prominent displays)
  static Widget largeAvatar({
    UserProfile? user,
    String? imageUrl,
    String? displayName,
    VoidCallback? onTap,
    bool showOnlineStatus = false,
    bool isOnline = false,
  }) {
    return avatar(
      user: user,
      imageUrl: imageUrl,
      displayName: displayName,
      size: ImageSize.large,
      onTap: onTap,
      showOnlineStatus: showOnlineStatus,
      isOnline: isOnline,
    );
  }

  /// Build avatar with loading state.
  static Widget avatarLoading({
    ImageSize size = ImageSize.medium,
    Color? backgroundColor,
  }) {
    return Builder(
      builder: (context) => Container(
        width: _getSizeValue(size),
        height: _getSizeValue(size),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color:
              backgroundColor ?? Theme.of(context).colorScheme.outlineVariant,
        ),
        // A still plate while the avatar loads, never a spinner
        // (produktregler.md:163, B-18).
        child: Semantics(
          label: Localizations.of<AppLocalizations>(
            context,
            AppLocalizations,
          )?.loadingImage,
        ),
      ),
    );
  }

  /// Build avatar with error state
  static Widget avatarError({
    ImageSize size = ImageSize.medium,
    VoidCallback? onRetry,
    String? errorMessage,
  }) {
    return Builder(
      builder: (context) {
        final cs = Theme.of(context).colorScheme;
        return Container(
          width: _getSizeValue(size),
          height: _getSizeValue(size),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: cs.error,
          ),
          child: ButleryIcon(
            ButleryIcons.triangleAlert,
            size: _getSizeValue(size) * 0.6,
            color: cs.surfaceContainerHighest,
          ),
        );
      },
    );
  }

  /// Build placeholder avatar (no user data)
  static Widget avatarPlaceholder({
    ImageSize size = ImageSize.medium,
    IconData icon = ButleryIcons.user,
    Color? backgroundColor,
    Color? iconColor,
  }) {
    return Builder(
      builder: (context) {
        final cs = Theme.of(context).colorScheme;
        return Container(
          width: _getSizeValue(size),
          height: _getSizeValue(size),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: backgroundColor ?? cs.outline,
          ),
          child: ButleryIcon(
            icon,
            size: _getSizeValue(size) * 0.6,
            color: iconColor ?? cs.onSurfaceVariant,
          ),
        );
      },
    );
  }

  /// Helper to convert ImageSize to double
  static double _getSizeValue(ImageSize size) {
    switch (size) {
      case ImageSize.small:
        return 32.0;
      case ImageSize.medium:
        return 48.0;
      case ImageSize.large:
        return 64.0;
      case ImageSize.extraLarge:
        return 96.0;
      case ImageSize.card:
        return 80.0;
      case ImageSize.hero:
        return 120.0;
      case ImageSize.thumbnail:
        return 24.0;
      case ImageSize.custom:
        return 48.0; // Default fallback for custom size
    }
  }
}
