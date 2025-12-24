// lib/widgets/common/user_avatar.dart

import 'package:flutter/material.dart';
import 'package:butlery/widgets/user/user_avatar_widgets.dart';
import 'package:butlery/widgets/user/user_display_models.dart';

/// Wrapper around UserAvatarWidgets for common usage.
class UserAvatar extends StatelessWidget {
  final String? imageUrl;
  final String displayName;
  final ImageSize size;
  final VoidCallback? onTap;
  final Color? borderColor;
  final double? borderWidth;
  final Color? backgroundColor;
  final Color? textColor;
  final bool showStatus;
  final bool isOnline;

  const UserAvatar({
    super.key,
    this.imageUrl,
    required this.displayName,
    this.size = ImageSize.medium,
    this.onTap,
    this.borderColor,
    this.borderWidth,
    this.backgroundColor,
    this.textColor,
    this.showStatus = false,
    this.isOnline = false,
  });

  @override
  Widget build(BuildContext context) {
    return UserAvatarWidgets.avatar(
      imageUrl: imageUrl,
      displayName: displayName,
      size: size,
      onTap: onTap,
      borderColor: borderColor,
      borderWidth: borderWidth,
      backgroundColor: backgroundColor,
      textColor: textColor,
      showStatus: showStatus,
      isOnline: isOnline,
    );
  }
}