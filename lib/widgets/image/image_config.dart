// lib/widgets/image/image_config.dart

import 'package:flutter/material.dart';
import 'package:butlery/theme/app_dimensions.dart';

/// Typ av image-hantering
enum ImageType {
  avatar,
  recipeCard,
  recipeDetail,
  recipeEdit,
  gallery,
  picker,
  hero,
  thumbnail,
  cached,
}

/// Display mode for image manager
enum ImageDisplayMode {
  readonly,
  editable,
  expandable,
  carousel,
  grid,
  picker,
}

/// Size for image display
enum ImageSize {
  small,
  medium,
  large,
  extraLarge,
  card,
  hero,
  thumbnail,
  picker,
  custom,
}

/// Optimized configuration for ImageManager
class ImageConfig {
  final ImageType type;
  final ImageDisplayMode mode;
  final ImageSize size;
  final double? customWidth;
  final double? customHeight;
  final BorderRadius? borderRadius;
  final bool showPlaceholder;
  final bool showLoadingIndicator;
  final bool showMultipleIndicator;
  final bool showEditControls;
  final bool showStatusIndicator;
  final bool showNavigationDots;
  final bool showImageCounter;
  final bool enableHapticFeedback;
  final int maxImages;
  final String? heroTag;

  /// Generates a stable Hero tag for recipe image transitions.
  static String recipeHeroTag(String recipeId) => 'recipe-image-$recipeId';

  final Color? backgroundColor;
  final Color? borderColor;
  final double? borderWidth;

  const ImageConfig({
    required this.type,
    this.mode = ImageDisplayMode.readonly,
    this.size = ImageSize.medium,
    this.customWidth,
    this.customHeight,
    this.borderRadius,
    this.showPlaceholder = true,
    this.showLoadingIndicator = true,
    this.showMultipleIndicator = true,
    this.showEditControls = true,
    this.showStatusIndicator = false,
    this.showNavigationDots = true,
    this.showImageCounter = true,
    this.enableHapticFeedback = true,
    this.maxImages = 5,
    this.heroTag,
    this.backgroundColor,
    this.borderColor,
    this.borderWidth,
  });

  /// Factory constructors med korrekta defaults
  factory ImageConfig.avatar({
    ImageSize size = ImageSize.medium,
    bool showStatus = false,
    Color? borderColor,
    double? borderWidth,
    Color? backgroundColor,
  }) {
    return ImageConfig(
      type: ImageType.avatar,
      mode: ImageDisplayMode.readonly,
      size: size,
      showPlaceholder: true,
      showLoadingIndicator: true,
      showMultipleIndicator: false,
      showEditControls: false,
      showStatusIndicator: showStatus,
      showNavigationDots: false,
      showImageCounter: false,
      enableHapticFeedback: false,
      maxImages: 1,
      borderRadius: BorderRadius.circular(AppDimensions.borderRadius100),
      backgroundColor: backgroundColor,
      borderColor: borderColor,
      borderWidth: borderWidth,
    );
  }

  factory ImageConfig.recipeCard({
    ImageSize size = ImageSize.card,
    bool showMultipleIndicator = true,
    bool showEditControls = false,
    double? customWidth,
    double? customHeight,
    BorderRadius? borderRadius,
  }) {
    return ImageConfig(
      type: ImageType.recipeCard,
      mode: ImageDisplayMode.readonly,
      size: size,
      customWidth: customWidth,
      customHeight: customHeight,
      borderRadius:
          borderRadius ?? BorderRadius.circular(AppDimensions.borderRadius12),
      showPlaceholder: true,
      showLoadingIndicator: true,
      showMultipleIndicator: showMultipleIndicator,
      showEditControls: showEditControls,
      showStatusIndicator: false,
      showNavigationDots: false,
      showImageCounter: false,
      enableHapticFeedback: true,
      maxImages: 5,
    );
  }

  factory ImageConfig.recipeDetail({
    ImageSize size = ImageSize.large,
    bool showNavigationDots = true,
    bool showImageCounter = true,
    String? heroTag,
  }) {
    return ImageConfig(
      type: ImageType.recipeDetail,
      mode: ImageDisplayMode.carousel,
      size: size,
      borderRadius: BorderRadius.circular(AppDimensions.borderRadius16),
      showPlaceholder: true,
      showLoadingIndicator: true,
      showMultipleIndicator: false,
      showEditControls: false,
      showStatusIndicator: false,
      showNavigationDots: showNavigationDots,
      showImageCounter: showImageCounter,
      enableHapticFeedback: true,
      maxImages: 5,
      heroTag: heroTag,
    );
  }

  factory ImageConfig.recipeEdit({
    ImageSize size = ImageSize.large,
    bool showEditControls = true,
    bool showNavigationDots = true,
    int maxImages = 5,
  }) {
    return ImageConfig(
      type: ImageType.recipeEdit,
      mode: ImageDisplayMode.editable,
      size: size,
      borderRadius: BorderRadius.circular(AppDimensions.borderRadius16),
      showPlaceholder: true,
      showLoadingIndicator: true,
      showMultipleIndicator: false,
      showEditControls: showEditControls,
      showStatusIndicator: false,
      showNavigationDots: showNavigationDots,
      showImageCounter: true,
      enableHapticFeedback: true,
      maxImages: maxImages,
    );
  }

  factory ImageConfig.gallery({
    ImageSize size = ImageSize.thumbnail,
    bool showEditControls = false,
  }) {
    return ImageConfig(
      type: ImageType.gallery,
      mode: ImageDisplayMode.grid,
      size: size,
      borderRadius: BorderRadius.circular(AppDimensions.borderRadius8),
      showPlaceholder: true,
      showLoadingIndicator: true,
      showMultipleIndicator: false,
      showEditControls: showEditControls,
      showStatusIndicator: false,
      showNavigationDots: false,
      showImageCounter: false,
      enableHapticFeedback: true,
      maxImages: 50,
    );
  }

  factory ImageConfig.picker({
    ImageSize size = ImageSize.picker,
    int maxImages = 5,
  }) {
    return ImageConfig(
      type: ImageType.picker,
      mode: ImageDisplayMode.picker,
      size: size,
      borderRadius: BorderRadius.circular(AppDimensions.borderRadius12),
      showPlaceholder: true,
      showLoadingIndicator: true,
      showMultipleIndicator: false,
      showEditControls: true,
      showStatusIndicator: false,
      showNavigationDots: false,
      showImageCounter: false,
      enableHapticFeedback: true,
      maxImages: maxImages,
    );
  }

  factory ImageConfig.hero({
    String? heroTag,
    double? customWidth,
    double? customHeight,
    BorderRadius? borderRadius,
  }) {
    return ImageConfig(
      type: ImageType.hero,
      mode: ImageDisplayMode.expandable,
      size: ImageSize.hero,
      customWidth: customWidth,
      customHeight: customHeight,
      borderRadius: borderRadius,
      showPlaceholder: true,
      showLoadingIndicator: true,
      showMultipleIndicator: false,
      showEditControls: false,
      showStatusIndicator: false,
      showNavigationDots: false,
      showImageCounter: false,
      enableHapticFeedback: true,
      maxImages: 1,
      heroTag: heroTag,
    );
  }

  factory ImageConfig.thumbnail({
    ImageSize size = ImageSize.thumbnail,
    BorderRadius? borderRadius,
    String? heroTag,
  }) {
    return ImageConfig(
      type: ImageType.thumbnail,
      mode: ImageDisplayMode.readonly,
      size: size,
      borderRadius:
          borderRadius ?? BorderRadius.circular(AppDimensions.borderRadius8),
      showPlaceholder: true,
      showLoadingIndicator: true,
      showMultipleIndicator: false,
      showEditControls: false,
      showStatusIndicator: false,
      showNavigationDots: false,
      showImageCounter: false,
      enableHapticFeedback: false,
      maxImages: 1,
      heroTag: heroTag,
    );
  }

  factory ImageConfig.cached({
    ImageSize size = ImageSize.medium,
    double? customWidth,
    double? customHeight,
    BorderRadius? borderRadius,
  }) {
    return ImageConfig(
      type: ImageType.cached,
      mode: ImageDisplayMode.readonly,
      size: size,
      customWidth: customWidth,
      customHeight: customHeight,
      borderRadius: borderRadius,
      showPlaceholder: true,
      showLoadingIndicator: true,
      showMultipleIndicator: false,
      showEditControls: false,
      showStatusIndicator: false,
      showNavigationDots: false,
      showImageCounter: false,
      enableHapticFeedback: false,
      maxImages: 1,
    );
  }

  /// Get dimensions based on size
  Size getDimensions() {
    switch (size) {
      case ImageSize.small:
        return const Size(40, 40);
      case ImageSize.medium:
        return const Size(80, 80);
      case ImageSize.large:
        // RESTORED: Fully responsive sizing - both width and height flexible for aspect ratio preservation
        return const Size(double.infinity, double.infinity);
      case ImageSize.extraLarge:
        return const Size(160, 160);
      case ImageSize.card:
        return const Size(200, 140);
      case ImageSize.hero:
        return const Size(double.infinity, 300);
      case ImageSize.thumbnail:
        return const Size(60, 60);
      case ImageSize.picker:
        // Compact size specifically for empty image picker - prevents oversized empty state
        return const Size(double.infinity, 120);
      case ImageSize.custom:
        return Size(customWidth ?? 80, customHeight ?? 80);
    }
  }

  /// Get aspect ratio
  double getAspectRatio() {
    final dimensions = getDimensions();
    if (dimensions.width == double.infinity) {
      return 16 / 9; // Default aspect ratio for responsive images
    }
    return dimensions.width / dimensions.height;
  }

  /// Check if image is square
  bool get isSquare {
    final dimensions = getDimensions();
    return dimensions.width == dimensions.height;
  }

  /// Get border radius with fallback
  BorderRadius get effectiveBorderRadius {
    if (borderRadius != null) return borderRadius!;

    switch (type) {
      case ImageType.avatar:
        return BorderRadius.circular(AppDimensions.borderRadius100);
      case ImageType.recipeCard:
        return BorderRadius.circular(AppDimensions.borderRadius12);
      case ImageType.recipeDetail:
      case ImageType.recipeEdit:
        return BorderRadius.circular(AppDimensions.borderRadius16);
      case ImageType.gallery:
      case ImageType.thumbnail:
        return BorderRadius.circular(AppDimensions.borderRadius8);
      case ImageType.picker:
        return BorderRadius.circular(AppDimensions.borderRadius12);
      case ImageType.hero:
      case ImageType.cached:
        return BorderRadius.circular(AppDimensions.borderRadius0);
    }
  }
}
