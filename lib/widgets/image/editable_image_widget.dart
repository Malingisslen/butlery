// lib/widgets/image/editable_image_widget.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:butlery/theme/app_colors.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/services/image_picker_service.dart';
import 'package:butlery/core/injection.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/widgets/image/image_config.dart';
import 'package:butlery/widgets/image/image_components.dart';

/// Editable image widget for recipe editing
class EditableImageWidget extends StatefulWidget {
  final List<String> imageUrls;
  final ImageConfig config;
  final Function(List<String>)? onImagesChanged;
  final Function(int)? onPrimaryImageChanged;
  final Function(int)? onImageTap;
  final int primaryIndex;
  final bool isLoading;

  const EditableImageWidget({
    super.key,
    required this.imageUrls,
    required this.config,
    this.onImagesChanged,
    this.onPrimaryImageChanged,
    this.onImageTap,
    this.primaryIndex = 0,
    this.isLoading = false,
  });

  /// Factory constructor for recipe editing
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
    int primaryIndex = 0,
    bool isLoading = false,
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
      primaryIndex: primaryIndex,
      isLoading: isLoading,
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
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Remove unused theme variable
    final dimensions = widget.config.getDimensions();

    return SizedBox(
      width: dimensions.width == double.infinity ? null : dimensions.width,
      height: dimensions.height,
      child: widget.imageUrls.isEmpty
          ? _buildEmptyEditState()
          : _buildEditCarousel(),
    );
  }

  /// Build empty state with add image button
  Widget _buildEmptyEditState() {
    // Remove unused theme variable
    
    return DecoratedBox(
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
          onTap: _isAddingImage ? null : _addImage,
          borderRadius: widget.config.effectiveBorderRadius,
          child: Center(
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_isAddingImage) ...[
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
                    const SizedBox(height: 8), // Reduced from 12
                    Text(
                      'Adding image...',
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: AppColors.textPrimary.withValues(alpha: 0.7),
                      ),
                    ),
                  ] else ...[
                    Container(
                      padding: const EdgeInsets.all(12), // Reduced from 16
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.primaryBlue.withValues(alpha: 0.1),
                      ),
                      child: const Icon(
                        Icons.add_photo_alternate_outlined,
                        size: 28, // Reduced from 32
                        color: AppColors.primaryBlue,
                      ),
                    ),
                    const SizedBox(height: 8), // Reduced from 12
                    Text(
                      'Add images',
                      style: AppTextStyles.bodyMedium.copyWith( // Changed from bodyLarge
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 2), // Reduced from 4
                    Text(
                      'Tap to add up to ${widget.config.maxImages} images',
                      style: AppTextStyles.bodySmall.copyWith( // Changed from bodyMedium
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
          child: PageView.builder(
            controller: _pageController,
            onPageChanged: _onPageChanged,
            itemCount: widget.imageUrls.length,
            itemBuilder: (context, index) {
              return _buildEditCarouselImage(index);
            },
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
        if (widget.config.showEditControls)
          _buildEditActions(),
        
        // Loading overlay
        if (widget.isLoading)
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: widget.config.effectiveBorderRadius,
                color: Colors.black.withValues(alpha: 0.5),
              ),
              child: const Center(
                child: CircularProgressIndicator(
                  color: Colors.white,
                ),
              ),
            ),
          ),
      ],
    );
  }

  /// Build individual image in carousel
  Widget _buildEditCarouselImage(int index) {
    final imageUrl = widget.imageUrls[index];
    final isPrimary = index == widget.primaryIndex;
    // Remove unused theme variable

    return Stack(
      children: [
        // Main image
        GestureDetector(
          onTap: () {
            if (widget.config.enableHapticFeedback) {
              HapticFeedback.lightImpact();
            }
            widget.onImageTap?.call(index);
          },
          child: ImageComponents.buildOptimizedCachedImage(
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
        ),
        
        // Primary image indicator
        if (isPrimary)
          Positioned(
            top: 12,
            left: 12,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.primaryBlue,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.star,
                    size: 14,
                    color: Colors.white,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Primary',
                    style: AppTextStyles.bodySmall.copyWith(
                      color: Colors.white,
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

  /// Build edit actions
  Widget _buildEditActions() {
    return Positioned(
      bottom: 16,
      right: 16,
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
          
          const SizedBox(height: 8),
          
          // Set as primary button
          if (widget.imageUrls.length > 1 && _currentIndex != widget.primaryIndex)
            _buildActionButton(
              icon: Icons.star_outline,
              onTap: _setPrimary,
              tooltip: 'Set as primary',
            ),
          
          const SizedBox(height: 8),
          
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
        color: isDestructive ? AppColors.error : AppColors.cardColor,
        borderRadius: BorderRadius.circular(AppDimensions.borderRadiusM),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppDimensions.borderRadiusM),
          child: Container(
            padding: const EdgeInsets.all(8),
            child: Icon(
              icon,
              size: 20,
              color: isDestructive ? Colors.white : AppColors.textPrimary,
            ),
          ),
        ),
      ),
    );
  }

  /// Handle page change
  void _onPageChanged(int index) {
    setState(() {
      _currentIndex = index;
    });
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
    if (_isAddingImage || widget.imageUrls.length >= widget.config.maxImages) return;

    setState(() {
      _isAddingImage = true;
    });

    try {
      if (widget.config.enableHapticFeedback) {
        HapticFeedback.lightImpact();
      }

      final imagePickerService = sl<ImagePickerService>();
      final result = await imagePickerService.pickMultipleImages();
      
      if (result.isNotEmpty) {
        final newUrls = List<String>.from(widget.imageUrls);
        final availableSlots = widget.config.maxImages - newUrls.length;
        final imagesToAdd = result.take(availableSlots).map((e) => e.path).toList();
        
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
}