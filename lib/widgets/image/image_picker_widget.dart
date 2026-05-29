// lib/widgets/image/image_picker_widget.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:butlery/core/utils/firebase_url_utils.dart';
import 'dart:io';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/services/image_picker_service.dart';
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/widgets/common/indicators/loading_indicator.dart';
import 'package:butlery/widgets/image/image_config.dart';

// Re-export removed - image_source_picker.dart was dead code
// export 'package:butlery/widgets/image/image_source_picker.dart';

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
    final cs = Theme.of(context).colorScheme;
    final hasImages = widget.selectedImages.isNotEmpty;
    final canAddMore = widget.selectedImages.length < widget.config.maxImages;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Add images section
        if (canAddMore || !hasImages) _buildAddImagesSection(),

        // Selected images preview
        if (hasImages && widget.showImagePreview) ...[
          if (canAddMore) const SizedBox(height: AppDimensions.spacingMd),
          _buildSelectedImagesPreview(),
        ],

        // Image count info
        if (hasImages)
          Padding(
            padding: const EdgeInsets.only(top: AppDimensions.spacingSm),
            child: Text(
              context.l10n.imageSelectedCount(
                  widget.selectedImages.length, widget.config.maxImages),
              style: AppTextStyles.bodySmall.copyWith(
                color:
                    cs.onSurface.withValues(alpha: AppDimensions.opacityDark),
              ),
            ),
          ),
      ],
    );
  }

  /// Build add images section
  Widget _buildAddImagesSection() {
    final cs = Theme.of(context).colorScheme;
    final dimensions = widget.config.getDimensions();

    return Container(
      width: double.infinity,
      constraints: BoxConstraints(minHeight: dimensions.height),
      decoration: BoxDecoration(
        borderRadius: widget.config.effectiveBorderRadius,
        border: Border.all(
          color: cs.outlineVariant
              .withValues(alpha: AppDimensions.opacityMediumLight),
          style: BorderStyle.solid,
        ),
        color: cs.surfaceContainerHighest,
      ),
      child: Material(
        color: Colors.transparent,
        child: Semantics(
          label: context.l10n.a11yImagePickerOpen,
          button: true,
          enabled: !_isLoading,
          child: InkWell(
            onTap: _isLoading ? null : _pickImages,
            borderRadius: widget.config.effectiveBorderRadius,
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_isLoading) ...[
                    LoadingIndicator(
                      size: 32,
                      strokeWidth: 2,
                      color: cs.primary,
                    ),
                    const SizedBox(
                        height: (AppDimensions.spacingSm +
                            AppDimensions.spacingXs)),
                    Text(
                      context.l10n.imageSelectingImages,
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: cs.onSurface
                            .withValues(alpha: AppDimensions.opacityDark),
                      ),
                    ),
                  ] else ...[
                    Container(
                      padding: const EdgeInsets.all(AppDimensions.spacingMd),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: cs.primary
                            .withValues(alpha: AppDimensions.opacityVeryLight),
                      ),
                      child: Icon(
                        Icons.add_photo_alternate_outlined,
                        size: AppDimensions.iconSizeXl,
                        color: cs.primary,
                      ),
                    ),
                    const SizedBox(
                        height: (AppDimensions.spacingSm +
                            AppDimensions.spacingXs)),
                    Text(
                      widget.allowMultiple
                          ? context.l10n.imageSelectImages
                          : context.l10n.imageSelectImage,
                      style: AppTextStyles.contentTitle,
                    ),
                    const SizedBox(height: AppDimensions.spacingXs),
                    Text(
                      widget.allowMultiple
                          ? context.l10n
                              .imageTapToSelectUpTo(widget.config.maxImages)
                          : context.l10n.imageTapToSelectOne,
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: cs.onSurface
                            .withValues(alpha: AppDimensions.opacityDark),
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ],
              ),
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
          context.l10n.imageSelectedImages,
          style: AppTextStyles.contentTitle,
        ),
        const SizedBox(height: AppDimensions.spacingSm),
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
    final cs = Theme.of(context).colorScheme;

    return Stack(
      children: [
        // Image container
        DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppDimensions.borderRadius8),
            border: Border.all(
              color: cs.outlineVariant
                  .withValues(alpha: AppDimensions.opacityLight),
            ),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(AppDimensions.borderRadius8),
            child: imagePath.startsWith('http')
                ? CachedNetworkImage(
                    imageUrl: imagePath,
                    cacheKey: FirebaseUrlUtils.stableCacheKey(imagePath),
                    fit: BoxFit.cover,
                    width: double.infinity,
                    height: double.infinity,
                    placeholder: (context, url) => ColoredBox(
                      color: cs.surfaceContainerHighest,
                      child: const Center(child: LoadingIndicator()),
                    ),
                    errorWidget: (context, url, error) => ColoredBox(
                      color: cs.surfaceContainerHighest,
                      child: Icon(
                        Icons.error_outline,
                        color: cs.error,
                      ),
                    ),
                  )
                : Image.asset(
                    imagePath,
                    semanticLabel: context.l10n.tooltipSelectedImage,
                    fit: BoxFit.cover,
                    width: double.infinity,
                    height: double.infinity,
                    errorBuilder: (context, error, stackTrace) => ColoredBox(
                      color: cs.surfaceContainerHighest,
                      child: Icon(
                        Icons.error_outline,
                        color: cs.error,
                      ),
                    ),
                  ),
          ),
        ),

        // Remove button
        Positioned(
          top: AppDimensions.spacingXs,
          right: AppDimensions.spacingXs,
          child: Semantics(
            label: context.l10n.a11yImagePickerRemove(index + 1),
            button: true,
            child: GestureDetector(
              onTap: () => _removeImage(imagePath, index),
              child: Container(
                padding: const EdgeInsets.all(AppDimensions.spacingXs),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: cs.error,
                  border: Border.all(
                    color: cs.surfaceContainerHighest,
                    width: 1,
                  ),
                ),
                child: Icon(
                  Icons.close,
                  size: AppDimensions.iconSizeS,
                  color: cs.surfaceContainerHighest,
                ),
              ),
            ),
          ),
        ),

        // Index indicator
        Positioned(
          bottom: AppDimensions.spacingXs,
          left: AppDimensions.spacingXs,
          child: Container(
            padding: const EdgeInsets.symmetric(
                horizontal: AppDimensions.spacingTight,
                vertical: AppDimensions.spacingXxs),
            decoration: BoxDecoration(
              color: cs.surfaceContainerHighest
                  .withValues(alpha: AppDimensions.opacityExtraDark),
              borderRadius: BorderRadius.circular(AppDimensions.borderRadius10),
            ),
            child: Text(
              '${index + 1}',
              style: AppTextStyles.textXsBold,
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
            content: Text(context.l10n.imageFailedToSelect(e.toString())),
            backgroundColor: Theme.of(context).colorScheme.error,
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
