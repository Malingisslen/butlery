// lib/widgets/social/avatar/avatar_widgets.dart

import 'package:flutter/material.dart';
import 'package:butlery/models/user_profile.dart';
import 'package:butlery/widgets/user/user_display_widgets.dart';

// Re-export ImageSize for easier imports
export '../../user/user_display_widgets.dart' show ImageSize, UserDisplayData;

/// Avatar and user display widgets for social features
/// This module provides all avatar-related widgets with a consistent API
/// that works with UserProfile objects or individual parameters.
class AvatarWidgets {
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
  }) {
    final effectiveImageUrl = user?.avatarUrl ?? imageUrl;
    final effectiveDisplayName = user?.displayName ?? displayName ?? 'Okänd';
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
    final effectiveDisplayName = user?.displayName ?? displayName ?? 'Okänd';

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
    final effectiveDisplayName = user?.displayName ?? displayName ?? 'Okänd';

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
    final effectiveDisplayName = user?.displayName ?? displayName ?? 'Okänd';
    final effectiveEmail = user?.email ?? email;

    return UserDisplayWidgets.userInfo(
      displayName: effectiveDisplayName,
      email: effectiveEmail,
      alignment: alignment,
      nameStyle: nameStyle,
      emailStyle: emailStyle,
    );
  }

  /// Build user row (avatar + info + trailing)
  static Widget userRow({
    UserProfile? user,
    String? imageUrl,
    String? displayName,
    String? email,
    String? subtitle,
    ImageSize avatarSize = ImageSize.medium,
    VoidCallback? onTap,
    Widget? trailing,
    bool showStatus = false,
    EdgeInsets? padding,
  }) {
    final effectiveImageUrl = user?.avatarUrl ?? imageUrl;
    final effectiveDisplayName = user?.displayName ?? displayName ?? 'Okänd';
    final effectiveEmail = user?.email ?? email;
    final effectiveSubtitle = subtitle;
    final effectiveIsOnline = user?.isOnline ?? false;

    return UserDisplayWidgets.userRow(
      imageUrl: effectiveImageUrl,
      displayName: effectiveDisplayName,
      email: effectiveEmail,
      subtitle: effectiveSubtitle,
      avatarSize: avatarSize,
      onTap: onTap,
      trailing: trailing,
      showStatus: showStatus,
      isOnline: effectiveIsOnline,
      padding: padding,
    );
  }

  /// Build user card (larger layout)
  static Widget userCard({
    UserProfile? user,
    String? imageUrl,
    String? displayName,
    String? email,
    String? subtitle,
    String? description,
    ImageSize avatarSize = ImageSize.large,
    VoidCallback? onTap,
    Widget? actions,
    bool showStatus = false,
    EdgeInsets? padding,
    EdgeInsets? margin,
    bool showBorder = true,
    bool showSubtitle = true,
    Color? backgroundColor,
    bool isOnline = false,
  }) {
    final effectiveImageUrl = user?.avatarUrl ?? imageUrl;
    final effectiveDisplayName = user?.displayName ?? displayName ?? 'Okänd';
    final effectiveEmail = user?.email ?? email;
    final effectiveSubtitle = subtitle;
    final effectiveDescription = description;
    final effectiveIsOnline = user?.isOnline ?? isOnline;

    return UserDisplayWidgets.userCard(
      imageUrl: effectiveImageUrl,
      displayName: effectiveDisplayName,
      email: effectiveEmail,
      subtitle: effectiveSubtitle,
      description: effectiveDescription,
      avatarSize: avatarSize,
      onTap: onTap,
      actions: actions,
      showStatus: showStatus,
      isOnline: effectiveIsOnline,
      padding: padding,
      margin: margin,
    );
  }

  /// Build user list tile
  static Widget userListTile({
    UserProfile? user,
    String? imageUrl,
    String? displayName,
    String? email,
    String? subtitle,
    ImageSize avatarSize = ImageSize.small,
    VoidCallback? onTap,
    Widget? trailing,
    bool showStatus = false,
    bool isOnline = false,
    bool enabled = true,
    Color? backgroundColor,
  }) {
    final effectiveImageUrl = user?.avatarUrl ?? imageUrl;
    final effectiveDisplayName = user?.displayName ?? displayName ?? 'Okänd';
    final effectiveEmail = user?.email ?? email;
    final effectiveSubtitle = subtitle;
    final effectiveIsOnline = user?.isOnline ?? isOnline;

    return UserDisplayWidgets.userRow(
      imageUrl: effectiveImageUrl,
      displayName: effectiveDisplayName,
      email: effectiveEmail,
      subtitle: effectiveSubtitle,
      avatarSize: avatarSize,
      onTap: enabled ? onTap : null,
      trailing: trailing,
      showStatus: showStatus,
      isOnline: effectiveIsOnline,
    );
  }

  /// Build list of users
  static Widget userList({
    required List<UserProfile> users,
    Function(UserProfile)? onUserTap,
    Widget Function(UserProfile)? trailingBuilder,
    bool showStatus = false,
    ImageSize avatarSize = ImageSize.medium,
    EdgeInsets? padding,
    bool shrinkWrap = true,
    ScrollPhysics? physics,
  }) {
    final userData =
        users.map((user) => UserDisplayData.fromUserProfile(user)).toList();

    return UserDisplayWidgets.userList(
      users: userData,
      onUserTap: onUserTap != null
          ? (userData) {
              final user = users.firstWhere((u) => u.uid == userData.id);
              onUserTap(user);
            }
          : null,
      trailingBuilder: trailingBuilder != null
          ? (userData) {
              final user = users.firstWhere((u) => u.uid == userData.id);
              return trailingBuilder(user);
            }
          : null,
      showStatus: showStatus,
      avatarSize: avatarSize,
      padding: padding,
      shrinkWrap: shrinkWrap,
      physics: physics,
    );
  }

  /// Build grid of users
  static Widget userGrid({
    required List<UserProfile> users,
    Function(UserProfile)? onUserTap,
    int crossAxisCount = 2,
    double aspectRatio = 1.2,
    ImageSize avatarSize = ImageSize.large,
    EdgeInsets? padding,
    bool shrinkWrap = true,
    ScrollPhysics? physics,
  }) {
    final userData =
        users.map((user) => UserDisplayData.fromUserProfile(user)).toList();

    return UserDisplayWidgets.userGrid(
      users: userData,
      onUserTap: onUserTap != null
          ? (userData) {
              final user = users.firstWhere((u) => u.uid == userData.id);
              onUserTap(user);
            }
          : null,
      crossAxisCount: crossAxisCount,
      aspectRatio: aspectRatio,
      avatarSize: avatarSize,
      padding: padding,
      shrinkWrap: shrinkWrap,
      physics: physics,
    );
  }

  /// Build empty state for users
  static Widget emptyUserState({
    String? title,
    String? subtitle,
    IconData icon = Icons.people_outline,
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
