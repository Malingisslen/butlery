// lib/widgets/image/avatar_image_widget.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:image_picker/image_picker.dart';
import 'package:butlery/theme/app_colors.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/services/image_picker_service.dart';
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/widgets/image/image_config.dart';
import 'package:butlery/widgets/image/image_components.dart';

/// Avatar image widget with support for initials fallback
class AvatarImageWidget extends StatelessWidget {
  final String? imageUrl;
  final String? displayName;
  final String? email;
  final bool isOnline;
  final ImageConfig config;
  final VoidCallback? onTap;
  final Function(String)? onImageSelected;

  const AvatarImageWidget({
    super.key,
    this.imageUrl,
    this.displayName,
    this.email,
    this.isOnline = false,
    required this.config,
    this.onTap,
    this.onImageSelected,
  });

  /// Factory constructor for readonly avatar
  factory AvatarImageWidget.readonly({
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
  }) {
    return AvatarImageWidget(
      key: key,
      imageUrl: imageUrl,
      displayName: displayName,
      email: email,
      isOnline: isOnline,
      config: ImageConfig.avatar(
        size: size,
        showStatus: showStatus,
        borderColor: borderColor,
        borderWidth: borderWidth,
        backgroundColor: backgroundColor,
      ),
      onTap: onTap,
    );
  }

  /// Factory constructor for editable avatar
  factory AvatarImageWidget.editable({
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
    required Function(String) onImageSelected,
  }) {
    return AvatarImageWidget(
      key: key,
      imageUrl: imageUrl,
      displayName: displayName,
      email: email,
      isOnline: isOnline,
      config: ImageConfig.avatar(
        size: size,
        showStatus: showStatus,
        borderColor: borderColor,
        borderWidth: borderWidth,
        backgroundColor: backgroundColor,
      ),
      onImageSelected: onImageSelected,
    );
  }

  @override
  Widget build(BuildContext context) {
    final dimensions = config.getDimensions();
    final isEditable = onImageSelected != null;

    Widget avatar = Stack(
      clipBehavior: Clip.none,
      children: [
        // Main avatar container
        Container(
          width: dimensions.width,
          height: dimensions.height,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: config.backgroundColor ?? AppColors.cardWhite,
            border: config.borderColor != null
                ? Border.all(
                    color: config.borderColor!,
                    width: config.borderWidth ?? 2.0,
                  )
                : null,
          ),
          child: ClipRRect(
            borderRadius: config.effectiveBorderRadius,
            child: _buildAvatarContent(),
          ),
        ),
        
        // Status indicator
        if (config.showStatusIndicator)
          ImageComponents.buildStatusIndicator(
            isOnline: isOnline,
            config: config,
          ),
        
        // Edit button for editable avatars
        if (isEditable)
          Positioned(
            bottom: -4,
            right: -4,
            child: Container(
              padding: const EdgeInsets.all(AppDimensions.spacingXs),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.primaryBlue,
                border: Border.all(
                  color: AppColors.cardWhite,
                  width: 2,
                ),
              ),
              child: const Icon(
                Icons.edit,
                size: 16,
                color: Colors.white,
              ),
            ),
          ),
      ],
    );

    // Wrap with tap handler
    if (onTap != null || isEditable) {
      avatar = GestureDetector(
        onTap: isEditable ? _handleEditTap : onTap,
        child: avatar,
      );
    }

    return avatar;
  }

  /// Build avatar content (image or initials)
  Widget _buildAvatarContent() {
    if (imageUrl != null && imageUrl!.isNotEmpty) {
      return CachedNetworkImage(
        imageUrl: imageUrl!,
        fit: BoxFit.cover,
        placeholder: (context, url) => _buildInitialsAvatar(),
        errorWidget: (context, url, error) => _buildInitialsAvatar(),
        memCacheWidth: config.getDimensions().width.toInt(),
        memCacheHeight: config.getDimensions().height.toInt(),
      );
    } else {
      return _buildInitialsAvatar();
    }
  }

  /// Build initials avatar fallback
  Widget _buildInitialsAvatar() {
    final dimensions = config.getDimensions();
    final initials = _getInitials();
    
    return Container(
      width: dimensions.width,
      height: dimensions.height,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: [
            AppColors.primaryBlue.withValues(alpha: 0.8),
            AppColors.primaryBlue,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Center(
        child: Text(
          initials,
          style: AppTextStyles.headlineMedium.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.w600,
            fontSize: _getFontSize(dimensions.width),
          ),
        ),
      ),
    );
  }

  /// Get initials from display name or email
  String _getInitials() {
    if (displayName != null && displayName!.trim().isNotEmpty) {
      final words = displayName!.trim()
          .split(' ')
          .where((word) => word.isNotEmpty)
          .toList();
      if (words.length >= 2) {
        return (words[0][0] + words[1][0]).toUpperCase();
      } else {
        return words[0][0].toUpperCase();
      }
    } else if (email != null && email!.isNotEmpty) {
      return email![0].toUpperCase();
    } else {
      return '?';
    }
  }

  /// Get font size based on avatar size
  double _getFontSize(double avatarSize) {
    if (avatarSize <= 40) return 12;
    if (avatarSize <= 60) return 16;
    if (avatarSize <= 80) return 20;
    if (avatarSize <= 120) return 24;
    return 28;
  }

  /// Handle edit tap for editable avatars
  Future<void> _handleEditTap() async {
    if (onImageSelected == null) return;

    try {
      if (config.enableHapticFeedback) {
        HapticFeedback.lightImpact();
      }

      final imagePickerService = ServiceLocator.get<ImagePickerService>();
      final result = await imagePickerService.pickImage(ImageSource.gallery);
      
      if (result != null) {
        onImageSelected!(result.path);
        AppLogger.debug('Avatar image selected: ${result.path}');
      }
    } catch (e) {
      AppLogger.error('Failed to pick avatar image: $e');
    }
  }
}

/// Editable avatar widget with built-in image picker
class EditableAvatarWidget extends StatefulWidget {
  final String? imageUrl;
  final String? displayName;
  final String? email;
  final bool isOnline;
  final ImageConfig config;
  final Function(String) onImageSelected;
  final VoidCallback? onImageRemoved;

  const EditableAvatarWidget({
    super.key,
    this.imageUrl,
    this.displayName,
    this.email,
    this.isOnline = false,
    required this.config,
    required this.onImageSelected,
    this.onImageRemoved,
  });

  @override
  State<EditableAvatarWidget> createState() => _EditableAvatarWidgetState();
}

class _EditableAvatarWidgetState extends State<EditableAvatarWidget> {
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        // Main avatar
        AvatarImageWidget(
          imageUrl: widget.imageUrl,
          displayName: widget.displayName,
          email: widget.email,
          isOnline: widget.isOnline,
          config: widget.config,
          onImageSelected: _handleImageSelected,
        ),
        
        // Loading overlay
        if (_isLoading)
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.cardWhite.withValues(alpha: 0.8),
              ),
              child: const Center(
                child: SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      AppColors.primaryBlue,
                    ),
                  ),
                ),
              ),
            ),
          ),
        
        // Remove button (if image exists)
        if (widget.imageUrl != null && 
            widget.imageUrl!.isNotEmpty && 
            widget.onImageRemoved != null)
          Positioned(
            top: -4,
            right: -4,
            child: GestureDetector(
              onTap: widget.onImageRemoved,
              child: Container(
                padding: const EdgeInsets.all(AppDimensions.spacingXs),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.error,
                  border: Border.all(
                    color: AppColors.cardWhite,
                    width: 2,
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
      ],
    );
  }

  /// Handle image selection with loading state
  Future<void> _handleImageSelected(String imagePath) async {
    setState(() {
      _isLoading = true;
    });

    try {
      await Future.delayed(const Duration(milliseconds: 100)); // Brief delay for UX
      widget.onImageSelected(imagePath);
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }
}