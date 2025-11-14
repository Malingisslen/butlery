// lib/widgets/image/editable_image_widget.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:butlery/theme/app_colors.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/services/image_picker_service.dart';
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/widgets/image/image_config.dart';
import 'package:butlery/widgets/image/image_components.dart';
import 'package:butlery/services/upload/upload_models.dart';

/// Editable image widget with individual progress tracking for recipe editing
class EditableImageWidget extends StatefulWidget {
  final List<String> imageUrls;
  final ImageConfig config;
  final Function(List<String>)? onImagesChanged;
  final Function(int)? onPrimaryImageChanged;
  final Function(int)? onImageTap;
  final VoidCallback? onPickImage;
  final int primaryIndex;
  final bool isLoading;

  // Enhanced Upload Progress Support
  final Map<String, ImageUploadStatus>? uploadStatuses;
  final Function(String)? onRetryUpload;
  final Function(String)? onCancelUpload;
  final String? uploadQueueStatus; // Overall upload queue summary text
  // Bulk Upload Management
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

  /// Factory constructor for recipe editing with upload progress support
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

    // Reset internal loading state when external loading starts
    // This provides seamless transition from widget loading to external loading
    if (!oldWidget.isLoading && widget.isLoading && _isAddingImage) {
      setState(() {
        _isAddingImage = false;
      });
    }

    // Update page controller if primary index changed
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
    Widget mainContent;

    // Determine main content based on image count
    if (widget.imageUrls.isEmpty) {
      // ULTRATHINK FIX: Use compact picker configuration for empty state to prevent oversized empty picker
      final pickerConfig =
          ImageConfig.picker(maxImages: widget.config.maxImages);
      final pickerDimensions = pickerConfig.getDimensions();
      mainContent = SizedBox(
        width: pickerDimensions.width == double.infinity
            ? null
            : pickerDimensions.width,
        height: pickerDimensions.height == double.infinity
            ? null
            : pickerDimensions.height,
        child: _buildEmptyEditState(),
      );
    } else if (widget.imageUrls.length == 1) {
      // Single image: use original config dimensions for proper image display
      final dimensions = widget.config.getDimensions();
      mainContent = SizedBox(
        width: dimensions.width == double.infinity ? null : dimensions.width,
        height: dimensions.height == double.infinity ? null : dimensions.height,
        child: _buildEditCarousel(),
      );
    } else {
      // Multiple images: use adaptive grid layout that expands with content
      final dimensions = widget.config.getDimensions();
      mainContent = SizedBox(
        width: dimensions.width == double.infinity ? null : dimensions.width,
        // Remove fixed height for multiple images to allow vertical expansion
        child: _buildMultiImageGrid(),
      );
    }

    // Wrap with upload status if needed
    if (widget.uploadQueueStatus != null &&
        widget.uploadQueueStatus!.isNotEmpty) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildUploadQueueStatusBanner(),
          const SizedBox(height: AppDimensions.spacingSm),
          mainContent,
        ],
      );
    }

    return mainContent;
  }

  /// Build enhanced upload queue status banner with bulk management controls
  Widget _buildUploadQueueStatusBanner() {
    if (widget.uploadQueueStatus == null || widget.uploadQueueStatus!.isEmpty) {
      return const SizedBox.shrink();
    }

    final managementSummary = widget.uploadManagementSummary;
    final showBulkControls = managementSummary != null &&
        ((managementSummary['canBulkRetry'] as bool? ?? false) ||
            (managementSummary['canBulkCancel'] as bool? ?? false) ||
            (managementSummary['hasRetryableFailures'] as bool? ?? false));

    return Container(
      padding: const EdgeInsets.all(AppDimensions.paddingM),
      decoration: BoxDecoration(
        color: AppColors.primaryBlue.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppDimensions.borderRadiusM),
        border: Border.all(
          color: AppColors.primaryBlue.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Status row with progress indicator and enhanced details
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: const AlwaysStoppedAnimation<Color>(
                          AppColors.primaryBlue),
                      value: managementSummary != null
                          ? (managementSummary['overallProgress'] as double?)
                          : null,
                    ),
                  ),
                  const SizedBox(width: AppDimensions.spacingM),
                  Expanded(
                    child: Text(
                      widget.uploadQueueStatus!,
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.primaryBlue,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),

              // Enhanced progress details
              if (managementSummary != null) ...[
                const SizedBox(height: AppDimensions.spacingXs),
                _buildProgressDetails(managementSummary),
              ],
            ],
          ),

          // Bulk management controls
          if (showBulkControls) ...[
            const SizedBox(height: AppDimensions.spacingM),
            _buildBulkManagementControls(managementSummary),
          ],
        ],
      ),
    );
  }

  /// Build bulk management control buttons
  Widget _buildBulkManagementControls(Map<String, dynamic>? summary) {
    if (summary == null) return const SizedBox.shrink();
    final canBulkRetry = summary['canBulkRetry'] as bool? ?? false;
    final canBulkCancel = summary['canBulkCancel'] as bool? ?? false;
    final hasRetryableFailures =
        summary['hasRetryableFailures'] as bool? ?? false;
    final failed = summary['failed'] as int? ?? 0;
    final active = summary['active'] as int? ?? 0;

    final controls = <Widget>[];

    // Retry all failed button
    if (canBulkRetry && widget.onRetryAllFailed != null) {
      controls.add(
        _buildBulkActionButton(
          icon: Icons.refresh,
          label: 'Försök alla ($failed)',
          onTap: widget.onRetryAllFailed!,
          color: AppColors.primaryBlue,
        ),
      );
    }

    // Cancel all active button
    if (canBulkCancel && widget.onCancelAllActive != null) {
      controls.add(
        _buildBulkActionButton(
          icon: Icons.stop,
          label: 'Stoppa alla ($active)',
          onTap: widget.onCancelAllActive!,
          color: AppColors.textMedium,
        ),
      );
    }

    // Clear failed button
    if (hasRetryableFailures && widget.onClearAllFailed != null) {
      controls.add(
        _buildBulkActionButton(
          icon: Icons.clear_all,
          label: 'Rensa misslyckade',
          onTap: widget.onClearAllFailed!,
          color: AppColors.error,
        ),
      );
    }

    if (controls.isEmpty) return const SizedBox.shrink();

    return Wrap(
      spacing: AppDimensions.spacingSm,
      runSpacing: AppDimensions.spacingSm,
      children: controls,
    );
  }

  /// Build bulk action button
  Widget _buildBulkActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    required Color color,
  }) {
    return Material(
      color: color.withValues(alpha: 0.9),
      borderRadius: BorderRadius.circular(AppDimensions.borderRadiusS),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppDimensions.borderRadiusS),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppDimensions.paddingM,
            vertical: AppDimensions.paddingS,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: AppDimensions.iconSizeS,
                color: AppColors.cardWhite,
              ),
              const SizedBox(width: AppDimensions.spacingXs),
              Text(
                label,
                style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.cardWhite,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Build enhanced progress details with analytics
  Widget _buildProgressDetails(Map<String, dynamic> summary) {
    final progressText = summary['progressText'] as String?;
    final speedText = summary['speedText'] as String?;
    final summaryText = summary['summaryText'] as String?;

    final details = <String>[];

    if (progressText != null && progressText.isNotEmpty) {
      details.add(progressText);
    }
    if (speedText != null && speedText.isNotEmpty) {
      details.add(speedText);
    }
    if (summaryText != null &&
        summaryText.isNotEmpty &&
        summaryText != progressText) {
      details.add(summaryText);
    }

    if (details.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: details
          .map((detail) => Padding(
                padding: const EdgeInsets.only(top: AppDimensions.spacingXxs),
                child: Text(
                  detail,
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.primaryBlue.withValues(alpha: 0.8),
                    fontSize: 11, // Slightly smaller for secondary details
                  ),
                ),
              ))
          .toList(),
    );
  }

  /// Build empty state with add image button
  Widget _buildEmptyEditState() {
    // Remove unused theme variable

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: widget.config.effectiveBorderRadius,
        border: Border.all(
          color: AppColors.divider.withValues(alpha: 0.3),
          style: BorderStyle.solid,
        ),
        color: AppColors.cardWhite,
      ),
      child: Material(
        color: AppColors.transparent,
        child: InkWell(
          onTap: (_isAddingImage || widget.isLoading) ? null : _addImage,
          borderRadius: widget.config.effectiveBorderRadius,
          child: Center(
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_isAddingImage || widget.isLoading) ...[
                    const SizedBox(
                      width: AppDimensions.iconSizeXl,
                      height: AppDimensions.iconSizeXl,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          AppColors.primaryBlue,
                        ),
                      ),
                    ),
                    const SizedBox(
                        height: AppDimensions.spacingSm), // Reduced from 12
                    Text(
                      'Adding image...',
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: AppColors.textDark.withValues(alpha: 0.7),
                      ),
                    ),
                  ] else ...[
                    Container(
                      padding: const EdgeInsets.all(
                          AppDimensions.paddingM), // Reduced from 16
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.primaryBlue.withValues(alpha: 0.1),
                      ),
                      child: const Icon(
                        Icons.add_photo_alternate_outlined,
                        size: AppDimensions.iconSizeXl, // Reduced from 32
                        color: AppColors.primaryBlue,
                      ),
                    ),
                    const SizedBox(
                        height: AppDimensions.spacingSm), // Reduced from 12
                    Text(
                      'Lägg till bilder',
                      style: AppTextStyles.bodyMedium.copyWith(
                        // Changed from bodyLarge
                        color: AppColors.textDark,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(
                        height: AppDimensions.spacingXxs), // Reduced from 4
                    Text(
                      'Tryck för att lägga till upp till ${widget.config.maxImages} bilder',
                      style: AppTextStyles.bodySmall.copyWith(
                        // Changed from bodyMedium
                        color: AppColors.textDark.withValues(alpha: 0.7),
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

  /// Build edit carousel with controls
  Widget _buildEditCarousel() {
    return Stack(
      children: [
        // Image carousel
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
                  child: _buildEditCarouselImage(index),
                );
              },
            ),
          ),
        ),

        // Navigation dots
        if (widget.config.showNavigationDots && widget.imageUrls.length > 1)
          ImageComponents.buildNavigationDots(
            currentIndex: _currentIndex,
            totalImages: widget.imageUrls.length,
            config: widget.config,
            onDotTap: _onDotTap,
          ),

        // Image counter
        if (widget.config.showImageCounter && widget.imageUrls.length > 1)
          ImageComponents.buildImageCounter(
            currentIndex: _currentIndex,
            totalImages: widget.imageUrls.length,
            config: widget.config,
          ),

        // Edit actions
        if (widget.config.showEditControls) _buildEditActions(),

        // Loading overlay
        if (widget.isLoading)
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: widget.config.effectiveBorderRadius,
                color: AppColors.textDark.withValues(alpha: 0.5),
              ),
              child: const Center(
                child: CircularProgressIndicator(
                  color: AppColors.cardWhite,
                ),
              ),
            ),
          ),
      ],
    );
  }

  /// Build individual image in carousel with upload progress indicators
  Widget _buildEditCarouselImage(int index) {
    final imageUrl = widget.imageUrls[index];
    final isPrimary = index == widget.primaryIndex;
    final uploadStatus = widget.uploadStatuses?[imageUrl];
    final hasUploadStatus = uploadStatus != null;

    return Stack(
      children: [
        // Main image with stable key
        Semantics(
          label: 'Visa fullstorlek av bild',
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
              pathOrUrl: imageUrl, // Now handles both file paths and URLs
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

        // Upload Progress Overlay
        if (hasUploadStatus && uploadStatus.state != ImageUploadState.completed)
          _buildUploadProgressOverlay(uploadStatus, imageUrl),

        // Primary image indicator (shown above upload overlay)
        if (isPrimary)
          Positioned(
            top: AppDimensions.paddingM,
            left: AppDimensions.paddingM,
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: AppDimensions.spacingSm,
                  vertical: AppDimensions.spacingXs),
              decoration: BoxDecoration(
                color: AppColors.primaryBlue,
                borderRadius: BorderRadius.circular(AppDimensions.paddingM),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.star,
                    size: AppDimensions.iconSizeS,
                    color: AppColors.cardWhite,
                  ),
                  const SizedBox(width: AppDimensions.spacingXs),
                  Text(
                    'Primary',
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.cardWhite,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  /// Build upload progress overlay for individual images
  Widget _buildUploadProgressOverlay(
      ImageUploadStatus status, String imageUrl) {
    return Positioned.fill(
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: widget.config.effectiveBorderRadius,
          color: AppColors.textDark.withValues(alpha: 0.6),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Progress Circle/Icon based on state
            _buildProgressIndicator(status),

            const SizedBox(height: AppDimensions.spacingSm),

            // Status text
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppDimensions.paddingM,
                vertical: AppDimensions.paddingS,
              ),
              decoration: BoxDecoration(
                color: AppColors.textDark.withValues(alpha: 0.8),
                borderRadius: BorderRadius.circular(AppDimensions.paddingS),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    status.statusDescription,
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.cardWhite,
                      fontWeight: FontWeight.w500,
                    ),
                    textAlign: TextAlign.center,
                  ),

                  // Additional info for active uploads
                  if (status.isActive &&
                      status.formattedTimeRemaining != null) ...[
                    const SizedBox(height: AppDimensions.spacingXxs),
                    Text(
                      '${status.formattedTimeRemaining} kvar',
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.cardWhite.withValues(alpha: 0.8),
                      ),
                    ),
                  ],

                  // File size info
                  if (status.fileSizeMB != null) ...[
                    const SizedBox(height: AppDimensions.spacingXxs),
                    Text(
                      '${status.fileSizeMB!.toStringAsFixed(1)} MB',
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.cardWhite.withValues(alpha: 0.7),
                      ),
                    ),
                  ],
                ],
              ),
            ),

            // Action buttons for failed/cancelled uploads
            if (status.state == ImageUploadState.failed ||
                status.state == ImageUploadState.cancelled) ...[
              const SizedBox(height: AppDimensions.spacingSm),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Retry button
                  if (status.canRetry && widget.onRetryUpload != null)
                    _buildUploadActionButton(
                      icon: Icons.refresh,
                      label: 'Försök igen',
                      onTap: () => widget.onRetryUpload!(imageUrl),
                      color: AppColors.primaryBlue,
                    ),

                  if (status.canRetry &&
                      widget.onRetryUpload != null &&
                      widget.onCancelUpload != null)
                    const SizedBox(width: AppDimensions.spacingSm),

                  // Cancel/Remove button
                  if (widget.onCancelUpload != null)
                    _buildUploadActionButton(
                      icon: Icons.close,
                      label: 'Ta bort',
                      onTap: () => widget.onCancelUpload!(imageUrl),
                      color: AppColors.error,
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// Build progress indicator based on upload state
  Widget _buildProgressIndicator(ImageUploadStatus status) {
    switch (status.state) {
      case ImageUploadState.pending:
        return Container(
          width: 60,
          height: 60,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.cardWhite.withValues(alpha: 0.2),
          ),
          child: const Icon(
            Icons.schedule,
            color: AppColors.cardWhite,
            size: AppDimensions.iconSizeL,
          ),
        );

      case ImageUploadState.uploading:
      case ImageUploadState.retrying:
        return SizedBox(
          width: 60,
          height: 60,
          child: CircularProgressIndicator(
            value: status.progress > 0 ? status.progress : null,
            strokeWidth: 4,
            backgroundColor: AppColors.cardWhite.withValues(alpha: 0.3),
            valueColor: AlwaysStoppedAnimation<Color>(
              status.state == ImageUploadState.retrying
                  ? AppColors.textMedium
                  : AppColors.primaryBlue,
            ),
          ),
        );

      case ImageUploadState.completed:
        return Container(
          width: 60,
          height: 60,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.primaryBlue.withValues(alpha: 0.9),
          ),
          child: const Icon(
            Icons.check,
            color: AppColors.cardWhite,
            size: AppDimensions.iconSizeL,
          ),
        );

      case ImageUploadState.failed:
        return Container(
          width: 60,
          height: 60,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.error.withValues(alpha: 0.9),
          ),
          child: const Icon(
            Icons.error,
            color: AppColors.cardWhite,
            size: AppDimensions.iconSizeL,
          ),
        );

      case ImageUploadState.cancelled:
        return Container(
          width: 60,
          height: 60,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.textMedium.withValues(alpha: 0.9),
          ),
          child: const Icon(
            Icons.cancel,
            color: AppColors.cardWhite,
            size: AppDimensions.iconSizeL,
          ),
        );
    }
  }

  /// Build action button for upload overlay
  Widget _buildUploadActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    required Color color,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppDimensions.paddingS),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppDimensions.paddingM,
          vertical: AppDimensions.paddingS,
        ),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.9),
          borderRadius: BorderRadius.circular(AppDimensions.paddingS),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: AppColors.cardWhite,
              size: AppDimensions.iconSizeS,
            ),
            const SizedBox(width: AppDimensions.spacingXs),
            Text(
              label,
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.cardWhite,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Build edit actions
  Widget _buildEditActions() {
    return Positioned(
      bottom: AppDimensions.spacingMd,
      right: AppDimensions.spacingMd,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Add image button
          if (widget.imageUrls.length < widget.config.maxImages)
            _buildActionButton(
              icon: Icons.add_photo_alternate_outlined,
              onTap: _addImage,
              tooltip: 'Add image',
            ),

          const SizedBox(height: AppDimensions.spacingSm),

          // Set as primary button
          if (widget.imageUrls.length > 1 &&
              _currentIndex != widget.primaryIndex)
            _buildActionButton(
              icon: Icons.star_outline,
              onTap: _setPrimary,
              tooltip: 'Set as primary',
            ),

          const SizedBox(height: AppDimensions.spacingSm),

          // Remove image button
          _buildActionButton(
            icon: Icons.delete_outline,
            onTap: _removeImage,
            tooltip: 'Remove image',
            isDestructive: true,
          ),
        ],
      ),
    );
  }

  /// Build action button
  Widget _buildActionButton({
    required IconData icon,
    required VoidCallback onTap,
    required String tooltip,
    bool isDestructive = false,
  }) {
    // Remove unused theme variable

    return Tooltip(
      message: tooltip,
      child: Material(
        color: isDestructive ? AppColors.error : AppColors.cardWhite,
        borderRadius: BorderRadius.circular(AppDimensions.borderRadiusM),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppDimensions.borderRadiusM),
          child: Container(
            padding: const EdgeInsets.all(AppDimensions.spacingSm),
            child: Icon(
              icon,
              size: AppDimensions.iconSizeM,
              color: isDestructive ? AppColors.cardWhite : AppColors.textDark,
            ),
          ),
        ),
      ),
    );
  }

  /// Handle page change
  void _onPageChanged(int index) {
    if (mounted) {
      setState(() {
        _currentIndex = index;
      });
    }
  }

  /// Handle dot tap
  void _onDotTap(int index) {
    if (widget.config.enableHapticFeedback) {
      HapticFeedback.lightImpact();
    }

    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  /// Add image
  Future<void> _addImage() async {
    if (_isAddingImage || widget.imageUrls.length >= widget.config.maxImages) {
      return;
    }

    if (mounted) {
      setState(() {
        _isAddingImage = true;
      });
    }

    try {
      if (widget.config.enableHapticFeedback) {
        HapticFeedback.lightImpact();
      }

      // Use custom onPickImage callback if provided, otherwise use default behavior
      if (widget.onPickImage != null) {
        AppLogger.info(
            '🎯 EDITABLE_IMAGE_WIDGET: Using custom onPickImage callback');
        widget.onPickImage!();
        // Don't reset loading state immediately - let callback handle it
        // The callback will manage its own loading states
        return; // Let the callback handle the image selection
      }

      AppLogger.info(
          '🎯 EDITABLE_IMAGE_WIDGET: Using default image picker behavior');
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
        setState(() {
          _isAddingImage = false;
        });
      }
    }
  }

  /// Remove current image
  void _removeImage() {
    if (widget.imageUrls.isEmpty) return;

    if (widget.config.enableHapticFeedback) {
      HapticFeedback.lightImpact();
    }

    final newUrls = List<String>.from(widget.imageUrls);
    newUrls.removeAt(_currentIndex);

    widget.onImagesChanged?.call(newUrls);

    // Adjust current index if needed
    if (_currentIndex >= newUrls.length && newUrls.isNotEmpty) {
      _currentIndex = newUrls.length - 1;
      _pageController.animateToPage(
        _currentIndex,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }

    AppLogger.debug('Removed image at index $_currentIndex');
  }

  /// Set current image as primary
  void _setPrimary() {
    if (widget.config.enableHapticFeedback) {
      HapticFeedback.lightImpact();
    }

    widget.onPrimaryImageChanged?.call(_currentIndex);
    AppLogger.debug('Set primary image to index $_currentIndex');
  }

  /// Build adaptive grid layout for multiple images (prevents horizontal scrolling)
  Widget _buildMultiImageGrid() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Images in a responsive grid
        GridView.builder(
          shrinkWrap: true, // Allow grid to size itself based on content
          physics:
              const NeverScrollableScrollPhysics(), // Disable scrolling since parent handles it
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2, // 2 images per row
            crossAxisSpacing: AppDimensions.spacingSm,
            mainAxisSpacing: AppDimensions.spacingSm,
            childAspectRatio:
                1.2, // Slightly wider than square for recipe images
          ),
          itemCount: widget.imageUrls.length,
          itemBuilder: (context, index) {
            return _buildGridImageItem(index);
          },
        ),

        // Add image button if under limit
        if (widget.imageUrls.length < widget.config.maxImages) ...[
          const SizedBox(height: AppDimensions.spacingSm),
          _buildAddImageButton(),
        ],
      ],
    );
  }

  /// Build individual image item for grid layout
  Widget _buildGridImageItem(int index) {
    final imageUrl = widget.imageUrls[index];
    final isPrimary = index == widget.primaryIndex;

    return Semantics(
      label: isPrimary ? 'Primär bild, tryck för att visa fullstorlek' : 'Välj som primär bild',
      button: true,
      child: GestureDetector(
        // Move GestureDetector to the outermost level for better touch detection
        behavior: HitTestBehavior.opaque,
        onTap: () {
        AppLogger.debug('👆 TOUCH: Image $index tapped! isPrimary: $isPrimary');

        if (widget.config.enableHapticFeedback) {
          HapticFeedback.lightImpact();
        }

        // Primary selection: Tap image to make it primary
        if (!isPrimary) {
          AppLogger.debug(
              '🌟 GRID: Setting primary at index $index (callback: ${widget.onPrimaryImageChanged != null})');
          if (widget.onPrimaryImageChanged != null) {
            widget.onPrimaryImageChanged!(index);
          } else {
            AppLogger.warning(
                '⚠️ GRID: onPrimaryImageChanged callback is null!');
          }
        } else {
          AppLogger.debug('🌟 GRID: Primary image tapped - calling onImageTap');
          widget.onImageTap?.call(index);
        }
      },
      child: Stack(
        children: [
          // Main image display with border that actually surrounds the image
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: widget.config.effectiveBorderRadius,
                border: Border.all(
                  color: Theme.of(context).primaryColor,
                  width: isPrimary
                      ? AppDimensions.borderWidthThick *
                          2 // PRIMARY: Extra thick border (4px)
                      : AppDimensions
                          .borderWidthStandard, // NON-PRIMARY: Standard border (1px)
                ),
              ),
              child: ClipRRect(
                borderRadius: widget.config.effectiveBorderRadius,
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
          ),

          // Primary indicator (doesn't block touches)
          Positioned(
            top: AppDimensions.spacingXs,
            left: AppDimensions.spacingXs,
            child: IgnorePointer(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppDimensions.spacingXs,
                  vertical: AppDimensions.spacingXxs,
                ),
                decoration: BoxDecoration(
                  color: isPrimary
                      ? Theme.of(context).primaryColor
                      : Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withValues(alpha: 0.6),
                  borderRadius:
                      BorderRadius.circular(AppDimensions.borderRadiusS),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isPrimary ? Icons.star : Icons.star_outline,
                      size: AppDimensions.iconSizeXs,
                      color: AppColors.cardWhite,
                    ),
                    if (isPrimary) ...[
                      const SizedBox(width: AppDimensions.spacingXxs),
                      Text(
                        'Primär',
                        style: AppTextStyles.labelSmall.copyWith(
                              color: AppColors.cardWhite,
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),

          // Delete button with separate gesture detector to prevent conflicts
          if (widget.config.showEditControls)
            Positioned(
              bottom: AppDimensions.spacingXs,
              right: AppDimensions.spacingXs,
              child: Semantics(
                label: 'Ta bort bild',
                button: true,
                child: GestureDetector(
                  onTap: () {
                    AppLogger.debug(
                        '🗑️ DELETE: Delete button tapped for image $index');
                    _removeImageAtIndex(index);
                  },
                  child: _buildGridActionButton(
                    icon: Icons.close,
                    onTap: () {}, // Empty since we handle tap above
                    tooltip: 'Ta bort bild',
                    isDestructive: true,
                  ),
                ),
              ),
            ),
        ],
      ),
    ),
    );
  }

  /// Build action button for grid layout
  Widget _buildGridActionButton({
    required IconData icon,
    required VoidCallback onTap,
    required String tooltip,
    bool isDestructive = false,
  }) {
    return Tooltip(
      message: tooltip,
      child: Container(
        width: AppDimensions.iconSizeAction,
        height: AppDimensions.iconSizeAction,
        decoration: BoxDecoration(
          color: isDestructive ? AppColors.error : AppColors.cardWhite,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: AppColors.textDark.withValues(alpha: 0.2),
              blurRadius: AppDimensions.spacingXs,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Icon(
          icon,
          size: AppDimensions.iconSizeS,
          color: isDestructive ? AppColors.cardWhite : AppColors.textDark,
        ),
      ),
    );
  }

  /// Build add image button for grid layout
  Widget _buildAddImageButton() {
    return Semantics(
      label: 'Lägg till bild',
      button: true,
      enabled: !(_isAddingImage || widget.isLoading),
      child: GestureDetector(
        onTap: (_isAddingImage || widget.isLoading) ? null : _addImage,
        child: Container(
          height: AppDimensions.buttonHeight,
          decoration: BoxDecoration(
            borderRadius: widget.config.effectiveBorderRadius,
            border: Border.all(
              color: AppColors.primaryBlue.withValues(alpha: 0.3),
              width: AppDimensions.borderWidthThin,
            ),
            color: AppColors.primaryBlue.withValues(alpha: 0.05),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (_isAddingImage || widget.isLoading) ...[
                const SizedBox(
                  width: AppDimensions.iconSizeM,
                  height: AppDimensions.iconSizeM,
                  child: CircularProgressIndicator(
                    strokeWidth: AppDimensions.borderWidthThin,
                    valueColor:
                        AlwaysStoppedAnimation<Color>(AppColors.primaryBlue),
                  ),
                ),
                const SizedBox(width: AppDimensions.spacingSm),
                Flexible(
                  child: Text(
                    'Lägger till...',
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: AppColors.primaryBlue,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ] else ...[
                const Icon(
                  Icons.add_photo_alternate_outlined,
                  color: AppColors.primaryBlue,
                  size: AppDimensions.iconSizeM,
                ),
                const SizedBox(width: AppDimensions.spacingSm),
                Flexible(
                  child: Text(
                    'Lägg till (${widget.config.maxImages - widget.imageUrls.length})',
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: AppColors.primaryBlue,
                      fontWeight: FontWeight.w500,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  /// Remove image at specific index (for grid layout)
  void _removeImageAtIndex(int index) {
    if (index < 0 || index >= widget.imageUrls.length) return;

    if (widget.config.enableHapticFeedback) {
      HapticFeedback.lightImpact();
    }

    final newUrls = List<String>.from(widget.imageUrls);
    newUrls.removeAt(index);

    widget.onImagesChanged?.call(newUrls);

    AppLogger.debug('Removed image at index $index from grid layout');
  }
}
