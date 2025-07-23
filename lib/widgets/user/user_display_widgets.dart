// lib/widgets/user/user_display_widgets.dart - OPTIMERAD VERSION
// ✅ INGA backwards compatibility aliases - Clean & Efficient
// ✅ 100% AppTheme - Optimerad performance utan funktionalitetsförlust


import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../theme/app_dimensions.dart';

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
        backgroundColor ?? AppColors.primaryBlue.withValues(alpha: 0.1);
    final effectiveTextColor = textColor ?? AppColors.primaryBlue;

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
                alignment: Alignment.center,
                placeholder: (context, url) => _buildInitialsAvatar(displayName,
                    avatarSize, effectiveBackgroundColor, effectiveTextColor),
                errorWidget: (context, url, error) => _buildInitialsAvatar(
                    displayName,
                    avatarSize,
                    effectiveBackgroundColor,
                    effectiveTextColor),
                fadeInDuration: const Duration(milliseconds: 300),
                fadeOutDuration: const Duration(milliseconds: 300),
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
                color: isOnline ? AppColors.success : AppColors.textTertiary,
                border: Border.all(
                  color: AppColors.cardWhite,
                  width: AppDimensions.borderWidthThin,
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
          borderColor: borderColor ?? AppColors.primaryBlue,
          borderWidth: borderWidth ?? AppDimensions.spacingXs,
        ),
        Positioned(
          right: 0,
          bottom: 0,
          child: Material(
            color: AppColors.primaryBlue,
            shape: const CircleBorder(),
            child: InkWell(
              onTap: onEditTap,
              borderRadius: BorderRadius.circular(AppDimensions.borderRadiusL),
              child: Container(
                width: AppDimensions.iconSizeS,
                height: AppDimensions.iconSizeS,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.primaryBlue,
                  border: Border.all(
                    color: AppColors.cardWhite,
                    width: AppDimensions.borderWidthThin,
                  ),
                ),
                child: Icon(
                  Icons.edit,
                  size: AppDimensions.iconSizeM,
                  color: AppColors.cardWhite,
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
        style: style ?? AppTextStyles.titleMedium,
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
        style: style ?? AppTextStyles.titleMedium,
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
          const SizedBox(height: AppDimensions.spacingXs),
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
      borderRadius: BorderRadius.circular(AppDimensions.borderRadiusM),
      child: Padding(
        padding: padding ?? EdgeInsets.all(AppDimensions.paddingL),
        child: Row(
          children: [
            avatar(
              imageUrl: imageUrl,
              displayName: displayName,
              size: avatarSize,
              showStatus: showStatus,
              isOnline: isOnline,
            ),
            SizedBox(width: AppDimensions.spacingM),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  userName(displayName: displayName),
                  if (email != null) ...[
                    const SizedBox(height: AppDimensions.spacingXs),
                    userEmail(email: email),
                  ],
                  if (subtitle != null) ...[
                    const SizedBox(height: AppDimensions.spacingXs),
                    Text(subtitle, style: AppTextStyles.bodySmall),
                  ],
                ],
              ),
            ),
            if (trailing != null) ...[
              const SizedBox(width: AppDimensions.spacingM),
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
      margin: margin ?? const EdgeInsets.all(AppDimensions.paddingL),
      elevation: AppDimensions.elevationLow,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppDimensions.borderRadiusL)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppDimensions.borderRadiusL),
        child: Padding(
          padding: padding ?? const EdgeInsets.all(AppDimensions.paddingL),
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
                  SizedBox(width: AppDimensions.spacingM),
                  Expanded(
                      child: userInfo(displayName: displayName, email: email)),
                ],
              ),
              if (subtitle != null) ...[
                const SizedBox(height: AppDimensions.spacingM),
                Text(subtitle, style: AppTextStyles.titleMedium),
              ],
              if (description != null) ...[
                const SizedBox(height: AppDimensions.spacingM),
                Text(description, style: AppTextStyles.bodyLarge),
              ],
              if (actions != null) ...[
                const SizedBox(height: AppDimensions.spacingXl),
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
      padding: padding ?? EdgeInsets.all(AppDimensions.paddingL),
      itemCount: users.length,
      separatorBuilder: (context, index) => const SizedBox(height: AppDimensions.spacingM),
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
      padding: padding ?? EdgeInsets.all(AppDimensions.paddingL),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        crossAxisSpacing: AppDimensions.spacingS,
        mainAxisSpacing: AppDimensions.spacingS,
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
          padding: const EdgeInsets.all(AppDimensions.paddingL),
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
        padding: EdgeInsets.all(AppDimensions.paddingL),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon,
                size: AppDimensions.iconSizeXl,
                color: AppColors.textTertiary),
            const SizedBox(height: AppDimensions.spacingXl),
            Text(title,
                style: AppTextStyles.titleMedium, textAlign: TextAlign.center),
            const SizedBox(height: AppDimensions.spacingM),
            Text(subtitle,
                style: AppTextStyles.titleMedium, textAlign: TextAlign.center),
            if (onAction != null && actionLabel != null) ...[
              SizedBox(height: AppDimensions.spacingXl),
              ElevatedButton(
                onPressed: onAction,
                style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primaryBlue,
            foregroundColor: AppColors.cardWhite,
          ),
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
    final indicatorSize = size ?? AppDimensions.iconSizeM;
    return Container(
      width: indicatorSize,
      height: indicatorSize,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: isOnline ? AppColors.success : AppColors.textTertiary,
        border:
            Border.all(color: AppColors.cardWhite, width: AppDimensions.borderWidthThin),
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
            horizontal: AppDimensions.spacingXs,
            vertical: AppDimensions.spacingXs / 2,
          ),
      decoration: BoxDecoration(
        color: backgroundColor ?? AppColors.primaryBlue,
        borderRadius: BorderRadius.circular(AppDimensions.borderRadiusS),
      ),
      child: Text(
        label,
        style: AppTextStyles.labelSmall.copyWith(
          color: textColor ?? AppColors.cardWhite,
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
          style: AppTextStyles.bodyLarge.copyWith(
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
      ImageSize.small => AppDimensions.iconSizeS, // 32px
      ImageSize.medium => AppDimensions.iconSizeM, // 48px
      ImageSize.large => AppDimensions.imageSizeLarge, // 80px
      ImageSize.extraLarge => AppDimensions.iconSizeXl * 1.875, // 120px
      ImageSize.card => AppDimensions.imageSizeCard, // 70px
      ImageSize.hero => AppDimensions.imageSizeHero, // 200px
      ImageSize.thumbnail => AppDimensions.imageSizeThumbnail, // 60px
      ImageSize.custom => AppDimensions.iconSizeM, // fallback
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
      UserStatus.online => AppColors.success,
      UserStatus.offline => AppColors.textTertiary,
      UserStatus.away => AppColors.warning,
      UserStatus.busy => AppColors.error,
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
    final iconSize = size ?? AppDimensions.iconSizeM;
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
