import 'package:flutter/material.dart';
import 'package:butlery/models/user_profile.dart';
import 'package:butlery/widgets/social/avatar/avatar_widgets.dart';

class SocialAvatarComponents {
  static Widget avatar({
    UserProfile? user,
    String? imageUrl,
    String? displayName,
    ImageSize size = ImageSize.medium,
    VoidCallback? onTap,
    bool showOnlineStatus = false,
    bool isOnline = false,
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
      announceName: announceName,
    );
  }
}
