// lib/widgets/image/simple_image_widget.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:butlery/core/utils/firebase_url_utils.dart';
import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/widgets/common/indicators/loading_indicator.dart';
import 'package:butlery/widgets/image/image_config.dart';
import 'package:butlery/widgets/image/image_components.dart';

class SimpleImageWidget extends StatelessWidget {
  final String? imageUrl;
  final ImageConfig config;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final Widget? placeholder;
  final Widget? errorWidget;
  final BoxFit fit;

  const SimpleImageWidget({
    super.key,
    this.imageUrl,
    required this.config,
    this.onTap,
    this.onLongPress,
    this.placeholder,
    this.errorWidget,
    this.fit = BoxFit.cover,
  });

  /// Factory constructor for hero image
  factory SimpleImageWidget.hero({
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
    return SimpleImageWidget(
      key: key,
      imageUrl: imageUrl,
      config: ImageConfig.hero(
        heroTag: heroTag,
        customWidth: customWidth,
        customHeight: customHeight,
        borderRadius: borderRadius,
      ),
      onTap: onTap,
      onLongPress: onLongPress,
      fit: fit,
    );
  }

  /// Factory constructor for thumbnail
  factory SimpleImageWidget.thumbnail({
    Key? key,
    required String imageUrl,
    ImageSize size = ImageSize.thumbnail,
    BorderRadius? borderRadius,
    VoidCallback? onTap,
    VoidCallback? onLongPress,
    BoxFit fit = BoxFit.cover,
  }) {
    return SimpleImageWidget(
      key: key,
      imageUrl: imageUrl,
      config: ImageConfig.thumbnail(
        size: size,
        borderRadius: borderRadius,
      ),
      onTap: onTap,
      onLongPress: onLongPress,
      fit: fit,
    );
  }

  /// Factory constructor for cached image
  factory SimpleImageWidget.cached({
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
    return SimpleImageWidget(
      key: key,
      imageUrl: imageUrl,
      config: ImageConfig.cached(
        size: size,
        customWidth: customWidth,
        customHeight: customHeight,
        borderRadius: borderRadius,
      ),
      onTap: onTap,
      onLongPress: onLongPress,
      fit: fit,
    );
  }

  @override
  Widget build(BuildContext context) {
    // Remove unused theme variable
    final dimensions = config.getDimensions();

    if (imageUrl == null || imageUrl!.isEmpty) {
      return _buildPlaceholder();
    }

    Widget image = SizedBox(
      width: dimensions.width == double.infinity ? null : dimensions.width,
      height: dimensions.height == double.infinity ? null : dimensions.height,
      child: ClipRRect(
        borderRadius: config.effectiveBorderRadius,
        child: ImageComponents.buildOptimizedCachedImage(
          imageUrl: imageUrl!,
          config: config,
          fit: fit,
          placeholder: placeholder ??
              ImageComponents.buildLoadingPlaceholder(
                config: config,
              ),
          errorWidget: errorWidget ??
              ImageComponents.buildErrorPlaceholder(
                config: config,
              ),
        ),
      ),
    );

    // Wrap with hero if needed
    if (config.heroTag != null) {
      image = Hero(
        tag: config.heroTag!,
        child: image,
      );
    }

    // Add tap handlers
    if (onTap != null || onLongPress != null) {
      image = Semantics(
        label: context.l10n.a11yViewFullSizeImage,
        button: true,
        child: GestureDetector(
          onTap: onTap != null
              ? () {
                  if (config.enableHapticFeedback) {
                    HapticFeedback.lightImpact();
                  }
                  onTap!();
                }
              : null,
          onLongPress: onLongPress != null
              ? () {
                  if (config.enableHapticFeedback) {
                    HapticFeedback.mediumImpact();
                  }
                  onLongPress!();
                }
              : null,
          child: image,
        ),
      );
    }

    return image;
  }

  /// Build placeholder when no image URL
  Widget _buildPlaceholder() {
    return placeholder ??
        ImageComponents.buildPlaceholder(
          config: config,
          child: onTap != null
              ? Builder(
                  builder: (context) => Semantics(
                    label: context.l10n.a11yAddImage,
                    button: true,
                    child: GestureDetector(
                      onTap: onTap,
                      child: const Center(
                        child: Icon(
                          Icons.add_photo_alternate_outlined,
                          size: AppDimensions.iconSizeXl,
                        ),
                      ),
                    ),
                  ),
                )
              : null,
        );
  }
}

/// Network image widget with built-in caching
class NetworkImageWidget extends StatelessWidget {
  final String imageUrl;
  final double? width;
  final double? height;
  final BoxFit fit;
  final BorderRadius? borderRadius;
  final Widget? placeholder;
  final Widget? errorWidget;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final bool enableHapticFeedback;

  const NetworkImageWidget({
    super.key,
    required this.imageUrl,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.borderRadius,
    this.placeholder,
    this.errorWidget,
    this.onTap,
    this.onLongPress,
    this.enableHapticFeedback = true,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    Widget image = CachedNetworkImage(
      imageUrl: imageUrl,
      cacheKey: FirebaseUrlUtils.stableCacheKey(imageUrl),
      width: width,
      height: height,
      fit: fit,
      memCacheWidth: width?.toInt(),
      memCacheHeight: height?.toInt(),
      placeholder: placeholder != null
          ? (_, __) => placeholder!
          : (_, __) => Container(
                width: width,
                height: height,
                color: cs.surfaceContainerHighest,
                child: const Center(
                  child: LoadingIndicator(),
                ),
              ),
      errorWidget: errorWidget != null
          ? (_, __, ___) => errorWidget!
          : (_, __, ___) => Container(
                width: width,
                height: height,
                color: cs.surfaceContainerHighest,
                child: Icon(
                  Icons.error_outline,
                  color: cs.error,
                ),
              ),
    );

    // Apply border radius if specified
    if (borderRadius != null) {
      image = ClipRRect(
        borderRadius: borderRadius!,
        child: image,
      );
    }

    // Add tap handlers
    if (onTap != null || onLongPress != null) {
      image = Semantics(
        label: context.l10n.a11yViewFullSizeImage,
        button: true,
        child: GestureDetector(
          onTap: onTap != null
              ? () {
                  if (enableHapticFeedback) {
                    HapticFeedback.lightImpact();
                  }
                  onTap!();
                }
              : null,
          onLongPress: onLongPress != null
              ? () {
                  if (enableHapticFeedback) {
                    HapticFeedback.mediumImpact();
                  }
                  onLongPress!();
                }
              : null,
          child: image,
        ),
      );
    }

    return image;
  }
}

/// Expandable image widget with zoom functionality
class ExpandableImageWidget extends StatefulWidget {
  final String imageUrl;
  final ImageConfig config;
  final VoidCallback? onTap;
  final Function(bool)? onExpandedChanged;
  final bool initiallyExpanded;

  const ExpandableImageWidget({
    super.key,
    required this.imageUrl,
    required this.config,
    this.onTap,
    this.onExpandedChanged,
    this.initiallyExpanded = false,
  });

  @override
  State<ExpandableImageWidget> createState() => _ExpandableImageWidgetState();
}

class _ExpandableImageWidgetState extends State<ExpandableImageWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  bool _isExpanded = false;

  @override
  void initState() {
    super.initState();
    _isExpanded = widget.initiallyExpanded;
    _animationController = AnimationController(
      duration: AppDimensions.animationDurationCommon,
      vsync: this,
    );
    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 1.5,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));

    if (_isExpanded) {
      _animationController.forward();
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: _isExpanded
          ? context.l10n.a11yShrinkImage
          : context.l10n.a11yEnlargeImage,
      button: true,
      child: GestureDetector(
        onTap: _toggleExpansion,
        child: AnimatedBuilder(
          animation: _scaleAnimation,
          builder: (context, child) {
            return Transform.scale(
              scale: _scaleAnimation.value,
              child: SimpleImageWidget(
                imageUrl: widget.imageUrl,
                config: widget.config,
                onTap: widget.onTap,
              ),
            );
          },
        ),
      ),
    );
  }

  /// Toggle expansion
  void _toggleExpansion() {
    if (widget.config.enableHapticFeedback) {
      HapticFeedback.lightImpact();
    }

    if (mounted) {
      setState(() {
        _isExpanded = !_isExpanded;
      });
    }

    if (_isExpanded) {
      _animationController.forward();
    } else {
      _animationController.reverse();
    }

    widget.onExpandedChanged?.call(_isExpanded);
    widget.onTap?.call();
  }
}

/// Lazy loading image widget
class LazyImageWidget extends StatefulWidget {
  final String imageUrl;
  final ImageConfig config;
  final VoidCallback? onTap;
  final bool autoLoad;

  const LazyImageWidget({
    super.key,
    required this.imageUrl,
    required this.config,
    this.onTap,
    this.autoLoad = true,
  });

  @override
  State<LazyImageWidget> createState() => _LazyImageWidgetState();
}

class _LazyImageWidgetState extends State<LazyImageWidget> {
  bool _shouldLoad = false;

  @override
  void initState() {
    super.initState();
    if (widget.autoLoad) {
      _shouldLoad = true;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_shouldLoad) {
      return Semantics(
        label: context.l10n.a11yLoadImage,
        button: true,
        child: GestureDetector(
          onTap: _loadImage,
          child: ImageComponents.buildPlaceholder(
            config: widget.config,
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.image_outlined,
                      size: AppDimensions.iconSizeXl),
                  const SizedBox(height: AppDimensions.spacingSm),
                  Text(context.l10n.imageTapToLoad),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return SimpleImageWidget(
      imageUrl: widget.imageUrl,
      config: widget.config,
      onTap: widget.onTap,
    );
  }

  /// Load image
  void _loadImage() {
    if (widget.config.enableHapticFeedback) {
      HapticFeedback.lightImpact();
    }

    if (mounted) {
      setState(() {
        _shouldLoad = true;
      });
    }
  }
}
