// lib/widgets/image/universal_image_manager.dart

import 'package:flutter/material.dart';
import 'package:butlery/widgets/image/image_config.dart';
import 'package:butlery/widgets/image/avatar_image_widget.dart';
import 'package:butlery/widgets/image/recipe_image_widget.dart';
import 'package:butlery/widgets/image/editable_image_widget.dart';
import 'package:butlery/widgets/image/image_picker_widget.dart';
import 'package:butlery/widgets/image/image_gallery_widget.dart';
import 'package:butlery/widgets/image/simple_image_widget.dart';
import 'package:butlery/services/upload/upload_models.dart';
import 'package:butlery/core/utils/logger.dart';

/// Universal Image Manager - Refactored with focused widgets
/// This is a compatibility layer that maintains the original API while
/// using the new focused widgets internally for better maintainability
class UniversalImageManager extends StatefulWidget {
  final List<String> imageUrls;
  final ImageConfig config;
  final Function(List<String>)? onImagesChanged;
  final Function(int)? onPrimaryImageChanged;
  final Function(int)? onImageTap;
  final Function(String)? onImageSelected;
  final Function(String)? onImageRemoved;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final VoidCallback? onPickImage;
  final String? displayName;
  final String? email;
  final bool isOnline;
  final int primaryIndex;
  final bool isLoading;
  final String? heroTag;
  // Enhanced Upload Progress Parameters
  final Map<String, ImageUploadStatus>? uploadStatuses;
  final Function(String)? onRetryUpload;
  final Function(String)? onCancelUpload;
  final String? uploadQueueStatus;
  // Bulk Upload Management Parameters
  final Map<String, dynamic>? uploadManagementSummary;
  final VoidCallback? onRetryAllFailed;
  final VoidCallback? onCancelAllActive;
  final VoidCallback? onClearAllFailed;
  // Dish name for screen-reader image content description (BUT-551).
  final String? semanticsLabel;

  const UniversalImageManager({
    super.key,
    this.imageUrls = const [],
    required this.config,
    this.onImagesChanged,
    this.onPrimaryImageChanged,
    this.onImageTap,
    this.onImageSelected,
    this.onImageRemoved,
    this.onTap,
    this.onLongPress,
    this.onPickImage,
    this.displayName,
    this.email,
    this.isOnline = false,
    this.primaryIndex = 0,
    this.isLoading = false,
    this.heroTag,
    // Enhanced Upload Progress Parameters
    this.uploadStatuses,
    this.onRetryUpload,
    this.onCancelUpload,
    this.uploadQueueStatus,
    // Bulk Upload Management Parameters
    this.uploadManagementSummary,
    this.onRetryAllFailed,
    this.onCancelAllActive,
    this.onClearAllFailed,
    this.semanticsLabel,
  });

  /// Avatar constructor
  factory UniversalImageManager.avatar({
    Key? key,
    String? imageUrl,
    String? displayName,
    String? email,
    bool isOnline = false,
    ImageSize size = ImageSize.medium,
    bool showStatus = false,
    Color? borderColor,
    double? borderWidth,
    Color? backgroundColor,
    VoidCallback? onTap,
    Function(String)? onImageSelected,
  }) {
    return UniversalImageManager(
      key: key,
      imageUrls: imageUrl != null ? [imageUrl] : [],
      config: ImageConfig.avatar(
        size: size,
        showStatus: showStatus,
        borderColor: borderColor,
        borderWidth: borderWidth,
        backgroundColor: backgroundColor,
      ),
      displayName: displayName,
      email: email,
      isOnline: isOnline,
      onTap: onTap,
      onImageSelected: onImageSelected,
    );
  }

  /// Recipe card constructor
  factory UniversalImageManager.recipeCard({
    Key? key,
    required List<String> imageUrls,
    ImageSize size = ImageSize.card,
    bool showMultipleIndicator = true,
    double? customWidth,
    double? customHeight,
    BorderRadius? borderRadius,
    VoidCallback? onTap,
    Function(int)? onImageTap,
    String? semanticsLabel,
  }) {
    return UniversalImageManager(
      key: key,
      imageUrls: imageUrls,
      config: ImageConfig.recipeCard(
        size: size,
        showMultipleIndicator: showMultipleIndicator,
        customWidth: customWidth,
        customHeight: customHeight,
        borderRadius: borderRadius,
      ),
      onTap: onTap,
      onImageTap: onImageTap,
      semanticsLabel: semanticsLabel,
    );
  }

  /// Recipe detail constructor
  factory UniversalImageManager.recipeDetail({
    Key? key,
    required List<String> imageUrls,
    ImageSize size = ImageSize.large,
    bool showNavigationDots = true,
    bool showImageCounter = true,
    String? heroTag,
    VoidCallback? onTap,
    Function(int)? onImageTap,
    String? semanticsLabel,
  }) {
    return UniversalImageManager(
      key: key,
      imageUrls: imageUrls,
      config: ImageConfig.recipeDetail(
        size: size,
        showNavigationDots: showNavigationDots,
        showImageCounter: showImageCounter,
        heroTag: heroTag,
      ),
      onTap: onTap,
      onImageTap: onImageTap,
      heroTag: heroTag,
      semanticsLabel: semanticsLabel,
    );
  }

  /// Recipe edit constructor
  factory UniversalImageManager.recipeEdit({
    Key? key,
    required List<String> imageUrls,
    ImageSize size = ImageSize.large,
    bool showEditControls = true,
    bool showNavigationDots = true,
    int maxImages = 5,
    Function(List<String>)? onImagesChanged,
    Function(int)? onPrimaryImageChanged,
    Function(int)? onImageTap,
    int primaryIndex = 0,
    bool isLoading = false,
    // Enhanced Upload Progress Parameters
    Map<String, ImageUploadStatus>? uploadStatuses,
    Function(String)? onRetryUpload,
    Function(String)? onCancelUpload,
    String? uploadQueueStatus,
    // Bulk Upload Management Parameters
    Map<String, dynamic>? uploadManagementSummary,
    VoidCallback? onRetryAllFailed,
    VoidCallback? onCancelAllActive,
    VoidCallback? onClearAllFailed,
    // Legacy API compatibility
    String? userId,
    Function(String)? onAddImage,
    Function(int)? onRemoveImage,
    Function(int)? onSetPrimary,
    VoidCallback? onPickImage,
  }) {
    // Handle legacy API by converting to new API
    Function(List<String>)? finalOnImagesChanged = onImagesChanged;
    Function(int)? finalOnPrimaryImageChanged = onPrimaryImageChanged;

    // Enhanced legacy API conversion for proper callback handling
    if (onRemoveImage != null) {
      finalOnImagesChanged = (List<String> newImages) {
        // Call the new API callback first
        onImagesChanged?.call(newImages);

        // For legacy onRemoveImage, we need to determine which index was removed
        // This is called when an image is removed from the new grid system
        if (newImages.length < imageUrls.length) {
          // Find the index of the removed image
          for (int i = 0; i < imageUrls.length; i++) {
            if (i >= newImages.length ||
                (i < newImages.length && imageUrls[i] != newImages[i])) {
              // Call the legacy callback with the removed index
              onRemoveImage(i);
              break;
            }
          }
        }
      };
    } else if (onAddImage != null) {
      // Handle onAddImage if provided (though this is less common)
      finalOnImagesChanged = (List<String> newImages) {
        onImagesChanged?.call(newImages);
        // Note: onAddImage expects a string, but we only have the full list here
        // This is a limitation of the legacy API conversion
      };
    }

    // Enhanced legacy API conversion for primary image selection
    if (onSetPrimary != null) {
      finalOnPrimaryImageChanged = (int index) {
        AppLogger.debug('🌟 UNIVERSAL: Primary image changed to index $index');
        // Call both new and legacy callbacks
        onPrimaryImageChanged?.call(index);
        onSetPrimary(index);
      };
    }

    return UniversalImageManager(
      key: key,
      imageUrls: imageUrls,
      config: ImageConfig.recipeEdit(
        size: size,
        showEditControls: showEditControls,
        showNavigationDots: showNavigationDots,
        maxImages: maxImages,
      ),
      onImagesChanged: finalOnImagesChanged,
      onPrimaryImageChanged: finalOnPrimaryImageChanged,
      onImageTap: onImageTap,
      onPickImage: onPickImage,
      primaryIndex: primaryIndex,
      isLoading: isLoading,
      // Enhanced Upload Progress Parameters
      uploadStatuses: uploadStatuses,
      onRetryUpload: onRetryUpload,
      onCancelUpload: onCancelUpload,
      uploadQueueStatus: uploadQueueStatus,
      // Bulk Upload Management Parameters
      uploadManagementSummary: uploadManagementSummary,
      onRetryAllFailed: onRetryAllFailed,
      onCancelAllActive: onCancelAllActive,
      onClearAllFailed: onClearAllFailed,
    );
  }

  /// Gallery constructor
  factory UniversalImageManager.gallery({
    Key? key,
    required List<String> imageUrls,
    ImageSize size = ImageSize.thumbnail,
    bool showEditControls = false,
    Function(int)? onImageTap,
    Function(String)? onImageLongPress,
  }) {
    return UniversalImageManager(
      key: key,
      imageUrls: imageUrls,
      config: ImageConfig.gallery(
        size: size,
        showEditControls: showEditControls,
      ),
      onImageTap: onImageTap,
      onLongPress: onImageLongPress != null
          ? () => onImageLongPress(imageUrls.isNotEmpty ? imageUrls.first : '')
          : null,
    );
  }

  /// Picker constructor
  factory UniversalImageManager.picker({
    Key? key,
    List<String> selectedImages = const [],
    ImageSize size = ImageSize.medium,
    int maxImages = 5,
    Function(List<String>)? onImagesChanged,
    Function(String)? onImageRemoved,
  }) {
    return UniversalImageManager(
      key: key,
      imageUrls: selectedImages,
      config: ImageConfig.picker(
        size: size,
        maxImages: maxImages,
      ),
      onImagesChanged: onImagesChanged,
      onImageRemoved: onImageRemoved,
    );
  }

  /// Hero constructor
  factory UniversalImageManager.hero({
    Key? key,
    required String imageUrl,
    String? heroTag,
    double? customWidth,
    double? customHeight,
    BorderRadius? borderRadius,
    VoidCallback? onTap,
  }) {
    return UniversalImageManager(
      key: key,
      imageUrls: [imageUrl],
      config: ImageConfig.hero(
        heroTag: heroTag,
        customWidth: customWidth,
        customHeight: customHeight,
        borderRadius: borderRadius,
      ),
      onTap: onTap,
      heroTag: heroTag,
    );
  }

  /// Thumbnail constructor
  factory UniversalImageManager.thumbnail({
    Key? key,
    required String imageUrl,
    ImageSize size = ImageSize.thumbnail,
    BorderRadius? borderRadius,
    VoidCallback? onTap,
  }) {
    return UniversalImageManager(
      key: key,
      imageUrls: [imageUrl],
      config: ImageConfig.thumbnail(
        size: size,
        borderRadius: borderRadius,
      ),
      onTap: onTap,
    );
  }

  /// Cached constructor
  factory UniversalImageManager.cached({
    Key? key,
    required String imageUrl,
    ImageSize size = ImageSize.medium,
    double? customWidth,
    double? customHeight,
    BorderRadius? borderRadius,
    VoidCallback? onTap,
  }) {
    return UniversalImageManager(
      key: key,
      imageUrls: [imageUrl],
      config: ImageConfig.cached(
        size: size,
        customWidth: customWidth,
        customHeight: customHeight,
        borderRadius: borderRadius,
      ),
      onTap: onTap,
    );
  }

  /// Carousel constructor (legacy compatibility)
  factory UniversalImageManager.carousel({
    Key? key,
    required List<String> imageUrls,
    ImageSize size = ImageSize.large,
    bool showNavigationDots = true,
    bool showImageCounter = true,
    String? heroTag,
    VoidCallback? onTap,
    Function(int)? onImageTap,
    int initialIndex = 0,
    double? height,
    double? width,
  }) {
    return UniversalImageManager.recipeDetail(
      key: key,
      imageUrls: imageUrls,
      size: size,
      showNavigationDots: showNavigationDots,
      showImageCounter: showImageCounter,
      heroTag: heroTag,
      onTap: onTap,
      onImageTap: onImageTap,
    );
  }

  @override
  State<UniversalImageManager> createState() => _UniversalImageManagerState();
}

class _UniversalImageManagerState extends State<UniversalImageManager> {
  @override
  Widget build(BuildContext context) {
    // Delegate to appropriate focused widget based on type
    switch (widget.config.type) {
      case ImageType.avatar:
        return _buildAvatarWidget();
      case ImageType.recipeCard:
        return _buildRecipeCardWidget();
      case ImageType.recipeDetail:
        return _buildRecipeDetailWidget();
      case ImageType.recipeEdit:
        return _buildRecipeEditWidget();
      case ImageType.gallery:
        return _buildGalleryWidget();
      case ImageType.picker:
        return _buildPickerWidget();
      case ImageType.hero:
        return _buildHeroWidget();
      case ImageType.thumbnail:
        return _buildThumbnailWidget();
      case ImageType.cached:
        return _buildCachedWidget();
    }
  }

  /// Build avatar widget
  Widget _buildAvatarWidget() {
    final imageUrl = widget.imageUrls.isNotEmpty
        ? widget.imageUrls.first
        : null;

    if (widget.onImageSelected != null) {
      return AvatarImageWidget.editable(
        imageUrl: imageUrl,
        displayName: widget.displayName,
        email: widget.email,
        isOnline: widget.isOnline,
        size: widget.config.size,
        showStatus: widget.config.showStatusIndicator,
        borderColor: widget.config.borderColor,
        borderWidth: widget.config.borderWidth,
        backgroundColor: widget.config.backgroundColor,
        onImageSelected: widget.onImageSelected!,
      );
    } else {
      return AvatarImageWidget.readonly(
        imageUrl: imageUrl,
        displayName: widget.displayName,
        email: widget.email,
        isOnline: widget.isOnline,
        size: widget.config.size,
        showStatus: widget.config.showStatusIndicator,
        borderColor: widget.config.borderColor,
        borderWidth: widget.config.borderWidth,
        backgroundColor: widget.config.backgroundColor,
        onTap: widget.onTap,
      );
    }
  }

  /// Build recipe card widget
  Widget _buildRecipeCardWidget() {
    return RecipeImageWidget.card(
      imageUrls: widget.imageUrls,
      size: widget.config.size,
      showMultipleIndicator: widget.config.showMultipleIndicator,
      customWidth: widget.config.customWidth,
      customHeight: widget.config.customHeight,
      borderRadius: widget.config.borderRadius,
      onTap: widget.onTap,
      onImageTap: widget.onImageTap,
      semanticsLabel: widget.semanticsLabel,
    );
  }

  /// Build recipe detail widget
  Widget _buildRecipeDetailWidget() {
    return RecipeImageWidget.detail(
      imageUrls: widget.imageUrls,
      size: widget.config.size,
      showNavigationDots: widget.config.showNavigationDots,
      showImageCounter: widget.config.showImageCounter,
      heroTag: widget.heroTag,
      onTap: widget.onTap,
      onImageTap: widget.onImageTap,
      semanticsLabel: widget.semanticsLabel,
    );
  }

  /// Build recipe edit widget
  Widget _buildRecipeEditWidget() {
    return EditableImageWidget.recipeEdit(
      imageUrls: widget.imageUrls,
      size: widget.config.size,
      showEditControls: widget.config.showEditControls,
      showNavigationDots: widget.config.showNavigationDots,
      maxImages: widget.config.maxImages,
      onImagesChanged: widget.onImagesChanged,
      onPrimaryImageChanged: widget.onPrimaryImageChanged,
      onImageTap: widget.onImageTap,
      onPickImage: widget.onPickImage,
      primaryIndex: widget.primaryIndex,
      isLoading: widget.isLoading,
      // Enhanced Upload Progress Parameters
      uploadStatuses: widget.uploadStatuses,
      onRetryUpload: widget.onRetryUpload,
      onCancelUpload: widget.onCancelUpload,
      uploadQueueStatus: widget.uploadQueueStatus,
      // Bulk Upload Management Parameters
      uploadManagementSummary: widget.uploadManagementSummary,
      onRetryAllFailed: widget.onRetryAllFailed,
      onCancelAllActive: widget.onCancelAllActive,
      onClearAllFailed: widget.onClearAllFailed,
    );
  }

  /// Build gallery widget
  Widget _buildGalleryWidget() {
    return ImageGalleryWidget.gallery(
      imageUrls: widget.imageUrls,
      size: widget.config.size,
      showEditControls: widget.config.showEditControls,
      onImageTap: widget.onImageTap,
      onImageLongPress: widget.onImageRemoved,
    );
  }

  /// Build picker widget
  Widget _buildPickerWidget() {
    return ImagePickerWidget.picker(
      selectedImages: widget.imageUrls,
      size: widget.config.size,
      maxImages: widget.config.maxImages,
      onImagesSelected: widget.onImagesChanged,
      onImageRemoved: widget.onImageRemoved,
    );
  }

  /// Build hero widget
  Widget _buildHeroWidget() {
    final imageUrl = widget.imageUrls.isNotEmpty ? widget.imageUrls.first : '';

    return SimpleImageWidget.hero(
      imageUrl: imageUrl,
      heroTag: widget.heroTag,
      customWidth: widget.config.customWidth,
      customHeight: widget.config.customHeight,
      borderRadius: widget.config.borderRadius,
      onTap: widget.onTap,
      onLongPress: widget.onLongPress,
    );
  }

  /// Build thumbnail widget
  Widget _buildThumbnailWidget() {
    final imageUrl = widget.imageUrls.isNotEmpty ? widget.imageUrls.first : '';

    return SimpleImageWidget.thumbnail(
      imageUrl: imageUrl,
      size: widget.config.size,
      borderRadius: widget.config.borderRadius,
      onTap: widget.onTap,
      onLongPress: widget.onLongPress,
    );
  }

  /// Build cached widget
  Widget _buildCachedWidget() {
    final imageUrl = widget.imageUrls.isNotEmpty ? widget.imageUrls.first : '';

    return SimpleImageWidget.cached(
      imageUrl: imageUrl,
      size: widget.config.size,
      customWidth: widget.config.customWidth,
      customHeight: widget.config.customHeight,
      borderRadius: widget.config.borderRadius,
      onTap: widget.onTap,
      onLongPress: widget.onLongPress,
    );
  }
}
