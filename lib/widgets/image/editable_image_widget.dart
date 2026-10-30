// lib/widgets/image/editable_image_widget.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/services/image_picker_service.dart';
import 'package:image_picker/image_picker.dart' show ImageSource;
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/widgets/image/image_config.dart';
import 'package:butlery/widgets/image/components/image_tile_row.dart';
import 'package:butlery/widgets/image/components/upload_progress_widgets.dart';
import 'package:butlery/services/upload/upload_models.dart';

/// Editable image widget with individual progress tracking for recipe editing.
class EditableImageWidget extends StatefulWidget {
  final List<String> imageUrls;
  final ImageConfig config;
  final Function(List<String>)? onImagesChanged;
  final Function(int)? onPrimaryImageChanged;
  final Function(int)? onImageTap;
  final VoidCallback? onPickImage;
  final int primaryIndex;
  final bool isLoading;
  final Map<String, ImageUploadStatus>? uploadStatuses;
  final Function(String)? onRetryUpload;
  final Function(String)? onCancelUpload;
  final String? uploadQueueStatus;
  final Map<String, dynamic>? uploadManagementSummary;
  final VoidCallback? onRetryAllFailed;
  final VoidCallback? onCancelAllActive;
  final VoidCallback? onClearAllFailed;

  const EditableImageWidget({
    super.key,
    required this.imageUrls,
    required this.config,
    this.onImagesChanged,
    this.onPrimaryImageChanged,
    this.onImageTap,
    this.onPickImage,
    this.primaryIndex = 0,
    this.isLoading = false,
    this.uploadStatuses,
    this.onRetryUpload,
    this.onCancelUpload,
    this.uploadQueueStatus,
    this.uploadManagementSummary,
    this.onRetryAllFailed,
    this.onCancelAllActive,
    this.onClearAllFailed,
  });

  factory EditableImageWidget.recipeEdit({
    Key? key,
    required List<String> imageUrls,
    ImageSize size = ImageSize.large,
    bool showEditControls = true,
    bool showNavigationDots = true,
    int maxImages = 5,
    Function(List<String>)? onImagesChanged,
    Function(int)? onPrimaryImageChanged,
    Function(int)? onImageTap,
    VoidCallback? onPickImage,
    int primaryIndex = 0,
    bool isLoading = false,
    Map<String, ImageUploadStatus>? uploadStatuses,
    Function(String)? onRetryUpload,
    Function(String)? onCancelUpload,
    String? uploadQueueStatus,
    Map<String, dynamic>? uploadManagementSummary,
    VoidCallback? onRetryAllFailed,
    VoidCallback? onCancelAllActive,
    VoidCallback? onClearAllFailed,
  }) {
    return EditableImageWidget(
      key: key,
      imageUrls: imageUrls,
      config: ImageConfig.recipeEdit(
        size: size,
        showEditControls: showEditControls,
        showNavigationDots: showNavigationDots,
        maxImages: maxImages,
      ),
      onImagesChanged: onImagesChanged,
      onPrimaryImageChanged: onPrimaryImageChanged,
      onImageTap: onImageTap,
      onPickImage: onPickImage,
      primaryIndex: primaryIndex,
      isLoading: isLoading,
      uploadStatuses: uploadStatuses,
      onRetryUpload: onRetryUpload,
      onCancelUpload: onCancelUpload,
      uploadQueueStatus: uploadQueueStatus,
      uploadManagementSummary: uploadManagementSummary,
      onRetryAllFailed: onRetryAllFailed,
      onCancelAllActive: onCancelAllActive,
      onClearAllFailed: onClearAllFailed,
    );
  }

  @override
  State<EditableImageWidget> createState() => _EditableImageWidgetState();
}

class _EditableImageWidgetState extends State<EditableImageWidget> {
  bool _isAddingImage = false;

  @override
  void didUpdateWidget(EditableImageWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!oldWidget.isLoading && widget.isLoading && _isAddingImage) {
      setState(() => _isAddingImage = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final mainContent = ImageTileRow(
      imageUrls: widget.imageUrls,
      config: widget.config,
      primaryIndex: widget.primaryIndex,
      isAdding: _isAddingImage || widget.isLoading,
      onAdd: _addImage,
      onRemove: _removeImageAtIndex,
      onSetPrimary: (index) => widget.onPrimaryImageChanged?.call(index),
      onOpen: (index) => widget.onImageTap?.call(index),
      uploadStatuses: widget.uploadStatuses,
      onRetryUpload: widget.onRetryUpload,
      onCancelUpload: widget.onCancelUpload,
    );

    if (widget.uploadQueueStatus != null &&
        widget.uploadQueueStatus!.isNotEmpty) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          UploadProgressWidgets.buildUploadQueueStatusBanner(
            uploadQueueStatus: widget.uploadQueueStatus,
            uploadManagementSummary: widget.uploadManagementSummary,
            onRetryAllFailed: widget.onRetryAllFailed,
            onCancelAllActive: widget.onCancelAllActive,
            onClearAllFailed: widget.onClearAllFailed,
          ),
          const SizedBox(height: AppDimensions.space8),
          mainContent,
        ],
      );
    }
    return mainContent;
  }

  Future<void> _addImage() async {
    if (_isAddingImage || widget.imageUrls.length >= widget.config.maxImages) {
      return;
    }

    if (mounted) {
      setState(() => _isAddingImage = true);
    }

    try {
      if (widget.config.enableHapticFeedback) {
        HapticFeedback.lightImpact();
      }

      if (widget.onPickImage != null) {
        widget.onPickImage!();
        return;
      }

      final imagePickerService = ServiceLocator.get<ImagePickerService>();
      // Flow 07: explanation before the system prompt.
      final outcome = await imagePickerService.pickMultipleImagesWithOutcome(
        rationale: mediaRationalePrompt(context),
      );
      if (outcome.blockedByPermission && mounted) {
        explainMediaPermission(
          context,
          outcome.permission,
          ImageSource.gallery,
        );
      }
      final result = outcome.files;

      if (result.isNotEmpty) {
        final newUrls = List<String>.from(widget.imageUrls);
        final availableSlots = widget.config.maxImages - newUrls.length;
        final imagesToAdd = result
            .take(availableSlots)
            .map((e) => e.path)
            .toList();
        newUrls.addAll(imagesToAdd);
        widget.onImagesChanged?.call(newUrls);
        AppLogger.debug('Added ${imagesToAdd.length} images');
      }
    } catch (e) {
      AppLogger.error('Failed to add images: $e');
    } finally {
      if (mounted) {
        setState(() => _isAddingImage = false);
      }
    }
  }

  void _removeImageAtIndex(int index) {
    if (index < 0 || index >= widget.imageUrls.length) return;

    if (widget.config.enableHapticFeedback) {
      HapticFeedback.lightImpact();
    }

    final newUrls = List<String>.from(widget.imageUrls);
    newUrls.removeAt(index);
    widget.onImagesChanged?.call(newUrls);
  }
}
