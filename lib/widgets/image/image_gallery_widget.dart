// lib/widgets/image/image_gallery_widget.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:butlery/theme/app_colors.dart';
import 'package:butlery/theme/app_text_styles.dart';
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
    this.crossAxisSpacing = 8.0,
    this.mainAxisSpacing = 8.0,
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
    double crossAxisSpacing = 8.0,
    double mainAxisSpacing = 8.0,
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
    // Remove unused theme variable

    return Container(
      height: 200,
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: widget.config.effectiveBorderRadius,
        border: Border.all(
          color: AppColors.dividerColor.withValues(alpha: 0.3),
        ),
        color: AppColors.cardColor,
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.photo_library_outlined,
              size: 48,
              color: AppColors.textPrimary.withValues(alpha: 0.4),
            ),
            const SizedBox(height: 12),
            Text(
              'No images yet',
              style: AppTextStyles.bodyLarge.copyWith(
                color: AppColors.textPrimary.withValues(alpha: 0.6),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Images will appear here',
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.textPrimary.withValues(alpha: 0.4),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Build selection mode header
  Widget _buildSelectionHeader() {
    // Remove unused theme variable

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        color: AppColors.primaryBlue,
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.check_circle,
            color: AppColors.primaryBlue,
          ),
          const SizedBox(width: 8),
          Text(
            '${_selectedImages.length} selected',
            style: AppTextStyles.bodyLarge.copyWith(
              fontWeight: FontWeight.w500,
              color: Colors.white,
            ),
          ),
          const Spacer(),
          TextButton(
            onPressed: _exitSelectionMode,
            child: Text(
              'Cancel',
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.primaryBlue,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Build add image button
  Widget _buildAddImageButton() {
    // Remove unused theme variable

    return Container(
      decoration: BoxDecoration(
        borderRadius: widget.config.effectiveBorderRadius,
        border: Border.all(
          color: AppColors.dividerColor.withValues(alpha: 0.3),
          style: BorderStyle.solid,
        ),
        color: AppColors.cardColor,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: widget.onAddImage,
          borderRadius: widget.config.effectiveBorderRadius,
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.add_photo_alternate_outlined,
                  size: 32,
                  color: AppColors.primaryBlue,
                ),
                const SizedBox(height: 4),
                Text(
                  'Add',
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.primaryBlue,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Build gallery image
  Widget _buildGalleryImage(String imageUrl, int index) {
    // Remove unused theme variable
    final isSelected = _selectedImages.contains(imageUrl);

    return Stack(
      children: [
        // Image container
        Container(
          decoration: BoxDecoration(
            borderRadius: widget.config.effectiveBorderRadius,
            border: Border.all(
              color: isSelected
                  ? AppColors.primaryBlue
                  : AppColors.dividerColor.withValues(alpha: 0.2),
              width: isSelected ? 2 : 1,
            ),
          ),
          child: ClipRRect(
            borderRadius: widget.config.effectiveBorderRadius,
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
                      color: AppColors.primaryBlue.withValues(alpha: 0.2),
                    ),
                ],
              ),
            ),
          ),
        ),

        // Selection indicator
        if (_isSelectionMode)
          Positioned(
            top: 8,
            right: 8,
            child: Container(
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isSelected
                    ? AppColors.primaryBlue
                    : AppColors.cardColor.withValues(alpha: 0.8),
                border: Border.all(
                  color: AppColors.dividerColor.withValues(alpha: 0.3),
                ),
              ),
              child: Icon(
                isSelected ? Icons.check : Icons.circle_outlined,
                size: 16,
                color: isSelected
                    ? Colors.white
                    : AppColors.textPrimary.withValues(alpha: 0.6),
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
    this.crossAxisSpacing = 8.0,
    this.mainAxisSpacing = 8.0,
  });

  @override
  Widget build(BuildContext context) {
    // Remove unused theme variable

    if (imageUrls.isEmpty) {
      return Container(
        height: 200,
        width: double.infinity,
        decoration: BoxDecoration(
          borderRadius: config.effectiveBorderRadius,
          border: Border.all(
            color: AppColors.dividerColor.withValues(alpha: 0.3),
          ),
          color: AppColors.cardColor,
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.photo_library_outlined,
                size: 48,
                color: AppColors.textPrimary.withValues(alpha: 0.4),
              ),
              const SizedBox(height: 12),
              Text(
                'No images to display',
                style: AppTextStyles.bodyLarge.copyWith(
                  color: AppColors.textPrimary.withValues(alpha: 0.6),
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

        return GestureDetector(
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
