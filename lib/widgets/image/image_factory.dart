// lib/widgets/image/image_factory.dart

import 'package:flutter/material.dart';
import 'image_config.dart';
import 'avatar_image_widget.dart';
import 'recipe_image_widget.dart';
import 'editable_image_widget.dart';
import 'image_picker_widget.dart';
import 'image_gallery_widget.dart';
import 'simple_image_widget.dart';

/// Factory for creating image widgets - maintains backward compatibility
class ImageFactory {
  /// Create avatar image widget
  static Widget avatar({
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
    if (onImageSelected != null) {
      return AvatarImageWidget.editable(
        key: key,
        imageUrl: imageUrl,
        displayName: displayName,
        email: email,
        isOnline: isOnline,
        size: size,
        showStatus: showStatus,
        borderColor: borderColor,
        borderWidth: borderWidth,
        backgroundColor: backgroundColor,
        onImageSelected: onImageSelected,
      );
    } else {
      return AvatarImageWidget.readonly(
        key: key,
        imageUrl: imageUrl,
        displayName: displayName,
        email: email,
        isOnline: isOnline,
        size: size,
        showStatus: showStatus,
        borderColor: borderColor,
        borderWidth: borderWidth,
        backgroundColor: backgroundColor,
        onTap: onTap,
      );
    }
  }

  /// Create recipe card image widget
  static Widget recipeCard({
    Key? key,
    required List<String> imageUrls,
    ImageSize size = ImageSize.card,
    bool showMultipleIndicator = true,
    double? customWidth,
    double? customHeight,
    BorderRadius? borderRadius,
    VoidCallback? onTap,
    Function(int)? onImageTap,
  }) {
    return RecipeImageWidget.card(
      key: key,
      imageUrls: imageUrls,
      size: size,
      showMultipleIndicator: showMultipleIndicator,
      customWidth: customWidth,
      customHeight: customHeight,
      borderRadius: borderRadius,
      onTap: onTap,
      onImageTap: onImageTap,
    );
  }

  /// Create recipe detail image widget
  static Widget recipeDetail({
    Key? key,
    required List<String> imageUrls,
    ImageSize size = ImageSize.large,
    bool showNavigationDots = true,
    bool showImageCounter = true,
    String? heroTag,
    VoidCallback? onTap,
    Function(int)? onImageTap,
  }) {
    return RecipeImageWidget.detail(
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

  /// Create recipe edit image widget
  static Widget recipeEdit({
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
  }) {
    return EditableImageWidget.recipeEdit(
      key: key,
      imageUrls: imageUrls,
      size: size,
      showEditControls: showEditControls,
      showNavigationDots: showNavigationDots,
      maxImages: maxImages,
      onImagesChanged: onImagesChanged,
      onPrimaryImageChanged: onPrimaryImageChanged,
      onImageTap: onImageTap,
      primaryIndex: primaryIndex,
      isLoading: isLoading,
    );
  }

  /// Create gallery image widget
  static Widget gallery({
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
    return ImageGalleryWidget.gallery(
      key: key,
      imageUrls: imageUrls,
      size: size,
      showEditControls: showEditControls,
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

  /// Create picker image widget
  static Widget picker({
    Key? key,
    List<String> selectedImages = const [],
    ImageSize size = ImageSize.medium,
    int maxImages = 5,
    Function(List<String>)? onImagesSelected,
    Function(String)? onImageRemoved,
    bool allowMultiple = true,
    bool showImagePreview = true,
  }) {
    return ImagePickerWidget.picker(
      key: key,
      selectedImages: selectedImages,
      size: size,
      maxImages: maxImages,
      onImagesSelected: onImagesSelected,
      onImageRemoved: onImageRemoved,
      allowMultiple: allowMultiple,
      showImagePreview: showImagePreview,
    );
  }

  /// Create hero image widget
  static Widget hero({
    Key? key,
    required String imageUrl,
    String? heroTag,
    double? customWidth,
    double? customHeight,
    BorderRadius? borderRadius,
    VoidCallback? onTap,
    VoidCallback? onLongPress,
    BoxFit fit = BoxFit.cover,
  }) {
    return SimpleImageWidget.hero(
      key: key,
      imageUrl: imageUrl,
      heroTag: heroTag,
      customWidth: customWidth,
      customHeight: customHeight,
      borderRadius: borderRadius,
      onTap: onTap,
      onLongPress: onLongPress,
      fit: fit,
    );
  }

  /// Create thumbnail image widget
  static Widget thumbnail({
    Key? key,
    required String imageUrl,
    ImageSize size = ImageSize.thumbnail,
    BorderRadius? borderRadius,
    VoidCallback? onTap,
    VoidCallback? onLongPress,
    BoxFit fit = BoxFit.cover,
  }) {
    return SimpleImageWidget.thumbnail(
      key: key,
      imageUrl: imageUrl,
      size: size,
      borderRadius: borderRadius,
      onTap: onTap,
      onLongPress: onLongPress,
      fit: fit,
    );
  }

  /// Create cached image widget
  static Widget cached({
    Key? key,
    required String imageUrl,
    ImageSize size = ImageSize.medium,
    double? customWidth,
    double? customHeight,
    BorderRadius? borderRadius,
    VoidCallback? onTap,
    VoidCallback? onLongPress,
    BoxFit fit = BoxFit.cover,
  }) {
    return SimpleImageWidget.cached(
      key: key,
      imageUrl: imageUrl,
      size: size,
      customWidth: customWidth,
      customHeight: customHeight,
      borderRadius: borderRadius,
      onTap: onTap,
      onLongPress: onLongPress,
      fit: fit,
    );
  }

  /// Create image carousel widget
  static Widget carousel({
    Key? key,
    required List<String> imageUrls,
    ImageSize size = ImageSize.large,
    bool showNavigationDots = true,
    bool showImageCounter = true,
    Function(int)? onImageTap,
    Function(int)? onPageChanged,
    int initialIndex = 0,
  }) {
    return ImageCarouselWidget(
      key: key,
      imageUrls: imageUrls,
      config: ImageConfig.recipeDetail(
        size: size,
        showNavigationDots: showNavigationDots,
        showImageCounter: showImageCounter,
      ),
      onImageTap: onImageTap,
      onPageChanged: onPageChanged,
      initialIndex: initialIndex,
    );
  }

  /// Create staggered gallery widget
  static Widget staggeredGallery({
    Key? key,
    required List<String> imageUrls,
    ImageSize size = ImageSize.thumbnail,
    Function(int)? onImageTap,
    Function(String)? onImageLongPress,
    int crossAxisCount = 2,
    double crossAxisSpacing = 8.0,
    double mainAxisSpacing = 8.0,
  }) {
    return StaggeredImageGalleryWidget(
      key: key,
      imageUrls: imageUrls,
      config: ImageConfig.gallery(size: size),
      onImageTap: onImageTap,
      onImageLongPress: onImageLongPress,
      crossAxisCount: crossAxisCount,
      crossAxisSpacing: crossAxisSpacing,
      mainAxisSpacing: mainAxisSpacing,
    );
  }

  /// Create expandable image widget
  static Widget expandable({
    Key? key,
    required String imageUrl,
    ImageSize size = ImageSize.large,
    VoidCallback? onTap,
    Function(bool)? onExpandedChanged,
    bool initiallyExpanded = false,
  }) {
    return ExpandableImageWidget(
      key: key,
      imageUrl: imageUrl,
      config: ImageConfig.hero(customWidth: 300, customHeight: 200),
      onTap: onTap,
      onExpandedChanged: onExpandedChanged,
      initiallyExpanded: initiallyExpanded,
    );
  }

  /// Create lazy loading image widget
  static Widget lazy({
    Key? key,
    required String imageUrl,
    ImageSize size = ImageSize.medium,
    VoidCallback? onTap,
    bool autoLoad = true,
  }) {
    return LazyImageWidget(
      key: key,
      imageUrl: imageUrl,
      config: ImageConfig.cached(size: size),
      onTap: onTap,
      autoLoad: autoLoad,
    );
  }

  /// Create network image widget
  static Widget network({
    Key? key,
    required String imageUrl,
    double? width,
    double? height,
    BoxFit fit = BoxFit.cover,
    BorderRadius? borderRadius,
    Widget? placeholder,
    Widget? errorWidget,
    VoidCallback? onTap,
    VoidCallback? onLongPress,
    bool enableHapticFeedback = true,
  }) {
    return NetworkImageWidget(
      key: key,
      imageUrl: imageUrl,
      width: width,
      height: height,
      fit: fit,
      borderRadius: borderRadius,
      placeholder: placeholder,
      errorWidget: errorWidget,
      onTap: onTap,
      onLongPress: onLongPress,
      enableHapticFeedback: enableHapticFeedback,
    );
  }

  /// Create image picker bottom sheet
  static Future<void> showImagePicker({
    required BuildContext context,
    bool showCamera = true,
    bool showGallery = true,
    String? title,
    Function(dynamic)? onSourceSelected,
  }) async {
    final source = await ImagePickerBottomSheet.show(
      context,
      showCamera: showCamera,
      showGallery: showGallery,
      title: title,
    );
    
    if (source != null) {
      onSourceSelected?.call(source);
    }
  }
}