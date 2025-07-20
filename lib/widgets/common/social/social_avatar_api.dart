// lib/widgets/common/social/social_avatar_api.dart

import 'package:flutter/material.dart';
import '../../../models/user_profile.dart';
import '../../social/avatar/avatar_widgets.dart';

/// Avatar API delegation for SocialComponents
class SocialAvatarApi {
  /// Build user avatar - delegates to AvatarWidgets
  static Widget avatar({
    UserProfile? user,
    String? imageUrl,
    String? displayName,
    dynamic size = 'medium',
    VoidCallback? onTap,
    bool showOnlineStatus = false,
    bool isOnline = false,
    EdgeInsets? padding,
    bool showBorder = true,
    Color? borderColor,
    bool showPlaceholder = true,
    String? placeholderText,
    double? customSize,
    bool isClickable = true,
    Widget? overlay,
    AlignmentGeometry overlayAlignment = Alignment.bottomRight,
  }) {
    return AvatarWidgets.avatar(
      user: user,
      imageUrl: imageUrl,
      displayName: displayName,
      size: size,
      onTap: onTap,
      showStatus: showOnlineStatus,
      isOnline: isOnline,
      borderColor: borderColor,
      clickable: isClickable,
    );
  }

  /// Build user card with avatar and info
  static Widget userCard({
    required UserProfile user,
    VoidCallback? onTap,
    Widget? trailing,
    dynamic avatarSize = 'medium',
    bool showOnlineStatus = false,
    bool isOnline = false,
    EdgeInsets? padding,
    bool showSubtitle = true,
    String? subtitle,
    Color? backgroundColor,
    bool showBorder = true,
  }) {
    return AvatarWidgets.userCard(
      user: user,
      onTap: onTap,
      actions: trailing,
      avatarSize: avatarSize,
      showStatus: showOnlineStatus,
      isOnline: isOnline,
      padding: padding,
      showSubtitle: showSubtitle,
      subtitle: subtitle,
      backgroundColor: backgroundColor,
    );
  }

  /// Build user list tile
  static Widget userListTile({
    required UserProfile user,
    VoidCallback? onTap,
    Widget? trailing,
    dynamic avatarSize = 'small',
    bool showOnlineStatus = false,
    bool isOnline = false,
    String? subtitle,
    bool enabled = true,
    Color? backgroundColor,
  }) {
    return AvatarWidgets.userListTile(
      user: user,
      onTap: onTap,
      trailing: trailing,
      avatarSize: avatarSize,
      showStatus: showOnlineStatus,
      isOnline: isOnline,
      subtitle: subtitle,
      enabled: enabled,
      backgroundColor: backgroundColor,
    );
  }
}
