// lib/widgets/image/image_source_picker.dart

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:butlery/theme/app_colors.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/theme/app_dimensions.dart';

/// Simple image source picker widget for selecting camera or gallery.
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

/// Image picker bottom sheet for presenting source selection.
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

  /// Show image picker bottom sheet.
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
