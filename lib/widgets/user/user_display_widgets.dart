import 'package:flutter/material.dart';
import 'package:butlery/widgets/common/icons/butlery_icons.dart';
import 'package:butlery/widgets/user/user_display_models.dart';
import 'package:butlery/widgets/user/user_avatar_widgets.dart';
import 'package:butlery/widgets/user/user_layout_widgets.dart';
import 'package:butlery/widgets/user/user_collection_widgets.dart';

// Export all components for backward compatibility
export 'user_display_models.dart';
export 'user_avatar_widgets.dart';
export 'user_layout_widgets.dart';
export 'user_collection_widgets.dart';

/// Facade for user display widgets. Delegates to focused components.
class UserDisplayWidgets {
  static Widget avatar({
    String? imageUrl,
    required String displayName,
    ImageSize size = ImageSize.medium,
    VoidCallback? onTap,
    Color? borderColor,
    double? borderWidth,
    Color? backgroundColor,
    Color? textColor,
    bool showStatus = false,
    bool isOnline = false,
    bool announceName = true,
  }) => UserAvatarWidgets.avatar(
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
    announceName: announceName,
  );

  static Widget editableAvatar({
    String? imageUrl,
    required String displayName,
    required VoidCallback onEditTap,
    ImageSize size = ImageSize.extraLarge,
    Color? borderColor,
    double? borderWidth,
  }) => UserAvatarWidgets.editableAvatar(
    imageUrl: imageUrl,
    displayName: displayName,
    onEditTap: onEditTap,
    size: size,
    borderColor: borderColor,
    borderWidth: borderWidth,
  );

  static Widget statusIndicator({
    required bool isOnline,
    double? size,
  }) => UserAvatarWidgets.statusIndicator(
    isOnline: isOnline,
    size: size,
  );

  static String getInitials(String name) => UserAvatarWidgets.getInitials(name);

  static Widget userName({
    required String displayName,
    TextStyle? style,
    int? maxLines,
    TextOverflow? overflow,
  }) => UserLayoutWidgets.userName(
    displayName: displayName,
    style: style,
    maxLines: maxLines,
    overflow: overflow,
  );

  static Widget userEmail({
    required String email,
    TextStyle? style,
    int? maxLines,
    TextOverflow? overflow,
  }) => UserLayoutWidgets.userEmail(
    email: email,
    style: style,
    maxLines: maxLines,
    overflow: overflow,
  );

  static Widget userInfo({
    required String displayName,
    String? email,
    CrossAxisAlignment alignment = CrossAxisAlignment.start,
    TextStyle? nameStyle,
    TextStyle? emailStyle,
  }) => UserLayoutWidgets.userInfo(
    displayName: displayName,
    email: email,
    alignment: alignment,
    nameStyle: nameStyle,
    emailStyle: emailStyle,
  );

  static Widget emptyUserState({
    String? title,
    String? subtitle,
    IconData icon = ButleryIcons.users,
    VoidCallback? onAction,
    String? actionLabel,
  }) => UserCollectionWidgets.emptyUserState(
    title: title,
    subtitle: subtitle,
    icon: icon,
    onAction: onAction,
    actionLabel: actionLabel,
  );

  static Widget userBadge({
    required String label,
    Color? backgroundColor,
    Color? textColor,
    EdgeInsets? padding,
  }) => UserCollectionWidgets.userBadge(
    label: label,
    backgroundColor: backgroundColor,
    textColor: textColor,
    padding: padding,
  );
}
