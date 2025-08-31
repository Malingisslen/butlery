// lib/widgets/image/image_picker_widget.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'dart:io';
import 'package:butlery/theme/app_colors.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/services/image_picker_service.dart';
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/widgets/image/image_config.dart';

/// Image picker widget for selecting images
class ImagePickerWidget extends StatefulWidget {
  final List<String> selectedImages;
  final ImageConfig config;
  final Function(List<String>)? onImagesSelected;
  final Function(String)? onImageRemoved;
  final bool allowMultiple;
  final bool showImagePreview;

  const ImagePickerWidget({
    super.key,
    this.selectedImages = const [],
    required this.config,
    this.onImagesSelected,
    this.onImageRemoved,
    this.allowMultiple = true,
    this.showImagePreview = true,
  });

  /// Factory constructor for picker
  factory ImagePickerWidget.picker({
    Key? key,
    List<String> selectedImages = const [],
    ImageSize size = ImageSize.medium,
    int maxImages = 5,
    Function(List<String>)? onImagesSelected,
    Function(String)? onImageRemoved,
    bool allowMultiple = true,
    bool showImagePreview = true,
  }) {
    return ImagePickerWidget(
      key: key,
      selectedImages: selectedImages,
      config: ImageConfig.picker(
        size: size,
        maxImages: maxImages,
      ),
      onImagesSelected: onImagesSelected,
      onImageRemoved: onImageRemoved,
      allowMultiple: allowMultiple,
      showImagePreview: showImagePreview,
    );
  }

  @override
  State<ImagePickerWidget> createState() => _ImagePickerWidgetState();
}

class _ImagePickerWidgetState extends State<ImagePickerWidget> {
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    // Remove unused theme variable
    final hasImages = widget.selectedImages.isNotEmpty;
    final canAddMore = widget.selectedImages.length < widget.config.maxImages;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Add images section
        if (canAddMore || !hasImages) _buildAddImagesSection(),

        // Selected images preview
        if (hasImages && widget.showImagePreview) ...[
          if (canAddMore) const SizedBox(height: AppDimensions.spacing16),
          _buildSelectedImagesPreview(),
        ],

        // Image count info
        if (hasImages)
          Padding(
            padding: const EdgeInsets.only(top: AppDimensions.spacingSm),
            child: Text(
              '${widget.selectedImages.length}/${widget.config.maxImages} images selected',
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.textPrimary.withValues(alpha: 0.7),
              ),
            ),
          ),
      ],
    );
  }

  /// Build add images section
  Widget _buildAddImagesSection() {
    // Remove unused theme variable
    final dimensions = widget.config.getDimensions();

    return Container(
      width: double.infinity,
      constraints: BoxConstraints(minHeight: dimensions.height),
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
          onTap: _isLoading ? null : _pickImages,
          borderRadius: widget.config.effectiveBorderRadius,
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_isLoading) ...[
                  const SizedBox(
                    width: 32,
                    height: 32,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        AppColors.primaryBlue,
                      ),
                    ),
                  ),
                  const SizedBox(height: AppDimensions.spacing12),
                  Text(
                    'Selecting images...',
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: AppColors.textPrimary.withValues(alpha: 0.7),
                    ),
                  ),
                ] else ...[
                  Container(
                    padding: const EdgeInsets.all(AppDimensions.spacing16),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.primaryBlue.withValues(alpha: 0.1),
                    ),
                    child: const Icon(
                      Icons.add_photo_alternate_outlined,
                      size: 32,
                      color: AppColors.primaryBlue,
                    ),
                  ),
                  const SizedBox(height: AppDimensions.spacing12),
                  Text(
                    widget.allowMultiple ? 'Select images' : 'Select image',
                    style: AppTextStyles.bodyLarge.copyWith(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: AppDimensions.spacing4),
                  Text(
                    widget.allowMultiple
                        ? 'Tap to select up to ${widget.config.maxImages} images'
                        : 'Tap to select an image',
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: AppColors.textPrimary.withValues(alpha: 0.7),
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Build selected images preview
  Widget _buildSelectedImagesPreview() {
    // Remove unused theme variable

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Selected Images',
          style: AppTextStyles.bodyLarge.copyWith(
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: AppDimensions.spacing8),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            crossAxisSpacing: AppDimensions.spacingSm,
            mainAxisSpacing: AppDimensions.spacingSm,
            childAspectRatio: 1,
          ),
          itemCount: widget.selectedImages.length,
          itemBuilder: (context, index) {
            return _buildImagePreview(widget.selectedImages[index], index);
          },
        ),
      ],
    );
  }

  /// Build individual image preview
  Widget _buildImagePreview(String imagePath, int index) {
    // Remove unused theme variable

    return Stack(
      children: [
        // Image container
        DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppDimensions.borderRadius8),
            border: Border.all(
              color: AppColors.dividerColor.withValues(alpha: 0.2),
            ),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(AppDimensions.borderRadius8),
            child: imagePath.startsWith('http')
                ? CachedNetworkImage(
                    imageUrl: imagePath,
                    fit: BoxFit.cover,
                    width: double.infinity,
                    height: double.infinity,
                    placeholder: (context, url) => const ColoredBox(
                      color: AppColors.cardColor,
                      child: Center(
                        child: CircularProgressIndicator(),
                      ),
                    ),
                    errorWidget: (context, url, error) => const ColoredBox(
                      color: AppColors.cardColor,
                      child: Icon(
                        Icons.error_outline,
                        color: AppColors.error,
                      ),
                    ),
                  )
                : Image.asset(
                    imagePath,
                    fit: BoxFit.cover,
                    width: double.infinity,
                    height: double.infinity,
                    errorBuilder: (context, error, stackTrace) => const ColoredBox(
                      color: AppColors.cardColor,
                      child: Icon(
                        Icons.error_outline,
                        color: AppColors.error,
                      ),
                    ),
                  ),
          ),
        ),

        // Remove button
        Positioned(
          top: AppDimensions.spacingXs,
          right: AppDimensions.spacingXs,
          child: GestureDetector(
            onTap: () => _removeImage(imagePath, index),
            child: Container(
              padding: const EdgeInsets.all(AppDimensions.spacing4),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.error,
                border: Border.all(
                  color: AppColors.cardColor,
                  width: 1,
                ),
              ),
              child: const Icon(
                Icons.close,
                size: 16,
                color: Colors.white,
              ),
            ),
          ),
        ),

        // Index indicator
        Positioned(
          bottom: AppDimensions.spacingXs,
          left: AppDimensions.spacingXs,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: AppDimensions.spacing6, vertical: AppDimensions.spacing2),
            decoration: BoxDecoration(
              color: AppColors.cardColor.withValues(alpha: 0.9),
              borderRadius: BorderRadius.circular(AppDimensions.borderRadius10),
            ),
            child: Text(
              '${index + 1}',
              style: AppTextStyles.bodySmall.copyWith(
                fontSize: 10,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// Pick images
  Future<void> _pickImages() async {
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
    });

    try {
      if (widget.config.enableHapticFeedback) {
        HapticFeedback.lightImpact();
      }

      final imagePickerService = ServiceLocator.get<ImagePickerService>();
      List<File> results = [];

      if (widget.allowMultiple) {
        final multipleResults = await imagePickerService.pickMultipleImages();
        results = multipleResults;
      } else {
        final result = await imagePickerService.pickImage(ImageSource.gallery);
        if (result != null) {
          results = [result];
        }
      }

      if (results.isNotEmpty) {
        final newImages = List<String>.from(widget.selectedImages);
        final availableSlots = widget.config.maxImages - newImages.length;
        final imagesToAdd =
            results.take(availableSlots).map((e) => e.path).toList();

        newImages.addAll(imagesToAdd);
        widget.onImagesSelected?.call(newImages);

        AppLogger.debug('Selected ${imagesToAdd.length} images');
      }
    } catch (e) {
      AppLogger.error('Failed to pick images: $e');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to select images: ${e.toString()}'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  /// Remove image
  void _removeImage(String imagePath, int index) {
    if (widget.config.enableHapticFeedback) {
      HapticFeedback.lightImpact();
    }

    final newImages = List<String>.from(widget.selectedImages);
    newImages.removeAt(index);

    widget.onImagesSelected?.call(newImages);
    widget.onImageRemoved?.call(imagePath);

    AppLogger.debug('Removed image at index $index');
  }
}

/// Simple image source picker widget
class ImageSourcePickerWidget extends StatelessWidget {
  final Function(ImageSource)? onSourceSelected;
  final bool showCamera;
  final bool showGallery;

  const ImageSourcePickerWidget({
    super.key,
    this.onSourceSelected,
    this.showCamera = true,
    this.showGallery = true,
  });

  @override
  Widget build(BuildContext context) {
    // Remove unused theme variable

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (showCamera)
          ListTile(
            leading: const Icon(
              Icons.camera_alt_outlined,
              color: AppColors.primaryBlue,
            ),
            title: const Text(
              'Camera',
              style: AppTextStyles.bodyLarge,
            ),
            onTap: () => onSourceSelected?.call(ImageSource.camera),
          ),
        if (showGallery)
          ListTile(
            leading: const Icon(
              Icons.photo_library_outlined,
              color: AppColors.primaryBlue,
            ),
            title: const Text(
              'Gallery',
              style: AppTextStyles.bodyLarge,
            ),
            onTap: () => onSourceSelected?.call(ImageSource.gallery),
          ),
      ],
    );
  }
}

/// Image picker bottom sheet
class ImagePickerBottomSheet extends StatelessWidget {
  final Function(ImageSource)? onSourceSelected;
  final bool showCamera;
  final bool showGallery;
  final String? title;

  const ImagePickerBottomSheet({
    super.key,
    this.onSourceSelected,
    this.showCamera = true,
    this.showGallery = true,
    this.title,
  });

  /// Show image picker bottom sheet
  static Future<ImageSource?> show(
    BuildContext context, {
    bool showCamera = true,
    bool showGallery = true,
    String? title,
  }) async {
    return await showModalBottomSheet<ImageSource>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppDimensions.borderRadius16)),
      ),
      builder: (context) => ImagePickerBottomSheet(
        onSourceSelected: (source) => Navigator.of(context).pop(source),
        showCamera: showCamera,
        showGallery: showGallery,
        title: title,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Remove unused theme variable

    return Container(
      padding: const EdgeInsets.all(AppDimensions.spacing16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title != null) ...[
            Text(
              title!,
              style: AppTextStyles.headlineSmall.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: AppDimensions.spacing16),
          ],
          ImageSourcePickerWidget(
            onSourceSelected: onSourceSelected,
            showCamera: showCamera,
            showGallery: showGallery,
          ),
          const SizedBox(height: AppDimensions.spacing8),
        ],
      ),
    );
  }
}
