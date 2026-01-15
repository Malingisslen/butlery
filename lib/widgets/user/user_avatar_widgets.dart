// lib/widgets/user/user_avatar_widgets.dart
// Avatar rendering and display logic for user components

import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:butlery/theme/app_colors.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/widgets/user/user_display_models.dart';

/// Avatar widgets and related functionality
class UserAvatarWidgets {
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
        backgroundColor ?? AppColors.primaryBlue.withValues(alpha: AppDimensions.opacityVeryLight);
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
                fadeInDuration: AppDimensions.animationDurationCommon,
                fadeOutDuration: AppDimensions.animationDurationCommon,
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
            color: AppColors.transparent,
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
                width: AppDimensions.iconSizeXl,
                height: AppDimensions.iconSizeXl,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.primaryBlue,
                  border: Border.all(
                    color: AppColors.cardWhite,
                    width: AppDimensions.borderWidthThick,
                  ),
                ),
                child: const Icon(
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
        border: Border.all(
            color: AppColors.cardWhite, width: AppDimensions.borderWidthThin),
      ),
    );
  }

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
          style: AppTextStyles.bodyLargeBold.copyWith(
            fontSize: fontSize,
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
      ImageSize.small => AppDimensions.iconSizeS, // 16px
      ImageSize.medium => AppDimensions.iconSizeXxl, // 48px - good for app bars
      ImageSize.large => AppDimensions.imageSizeThumbnail, // 80px
      ImageSize.extraLarge => AppDimensions.thumbnailLargeSize, // 120px
      ImageSize.card => AppDimensions.imageSizeCard, // 150px
      ImageSize.hero => AppDimensions.imageSizeHero, // 400px
      ImageSize.thumbnail => AppDimensions.imageSizeThumbnail, // 80px
      ImageSize.custom => AppDimensions.iconSizeM, // fallback 20px
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
