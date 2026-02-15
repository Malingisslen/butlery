// lib/widgets/image/editable_image_widget.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/services/image_picker_service.dart';
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/widgets/image/image_config.dart';
import 'package:butlery/widgets/image/image_components.dart';
import 'package:butlery/widgets/image/components/upload_progress_widgets.dart';
import 'package:butlery/widgets/image/components/image_grid_widgets.dart';
import 'package:butlery/widgets/image/components/empty_image_state.dart';
import 'package:butlery/widgets/image/components/edit_actions_panel.dart';
import 'package:butlery/widgets/image/components/primary_badge.dart';
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
  late PageController _pageController;
  late int _currentIndex;
  bool _isAddingImage = false;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.primaryIndex;
    _pageController = PageController(initialPage: widget.primaryIndex);
  }

  @override
  void didUpdateWidget(EditableImageWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!oldWidget.isLoading && widget.isLoading && _isAddingImage) {
      setState(() => _isAddingImage = false);
    }
    if (oldWidget.primaryIndex != widget.primaryIndex) {
      _currentIndex = widget.primaryIndex;
      _pageController = PageController(initialPage: widget.primaryIndex);
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final mainContent = _buildMainContent();

    if (widget.uploadQueueStatus != null &&
        widget.uploadQueueStatus!.isNotEmpty) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          UploadProgressWidgets.buildUploadQueueStatusBanner(
            uploadQueueStatus: widget.uploadQueueStatus,
            uploadManagementSummary: widget.uploadManagementSummary,
            onRetryAllFailed: widget.onRetryAllFailed,
            onCancelAllActive: widget.onCancelAllActive,
            onClearAllFailed: widget.onClearAllFailed,
          ),
          const SizedBox(height: AppDimensions.spacingSm),
          mainContent,
        ],
      );
    }
    return mainContent;
  }

  Widget _buildMainContent() {
    if (widget.imageUrls.isEmpty) {
      return _buildEmptyState();
    } else if (widget.imageUrls.length == 1) {
      return _buildSingleImageCarousel();
    } else {
      return _buildMultiImageGrid();
    }
  }

  Widget _buildEmptyState() {
    final pickerConfig = ImageConfig.picker(maxImages: widget.config.maxImages);
    final pickerDimensions = pickerConfig.getDimensions();
    return SizedBox(
      width: pickerDimensions.width == double.infinity
          ? null
          : pickerDimensions.width,
      height: pickerDimensions.height == double.infinity
          ? null
          : pickerDimensions.height,
      child: EmptyImageState(
        borderRadius: widget.config.effectiveBorderRadius,
        onTap: _addImage,
        isLoading: _isAddingImage || widget.isLoading,
        maxImages: widget.config.maxImages,
      ),
    );
  }

  Widget _buildSingleImageCarousel() {
    final dimensions = widget.config.getDimensions();
    final isUnboundedHeight = dimensions.height == double.infinity;
    final isUnboundedWidth = dimensions.width == double.infinity;

    Widget carousel = _buildEditCarousel();
    if (isUnboundedHeight) {
      carousel = AspectRatio(
        aspectRatio: widget.config.getAspectRatio(),
        child: carousel,
      );
    }

    return SizedBox(
      width: isUnboundedWidth ? null : dimensions.width,
      height: isUnboundedHeight ? null : dimensions.height,
      child: carousel,
    );
  }

  Widget _buildMultiImageGrid() {
    final dimensions = widget.config.getDimensions();
    return SizedBox(
      width: dimensions.width == double.infinity ? null : dimensions.width,
      child: ImageGridWidgets.buildMultiImageGrid(
        imageUrls: widget.imageUrls,
        config: widget.config,
        primaryIndex: widget.primaryIndex,
        isLoading: widget.isLoading,
        isAddingImage: _isAddingImage,
        onPrimaryImageChanged: (index) =>
            widget.onPrimaryImageChanged?.call(index),
        onImageTap: (index) => widget.onImageTap?.call(index),
        onRemoveImage: _removeImageAtIndex,
        onAddImage: _addImage,
      ),
    );
  }

  Widget _buildEditCarousel() {
    return Stack(
      children: [
        ClipRRect(
          borderRadius: widget.config.effectiveBorderRadius,
          child: RepaintBoundary(
            child: PageView.builder(
              controller: _pageController,
              onPageChanged: _onPageChanged,
              itemCount: widget.imageUrls.length,
              itemBuilder: (context, index) {
                final imageUrl = widget.imageUrls[index];
                return RepaintBoundary(
                  key: ValueKey('edit_image_$imageUrl'),
                  child: _buildCarouselImage(index),
                );
              },
            ),
          ),
        ),
        if (widget.config.showNavigationDots && widget.imageUrls.length > 1)
          ImageComponents.buildNavigationDots(
            currentIndex: _currentIndex,
            totalImages: widget.imageUrls.length,
            config: widget.config,
            onDotTap: _onDotTap,
          ),
        if (widget.config.showImageCounter && widget.imageUrls.length > 1)
          ImageComponents.buildImageCounter(
            currentIndex: _currentIndex,
            totalImages: widget.imageUrls.length,
            config: widget.config,
          ),
        if (widget.config.showEditControls)
          EditActionsPanel(
            canAddImage: widget.imageUrls.length < widget.config.maxImages,
            canSetPrimary: widget.imageUrls.length > 1 &&
                _currentIndex != widget.primaryIndex,
            onAddImage: _addImage,
            onSetPrimary: _setPrimary,
            onRemoveImage: _removeImage,
          ),
        if (widget.isLoading) _buildLoadingOverlay(),
      ],
    );
  }

  Widget _buildCarouselImage(int index) {
    final imageUrl = widget.imageUrls[index];
    final isPrimary = index == widget.primaryIndex;
    final uploadStatus = widget.uploadStatuses?[imageUrl];
    final hasUploadStatus = uploadStatus != null;

    return Stack(
      children: [
        Semantics(
          label: context.l10n.a11yViewFullSizeImage,
          button: true,
          child: GestureDetector(
            key: ValueKey('gesture_$imageUrl'),
            onTap: () {
              if (widget.config.enableHapticFeedback) {
                HapticFeedback.lightImpact();
              }
              widget.onImageTap?.call(index);
            },
            child: ImageComponents.buildAdaptiveImage(
              pathOrUrl: imageUrl,
              config: widget.config,
              fit: BoxFit.cover,
              placeholder: ImageComponents.buildLoadingPlaceholder(
                config: widget.config,
              ),
              errorWidget: ImageComponents.buildErrorPlaceholder(
                config: widget.config,
              ),
            ),
          ),
        ),
        if (hasUploadStatus && uploadStatus.state != ImageUploadState.completed)
          UploadProgressWidgets.buildUploadProgressOverlay(
            status: uploadStatus,
            imageUrl: imageUrl,
            borderRadius: widget.config.effectiveBorderRadius,
            onRetryUpload: widget.onRetryUpload,
            onCancelUpload: widget.onCancelUpload,
          ),
        if (isPrimary) const PrimaryBadge(),
      ],
    );
  }

  Widget _buildLoadingOverlay() {
    final cs = Theme.of(context).colorScheme;
    return Positioned.fill(
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: widget.config.effectiveBorderRadius,
          color: cs.onSurface.withValues(alpha: AppDimensions.opacityHalf),
        ),
        child: Center(
          child: CircularProgressIndicator(color: cs.surfaceContainerHighest),
        ),
      ),
    );
  }

  void _onPageChanged(int index) {
    if (mounted) {
      setState(() => _currentIndex = index);
    }
  }

  void _onDotTap(int index) {
    if (widget.config.enableHapticFeedback) {
      HapticFeedback.lightImpact();
    }
    _pageController.animateToPage(
      index,
      duration: AppDimensions.animationDurationCommon,
      curve: Curves.easeInOut,
    );
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
      final result = await imagePickerService.pickMultipleImages();

      if (result.isNotEmpty) {
        final newUrls = List<String>.from(widget.imageUrls);
        final availableSlots = widget.config.maxImages - newUrls.length;
        final imagesToAdd =
            result.take(availableSlots).map((e) => e.path).toList();
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

  void _removeImage() {
    if (widget.imageUrls.isEmpty) return;

    if (widget.config.enableHapticFeedback) {
      HapticFeedback.lightImpact();
    }

    final newUrls = List<String>.from(widget.imageUrls);
    newUrls.removeAt(_currentIndex);
    widget.onImagesChanged?.call(newUrls);

    if (_currentIndex >= newUrls.length && newUrls.isNotEmpty) {
      _currentIndex = newUrls.length - 1;
      _pageController.animateToPage(
        _currentIndex,
        duration: AppDimensions.animationDurationCommon,
        curve: Curves.easeInOut,
      );
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

  void _setPrimary() {
    if (widget.config.enableHapticFeedback) {
      HapticFeedback.lightImpact();
    }
    widget.onPrimaryImageChanged?.call(_currentIndex);
  }
}
