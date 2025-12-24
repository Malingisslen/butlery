import 'package:flutter/material.dart';
import 'package:butlery/models/user_profile.dart';
import 'package:butlery/widgets/user/user_display_widgets.dart' show ImageSize;
import 'package:butlery/widgets/common/social/social_facade.dart';
import 'package:butlery/theme/app_colors.dart';
import 'package:butlery/theme/app_dimensions.dart';

/// Social avatar and user display components.
class SocialAvatarComponents {
  /// Build user avatar.
  static Widget avatar({
    UserProfile? user,
    String? imageUrl,
    String? displayName,
    ImageSize size = ImageSize.medium,
    VoidCallback? onTap,
    bool showOnlineStatus = false,
    bool isOnline = false,
    EdgeInsets? padding,
    Color? backgroundColor,
    bool showBorder = false,
  }) {
    return SocialFacade.avatar(
      user: user,
      imageUrl: imageUrl,
      displayName: displayName,
      size: size,
      onTap: onTap,
      showOnlineStatus: showOnlineStatus,
      isOnline: isOnline,
      padding: padding,
      showBorder: showBorder,
    );
  }

  /// Build user card with avatar and information
  static Widget userCard({
    required UserProfile user,
    VoidCallback? onTap,
    ImageSize avatarSize = ImageSize.medium,
    bool showOnlineStatus = false,
    bool isOnline = false,
    EdgeInsets? padding,
    bool showSubtitle = true,
    String? subtitle,
    Color? backgroundColor,
    bool showBorder = false,
  }) {
    return SocialFacade.userCard(
      user: user,
      onTap: onTap,
      avatarSize: avatarSize,
      showOnlineStatus: showOnlineStatus,
      isOnline: isOnline,
      padding: padding,
      showSubtitle: showSubtitle,
      subtitle: subtitle,
      backgroundColor: backgroundColor,
      showBorder: showBorder,
    );
  }

  /// Build user list tile
  static Widget userListTile({
    required UserProfile user,
    VoidCallback? onTap,
    Widget? trailing,
    ImageSize avatarSize = ImageSize.small,
    bool showOnlineStatus = false,
    bool isOnline = false,
    String? subtitle,
    bool enabled = true,
    Color? backgroundColor,
  }) {
    return SocialFacade.userListTile(
      user: user,
      onTap: onTap,
      trailing: trailing,
      avatarSize: avatarSize,
      showOnlineStatus: showOnlineStatus,
      isOnline: isOnline,
      subtitle: subtitle,
      enabled: enabled,
      backgroundColor: backgroundColor,
    );
  }

  /// Format user display name consistently.
  static String formatUserDisplayName(UserProfile? user) {
    return SocialFacade.formatUserDisplayName(user);
  }

  /// Check if user is currently online
  /// Returns online status for presence indicators
  static bool isUserOnline(UserProfile? user) {
    return SocialFacade.isUserOnline(user);
  }

  /// Get user avatar URL with fallbacks
  /// Returns the best available avatar URL for the user
  static String? getUserAvatarUrl(UserProfile? user) {
    return SocialFacade.getUserAvatarUrl(user);
  }

  /// Build small avatar (typically for lists).
  static Widget smallAvatar({
    UserProfile? user,
    String? imageUrl,
    String? displayName,
    VoidCallback? onTap,
    bool showOnlineStatus = false,
    bool isOnline = false,
  }) {
    return avatar(
      user: user,
      imageUrl: imageUrl,
      displayName: displayName,
      size: ImageSize.small,
      onTap: onTap,
      showOnlineStatus: showOnlineStatus,
      isOnline: isOnline,
    );
  }

  /// Build medium avatar (default size)
  static Widget mediumAvatar({
    UserProfile? user,
    String? imageUrl,
    String? displayName,
    VoidCallback? onTap,
    bool showOnlineStatus = false,
    bool isOnline = false,
  }) {
    return avatar(
      user: user,
      imageUrl: imageUrl,
      displayName: displayName,
      size: ImageSize.medium,
      onTap: onTap,
      showOnlineStatus: showOnlineStatus,
      isOnline: isOnline,
    );
  }

  /// Build large avatar (for profiles and prominent displays)
  static Widget largeAvatar({
    UserProfile? user,
    String? imageUrl,
    String? displayName,
    VoidCallback? onTap,
    bool showOnlineStatus = false,
    bool isOnline = false,
  }) {
    return avatar(
      user: user,
      imageUrl: imageUrl,
      displayName: displayName,
      size: ImageSize.large,
      onTap: onTap,
      showOnlineStatus: showOnlineStatus,
      isOnline: isOnline,
    );
  }

  /// Build compact user card (minimal information).
  static Widget compactUserCard({
    required UserProfile user,
    VoidCallback? onTap,
    bool showOnlineStatus = false,
    bool isOnline = false,
  }) {
    return userCard(
      user: user,
      onTap: onTap,
      avatarSize: ImageSize.small,
      showOnlineStatus: showOnlineStatus,
      isOnline: isOnline,
      showSubtitle: false,
      padding: const EdgeInsets.all(AppDimensions.spacingSm),
    );
  }

  /// Build detailed user card (full information)
  static Widget detailedUserCard({
    required UserProfile user,
    VoidCallback? onTap,
    bool showOnlineStatus = true,
    bool isOnline = false,
    String? customSubtitle,
  }) {
    return userCard(
      user: user,
      onTap: onTap,
      avatarSize: ImageSize.large,
      showOnlineStatus: showOnlineStatus,
      isOnline: isOnline,
      showSubtitle: true,
      subtitle: customSubtitle,
      padding: const EdgeInsets.all(AppDimensions.spacingMd),
      showBorder: true,
    );
  }

  /// Build avatar list for multiple users.
  static Widget avatarList({
    required List<UserProfile> users,
    ImageSize avatarSize = ImageSize.small,
    bool horizontal = true,
    void Function(UserProfile)? onUserTap,
    bool showOnlineStatus = false,
    int? maxUsers,
    String? moreUsersText = '+{count} mer',
  }) {
    final displayUsers = maxUsers != null && users.length > maxUsers
        ? users.take(maxUsers).toList()
        : users;
    
    final remainingCount = maxUsers != null && users.length > maxUsers
        ? users.length - maxUsers
        : 0;

    return horizontal 
        ? _buildHorizontalAvatarList(
            displayUsers, 
            avatarSize, 
            onUserTap, 
            showOnlineStatus,
            remainingCount,
            moreUsersText,
          )
        : _buildVerticalAvatarList(
            displayUsers, 
            avatarSize, 
            onUserTap, 
            showOnlineStatus,
          );
  }

  /// Build horizontal avatar list
  static Widget _buildHorizontalAvatarList(
    List<UserProfile> users,
    ImageSize avatarSize,
    void Function(UserProfile)? onUserTap,
    bool showOnlineStatus,
    int remainingCount,
    String? moreUsersText,
  ) {
    return Row(
      children: [
        ...users.map((user) => Padding(
          padding: const EdgeInsets.only(right: AppDimensions.spacingSm),
          child: avatar(
            user: user,
            size: avatarSize,
            onTap: onUserTap != null ? () => onUserTap(user) : null,
            showOnlineStatus: showOnlineStatus,
            isOnline: isUserOnline(user),
          ),
        )),
        if (remainingCount > 0 && moreUsersText != null)
          Builder(
            builder: (context) => Text(
              moreUsersText.replaceAll('{count}', remainingCount.toString()),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppColors.textMedium,
              ),
            ),
          ),
      ],
    );
  }

  /// Build vertical avatar list
  static Widget _buildVerticalAvatarList(
    List<UserProfile> users,
    ImageSize avatarSize,
    void Function(UserProfile)? onUserTap,
    bool showOnlineStatus,
  ) {
    return Column(
      children: users.map((user) => Padding(
        padding: const EdgeInsets.only(bottom: AppDimensions.spacingSm),
        child: userListTile(
          user: user,
          onTap: onUserTap != null ? () => onUserTap(user) : null,
          avatarSize: avatarSize,
          showOnlineStatus: showOnlineStatus,
          isOnline: isUserOnline(user),
        ),
      )).toList(),
    );
  }

  /// Build avatar with loading state.
  static Widget avatarLoading({
    ImageSize size = ImageSize.medium,
    Color? backgroundColor,
  }) {
    return Container(
      width: _getSizeValue(size),
      height: _getSizeValue(size),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: backgroundColor ?? AppColors.textMedium200,
      ),
      child: const CircularProgressIndicator(),
    );
  }

  /// Build avatar with error state
  static Widget avatarError({
    ImageSize size = ImageSize.medium,
    VoidCallback? onRetry,
    String? errorMessage,
  }) {
    return Container(
      width: _getSizeValue(size),
      height: _getSizeValue(size),
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.red,
      ),
      child: Icon(
        Icons.error,
        size: _getSizeValue(size) * 0.6,
        color: Colors.white,
      ),
    );
  }

  /// Build placeholder avatar (no user data)
  static Widget avatarPlaceholder({
    ImageSize size = ImageSize.medium,
    IconData icon = Icons.person,
    Color? backgroundColor,
    Color? iconColor,
  }) {
    return Container(
      width: _getSizeValue(size),
      height: _getSizeValue(size),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: backgroundColor ?? AppColors.textMedium300,
      ),
      child: Icon(
        icon,
        size: _getSizeValue(size) * 0.6,
        color: iconColor ?? AppColors.textMedium600,
      ),
    );
  }

  /// Helper to convert ImageSize to double
  static double _getSizeValue(ImageSize size) {
    switch (size) {
      case ImageSize.small:
        return 32.0;
      case ImageSize.medium:
        return 48.0;
      case ImageSize.large:
        return 64.0;
      case ImageSize.extraLarge:
        return 96.0;
      case ImageSize.card:
        return 80.0;
      case ImageSize.hero:
        return 120.0;
      case ImageSize.thumbnail:
        return 24.0;
      case ImageSize.custom:
        return 48.0; // Default fallback for custom size
    }
  }
}