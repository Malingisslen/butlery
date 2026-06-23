// lib/widgets/image/image_gallery_widget.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/widgets/image/image_config.dart';
import 'package:butlery/widgets/image/image_components.dart';

/// Image gallery widget for grid display
class ImageGalleryWidget extends StatefulWidget {
  final List<String> imageUrls;
  final ImageConfig config;
  final Function(int)? onImageTap;
  final Function(String)? onImageLongPress;
  final Function()? onAddImage;
  final bool showAddButton;
  final int crossAxisCount;
  final double crossAxisSpacing;
  final double mainAxisSpacing;
  final double childAspectRatio;

  const ImageGalleryWidget({
    super.key,
    required this.imageUrls,
    required this.config,
    this.onImageTap,
    this.onImageLongPress,
    this.onAddImage,
    this.showAddButton = false,
    this.crossAxisCount = 3,
    this.crossAxisSpacing = AppDimensions.spacingSm,
    this.mainAxisSpacing = AppDimensions.spacingSm,
    this.childAspectRatio = 1.0,
  });

  /// Factory constructor for gallery
  factory ImageGalleryWidget.gallery({
    Key? key,
    required List<String> imageUrls,
    ImageSize size = ImageSize.thumbnail,
    bool showEditControls = false,
    Function(int)? onImageTap,
    Function(String)? onImageLongPress,
    Function()? onAddImage,
    bool showAddButton = false,
    int crossAxisCount = 3,
    double crossAxisSpacing = AppDimensions.spacingSm,
    double mainAxisSpacing = AppDimensions.spacingSm,
    double childAspectRatio = 1.0,
  }) {
    return ImageGalleryWidget(
      key: key,
      imageUrls: imageUrls,
      config: ImageConfig.gallery(
        size: size,
        showEditControls: showEditControls,
      ),
      onImageTap: onImageTap,
      onImageLongPress: onImageLongPress,
      onAddImage: onAddImage,
      showAddButton: showAddButton,
      crossAxisCount: crossAxisCount,
      crossAxisSpacing: crossAxisSpacing,
      mainAxisSpacing: mainAxisSpacing,
      childAspectRatio: childAspectRatio,
    );
  }

  @override
  State<ImageGalleryWidget> createState() => _ImageGalleryWidgetState();
}

class _ImageGalleryWidgetState extends State<ImageGalleryWidget> {
  final Set<String> _selectedImages = <String>{};
  bool _isSelectionMode = false;

  @override
  Widget build(BuildContext context) {
    // Remove unused theme variable
    final hasImages = widget.imageUrls.isNotEmpty;
    final totalItems = widget.imageUrls.length + (widget.showAddButton ? 1 : 0);

    if (!hasImages && !widget.showAddButton) {
      return _buildEmptyGallery();
    }

    return Column(
      children: [
        // Selection mode header
        if (_isSelectionMode) _buildSelectionHeader(),

        // Gallery grid
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          cacheExtent:
              2000, // Performance optimization: cache more items for smooth scrolling
          addRepaintBoundaries: true, // Optimization: reduce repaints
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: widget.crossAxisCount,
            crossAxisSpacing: widget.crossAxisSpacing,
            mainAxisSpacing: widget.mainAxisSpacing,
            childAspectRatio: widget.childAspectRatio,
          ),
          itemCount: totalItems,
          itemBuilder: (context, index) {
            if (widget.showAddButton && index == widget.imageUrls.length) {
              return _buildAddImageButton();
            }

            final imageUrl = widget.imageUrls[index];
            return _buildGalleryImage(imageUrl, index);
          },
        ),
      ],
    );
  }

  /// Build empty gallery state
  Widget _buildEmptyGallery() {
    final cs = Theme.of(context).colorScheme;

    return Container(
      height: AppDimensions.minHeightLarge,
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: widget.config.effectiveBorderRadius,
        border: Border.all(
          color: cs.outlineVariant.withValues(
            alpha: AppDimensions.opacityMediumLight,
          ),
        ),
        color: cs.surfaceContainerHighest,
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.photo_library_outlined,
              size: AppDimensions.iconSizeXxl,
              color: cs.onSurface.withValues(
                alpha: AppDimensions.opacityMedium,
              ),
            ),
            const SizedBox(
              height: (AppDimensions.spacingSm + AppDimensions.spacingXs),
            ),
            Text(
              context.l10n.imageNoImagesYet,
              style: AppTextStyles.bodyLarge.copyWith(
                color: cs.onSurface.withValues(
                  alpha: AppDimensions.opacityMediumDark,
                ),
              ),
            ),
            const SizedBox(height: AppDimensions.spacingXs),
            Text(
              context.l10n.imageWillAppearHere,
              style: AppTextStyles.bodyMedium.copyWith(
                color: cs.onSurface.withValues(
                  alpha: AppDimensions.opacityMedium,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Build selection mode header
  Widget _buildSelectionHeader() {
    final cs = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(AppDimensions.spacingMd),
      decoration: BoxDecoration(
        color: cs.primary,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(AppDimensions.borderRadius16),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.check_circle,
            color: cs.onPrimary,
          ),
          const SizedBox(width: AppDimensions.spacingSm),
          Text(
            context.l10n.imageCountSelected(_selectedImages.length),
            style: AppTextStyles.contentTitle.copyWith(
              color: cs.onPrimary,
            ),
          ),
          const Spacer(),
          TextButton(
            onPressed: _exitSelectionMode,
            child: Text(
              context.l10n.commonCancel,
              style: AppTextStyles.bodyMedium.copyWith(
                color: cs.onPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Build add image button
  Widget _buildAddImageButton() {
    final cs = Theme.of(context).colorScheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: widget.config.effectiveBorderRadius,
        border: Border.all(
          color: cs.outlineVariant.withValues(
            alpha: AppDimensions.opacityMediumLight,
          ),
          style: BorderStyle.solid,
        ),
        color: cs.surfaceContainerHighest,
      ),
      child: Material(
        color: Colors.transparent,
        child: Semantics(
          label: context.l10n.a11yGalleryAddImage,
          button: true,
          child: InkWell(
            onTap: widget.onAddImage,
            borderRadius: widget.config.effectiveBorderRadius,
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.add_photo_alternate_outlined,
                    size: AppDimensions.iconSizeXl,
                    color: cs.primary,
                  ),
                  const SizedBox(height: AppDimensions.spacingXs),
                  Text(
                    context.l10n.commonAdd,
                    style: AppTextStyles.bodySmall.copyWith(
                      color: cs.primary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Build gallery image
  Widget _buildGalleryImage(String imageUrl, int index) {
    final cs = Theme.of(context).colorScheme;
    final isSelected = _selectedImages.contains(imageUrl);

    return Stack(
      children: [
        // Image container
        DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: widget.config.effectiveBorderRadius,
            border: Border.all(
              color: isSelected
                  ? cs.primary
                  : cs.outlineVariant.withValues(
                      alpha: AppDimensions.opacityLight,
                    ),
              width: isSelected ? 2 : 1,
            ),
          ),
          child: ClipRRect(
            borderRadius: widget.config.effectiveBorderRadius,
            child: Semantics(
              label: context.l10n.a11yShowImage,
              button: true,
              child: GestureDetector(
                onTap: () => _handleImageTap(imageUrl, index),
                onLongPress: () => _handleImageLongPress(imageUrl, index),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    // Image
                    ImageComponents.buildOptimizedCachedImage(
                      imageUrl: imageUrl,
                      config: widget.config,
                      fit: BoxFit.cover,
                      placeholder: ImageComponents.buildLoadingPlaceholder(
                        config: widget.config,
                      ),
                      errorWidget: ImageComponents.buildErrorPlaceholder(
                        config: widget.config,
                      ),
                    ),

                    // Selection overlay
                    if (isSelected)
                      Container(
                        color: cs.primary.withValues(
                          alpha: AppDimensions.opacityLight,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),

        // Selection indicator
        if (_isSelectionMode)
          Positioned(
            top: AppDimensions.spacingSm,
            right: AppDimensions.spacingSm,
            child: Container(
              padding: const EdgeInsets.all(AppDimensions.spacingXxs),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isSelected
                    ? cs.primary
                    : cs.surfaceContainerHighest.withValues(
                        alpha: AppDimensions.opacityVeryDark,
                      ),
                border: Border.all(
                  color: cs.outlineVariant.withValues(
                    alpha: AppDimensions.opacityMediumLight,
                  ),
                ),
              ),
              child: Icon(
                isSelected ? Icons.check : Icons.circle_outlined,
                size: AppDimensions.iconSizeS,
                color: isSelected
                    ? cs.surfaceContainerHighest
                    : cs.onSurface.withValues(
                        alpha: AppDimensions.opacityMediumDark,
                      ),
              ),
            ),
          ),
      ],
    );
  }

  /// Handle image tap
  void _handleImageTap(String imageUrl, int index) {
    if (widget.config.enableHapticFeedback) {
      HapticFeedback.lightImpact();
    }

    if (_isSelectionMode) {
      _toggleImageSelection(imageUrl);
    } else {
      widget.onImageTap?.call(index);
    }
  }

  /// Handle image long press
  void _handleImageLongPress(String imageUrl, int index) {
    if (widget.config.enableHapticFeedback) {
      HapticFeedback.mediumImpact();
    }

    if (widget.onImageLongPress != null) {
      widget.onImageLongPress!(imageUrl);
    } else {
      // Enter selection mode
      _enterSelectionMode(imageUrl);
    }
  }

  /// Enter selection mode
  void _enterSelectionMode(String initialImage) {
    setState(() {
      _isSelectionMode = true;
      _selectedImages.clear();
      _selectedImages.add(initialImage);
    });
  }

  /// Exit selection mode
  void _exitSelectionMode() {
    setState(() {
      _isSelectionMode = false;
      _selectedImages.clear();
    });
  }

  /// Toggle image selection
  void _toggleImageSelection(String imageUrl) {
    setState(() {
      if (_selectedImages.contains(imageUrl)) {
        _selectedImages.remove(imageUrl);
      } else {
        _selectedImages.add(imageUrl);
      }

      // Exit selection mode if no images selected
      if (_selectedImages.isEmpty) {
        _isSelectionMode = false;
      }
    });
  }
}

/// Staggered image gallery widget
class StaggeredImageGalleryWidget extends StatelessWidget {
  final List<String> imageUrls;
  final ImageConfig config;
  final Function(int)? onImageTap;
  final Function(String)? onImageLongPress;
  final int crossAxisCount;
  final double crossAxisSpacing;
  final double mainAxisSpacing;

  const StaggeredImageGalleryWidget({
    super.key,
    required this.imageUrls,
    required this.config,
    this.onImageTap,
    this.onImageLongPress,
    this.crossAxisCount = 2,
    this.crossAxisSpacing = AppDimensions.spacingSm,
    this.mainAxisSpacing = AppDimensions.spacingSm,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    if (imageUrls.isEmpty) {
      return Container(
        height: AppDimensions.minHeightLarge,
        width: double.infinity,
        decoration: BoxDecoration(
          borderRadius: config.effectiveBorderRadius,
          border: Border.all(
            color: cs.outlineVariant.withValues(
              alpha: AppDimensions.opacityMediumLight,
            ),
          ),
          color: cs.surfaceContainerHighest,
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.photo_library_outlined,
                size: AppDimensions.iconSizeXxl,
                color: cs.onSurface.withValues(
                  alpha: AppDimensions.opacityMedium,
                ),
              ),
              const SizedBox(
                height: (AppDimensions.spacingSm + AppDimensions.spacingXs),
              ),
              Text(
                context.l10n.imageNoImagesToDisplay,
                style: AppTextStyles.bodyLarge.copyWith(
                  color: cs.onSurface.withValues(
                    alpha: AppDimensions.opacityMediumDark,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        crossAxisSpacing: crossAxisSpacing,
        mainAxisSpacing: mainAxisSpacing,
        childAspectRatio: _getAspectRatio(),
      ),
      itemCount: imageUrls.length,
      itemBuilder: (context, index) {
        final imageUrl = imageUrls[index];

        return Semantics(
          label: context.l10n.a11yShowImage,
          button: true,
          child: GestureDetector(
            onTap: () {
              if (config.enableHapticFeedback) {
                HapticFeedback.lightImpact();
              }
              onImageTap?.call(index);
            },
            onLongPress: () {
              if (config.enableHapticFeedback) {
                HapticFeedback.mediumImpact();
              }
              onImageLongPress?.call(imageUrl);
            },
            child: ClipRRect(
              borderRadius: config.effectiveBorderRadius,
              child: ImageComponents.buildOptimizedCachedImage(
                imageUrl: imageUrl,
                config: config,
                fit: BoxFit.cover,
                placeholder: ImageComponents.buildLoadingPlaceholder(
                  config: config,
                ),
                errorWidget: ImageComponents.buildErrorPlaceholder(
                  config: config,
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  /// Get aspect ratio based on index for staggered effect
  double _getAspectRatio() {
    // You can customize this to create different aspect ratios
    return 1.0;
  }
}
