// lib/widgets/user/user_display_widgets.dart - OPTIMERAD VERSION
// ✅ INGA backwards compatibility aliases - Clean & Efficient
// ✅ 100% AppTheme - Optimerad performance utan funktionalitetsförlust


import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../theme/app_theme.dart';

/// Image Size enum
enum ImageSize {
  small, // 32px
  medium, // 48px
  large, // 80px
  extraLarge, // 120px
  card, // 70px
  hero, // 200px
  thumbnail, // 60px
  custom, // Anpassad storlek
}

/// User Status enum
enum UserStatus { online, offline, away, busy }

/// Optimerad User Display Data class
class UserDisplayData {
  final String id;
  final String displayName;
  final String? email;
  final String? imageUrl;
  final String? subtitle;
  final String? description;
  final bool isOnline;
  final DateTime? lastSeen;
  final Map<String, dynamic>? metadata;

  const UserDisplayData({
    required this.id,
    required this.displayName,
    this.email,
    this.imageUrl,
    this.subtitle,
    this.description,
    this.isOnline = false,
    this.lastSeen,
    this.metadata,
  });

  /// Optimerade factory constructors
  factory UserDisplayData.fromFirebaseUser(dynamic user) => UserDisplayData(
        id: user.uid,
        displayName: user.displayName ?? 'Okänd användare',
        email: user.email,
        imageUrl: user.photoURL,
      );

  factory UserDisplayData.fromUserProfile(dynamic userProfile) =>
      UserDisplayData(
        id: userProfile.uid,
        displayName: userProfile.displayName,
        email: userProfile.email,
        imageUrl: userProfile.avatarUrl,
        isOnline: userProfile.isOnline,
      );

  UserDisplayData copyWith({
    String? id,
    String? displayName,
    String? email,
    String? imageUrl,
    String? subtitle,
    String? description,
    bool? isOnline,
    DateTime? lastSeen,
    Map<String, dynamic>? metadata,
  }) =>
      UserDisplayData(
        id: id ?? this.id,
        displayName: displayName ?? this.displayName,
        email: email ?? this.email,
        imageUrl: imageUrl ?? this.imageUrl,
        subtitle: subtitle ?? this.subtitle,
        description: description ?? this.description,
        isOnline: isOnline ?? this.isOnline,
        lastSeen: lastSeen ?? this.lastSeen,
        metadata: metadata ?? this.metadata,
      );
}

/// Optimerade User Display Widgets - STREAMLINED
class UserDisplayWidgets {
  // ===== CORE AVATARS =====

  /// Optimerad avatar implementation
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
  }) {
    final avatarSize = _getAvatarSize(size);
    final effectiveBackgroundColor =
        backgroundColor ?? AppTheme.primaryColor.withValues(alpha: 0.1);
    final effectiveTextColor = textColor ?? AppTheme.primaryColor;

    Widget avatar = Container(
      width: avatarSize,
      height: avatarSize,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: effectiveBackgroundColor,
        border: borderWidth != null && borderColor != null
            ? Border.all(width: borderWidth, color: borderColor)
            : null,
      ),
      child: (imageUrl != null && imageUrl.isNotEmpty)
          ? ClipOval(
              child: CachedNetworkImage(
                imageUrl: imageUrl,
                width: avatarSize,
                height: avatarSize,
                fit: BoxFit.cover,
                placeholder: (context, url) => _buildInitialsAvatar(displayName,
                    avatarSize, effectiveBackgroundColor, effectiveTextColor),
                errorWidget: (context, url, error) => _buildInitialsAvatar(
                    displayName,
                    avatarSize,
                    effectiveBackgroundColor,
                    effectiveTextColor),
                memCacheWidth: (avatarSize * 2).toInt(),
                memCacheHeight: (avatarSize * 2).toInt(),
                fadeInDuration: AppTheme.animationDurationMedium,
                fadeOutDuration: AppTheme.animationDurationMedium,
              ),
            )
          : _buildInitialsAvatar(displayName, avatarSize,
              effectiveBackgroundColor, effectiveTextColor),
    );

    // Status indicator
    if (showStatus) {
      avatar = Stack(
        children: [
          avatar,
          Positioned(
            right: 0,
            bottom: 0,
            child: Container(
              width: avatarSize * 0.25,
              height: avatarSize * 0.25,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isOnline ? AppTheme.successColor : AppTheme.textTertiary,
                border: Border.all(
                  color: AppTheme.cardColor,
                  width: AppTheme.spacingXxs,
                ),
              ),
            ),
          ),
        ],
      );
    }

    return onTap != null
        ? Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(avatarSize / 2),
              child: avatar,
            ),
          )
        : avatar;
  }

  /// Editable avatar
  static Widget editableAvatar({
    String? imageUrl,
    required String displayName,
    required VoidCallback onEditTap,
    ImageSize size = ImageSize.extraLarge,
    Color? borderColor,
    double? borderWidth,
  }) {
    return Stack(
      children: [
        avatar(
          imageUrl: imageUrl,
          displayName: displayName,
          size: size,
          borderColor: borderColor ?? AppTheme.primaryColor,
          borderWidth: borderWidth ?? AppTheme.spacingXs,
        ),
        Positioned(
          right: 0,
          bottom: 0,
          child: Material(
            color: AppTheme.primaryColor,
            shape: const CircleBorder(),
            child: InkWell(
              onTap: onEditTap,
              borderRadius: AppTheme.roundRadius,
              child: Container(
                width: AppTheme.iconSizeDisplay,
                height: AppTheme.iconSizeDisplay,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppTheme.primaryColor,
                  border: Border.all(
                    color: AppTheme.cardColor,
                    width: AppTheme.spacingXxs,
                  ),
                ),
                child: Icon(
                  Icons.edit,
                  size: AppTheme.iconSizeInfo,
                  color: AppTheme.cardColor,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ===== TEXT COMPONENTS =====

  /// Optimerad user name
  static Widget userName({
    required String displayName,
    TextStyle? style,
    int? maxLines,
    TextOverflow? overflow,
  }) =>
      Text(
        displayName,
        style: style ?? AppTheme.cardTitleStyle,
        maxLines: maxLines,
        overflow: overflow ?? TextOverflow.ellipsis,
      );

  /// Optimerad user email
  static Widget userEmail({
    required String email,
    TextStyle? style,
    int? maxLines,
    TextOverflow? overflow,
  }) =>
      Text(
        email,
        style: style ?? AppTheme.subtitleStyle,
        maxLines: maxLines,
        overflow: overflow ?? TextOverflow.ellipsis,
      );

  /// Kombinerad user info
  static Widget userInfo({
    required String displayName,
    String? email,
    CrossAxisAlignment alignment = CrossAxisAlignment.start,
    TextStyle? nameStyle,
    TextStyle? emailStyle,
  }) {
    return Column(
      crossAxisAlignment: alignment,
      children: [
        userName(displayName: displayName, style: nameStyle),
        if (email != null) ...[
          AppTheme.tinyGap,
          userEmail(email: email, style: emailStyle),
        ],
      ],
    );
  }

  // ===== COMPOSITE LAYOUTS =====

  /// Optimerad user row
  static Widget userRow({
    String? imageUrl,
    required String displayName,
    String? email,
    String? subtitle,
    ImageSize avatarSize = ImageSize.medium,
    VoidCallback? onTap,
    Widget? trailing,
    bool showStatus = false,
    bool isOnline = false,
    EdgeInsets? padding,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: AppTheme.mediumRadius,
      child: Padding(
        padding: padding ?? AppTheme.listItemPadding,
        child: Row(
          children: [
            avatar(
              imageUrl: imageUrl,
              displayName: displayName,
              size: avatarSize,
              showStatus: showStatus,
              isOnline: isOnline,
            ),
            AppTheme.mediumHorizontalGap,
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  userName(displayName: displayName),
                  if (email != null) ...[
                    AppTheme.tinyGap,
                    userEmail(email: email),
                  ],
                  if (subtitle != null) ...[
                    AppTheme.tinyGap,
                    Text(subtitle, style: AppTheme.captionStyle),
                  ],
                ],
              ),
            ),
            if (trailing != null) ...[
              AppTheme.smallHorizontalGap,
              trailing,
            ],
          ],
        ),
      ),
    );
  }

  /// Optimerad user card
  static Widget userCard({
    String? imageUrl,
    required String displayName,
    String? email,
    String? subtitle,
    String? description,
    ImageSize avatarSize = ImageSize.large,
    VoidCallback? onTap,
    Widget? actions,
    bool showStatus = false,
    bool isOnline = false,
    EdgeInsets? padding,
    EdgeInsets? margin,
  }) {
    return Card(
      margin: margin ?? AppTheme.cardPadding,
      elevation: AppTheme.elevationLow,
      shape: RoundedRectangleBorder(borderRadius: AppTheme.largeRadius),
      child: InkWell(
        onTap: onTap,
        borderRadius: AppTheme.largeRadius,
        child: Padding(
          padding: padding ?? AppTheme.cardPadding,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  avatar(
                    imageUrl: imageUrl,
                    displayName: displayName,
                    size: avatarSize,
                    showStatus: showStatus,
                    isOnline: isOnline,
                  ),
                  AppTheme.mediumHorizontalGap,
                  Expanded(
                      child: userInfo(displayName: displayName, email: email)),
                ],
              ),
              if (subtitle != null) ...[
                AppTheme.smallGap,
                Text(subtitle, style: AppTheme.subtitleStyle),
              ],
              if (description != null) ...[
                AppTheme.smallGap,
                Text(description, style: AppTheme.bodyStyle),
              ],
              if (actions != null) ...[
                AppTheme.mediumGap,
                actions,
              ],
            ],
          ),
        ),
      ),
    );
  }

  // ===== LIST COMPONENTS =====

  /// Optimerad user list
  static Widget userList({
    required List<UserDisplayData> users,
    Function(UserDisplayData)? onUserTap,
    Widget Function(UserDisplayData)? trailingBuilder,
    bool showStatus = false,
    ImageSize avatarSize = ImageSize.medium,
    EdgeInsets? padding,
    bool shrinkWrap = true,
    ScrollPhysics? physics,
  }) {
    return ListView.separated(
      shrinkWrap: shrinkWrap,
      physics: physics ?? const NeverScrollableScrollPhysics(),
      padding: padding ?? AppTheme.screenPadding,
      itemCount: users.length,
      separatorBuilder: (context, index) => AppTheme.smallGap,
      itemBuilder: (context, index) {
        final user = users[index];
        return userRow(
          imageUrl: user.imageUrl,
          displayName: user.displayName,
          email: user.email,
          subtitle: user.subtitle,
          avatarSize: avatarSize,
          onTap: onUserTap != null ? () => onUserTap(user) : null,
          trailing: trailingBuilder?.call(user),
          showStatus: showStatus,
          isOnline: user.isOnline,
        );
      },
    );
  }

  /// Optimerad user grid
  static Widget userGrid({
    required List<UserDisplayData> users,
    Function(UserDisplayData)? onUserTap,
    int crossAxisCount = 2,
    double aspectRatio = 1.2,
    ImageSize avatarSize = ImageSize.large,
    EdgeInsets? padding,
    bool shrinkWrap = true,
    ScrollPhysics? physics,
  }) {
    return GridView.builder(
      shrinkWrap: shrinkWrap,
      physics: physics ?? const NeverScrollableScrollPhysics(),
      padding: padding ?? AppTheme.screenPadding,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        crossAxisSpacing: AppTheme.spacingSm,
        mainAxisSpacing: AppTheme.spacingSm,
        childAspectRatio: aspectRatio,
      ),
      itemCount: users.length,
      itemBuilder: (context, index) {
        final user = users[index];
        return userCard(
          imageUrl: user.imageUrl,
          displayName: user.displayName,
          email: user.email,
          subtitle: user.subtitle,
          avatarSize: avatarSize,
          onTap: onUserTap != null ? () => onUserTap(user) : null,
          padding: AppTheme.cardPadding,
        );
      },
    );
  }

  // ===== UTILITY WIDGETS =====

  /// Empty state
  static Widget emptyUserState({
    String title = 'Inga användare',
    String subtitle = 'Inga användare att visa',
    IconData icon = Icons.people_outline,
    VoidCallback? onAction,
    String? actionLabel,
  }) {
    return Center(
      child: Padding(
        padding: AppTheme.screenPadding,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon,
                size: AppTheme.iconSizeEmptyState,
                color: AppTheme.textTertiary),
            AppTheme.mediumGap,
            Text(title,
                style: AppTheme.cardTitleStyle, textAlign: TextAlign.center),
            AppTheme.smallGap,
            Text(subtitle,
                style: AppTheme.subtitleStyle, textAlign: TextAlign.center),
            if (onAction != null && actionLabel != null) ...[
              AppTheme.largeGap,
              ElevatedButton(
                onPressed: onAction,
                style: AppTheme.primaryButtonStyle,
                child: Text(actionLabel),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// Status indicator
  static Widget statusIndicator({
    required bool isOnline,
    double? size,
  }) {
    final indicatorSize = size ?? AppTheme.iconSizeInfo;
    return Container(
      width: indicatorSize,
      height: indicatorSize,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: isOnline ? AppTheme.successColor : AppTheme.textTertiary,
        border:
            Border.all(color: AppTheme.cardColor, width: AppTheme.spacingXxs),
      ),
    );
  }

  /// User badge
  static Widget userBadge({
    required String label,
    Color? backgroundColor,
    Color? textColor,
    EdgeInsets? padding,
  }) {
    return Container(
      padding: padding ??
          EdgeInsets.symmetric(
            horizontal: AppTheme.spacingXs,
            vertical: AppTheme.spacingXs / 2,
          ),
      decoration: BoxDecoration(
        color: backgroundColor ?? AppTheme.primaryColor,
        borderRadius: AppTheme.chipRadius,
      ),
      child: Text(
        label,
        style: AppTheme.chipLabelStyle.copyWith(
          color: textColor ?? AppTheme.cardColor,
        ),
      ),
    );
  }

  // ===== PRIVATE HELPERS =====

  /// Optimerad initials avatar
  static Widget _buildInitialsAvatar(
    String displayName,
    double size,
    Color backgroundColor,
    Color textColor,
  ) {
    final initials = getInitials(displayName);
    final fontSize = size * 0.4;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: backgroundColor,
      ),
      child: Center(
        child: Text(
          initials,
          style: AppTheme.bodyStyle.copyWith(
            fontSize: fontSize,
            fontWeight: FontWeight.w600,
            color: textColor,
            letterSpacing: 0.5,
          ),
        ),
      ),
    );
  }

  /// Optimerad avatar size calculation
  static double _getAvatarSize(ImageSize size) {
    return switch (size) {
      ImageSize.small => AppTheme.iconSizeDisplay, // 32px
      ImageSize.medium => AppTheme.iconSizeHero, // 48px
      ImageSize.large => AppTheme.thumbnailLargeSize, // 80px
      ImageSize.extraLarge => AppTheme.iconSizeEmptyState * 1.875, // 120px
      ImageSize.card => AppTheme.recipeImageSize, // 70px
      ImageSize.hero => AppTheme.imageHeightMedium, // 200px
      ImageSize.thumbnail => AppTheme.thumbnailSize, // 60px
      ImageSize.custom => AppTheme.iconSizeHero, // fallback
    };
  }

  /// Optimerad initials generation
  static String getInitials(String name) {
    if (name.isEmpty) return '?';

    final words = name.trim().split(RegExp(r'\s+'));

    if (words.length == 1) {
      final word = words[0];
      return word.length >= 2
          ? '${word[0]}${word[1]}'.toUpperCase()
          : word[0].toUpperCase();
    } else {
      return '${words[0][0]}${words[1][0]}'.toUpperCase();
    }
  }
}

/// Optimerade Status Helper funktioner
class UserStatusHelper {
  static Color getStatusColor(UserStatus status) {
    return switch (status) {
      UserStatus.online => AppTheme.successColor,
      UserStatus.offline => AppTheme.textTertiary,
      UserStatus.away => AppTheme.warningColor,
      UserStatus.busy => AppTheme.errorColor,
    };
  }

  static String getStatusText(UserStatus status) {
    return switch (status) {
      UserStatus.online => 'Online',
      UserStatus.offline => 'Offline',
      UserStatus.away => 'Frånvarande',
      UserStatus.busy => 'Upptagen',
    };
  }

  static Icon getStatusIcon(UserStatus status, {double? size}) {
    final iconSize = size ?? AppTheme.iconSizeInfo;
    final color = getStatusColor(status);

    return switch (status) {
      UserStatus.online => Icon(Icons.circle, color: color, size: iconSize),
      UserStatus.offline =>
        Icon(Icons.circle_outlined, color: color, size: iconSize),
      UserStatus.away => Icon(Icons.schedule, color: color, size: iconSize),
      UserStatus.busy =>
        Icon(Icons.do_not_disturb, color: color, size: iconSize),
    };
  }
}
