// lib/widgets/user/user_avatar_widgets.dart
// Avatar rendering and display logic for user components

import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:butlery/core/utils/firebase_url_utils.dart';
import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/theme/butlery_colors_extension.dart';
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
    return Builder(
      builder: (context) {
        final cs = Theme.of(context).colorScheme;
        final bc = context.butleryColors;
        final avatarSize = _getAvatarSize(size);
        // UI Redesign: Avatar uses rust (secondary) color scheme
        final effectiveBackgroundColor = backgroundColor ?? cs.secondary;
        final effectiveTextColor = textColor ?? cs.surfaceContainerHighest;

        Widget avatarWidget = Container(
          width: avatarSize,
          height: avatarSize,
          decoration: BoxDecoration(
            color: effectiveBackgroundColor,
            border: borderWidth != null && borderColor != null
                ? Border.all(width: borderWidth, color: borderColor)
                : null,
          ),
          child: (imageUrl != null && imageUrl.isNotEmpty)
              ? ClipRect(
                  child: CachedNetworkImage(
                    imageUrl: imageUrl,
                    cacheKey: FirebaseUrlUtils.stableCacheKey(imageUrl),
                    width: avatarSize,
                    height: avatarSize,
                    fit: BoxFit.cover,
                    alignment: Alignment.center,
                    placeholder: (_, url) => _buildInitialsAvatar(
                        displayName,
                        avatarSize,
                        effectiveBackgroundColor,
                        effectiveTextColor),
                    errorWidget: (_, url, error) => _buildInitialsAvatar(
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
          avatarWidget = Stack(
            children: [
              avatarWidget,
              Positioned(
                right: 0,
                bottom: 0,
                child: Container(
                  width: avatarSize * 0.25,
                  height: avatarSize * 0.25,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isOnline ? bc.success : cs.outline,
                    border: Border.all(
                      color: cs.surfaceContainerHighest,
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
                child: Semantics(
                  label: context.l10n.a11yProfileImage(displayName),
                  button: true,
                  child: InkWell(
                    onTap: onTap,
                    borderRadius: BorderRadius.zero,
                    child: avatarWidget,
                  ),
                ),
              )
            : avatarWidget;
      },
    );
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
    return Builder(
      builder: (context) {
        final cs = Theme.of(context).colorScheme;
        return Stack(
          children: [
            avatar(
              imageUrl: imageUrl,
              displayName: displayName,
              size: size,
              borderColor: borderColor ?? cs.primary,
              borderWidth: borderWidth ?? AppDimensions.spacingXs,
            ),
            Positioned(
              right: 0,
              bottom: 0,
              child: Material(
                color: cs.primary,
                shape: const CircleBorder(),
                child: Semantics(
                  label: context.l10n.a11yChangeProfileImage,
                  button: true,
                  child: InkWell(
                    onTap: onEditTap,
                    borderRadius:
                        BorderRadius.circular(AppDimensions.borderRadiusL),
                    child: Container(
                      width: AppDimensions.iconSizeXl,
                      height: AppDimensions.iconSizeXl,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: cs.primary,
                        border: Border.all(
                          color: cs.surfaceContainerHighest,
                          width: AppDimensions.borderWidthThick,
                        ),
                      ),
                      child: Icon(
                        Icons.edit,
                        size: AppDimensions.iconSizeM,
                        color: cs.surfaceContainerHighest,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  /// Status indicator
  static Widget statusIndicator({
    required bool isOnline,
    double? size,
  }) {
    return Builder(
      builder: (context) {
        final cs = Theme.of(context).colorScheme;
        final bc = context.butleryColors;
        final indicatorSize = size ?? AppDimensions.iconSizeM;
        return Container(
          width: indicatorSize,
          height: indicatorSize,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isOnline ? bc.success : cs.outline,
            border: Border.all(
                color: cs.surfaceContainerHighest,
                width: AppDimensions.borderWidthThin),
          ),
        );
      },
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
