// lib/widgets/social/avatar/avatar_widgets.dart

import 'package:flutter/material.dart';
import 'package:butlery/models/user_profile.dart';
import 'package:butlery/widgets/common/icons/butlery_icons.dart';
import 'package:butlery/widgets/user/user_display_widgets.dart';

// Re-export ImageSize for easier imports
export '../../user/user_display_widgets.dart' show ImageSize, UserDisplayData;

/// Avatar and user display widgets for social features
/// This module provides all avatar-related widgets with a consistent API
/// that works with UserProfile objects or individual parameters.
class AvatarWidgets {
  /// Resolves display name from user profile or explicit parameter,
  /// handling empty strings from pre-profile-load state.
  static String _effectiveDisplayName(UserProfile? user, String? displayName) =>
      (user?.displayName.isNotEmpty == true ? user!.displayName : null) ??
      displayName ??
      '?';

  /// Build user avatar - MAIN METHOD that replaces UserDisplayWidgets.avatar()
  static Widget avatar({
    UserProfile? user,
    String? imageUrl,
    String? displayName,
    ImageSize size = ImageSize.medium,
    VoidCallback? onTap,
    Color? borderColor,
    double? borderWidth,
    Color? backgroundColor,
    Color? textColor,
    bool showStatus = false,
    bool isOnline = false,
    bool clickable = false,
    bool announceName = true,
  }) {
    final effectiveImageUrl = user?.avatarUrl ?? imageUrl;
    final effectiveDisplayName = _effectiveDisplayName(user, displayName);
    final effectiveIsOnline = user?.isOnline ?? isOnline;

    return UserDisplayWidgets.avatar(
      imageUrl: effectiveImageUrl,
      displayName: effectiveDisplayName,
      size: size,
      onTap: clickable ? onTap : onTap,
      borderColor: borderColor,
      borderWidth: borderWidth,
      backgroundColor: backgroundColor,
      textColor: textColor,
      showStatus: showStatus,
      isOnline: effectiveIsOnline,
      announceName: announceName,
    );
  }

  /// Build editable avatar with edit button
  static Widget editableAvatar({
    UserProfile? user,
    String? imageUrl,
    String? displayName,
    required VoidCallback onEditTap,
    ImageSize size = ImageSize.extraLarge,
    Color? borderColor,
    double? borderWidth,
  }) {
    final effectiveImageUrl = user?.avatarUrl ?? imageUrl;
    final effectiveDisplayName = _effectiveDisplayName(user, displayName);

    return UserDisplayWidgets.editableAvatar(
      imageUrl: effectiveImageUrl,
      displayName: effectiveDisplayName,
      onEditTap: onEditTap,
      size: size,
      borderColor: borderColor,
      borderWidth: borderWidth,
    );
  }

  /// Build username with consistent styling
  static Widget userName({
    UserProfile? user,
    String? displayName,
    TextStyle? style,
    int? maxLines,
    TextOverflow? overflow,
  }) {
    final effectiveDisplayName = _effectiveDisplayName(user, displayName);

    return UserDisplayWidgets.userName(
      displayName: effectiveDisplayName,
      style: style,
      maxLines: maxLines,
      overflow: overflow,
    );
  }

  /// Build user info (name + email)
  static Widget userInfo({
    UserProfile? user,
    String? displayName,
    String? email,
    CrossAxisAlignment alignment = CrossAxisAlignment.start,
    TextStyle? nameStyle,
    TextStyle? emailStyle,
  }) {
    final effectiveDisplayName = _effectiveDisplayName(user, displayName);
    final effectiveEmail = user?.email ?? email;

    return UserDisplayWidgets.userInfo(
      displayName: effectiveDisplayName,
      email: effectiveEmail,
      alignment: alignment,
      nameStyle: nameStyle,
      emailStyle: emailStyle,
    );
  }

  /// Build empty state for users
  static Widget emptyUserState({
    String? title,
    String? subtitle,
    IconData icon = ButleryIcons.users,
    VoidCallback? onAction,
    String? actionLabel,
  }) {
    return UserDisplayWidgets.emptyUserState(
      title: title,
      subtitle: subtitle,
      icon: icon,
      onAction: onAction,
      actionLabel: actionLabel,
    );
  }

  /// Build status indicator
  static Widget statusIndicator({
    required bool isOnline,
    double? size,
  }) {
    return UserDisplayWidgets.statusIndicator(
      isOnline: isOnline,
      size: size,
    );
  }

  /// Build user badge
  static Widget userBadge({
    required String label,
    Color? backgroundColor,
    Color? textColor,
    EdgeInsets? padding,
  }) {
    return UserDisplayWidgets.userBadge(
      label: label,
      backgroundColor: backgroundColor,
      textColor: textColor,
      padding: padding,
    );
  }
}
