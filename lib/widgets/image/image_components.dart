// lib/widgets/image/image_components.dart

import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:butlery/theme/app_colors.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/widgets/image/image_config.dart';

/// Shared image components and utilities
class ImageComponents {
  /// Build optimized cached image with memory management
  static Widget buildOptimizedCachedImage({
    required String imageUrl,
    required ImageConfig config,
    BoxFit fit = BoxFit.cover,
    VoidCallback? onTap,
    Widget? placeholder,
    Widget? errorWidget,
  }) {
    final dimensions = config.getDimensions();

    Widget image = CachedNetworkImage(
      imageUrl: imageUrl,
      fit: fit,
      width: dimensions.width == double.infinity ? null : dimensions.width,
      height: dimensions.height,
      memCacheWidth:
          dimensions.width == double.infinity ? 800 : dimensions.width.toInt(),
      memCacheHeight: dimensions.height.toInt(),
      placeholder: placeholder != null ? (_, __) => placeholder : null,
      errorWidget: errorWidget != null ? (_, __, ___) => errorWidget : null,
    );

    if (config.borderRadius != null) {
      image = ClipRRect(
        borderRadius: config.effectiveBorderRadius,
        child: image,
      );
    }

    if (onTap != null) {
      image = _wrapWithTapHandler(image, onTap);
    }

    return image;
  }

  /// Build standard placeholder
  static Widget buildPlaceholder({
    required ImageConfig config,
    Color? backgroundColor,
    Widget? child,
  }) {
    final dimensions = config.getDimensions();

    return Container(
      width: dimensions.width == double.infinity ? null : dimensions.width,
      height: dimensions.height,
      decoration: BoxDecoration(
        color:
            backgroundColor ?? AppColors.backgroundTint, // Lighter background
        borderRadius: config.effectiveBorderRadius,
        border: config.borderColor != null
            ? Border.all(
                color: config.borderColor!,
                width: config.borderWidth ?? 1.0,
              )
            : null,
      ),
      child: child ??
          const Icon(
            Icons.restaurant_menu, // More contextual for recipe images
            size: AppDimensions.iconSizeM, // Much smaller, more elegant
            color: AppColors.textTertiary, // Lighter icon color
          ),
    );
  }

  /// Build loading placeholder with spinner
  static Widget buildLoadingPlaceholder({
    required ImageConfig config,
    Color? backgroundColor,
  }) {
    return buildPlaceholder(
      config: config,
      backgroundColor: backgroundColor,
      child: const Center(
        child: SizedBox(
          width: AppDimensions.iconSizeM,
          height: AppDimensions.iconSizeM,
          child: CircularProgressIndicator(
            strokeWidth: AppDimensions.strokeWidth2,
            valueColor: AlwaysStoppedAnimation<Color>(
              AppColors.primaryBlue,
            ),
          ),
        ),
      ),
    );
  }

  /// Build error placeholder with retry option
  static Widget buildErrorPlaceholder({
    required ImageConfig config,
    VoidCallback? onRetry,
    Color? backgroundColor,
    String? errorMessage,
  }) {
    final dimensions = config.getDimensions();

    final Widget content = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          Icons.error_outline,
          size:
              dimensions.width == double.infinity ? 32 : dimensions.width * 0.3,
          color: AppColors.error,
        ),
        if (errorMessage != null) ...[
          const SizedBox(height: AppDimensions.spacingXs),
          Text(
            errorMessage,
            style: const TextStyle(
              color: AppColors.error,
              fontSize: 12,
            ),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
        if (onRetry != null) ...[
          const SizedBox(height: AppDimensions.spacingXs),
          TextButton(
            onPressed: onRetry,
            child: const Text(
              'Retry',
              style: TextStyle(
                color: AppColors.primaryBlue,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ],
    );

    return buildPlaceholder(
      config: config,
      backgroundColor: backgroundColor,
      child: Center(child: content),
    );
  }

  /// Build multiple image indicator
  static Widget buildMultipleIndicator({
    required int imageCount,
    required ImageConfig config,
  }) {
    if (imageCount <= 1) return const SizedBox.shrink();

    return Positioned(
      top: AppDimensions.spacingSm,
      right: AppDimensions.spacingSm,
      child: Container(
        padding: const EdgeInsets.symmetric(
            horizontal: AppDimensions.spacing6,
            vertical: AppDimensions.spacing2),
        decoration: BoxDecoration(
          color: AppColors.cardWhite.withValues(alpha: 0.9),
          borderRadius: BorderRadius.circular(AppDimensions.borderRadius10),
          border: Border.all(
            color: AppColors.divider,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.collections_outlined,
              size: AppDimensions.iconSizeXs,
              color: AppColors.textPrimary,
            ),
            const SizedBox(width: AppDimensions.spacing2),
            Text(
              '$imageCount',
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w500,
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Build image counter for carousels
  static Widget buildImageCounter({
    required int currentIndex,
    required int totalImages,
    required ImageConfig config,
  }) {
    if (totalImages <= 1) return const SizedBox.shrink();

    return Positioned(
      top: AppDimensions.spacingMd,
      right: AppDimensions.spacingMd,
      child: Container(
        padding: const EdgeInsets.symmetric(
            horizontal: AppDimensions.spacingSm,
            vertical: AppDimensions.spacingXs),
        decoration: BoxDecoration(
          color: AppColors.cardWhite.withValues(alpha: 0.9),
          borderRadius: BorderRadius.circular(AppDimensions.borderRadius12),
          border: Border.all(
            color: AppColors.divider,
          ),
        ),
        child: Text(
          '${currentIndex + 1}/$totalImages',
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: AppColors.textPrimary,
          ),
        ),
      ),
    );
  }

  /// Build navigation dots for carousels
  static Widget buildNavigationDots({
    required int currentIndex,
    required int totalImages,
    required ImageConfig config,
    Function(int)? onDotTap,
  }) {
    if (totalImages <= 1) return const SizedBox.shrink();

    return Positioned(
      bottom: AppDimensions.spacingMd,
      left: 0,
      right: 0,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(
          totalImages,
          (index) => GestureDetector(
            onTap: onDotTap != null ? () => onDotTap(index) : null,
            child: Container(
              width: AppDimensions.dotSize,
              height: AppDimensions.dotSize,
              margin: const EdgeInsets.symmetric(horizontal: AppDimensions.spacingXs),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: index == currentIndex
                    ? AppColors.primaryBlue
                    : AppColors.cardWhite.withValues(alpha: 0.6),
                border: Border.all(
                  color: AppColors.divider,
                  width: AppDimensions.strokeWidth05,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Build status indicator for avatars
  static Widget buildStatusIndicator({
    required bool isOnline,
    required ImageConfig config,
  }) {
    if (!config.showStatusIndicator) return const SizedBox.shrink();

    final dimensions = config.getDimensions();
    final indicatorSize = dimensions.width * 0.25;

    return Positioned(
      bottom: 0,
      right: 0,
      child: Container(
        width: indicatorSize,
        height: indicatorSize,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: isOnline ? AppColors.success : AppColors.textSecondary,
          border: Border.all(
            color: AppColors.cardWhite,
            width: AppDimensions.strokeWidth2,
          ),
        ),
      ),
    );
  }

  /// Wrap widget with tap handler
  static Widget _wrapWithTapHandler(Widget child, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: child,
    );
  }
}
