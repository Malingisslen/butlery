/// Platform badge widget showing detected platform with icon.
///
/// Displays the platform icon and Swedish label for detected input type
/// (YouTube, TikTok, Instagram, Website, or Text).
library;

import 'package:flutter/material.dart';
import 'package:butlery/services/import/input_detector.dart';
import 'package:butlery/theme/brand_colors.dart';
import 'package:butlery/theme/app_dimensions.dart';

/// Badge showing detected platform from user input.
class PlatformBadgeWidget extends StatelessWidget {
  /// The detection result from InputDetector.
  final InputDetectionResult? detection;

  /// Whether to show the badge (hidden when detection is null).
  final bool isVisible;

  const PlatformBadgeWidget({
    super.key,
    required this.detection,
    this.isVisible = true,
  });

  @override
  Widget build(BuildContext context) {
    if (!isVisible || detection == null || detection!.input.isEmpty) {
      return const SizedBox.shrink();
    }

    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return AnimatedOpacity(
      duration: AppDimensions.animationDurationMedium,
      opacity: isVisible ? 1.0 : 0.0,
      child: Container(
        padding: AppDimensions.paddingSymmetric12x6,
        decoration: BoxDecoration(
          color: _getBackgroundColor(detection!.platform, colorScheme),
          borderRadius: BorderRadius.circular(AppDimensions.borderRadius16),
          border: Border.all(
            color: _getBorderColor(detection!.platform, colorScheme),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              _getIconForPlatform(detection!.platform),
              size: AppDimensions.iconSizeS,
              color: _getIconColor(detection!.platform, colorScheme),
            ),
            const SizedBox(width: AppDimensions.spacing6),
            Text(
              detection!.platformLabel,
              style: theme.textTheme.labelMedium?.copyWith(
                color: _getTextColor(detection!.platform, colorScheme),
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _getIconForPlatform(Platform platform) {
    switch (platform) {
      case Platform.youtube:
        return Icons.play_circle_outline;
      case Platform.tiktok:
        return Icons.music_note;
      case Platform.instagram:
        return Icons.camera_alt_outlined;
      case Platform.website:
        return Icons.language;
      case Platform.unknown:
        return Icons.text_snippet_outlined;
    }
  }

  Color _getBackgroundColor(Platform platform, ColorScheme colorScheme) {
    switch (platform) {
      case Platform.youtube:
        return BrandColors.youtubeBackground;
      case Platform.tiktok:
        return BrandColors.tiktokBackground;
      case Platform.instagram:
        return BrandColors.instagramBackground;
      case Platform.website:
        return colorScheme.primaryContainer.withValues(alpha: AppDimensions.opacityHalf);
      case Platform.unknown:
        return colorScheme.surfaceContainerHighest;
    }
  }

  Color _getBorderColor(Platform platform, ColorScheme colorScheme) {
    switch (platform) {
      case Platform.youtube:
        return BrandColors.youtube.withValues(alpha: AppDimensions.opacityMediumLight);
      case Platform.tiktok:
        return BrandColors.tiktok.withValues(alpha: AppDimensions.opacityHalf);
      case Platform.instagram:
        return BrandColors.instagram.withValues(alpha: AppDimensions.opacityMediumLight);
      case Platform.website:
        return colorScheme.primary.withValues(alpha: AppDimensions.opacityMediumLight);
      case Platform.unknown:
        return colorScheme.outline.withValues(alpha: AppDimensions.opacityHalf);
    }
  }

  Color _getIconColor(Platform platform, ColorScheme colorScheme) {
    switch (platform) {
      case Platform.youtube:
        return BrandColors.youtube;
      case Platform.tiktok:
        return BrandColors.tiktokText;
      case Platform.instagram:
        return BrandColors.instagram;
      case Platform.website:
        return colorScheme.primary;
      case Platform.unknown:
        return colorScheme.onSurfaceVariant;
    }
  }

  Color _getTextColor(Platform platform, ColorScheme colorScheme) {
    switch (platform) {
      case Platform.youtube:
        return BrandColors.youtubeText;
      case Platform.tiktok:
        return BrandColors.tiktokText;
      case Platform.instagram:
        return BrandColors.instagramText;
      case Platform.website:
        return colorScheme.onPrimaryContainer;
      case Platform.unknown:
        return colorScheme.onSurfaceVariant;
    }
  }
}

/// Compact platform icon for inline display.
class PlatformIconWidget extends StatelessWidget {
  /// The platform to display.
  final Platform platform;

  /// Icon size.
  final double size;

  const PlatformIconWidget({
    super.key,
    required this.platform,
    this.size = 20,
  });

  @override
  Widget build(BuildContext context) {
    return Icon(
      _getIconForPlatform(platform),
      size: size,
      color: _getIconColor(platform, Theme.of(context).colorScheme),
    );
  }

  IconData _getIconForPlatform(Platform platform) {
    switch (platform) {
      case Platform.youtube:
        return Icons.play_circle_outline;
      case Platform.tiktok:
        return Icons.music_note;
      case Platform.instagram:
        return Icons.camera_alt_outlined;
      case Platform.website:
        return Icons.language;
      case Platform.unknown:
        return Icons.text_snippet_outlined;
    }
  }

  Color _getIconColor(Platform platform, ColorScheme colorScheme) {
    switch (platform) {
      case Platform.youtube:
        return BrandColors.youtube;
      case Platform.tiktok:
        return BrandColors.tiktokText;
      case Platform.instagram:
        return BrandColors.instagram;
      case Platform.website:
        return colorScheme.primary;
      case Platform.unknown:
        return colorScheme.onSurfaceVariant;
    }
  }
}
