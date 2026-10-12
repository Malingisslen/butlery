// lib/widgets/common/user_avatar.dart

import 'package:flutter/material.dart';
import 'package:butlery/widgets/user/user_avatar_widgets.dart';
import 'package:butlery/widgets/user/user_display_models.dart';

/// Wrapper around UserAvatarWidgets for common usage.
class UserAvatar extends StatelessWidget {
  final String? imageUrl;
  final String displayName;
  final ImageSize size;

  /// A pixel size the [ImageSize] steps do not carry; wins over [size].
  final double? explicitSize;
  final VoidCallback? onTap;
  final Color? borderColor;
  final double? borderWidth;
  final Color? backgroundColor;
  final Color? textColor;
  final bool showStatus;
  final bool isOnline;
  final bool announceName;

  /// A circle, as the sketch draws people in lists and headers.
  final bool round;

  const UserAvatar({
    super.key,
    this.imageUrl,
    required this.displayName,
    this.size = ImageSize.medium,
    this.explicitSize,
    this.onTap,
    this.borderColor,
    this.borderWidth,
    this.backgroundColor,
    this.textColor,
    this.showStatus = false,
    this.isOnline = false,
    this.announceName = true,
    this.round = false,
  });

  @override
  Widget build(BuildContext context) {
    return UserAvatarWidgets.avatar(
      imageUrl: imageUrl,
      displayName: displayName,
      size: size,
      explicitSize: explicitSize,
      onTap: onTap,
      borderColor: borderColor,
      borderWidth: borderWidth,
      backgroundColor: backgroundColor,
      textColor: textColor,
      showStatus: showStatus,
      isOnline: isOnline,
      announceName: announceName,
      round: round,
    );
  }
}
