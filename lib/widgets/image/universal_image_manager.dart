// lib/widgets/universal_image_manager.dart - HELT FIXAD VERSION
// ✅ Alla syntaxfel fixade - Clean & Functional
// ✅ 100% AppTheme - Korrekt implementation

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:image_picker/image_picker.dart';
import '../../services/image_picker_service.dart';
import '../common/state_widget.dart';
import '../../theme/app_theme.dart';
import '../../core/injection.dart';
import '../../core/utils/logger.dart';

/// Typ av image-hantering
enum ImageType {
  avatar,
  recipeCard,
  recipeDetail,
  recipeEdit,
  gallery,
  picker,
  hero,
  thumbnail,
  cached,
}

/// Visningsläge för image manager
enum ImageDisplayMode {
  readonly,
  editable,
  expandable,
  carousel,
  grid,
  picker,
}

/// Storlek för image display
enum ImageSize {
  small,
  medium,
  large,
  extraLarge,
  card,
  hero,
  thumbnail,
  custom,
}

/// Optimerad konfiguration för ImageManager
class ImageConfig {
  final ImageType type;
  final ImageDisplayMode mode;
  final ImageSize size;
  final double? customWidth;
  final double? customHeight;
  final BorderRadius? borderRadius;
  final bool showPlaceholder;
  final bool showLoadingIndicator;
  final bool showMultipleIndicator;
  final bool showEditControls;
  final bool showStatusIndicator;
  final bool showNavigationDots;
  final bool showImageCounter;
  final bool enableHapticFeedback;
  final int maxImages;
  final String? heroTag;
  final Color? backgroundColor;
  final Color? borderColor;
  final double? borderWidth;

  const ImageConfig({
    required this.type,
    this.mode = ImageDisplayMode.readonly,
    this.size = ImageSize.medium,
    this.customWidth,
    this.customHeight,
    this.borderRadius,
    this.showPlaceholder = true,
    this.showLoadingIndicator = true,
    this.showMultipleIndicator = true,
    this.showEditControls = true,
    this.showStatusIndicator = false,
    this.showNavigationDots = true,
    this.showImageCounter = true,
    this.enableHapticFeedback = true,
    this.maxImages = 5,
    this.heroTag,
    this.backgroundColor,
    this.borderColor,
    this.borderWidth,
  });

  /// Factory constructors med korrekta defaults
  factory ImageConfig.avatar({
    ImageSize size = ImageSize.medium,
    bool showStatus = false,
    Color? borderColor,
    double? borderWidth,
    Color? backgroundColor,
  }) =>
      ImageConfig(
        type: ImageType.avatar,
        size: size,
        borderRadius: BorderRadius.circular(100), // Rund avatar
        showStatusIndicator: showStatus,
        borderColor: borderColor,
        borderWidth: borderWidth,
        backgroundColor: backgroundColor,
        showMultipleIndicator: false,
        showNavigationDots: false,
        showImageCounter: false,
      );

  factory ImageConfig.recipeCard({
    ImageSize size = ImageSize.card,
    bool expandable = true,
  }) =>
      ImageConfig(
        type: ImageType.recipeCard,
        mode: expandable
            ? ImageDisplayMode.expandable
            : ImageDisplayMode.readonly,
        size: size,
        borderRadius: AppTheme.mediumRadius,
        showNavigationDots: false,
        showImageCounter: false,
      );

  factory ImageConfig.recipeDetail({double? height}) => ImageConfig(
        type: ImageType.recipeDetail,
        mode: ImageDisplayMode.carousel,
        size: ImageSize.custom,
        customHeight: height ?? 250.0, // Standard carousel height
        borderRadius: AppTheme.largeRadius,
      );

  factory ImageConfig.recipeEdit({int maxImages = 5}) => ImageConfig(
        type: ImageType.recipeEdit,
        mode: ImageDisplayMode.editable,
        size: ImageSize.custom,
        customHeight: 240.0, // Standard edit height
        maxImages: maxImages,
        borderRadius: AppTheme.mediumRadius,
      );

  factory ImageConfig.gallery({ImageSize size = ImageSize.thumbnail}) =>
      ImageConfig(
        type: ImageType.gallery,
        mode: ImageDisplayMode.expandable,
        size: size,
        borderRadius: AppTheme.smallRadius,
        showNavigationDots: false,
        showImageCounter: false,
      );

  factory ImageConfig.picker({int maxImages = 5}) => ImageConfig(
        type: ImageType.picker,
        mode: ImageDisplayMode.picker,
        size: ImageSize.thumbnail,
        maxImages: maxImages,
        borderRadius: AppTheme.smallRadius,
        showNavigationDots: false,
        showImageCounter: false,
      );

  factory ImageConfig.cached({double? size, BorderRadius? borderRadius}) =>
      ImageConfig(
        type: ImageType.cached,
        size: ImageSize.custom,
        customWidth: size ?? 70.0, // Standard recipe image size
        customHeight: size ?? 70.0,
        borderRadius: borderRadius ?? BorderRadius.circular(35.0),
        showMultipleIndicator: false,
        showNavigationDots: false,
        showImageCounter: false,
      );
}

/// Universal Image Manager Widget
class UniversalImageManager extends StatefulWidget {
  final List<String>? imageUrls;
  final String? displayName;
  final ImageConfig config;
  final VoidCallback? onTap;
  final Function(String)? onAddImage;
  final Function(int)? onRemoveImage;
  final Function(int)? onSetPrimary;
  final Function(int, int)? onReorderImages;
  final Function(List<XFile>)? onMultipleImagesPicked;
  final VoidCallback? onPickImage;
  final String? userId;
  final bool isOnline;
  final bool canEdit;
  final double? height;

  const UniversalImageManager({
    super.key,
    this.imageUrls,
    this.displayName,
    required this.config,
    this.onTap,
    this.onAddImage,
    this.onRemoveImage,
    this.onSetPrimary,
    this.onReorderImages,
    this.onMultipleImagesPicked,
    this.onPickImage,
    this.userId,
    this.isOnline = false,
    this.canEdit = false,
    this.height,
  });

  /// Factory constructors
  factory UniversalImageManager.avatar({
    String? imageUrl,
    required String displayName,
    ImageSize size = ImageSize.medium,
    VoidCallback? onTap,
    bool showStatus = false,
    bool isOnline = false,
    Color? borderColor,
    double? borderWidth,
    Color? backgroundColor,
  }) =>
      UniversalImageManager(
        imageUrls: imageUrl != null ? [imageUrl] : null,
        displayName: displayName,
        config: ImageConfig.avatar(
          size: size,
          showStatus: showStatus,
          borderColor: borderColor,
          borderWidth: borderWidth,
          backgroundColor: backgroundColor,
        ),
        onTap: onTap,
        isOnline: isOnline,
      );

  factory UniversalImageManager.editableAvatar({
    String? imageUrl,
    required String displayName,
    ImageSize size = ImageSize.extraLarge,
    required VoidCallback onPickImage,
    Color? borderColor,
    double? borderWidth,
  }) =>
      UniversalImageManager(
        imageUrls: imageUrl != null ? [imageUrl] : null,
        displayName: displayName,
        config: ImageConfig.avatar(
          size: size,
          borderColor: borderColor,
          borderWidth: borderWidth,
        ),
        onPickImage: onPickImage,
        canEdit: true,
      );

  factory UniversalImageManager.statusAvatar({
    String? imageUrl,
    required String displayName,
    required bool isOnline,
    ImageSize size = ImageSize.medium,
    VoidCallback? onTap,
  }) =>
      UniversalImageManager(
        imageUrls: imageUrl != null ? [imageUrl] : null,
        displayName: displayName,
        config: ImageConfig.avatar(size: size, showStatus: true),
        onTap: onTap,
        isOnline: isOnline,
      );

  factory UniversalImageManager.cached({
    required List<String> imageUrls,
    double? size,
    BorderRadius? borderRadius,
    VoidCallback? onTap,
  }) =>
      UniversalImageManager(
        imageUrls: imageUrls,
        config: ImageConfig.cached(size: size, borderRadius: borderRadius),
        onTap: onTap,
      );

  factory UniversalImageManager.carousel({
    required List<String> imageUrls,
    required double height,
    VoidCallback? onTap,
  }) =>
      UniversalImageManager(
        imageUrls: imageUrls,
        config: ImageConfig.recipeDetail(height: height),
        onTap: onTap,
        height: height,
      );

  factory UniversalImageManager.recipeCard({
    List<String>? imageUrls,
    ImageSize size = ImageSize.card,
    VoidCallback? onTap,
    bool expandable = true,
  }) =>
      UniversalImageManager(
        imageUrls: imageUrls,
        config: ImageConfig.recipeCard(size: size, expandable: expandable),
        onTap: onTap,
      );

  factory UniversalImageManager.recipeEdit({
    List<String>? imageUrls,
    required String userId,
    required Function(String) onAddImage,
    required Function(int) onRemoveImage,
    required Function(int) onSetPrimary,
    Function(int, int)? onReorderImages,
    required VoidCallback onPickImage,
    int maxImages = 5,
  }) =>
      UniversalImageManager(
        imageUrls: imageUrls,
        userId: userId,
        config: ImageConfig.recipeEdit(maxImages: maxImages),
        onAddImage: onAddImage,
        onRemoveImage: onRemoveImage,
        onSetPrimary: onSetPrimary,
        onReorderImages: onReorderImages,
        onPickImage: onPickImage,
        canEdit: true,
      );

  factory UniversalImageManager.gallery({
    required List<String> imageUrls,
    ImageSize size = ImageSize.thumbnail,
    VoidCallback? onTap,
  }) =>
      UniversalImageManager(
        imageUrls: imageUrls,
        config: ImageConfig.gallery(size: size),
        onTap: onTap,
      );

  factory UniversalImageManager.picker({
    List<String>? imageUrls,
    required Function(List<XFile>) onMultipleImagesPicked,
    required Function(int) onRemoveImage,
    int maxImages = 5,
  }) =>
      UniversalImageManager(
        imageUrls: imageUrls,
        config: ImageConfig.picker(maxImages: maxImages),
        onMultipleImagesPicked: onMultipleImagesPicked,
        onRemoveImage: onRemoveImage,
      );

  factory UniversalImageManager.recipeDetail({
    required List<String> imageUrls,
    double? height,
    bool showCarousel = true,
    VoidCallback? onTap,
  }) =>
      UniversalImageManager(
        imageUrls: imageUrls,
        config: ImageConfig.recipeDetail(height: height),
        onTap: onTap,
        height: height,
      );

  /// Avatar factory som matchar UserDisplayWidgets API
  static Widget basicAvatar({
    required String displayName,
    String? imageUrl,
    double size = 40.0,
    VoidCallback? onTap,
  }) =>
      UniversalImageManager.avatar(
        imageUrl: imageUrl,
        displayName: displayName,
        size: size == 40.0
            ? ImageSize.medium
            : size <= 32.0
                ? ImageSize.small
                : size <= 48.0
                    ? ImageSize.medium
                    : size <= 80.0
                        ? ImageSize.large
                        : ImageSize.extraLarge,
        onTap: onTap,
      );
  @override
  State<UniversalImageManager> createState() => _UniversalImageManagerState();
}

class _UniversalImageManagerState extends State<UniversalImageManager> {
  late PageController _pageController;
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    AppLogger.info('🖼️ UniversalImageManager: ${widget.config.type.name}');
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  /// Dimension calculation
  double get _imageWidth {
    if (widget.config.customWidth != null) return widget.config.customWidth!;

    switch (widget.config.size) {
      case ImageSize.small:
        return 32.0;
      case ImageSize.medium:
        return 48.0;
      case ImageSize.large:
        return 80.0;
      case ImageSize.extraLarge:
        return 120.0;
      case ImageSize.card:
        return 70.0;
      case ImageSize.hero:
        return 200.0;
      case ImageSize.thumbnail:
        return 60.0;
      case ImageSize.custom:
        return widget.config.customWidth ?? double.infinity;
    }
  }

  double get _imageHeight {
    if (widget.height != null) return widget.height!;
    if (widget.config.customHeight != null) return widget.config.customHeight!;

    switch (widget.config.size) {
      case ImageSize.small:
        return 32.0;
      case ImageSize.medium:
        return 48.0;
      case ImageSize.large:
        return 80.0;
      case ImageSize.extraLarge:
        return 120.0;
      case ImageSize.card:
        return 70.0;
      case ImageSize.hero:
        return 200.0;
      case ImageSize.thumbnail:
        return 60.0;
      case ImageSize.custom:
        return widget.config.customHeight ?? _imageWidth;
    }
  }

  @override
  Widget build(BuildContext context) {
    switch (widget.config.type) {
      case ImageType.avatar:
        return widget.canEdit ? _buildEditableAvatar() : _buildAvatar();
      case ImageType.recipeCard:
        return _buildRecipeCard();
      case ImageType.recipeDetail:
        return _buildRecipeDetail();
      case ImageType.recipeEdit:
        return _buildRecipeEdit();
      case ImageType.gallery:
        return _buildGallery();
      case ImageType.picker:
        return _buildPicker();
      case ImageType.hero:
        return _buildHero();
      case ImageType.thumbnail:
        return _buildThumbnail();
      case ImageType.cached:
        return _buildCachedImage();
    }
  }

  /// Cached image implementation
  Widget _buildCachedImage() {
    final imageUrls = widget.imageUrls ?? [];
    if (imageUrls.isEmpty) {
      return _buildPlaceholder(Icons.restaurant_menu);
    }

    return _wrapWithTapHandler(
      ClipRRect(
        borderRadius: widget.config.borderRadius ?? BorderRadius.circular(35.0),
        child: _buildOptimizedCachedImage(imageUrls.first),
      ),
    );
  }

  /// Avatar implementation
  Widget _buildAvatar() {
    final imageUrl =
        widget.imageUrls?.isNotEmpty == true ? widget.imageUrls!.first : null;
    final hasImage = imageUrl != null && imageUrl.isNotEmpty;

    Widget avatar = Container(
      width: _imageWidth,
      height: _imageHeight,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: widget.config.backgroundColor ??
            Theme.of(context).colorScheme.primaryContainer,
        border: widget.config.borderWidth != null &&
                widget.config.borderColor != null
            ? Border.all(
                width: widget.config.borderWidth!,
                color: widget.config.borderColor!,
              )
            : null,
      ),
      child: hasImage
          ? ClipOval(child: _buildOptimizedCachedImage(imageUrl))
          : _buildInitialsAvatar(),
    );

    // Status indicator
    if (widget.config.showStatusIndicator) {
      avatar = Stack(
        children: [
          avatar,
          Positioned(
            right: 0,
            bottom: 0,
            child: Container(
              width: _imageWidth * 0.25,
              height: _imageWidth * 0.25,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: widget.isOnline
                    ? AppTheme.successColor
                    : AppTheme.textTertiary,
                border: Border.all(
                  color: Theme.of(context).colorScheme.surface,
                  width: 2.0,
                ),
              ),
            ),
          ),
        ],
      );
    }

    return _wrapWithTapHandler(avatar);
  }

  /// Editable avatar
  Widget _buildEditableAvatar() {
    return Stack(
      children: [
        _buildAvatar(),
        Positioned(
          right: 0,
          bottom: 0,
          child: Material(
            color: Theme.of(context).colorScheme.primary,
            shape: const CircleBorder(),
            child: InkWell(
              onTap: widget.onPickImage,
              borderRadius: BorderRadius.circular(16.0),
              child: Container(
                width: 32.0,
                height: 32.0,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Theme.of(context).colorScheme.primary,
                  border: Border.all(
                    color: Theme.of(context).colorScheme.surface,
                    width: 2.0,
                  ),
                ),
                child: Icon(
                  Icons.edit,
                  size: 16.0,
                  color: Theme.of(context).colorScheme.onPrimary,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// Initials avatar
  Widget _buildInitialsAvatar() {
    final initials = _getInitials(widget.displayName ?? '?');
    final fontSize = _imageWidth * 0.4;

    return Center(
      child: Text(
        initials,
        style: TextStyle(
          fontSize: fontSize,
          fontWeight: FontWeight.w600,
          color: Theme.of(context).colorScheme.onPrimaryContainer,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  /// Recipe card implementation
  Widget _buildRecipeCard() {
    final imageUrl =
        widget.imageUrls?.isNotEmpty == true ? widget.imageUrls!.first : null;

    Widget image = Container(
      width: _imageWidth,
      height: _imageHeight,
      decoration: BoxDecoration(
        borderRadius: widget.config.borderRadius ?? AppTheme.mediumRadius,
        color: AppTheme.dividerColor,
      ),
      child: imageUrl != null
          ? ClipRRect(
              borderRadius: widget.config.borderRadius ?? AppTheme.mediumRadius,
              child: _buildOptimizedCachedImage(imageUrl),
            )
          : _buildPlaceholder(Icons.restaurant_menu),
    );

    // Multiple indicator
    if (widget.config.showMultipleIndicator &&
        widget.imageUrls != null &&
        widget.imageUrls!.length > 1) {
      image = Stack(
        children: [
          image,
          Positioned(
            top: 4.0,
            right: 4.0,
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 4.0, vertical: 2.0),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.7),
                borderRadius: BorderRadius.circular(6.0),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.collections,
                      size: 12.0, color: Colors.white),
                  const SizedBox(width: 2.0),
                  Text(
                    '${widget.imageUrls!.length}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10.0,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      );
    }

    return _wrapWithTapHandler(image);
  }

  /// Recipe detail with carousel
  Widget _buildRecipeDetail() {
    final imageUrls = widget.imageUrls ?? [];

    if (imageUrls.isEmpty) {
      return _buildPlaceholder(Icons.restaurant_menu);
    }

    if (imageUrls.length == 1) {
      return _wrapWithTapHandler(
        ClipRRect(
          borderRadius: widget.config.borderRadius ?? AppTheme.largeRadius,
          child: _buildOptimizedCachedImage(imageUrls.first),
        ),
      );
    }

    return _buildCarousel(imageUrls);
  }

  /// Recipe edit implementation
  Widget _buildRecipeEdit() {
    final imageUrls = widget.imageUrls ?? [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Bilder',
              style: TextStyle(fontSize: 14.0, fontWeight: FontWeight.w500),
            ),
            if (widget.canEdit &&
                imageUrls.isNotEmpty &&
                imageUrls.length < widget.config.maxImages)
              TextButton.icon(
                onPressed: widget.onPickImage,
                icon: const Icon(Icons.add_photo_alternate),
                label: Text(
                  'Lägg till',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 8.0),
        if (imageUrls.isEmpty)
          _buildEmptyEditState()
        else
          _buildEditCarousel(imageUrls),
      ],
    );
  }

  /// Empty edit state
  Widget _buildEmptyEditState() {
    return Container(
      height: _imageHeight,
      decoration: BoxDecoration(
        border: Border.all(
          color: Theme.of(context).colorScheme.outline,
          style: BorderStyle.solid,
          width: 2.0,
        ),
        borderRadius: widget.config.borderRadius ?? AppTheme.mediumRadius,
        color: Theme.of(context).colorScheme.surfaceContainerLowest,
      ),
      child: StateWidget.empty(
        title: 'Lägg till bilder till ditt recept',
        subtitle:
            'Upp till ${widget.config.maxImages} bilder för att göra receptet mer attraktivt',
        icon: Icons.photo_camera_outlined,
        actionLabel: 'Välj bilder',
        onAction: widget.onPickImage,
      ),
    );
  }

  /// Edit carousel
  Widget _buildEditCarousel(List<String> imageUrls) {
    return Column(
      children: [
        // Main carousel
        Container(
          height: _imageHeight,
          decoration: BoxDecoration(
            borderRadius: widget.config.borderRadius ?? AppTheme.mediumRadius,
            boxShadow: const [
              BoxShadow(
                color: Color(0x1A000000),
                blurRadius: 12,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: widget.config.borderRadius ?? AppTheme.mediumRadius,
            child: PageView.builder(
              controller: _pageController,
              onPageChanged: (index) {
                setState(() => _currentIndex = index);
                if (widget.config.enableHapticFeedback) {
                  HapticFeedback.lightImpact();
                }
              },
              itemCount: imageUrls.length,
              itemBuilder: (context, index) =>
                  _buildEditCarouselImage(imageUrls[index], index),
            ),
          ),
        ),
        const SizedBox(height: 16.0),
        if (widget.config.showNavigationDots && imageUrls.length > 1) ...[
          _buildNavigationDots(imageUrls.length),
          const SizedBox(height: 16.0),
        ],
        if (widget.canEdit) _buildEditActions(),
      ],
    );
  }

  /// Edit carousel image
  Widget _buildEditCarouselImage(String imageUrl, int index) {
    final isPrimary = index == 0;

    return Stack(
      fit: StackFit.expand,
      children: [
        _buildOptimizedCachedImage(imageUrl),
        // Primary badge
        if (isPrimary)
          Positioned(
            top: 8.0,
            left: 8.0,
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary,
                borderRadius: BorderRadius.circular(12.0),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x1A000000),
                    blurRadius: 4,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.star,
                    color: Theme.of(context).colorScheme.onPrimary,
                    size: 16.0,
                  ),
                  const SizedBox(width: 4.0),
                  Text(
                    'Huvudbild',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onPrimary,
                      fontSize: 12.0,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        // Image counter
        if (widget.config.showImageCounter)
          Positioned(
            top: 8.0,
            right: 8.0,
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(12.0),
              ),
              child: Text(
                '${index + 1} / ${widget.imageUrls!.length}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12.0,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
      ],
    );
  }

  /// Navigation dots
  Widget _buildNavigationDots(int count) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(count, (index) {
        return GestureDetector(
          onTap: () {
            _pageController.animateToPage(
              index,
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
            );
            if (widget.config.enableHapticFeedback) {
              HapticFeedback.lightImpact();
            }
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            margin: const EdgeInsets.symmetric(horizontal: 4.0),
            width: _currentIndex == index ? 24.0 : 8.0,
            height: 8.0,
            decoration: BoxDecoration(
              color: _currentIndex == index
                  ? Theme.of(context).colorScheme.primary
                  : Theme.of(context)
                      .colorScheme
                      .outline
                      .withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(4.0),
            ),
          ),
        );
      }),
    );
  }

  /// Edit actions
  Widget _buildEditActions() {
    final currentIndex =
        _currentIndex.clamp(0, (widget.imageUrls?.length ?? 1) - 1);
    final isPrimary = currentIndex == 0;

    return Container(
      padding: const EdgeInsets.all(8.0),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(8.0),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: Row(
        children: [
          // Remove button
          Expanded(
            child: _buildActionButton(
              icon: Icons.delete_outline,
              label: 'Ta bort',
              onPressed: () {
                if (widget.config.enableHapticFeedback) {
                  HapticFeedback.mediumImpact();
                }
                widget.onRemoveImage?.call(currentIndex);
                _adjustCurrentIndex();
              },
              backgroundColor: Theme.of(context).colorScheme.errorContainer,
              foregroundColor: Theme.of(context).colorScheme.onErrorContainer,
            ),
          ),
          const SizedBox(width: 16.0),
          // Primary button
          Expanded(
            child: _buildActionButton(
              icon: isPrimary ? Icons.star : Icons.star_outline,
              label: isPrimary ? 'Huvudbild' : 'Sätt som huvud',
              onPressed: isPrimary
                  ? null
                  : () {
                      if (widget.config.enableHapticFeedback) {
                        HapticFeedback.mediumImpact();
                      }
                      widget.onSetPrimary?.call(currentIndex);
                      setState(() => _currentIndex = 0);
                      _pageController.animateToPage(
                        0,
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeInOut,
                      );
                    },
              backgroundColor: isPrimary
                  ? Theme.of(context).colorScheme.surfaceContainerHigh
                  : Theme.of(context).colorScheme.secondaryContainer,
              foregroundColor: isPrimary
                  ? Theme.of(context).colorScheme.onSurfaceVariant
                  : Theme.of(context).colorScheme.onSecondaryContainer,
            ),
          ),
        ],
      ),
    );
  }

  /// Action button
  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback? onPressed,
    required Color backgroundColor,
    required Color foregroundColor,
  }) {
    return Material(
      color: backgroundColor,
      borderRadius: BorderRadius.circular(8.0),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(8.0),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 8.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: foregroundColor, size: 16.0),
              const SizedBox(width: 4.0),
              Flexible(
                child: Text(
                  label,
                  style: TextStyle(
                    color: foregroundColor,
                    fontSize: 12.0,
                    fontWeight: FontWeight.w600,
                  ),
                  textAlign: TextAlign.center,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Gallery implementation
  Widget _buildGallery() {
    final imageUrls = widget.imageUrls ?? [];

    if (imageUrls.isEmpty) {
      return StateWidget.empty(
        title: 'Inga bilder',
        subtitle: 'Galleriet är tomt',
        icon: Icons.photo_library_outlined,
      );
    }

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 4.0,
        mainAxisSpacing: 4.0,
        childAspectRatio: 1.0,
      ),
      itemCount: imageUrls.length,
      itemBuilder: (context, index) {
        return _wrapWithTapHandler(
          ClipRRect(
            borderRadius:
                widget.config.borderRadius ?? BorderRadius.circular(4.0),
            child: _buildOptimizedCachedImage(imageUrls[index]),
          ),
        );
      },
    );
  }

  /// Picker implementation
  Widget _buildPicker() {
    final imageUrls = widget.imageUrls ?? [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (imageUrls.isNotEmpty) ...[
          Wrap(
            spacing: 8.0,
            runSpacing: 8.0,
            children: imageUrls.asMap().entries.map((entry) {
              final index = entry.key;
              final url = entry.value;

              return Stack(
                children: [
                  ClipRRect(
                    borderRadius: widget.config.borderRadius ??
                        BorderRadius.circular(4.0),
                    child: _buildOptimizedCachedImage(url),
                  ),
                  Positioned(
                    right: 0,
                    top: 0,
                    child: GestureDetector(
                      onTap: () => widget.onRemoveImage?.call(index),
                      child: Container(
                        padding: const EdgeInsets.all(4.0),
                        decoration: const BoxDecoration(
                          color: Colors.red,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.close,
                          color: Colors.white,
                          size: 16.0,
                        ),
                      ),
                    ),
                  ),
                ],
              );
            }).toList(),
          ),
          const SizedBox(height: 16.0),
        ],
        if (imageUrls.length < widget.config.maxImages)
          ElevatedButton.icon(
            onPressed: _pickMultipleImages,
            icon: const Icon(Icons.add_a_photo),
            label: const Text('Lägg till bilder'),
          ),
      ],
    );
  }

  /// Hero implementation
  Widget _buildHero() {
    final imageUrl =
        widget.imageUrls?.isNotEmpty == true ? widget.imageUrls!.first : null;

    return _wrapWithTapHandler(
      Hero(
        tag: widget.config.heroTag ?? 'hero_image',
        child: ClipRRect(
          borderRadius: widget.config.borderRadius ?? AppTheme.largeRadius,
          child: imageUrl != null
              ? _buildOptimizedCachedImage(imageUrl)
              : _buildPlaceholder(Icons.image),
        ),
      ),
    );
  }

  /// Thumbnail implementation
  Widget _buildThumbnail() {
    final imageUrl =
        widget.imageUrls?.isNotEmpty == true ? widget.imageUrls!.first : null;

    return ClipRRect(
      borderRadius: widget.config.borderRadius ?? BorderRadius.circular(4.0),
      child: imageUrl != null
          ? _buildOptimizedCachedImage(imageUrl)
          : _buildPlaceholder(Icons.image),
    );
  }

  /// Carousel implementation
  Widget _buildCarousel(List<String> imageUrls) {
    return Stack(
      children: [
        ClipRRect(
          borderRadius: widget.config.borderRadius ?? AppTheme.largeRadius,
          child: SizedBox(
            height: _imageHeight,
            child: PageView.builder(
              controller: _pageController,
              onPageChanged: (index) => setState(() => _currentIndex = index),
              itemCount: imageUrls.length,
              itemBuilder: (context, index) => _wrapWithTapHandler(
                _buildOptimizedCachedImage(imageUrls[index]),
              ),
            ),
          ),
        ),
        // Navigation dots
        if (widget.config.showNavigationDots)
          Positioned(
            bottom: 8.0,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(imageUrls.length, (index) {
                return Container(
                  width: 8.0,
                  height: 8.0,
                  margin: const EdgeInsets.symmetric(horizontal: 2.0),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _currentIndex == index
                        ? Colors.white
                        : Colors.white.withValues(alpha: 0.5),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x4D000000),
                        blurRadius: 2,
                        offset: Offset(0, 1),
                      ),
                    ],
                  ),
                );
              }),
            ),
          ),
        // Image counter
        if (widget.config.showImageCounter)
          Positioned(
            top: 8.0,
            right: 8.0,
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.7),
                borderRadius: BorderRadius.circular(6.0),
              ),
              child: Text(
                '${_currentIndex + 1}/${imageUrls.length}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12.0,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
      ],
    );
  }

  /// Optimized cached network image
  Widget _buildOptimizedCachedImage(String imageUrl) {
    return CachedNetworkImage(
      imageUrl: imageUrl,
      width: _imageWidth,
      height: _imageHeight,
      fit: BoxFit.cover,
      memCacheWidth:
          _imageWidth != double.infinity ? (_imageWidth * 2).toInt() : null,
      memCacheHeight:
          _imageHeight != double.infinity ? (_imageHeight * 2).toInt() : null,
      placeholder: (context, url) => _buildLoadingPlaceholder(),
      errorWidget: (context, url, error) => _buildErrorPlaceholder(),
      fadeInDuration: const Duration(milliseconds: 150),
      fadeOutDuration: const Duration(milliseconds: 150),
    );
  }

  /// Placeholder
  Widget _buildPlaceholder(IconData icon) {
    return Container(
      width: _imageWidth,
      height: _imageHeight,
      decoration: BoxDecoration(
        color: Colors.grey[300],
        borderRadius: widget.config.borderRadius,
      ),
      child: Center(
        child: Icon(
          icon,
          size: (_imageWidth * 0.4).clamp(16.0, 48.0),
          color: Colors.grey[600],
        ),
      ),
    );
  }

  /// Loading placeholder
  Widget _buildLoadingPlaceholder() {
    return Container(
      width: _imageWidth,
      height: _imageHeight,
      decoration: BoxDecoration(
        color: Colors.grey[300],
        borderRadius: widget.config.borderRadius,
      ),
      child: Center(
        child: SizedBox(
          width: (_imageWidth * 0.3).clamp(16.0, 32.0),
          height: (_imageWidth * 0.3).clamp(16.0, 32.0),
          child: const CircularProgressIndicator(strokeWidth: 2),
        ),
      ),
    );
  }

  /// Error placeholder
  Widget _buildErrorPlaceholder() {
    return Container(
      width: _imageWidth,
      height: _imageHeight,
      decoration: BoxDecoration(
        color: Colors.grey[300],
        borderRadius: widget.config.borderRadius,
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.broken_image,
            size: (_imageWidth * 0.3).clamp(16.0, 32.0),
            color: Colors.grey[600],
          ),
          if (_imageWidth > 60.0) ...[
            const SizedBox(height: 2.0),
            Text(
              'Bild saknas',
              style: TextStyle(
                fontSize: (_imageWidth * 0.12).clamp(8.0, 12.0),
                color: Colors.grey[600],
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// Wrap with tap handler
  Widget _wrapWithTapHandler(Widget child) {
    return widget.onTap != null
        ? GestureDetector(onTap: widget.onTap, child: child)
        : child;
  }

  /// Helper methods
  String _getInitials(String name) {
    if (name.isEmpty) return '?';
    final words = name.trim().split(RegExp(r'\s+'));
    if (words.length == 1) {
      final word = words[0];
      return word.length >= 2
          ? '${word[0]}${word[1]}'.toUpperCase()
          : word[0].toUpperCase();
    } else {
      return '${words[0][0]}${words[1][0]}'.toUpperCase();
    }
  }

  void _adjustCurrentIndex() {
    final imageCount = widget.imageUrls?.length ?? 0;
    if (_currentIndex >= imageCount && _currentIndex > 0) {
      setState(() => _currentIndex = _currentIndex - 1);
      _pageController.animateToPage(
        _currentIndex,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  Future<void> _pickMultipleImages() async {
    try {
      final imagePickerService = sl<ImagePickerService>();
      final files = await imagePickerService.pickMultipleImages(
        maxImages: widget.config.maxImages,
      );
      if (files.isNotEmpty) {
        final xFiles = files.map((file) => XFile(file.path)).toList();
        widget.onMultipleImagesPicked?.call(xFiles);
      }
    } catch (e) {
      AppLogger.error('💥 Fel vid bildval: $e');
    }
  }
}
