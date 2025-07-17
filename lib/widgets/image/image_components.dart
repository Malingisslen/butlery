// lib/widgets/image/image_components.dart

import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../theme/app_theme.dart';
import 'image_config.dart';

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
      memCacheWidth: dimensions.width == double.infinity ? 800 : dimensions.width.toInt(),
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
        color: backgroundColor ?? AppTheme.cardColor,
        borderRadius: config.effectiveBorderRadius,
        border: config.borderColor != null
            ? Border.all(
                color: config.borderColor!,
                width: config.borderWidth ?? 1.0,
              )
            : null,
      ),
      child: child ??
          Icon(
            Icons.image_outlined,
            size: dimensions.width == double.infinity ? 48 : dimensions.width * 0.4,
            color: AppTheme.textSecondary,
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
          width: 24,
          height: 24,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            valueColor: AlwaysStoppedAnimation<Color>(
              AppTheme.primaryColor,
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
    
    Widget content = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          Icons.error_outline,
          size: dimensions.width == double.infinity ? 32 : dimensions.width * 0.3,
          color: AppTheme.errorColor,
        ),
        if (errorMessage != null) ...[
          const SizedBox(height: 4),
          Text(
            errorMessage,
            style: const TextStyle(
              color: AppTheme.errorColor,
              fontSize: 12,
            ),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
        if (onRetry != null) ...[
          const SizedBox(height: 4),
          TextButton(
            onPressed: onRetry,
            child: const Text(
              'Retry',
              style: TextStyle(
                color: AppTheme.primaryColor,
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
      top: 8,
      right: 8,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: AppTheme.cardColor.withValues(alpha: 0.9),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: AppTheme.dividerColor,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.collections_outlined,
              size: 12,
              color: AppTheme.textPrimary,
            ),
            const SizedBox(width: 2),
            Text(
              '$imageCount',
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w500,
                color: AppTheme.textPrimary,
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
      top: 16,
      right: 16,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: AppTheme.cardColor.withValues(alpha: 0.9),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: AppTheme.dividerColor,
          ),
        ),
        child: Text(
          '${currentIndex + 1}/$totalImages',
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: AppTheme.textPrimary,
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
      bottom: 16,
      left: 0,
      right: 0,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(
          totalImages,
          (index) => GestureDetector(
            onTap: onDotTap != null ? () => onDotTap(index) : null,
            child: Container(
              width: 8,
              height: 8,
              margin: const EdgeInsets.symmetric(horizontal: 4),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: index == currentIndex
                    ? AppTheme.primaryColor
                    : AppTheme.cardColor.withValues(alpha: 0.6),
                border: Border.all(
                  color: AppTheme.dividerColor,
                  width: 0.5,
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
          color: isOnline ? AppTheme.successColor : AppTheme.textSecondary,
          border: Border.all(
            color: AppTheme.cardColor,
            width: 2,
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