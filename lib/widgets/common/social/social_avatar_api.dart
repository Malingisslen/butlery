// lib/widgets/common/social/social_avatar_api.dart

import 'package:flutter/material.dart';
import 'package:butlery/models/user_profile.dart';
import 'package:butlery/widgets/social/avatar/avatar_widgets.dart';

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
    bool announceName = true,
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
      announceName: announceName,
    );
  }
}
