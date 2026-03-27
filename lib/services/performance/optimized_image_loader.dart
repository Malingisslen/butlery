/// Optimized image loader with automatic resizing, progressive loading, and memory management.
/// This service improves image loading performance by:
/// - Automatically resizing images based on display size
/// - Progressive loading with blur-up effect
/// - Memory-efficient caching with size limits
/// - Thumbnail generation for lists
/// - Network bandwidth optimization

import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:butlery/core/utils/animation_utils.dart';
import 'package:butlery/core/utils/firebase_url_utils.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/widgets/image/image_config.dart';
import 'package:butlery/widgets/image/image_components.dart';

/// Image size optimization parameters
class ImageOptimizationParams {
  final Size targetSize;
  final int quality;
  final String format;
  final bool progressive;

  const ImageOptimizationParams({
    required this.targetSize,
    this.quality = 85,
    this.format = 'webp',
    this.progressive = true,
  });

  /// Calculate optimal cache dimensions based on device pixel ratio
  Size getOptimalCacheSize(BuildContext context) {
    final pixelRatio = MediaQuery.of(context).devicePixelRatio;
    return Size(
      (targetSize.width * pixelRatio).roundToDouble(),
      (targetSize.height * pixelRatio).roundToDouble(),
    );
  }

  /// Returns the original URL unchanged.
  /// Firebase Storage doesn't support URL-based transforms;
  /// use pre-generated thumbnails instead.
  String getOptimizedUrl(String originalUrl) {
    return originalUrl;
  }
}

/// Memory cache manager for images
class ImageMemoryCacheManager {
  static final ImageMemoryCacheManager _instance =
      ImageMemoryCacheManager._internal();
  factory ImageMemoryCacheManager() => _instance;
  ImageMemoryCacheManager._internal();

  // Configuration
  static const int _maxCacheSizeMB = 100;

  // Track cache usage
  int _currentSizeBytes = 0;
  int _cacheHits = 0;
  int _cacheMisses = 0;

  /// Monitor memory pressure and clear cache if needed
  void checkMemoryPressure() {
    final currentSizeMB = _currentSizeBytes / 1024 / 1024;

    if (currentSizeMB > _maxCacheSizeMB) {
      AppLogger.warning(
          'Image cache memory pressure: ${currentSizeMB.toStringAsFixed(2)}MB');
      _clearLeastRecentlyUsed();
    }
  }

  /// Clear least recently used images
  void _clearLeastRecentlyUsed() {
    // This would integrate with CachedNetworkImage's cache
    // For now, we'll clear the entire cache
    PaintingBinding.instance.imageCache.clear();
    PaintingBinding.instance.imageCache.clearLiveImages();
    _currentSizeBytes = 0;

    AppLogger.info('Cleared image memory cache due to memory pressure');
  }

  /// Record cache access
  void recordCacheAccess(bool hit, int sizeBytes) {
    if (hit) {
      _cacheHits++;
    } else {
      _cacheMisses++;
      _currentSizeBytes += sizeBytes;
    }

    checkMemoryPressure();
  }

  /// Get cache statistics
  Map<String, dynamic> getCacheStats() {
    final hitRate = _cacheHits + _cacheMisses > 0
        ? (_cacheHits / (_cacheHits + _cacheMisses) * 100).toStringAsFixed(1)
        : '0.0';

    return {
      'hits': _cacheHits,
      'misses': _cacheMisses,
      'hitRate': '$hitRate%',
      'sizeMB': (_currentSizeBytes / 1024 / 1024).toStringAsFixed(2),
      'maxSizeMB': _maxCacheSizeMB,
    };
  }
}

/// Optimized image loader widget
class OptimizedImageLoader extends StatefulWidget {
  final String imageUrl;
  final ImageConfig config;
  final Size targetSize;
  final BoxFit fit;
  final Widget? placeholder;
  final Widget? errorWidget;
  final VoidCallback? onTap;
  final bool enableProgressive;
  final bool enableThumbnail;
  final String? thumbnailUrl;

  const OptimizedImageLoader({
    super.key,
    required this.imageUrl,
    required this.config,
    required this.targetSize,
    this.fit = BoxFit.cover,
    this.placeholder,
    this.errorWidget,
    this.onTap,
    this.enableProgressive = true,
    this.enableThumbnail = true,
    this.thumbnailUrl,
  });

  /// Factory for recipe card images
  factory OptimizedImageLoader.recipeCard({
    Key? key,
    required String imageUrl,
    required ImageConfig config,
    String? thumbnailUrl,
    VoidCallback? onTap,
  }) {
    final dimensions = config.getDimensions();

    return OptimizedImageLoader(
      key: key,
      imageUrl: imageUrl,
      config: config,
      targetSize: Size(
        dimensions.width == double.infinity ? 400 : dimensions.width,
        dimensions.height,
      ),
      onTap: onTap,
      enableThumbnail: true,
      thumbnailUrl: thumbnailUrl,
    );
  }

  /// Factory for recipe detail images
  factory OptimizedImageLoader.recipeDetail({
    Key? key,
    required String imageUrl,
    required ImageConfig config,
    String? thumbnailUrl,
    VoidCallback? onTap,
  }) {
    final dimensions = config.getDimensions();

    return OptimizedImageLoader(
      key: key,
      imageUrl: imageUrl,
      config: config,
      targetSize: Size(
        dimensions.width == double.infinity ? 800 : dimensions.width,
        dimensions.height,
      ),
      fit: BoxFit.contain, // Show full image without cropping
      onTap: onTap,
      enableProgressive: true,
      enableThumbnail: thumbnailUrl != null,
      thumbnailUrl: thumbnailUrl,
    );
  }

  @override
  State<OptimizedImageLoader> createState() => _OptimizedImageLoaderState();
}

class _OptimizedImageLoaderState extends State<OptimizedImageLoader>
    with SingleTickerProviderStateMixin {
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;
  final ImageMemoryCacheManager _cacheManager = ImageMemoryCacheManager();
  bool _reduceMotion = false;

  // Loading states
  bool _isLoadingFull = true;
  bool _hasError = false;
  bool _hasRecordedCacheMiss = false;

  // Thumbnail for progressive loading
  String? _thumbnailUrl;

  @override
  void initState() {
    super.initState();

    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeIn,
    );

    if (widget.enableThumbnail) {
      _thumbnailUrl = _generateThumbnailUrl();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduceMotion = !AnimationUtils.shouldAnimate(context);
    if (_reduceMotion) {
      _fadeController.value = 1.0;
    }
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  /// Get thumbnail URL for progressive loading.
  /// Uses real thumbnail URL when available, falls back to original URL.
  String _generateThumbnailUrl() {
    return widget.thumbnailUrl ?? widget.imageUrl;
  }

  @override
  Widget build(BuildContext context) {
    // Check if this is a local file path or network URL
    final isFilePath = _isFilePath(widget.imageUrl);

    if (isFilePath) {
      // For local files, use adaptive image handling
      return ImageComponents.buildAdaptiveImage(
        pathOrUrl: widget.imageUrl,
        config: widget.config,
        fit: widget.fit,
        onTap: widget.onTap,
        placeholder: widget.placeholder,
        errorWidget: widget.errorWidget,
      );
    }

    // For network URLs, use optimized loading
    final optParams = ImageOptimizationParams(
      targetSize: widget.targetSize,
      quality: 85,
      progressive: widget.enableProgressive,
    );

    final optimalSize = optParams.getOptimalCacheSize(context);
    final optimizedUrl = optParams.getOptimizedUrl(widget.imageUrl);

    Widget imageStack = Stack(
      fit: StackFit.expand,
      children: [
        // Thumbnail layer (blurred)
        if (widget.enableThumbnail && _thumbnailUrl != null)
          AnimatedOpacity(
            opacity: _isLoadingFull ? 1.0 : 0.0,
            duration: AnimationUtils.getDuration(
                context, const Duration(milliseconds: 200)),
            child: _buildThumbnailLayer(),
          ),

        // Full image layer
        FadeTransition(
          opacity: _fadeAnimation,
          child: _buildFullImage(optimizedUrl, optimalSize),
        ),

        // Error or placeholder overlay
        if (_hasError && widget.errorWidget != null)
          widget.errorWidget!
        else if (_isLoadingFull && widget.placeholder != null)
          AnimatedOpacity(
            opacity: _isLoadingFull ? 1.0 : 0.0,
            duration: AnimationUtils.getDuration(
                context, const Duration(milliseconds: 200)),
            child: widget.placeholder!,
          ),
      ],
    );

    // Wrap with clip if needed
    if (widget.config.borderRadius != null) {
      imageStack = ClipRRect(
        borderRadius: widget.config.effectiveBorderRadius,
        child: imageStack,
      );
    }

    // Wrap with gesture detector if needed
    if (widget.onTap != null) {
      imageStack = GestureDetector(
        onTap: widget.onTap,
        child: imageStack,
      );
    }

    return SizedBox(
      width: widget.targetSize.width == double.infinity
          ? double.infinity
          : widget.targetSize.width,
      height: widget.targetSize.height,
      child: imageStack,
    );
  }

  /// Build thumbnail layer with blur effect
  Widget _buildThumbnailLayer() {
    final tintColor = Theme.of(context).colorScheme.surfaceContainerLow;
    return CachedNetworkImage(
      imageUrl: _thumbnailUrl!,
      cacheKey: FirebaseUrlUtils.stableCacheKey(_thumbnailUrl!),
      fit: widget.fit,
      placeholder: (_, __) => Container(color: tintColor),
      errorWidget: (_, __, ___) => Container(color: tintColor),
      imageBuilder: (context, imageProvider) {
        return DecoratedBox(
          decoration: BoxDecoration(
            image: DecorationImage(
              image: imageProvider,
              fit: widget.fit,
            ),
          ),
          child: BackdropFilter(
            filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: const ColoredBox(
              color: Colors.transparent,
            ),
          ),
        );
      },
    );
  }

  /// Build full resolution image
  Widget _buildFullImage(String optimizedUrl, Size cacheSize) {
    return CachedNetworkImage(
      imageUrl: optimizedUrl,
      cacheKey: FirebaseUrlUtils.stableCacheKey(optimizedUrl),
      fit: widget.fit,
      memCacheWidth:
          cacheSize.width == double.infinity ? 800 : cacheSize.width.toInt(),
      memCacheHeight:
          cacheSize.height == double.infinity ? 600 : cacheSize.height.toInt(),
      fadeInDuration: Duration.zero, // We handle fade ourselves
      progressIndicatorBuilder: (context, url, progress) {
        if (!_isLoadingFull) {
          // Defer setState to avoid calling it during build
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              setState(() => _isLoadingFull = true);
            }
          });
        }

        // Record cache miss once per load, not on every progress tick
        if (!_hasRecordedCacheMiss) {
          _hasRecordedCacheMiss = true;
          _cacheManager.recordCacheAccess(false, _estimateImageSize(cacheSize));
        }

        return const SizedBox.shrink(); // Thumbnail handles loading state
      },
      imageBuilder: (context, imageProvider) {
        // Start fade animation when image is ready
        if (_isLoadingFull) {
          // Defer setState to avoid calling it during build
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              setState(() => _isLoadingFull = false);
              if (_reduceMotion) {
                _fadeController.value = 1.0;
              } else {
                _fadeController.forward();
              }
            }
          });
        }

        // Record cache hit
        _cacheManager.recordCacheAccess(true, 0);

        return Image(
          image: imageProvider,
          fit: widget.fit,
        );
      },
      errorWidget: (context, url, error) {
        AppLogger.error('Failed to load image: $url - $error');

        // Defer setState to avoid calling it during build
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            setState(() {
              _hasError = true;
              _isLoadingFull = false;
            });
          }
        });

        return widget.errorWidget ?? _buildDefaultErrorWidget();
      },
    );
  }

  /// Build default error widget
  Widget _buildDefaultErrorWidget() {
    final cs = Theme.of(context).colorScheme;
    return ColoredBox(
      color: cs.surfaceContainerLow,
      child: Center(
        child: Icon(
          Icons.broken_image,
          size: 48,
          color: cs.outline,
        ),
      ),
    );
  }

  /// Estimate image size in bytes
  int _estimateImageSize(Size size) {
    // Rough estimate: width * height * 4 bytes per pixel
    // Handle infinity/NaN dimensions safely
    final width = size.width.isFinite ? size.width : 800.0;
    final height = size.height.isFinite ? size.height : 600.0;
    return (width * height * 4).toInt();
  }

  /// Check if string is a file path (vs URL)
  bool _isFilePath(String pathOrUrl) {
    // File paths start with '/' or contain file system patterns
    return pathOrUrl.startsWith('/') ||
        pathOrUrl.contains('\\') ||
        (!pathOrUrl.startsWith('http') && !pathOrUrl.startsWith('gs://'));
  }
}

/// Extension to easily use optimized image loader
extension OptimizedImageExtension on ImageConfig {
  /// Build an optimized image widget
  Widget buildOptimizedImage({
    required String imageUrl,
    VoidCallback? onTap,
    Widget? placeholder,
    Widget? errorWidget,
  }) {
    final dimensions = getDimensions();

    return OptimizedImageLoader(
      imageUrl: imageUrl,
      config: this,
      targetSize: Size(
        dimensions.width == double.infinity ? 800 : dimensions.width,
        dimensions.height,
      ),
      onTap: onTap,
      placeholder: placeholder,
      errorWidget: errorWidget,
    );
  }
}
