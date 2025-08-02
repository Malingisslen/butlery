// lib/widgets/image/recipe_image_widget.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:butlery/theme/app_colors.dart';
import 'package:butlery/widgets/image/image_config.dart';
import 'package:butlery/widgets/image/image_components.dart';
import 'package:butlery/services/performance/optimized_image_loader.dart';

class RecipeImageWidget extends StatefulWidget {
  final List<String> imageUrls;
  final ImageConfig config;
  final VoidCallback? onTap;
  final Function(int)? onImageTap;
  final String? heroTag;

  const RecipeImageWidget({
    super.key,
    required this.imageUrls,
    required this.config,
    this.onTap,
    this.onImageTap,
    this.heroTag,
  });

  factory RecipeImageWidget.card({
    Key? key,
    required List<String> imageUrls,
    ImageSize size = ImageSize.card,
    bool showMultipleIndicator = true,
    double? customWidth,
    double? customHeight,
    BorderRadius? borderRadius,
    VoidCallback? onTap,
    Function(int)? onImageTap,
  }) {
    return RecipeImageWidget(
      key: key,
      imageUrls: imageUrls,
      config: ImageConfig.recipeCard(
        size: size,
        showMultipleIndicator: showMultipleIndicator,
        customWidth: customWidth,
        customHeight: customHeight,
        borderRadius: borderRadius,
      ),
      onTap: onTap,
      onImageTap: onImageTap,
    );
  }

  factory RecipeImageWidget.detail({
    Key? key,
    required List<String> imageUrls,
    ImageSize size = ImageSize.large,
    bool showNavigationDots = true,
    bool showImageCounter = true,
    String? heroTag,
    VoidCallback? onTap,
    Function(int)? onImageTap,
  }) {
    return RecipeImageWidget(
      key: key,
      imageUrls: imageUrls,
      config: ImageConfig.recipeDetail(
        size: size,
        showNavigationDots: showNavigationDots,
        showImageCounter: showImageCounter,
        heroTag: heroTag,
      ),
      onTap: onTap,
      onImageTap: onImageTap,
      heroTag: heroTag,
    );
  }

  @override
  State<RecipeImageWidget> createState() => _RecipeImageWidgetState();
}

class _RecipeImageWidgetState extends State<RecipeImageWidget> {
  late PageController _pageController;
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dimensions = widget.config.getDimensions();
    final hasImages = widget.imageUrls.isNotEmpty;

    return Container(
      width: dimensions.width == double.infinity ? null : dimensions.width,
      height: dimensions.height,
      decoration: BoxDecoration(
        borderRadius: widget.config.effectiveBorderRadius,
        color: AppColors.cardWhite,
      ),
      child: hasImages ? _buildImageContent() : _buildEmptyState(),
    );
  }

  Widget _buildImageContent() {
    switch (widget.config.type) {
      case ImageType.recipeCard:
        return _buildRecipeCard();
      case ImageType.recipeDetail:
        return _buildRecipeDetail();
      default:
        return _buildRecipeCard();
    }
  }

  Widget _buildRecipeCard() {
    final primaryImage = widget.imageUrls.first;

    return Stack(
      children: [
        OptimizedImageLoader.recipeCard(
          imageUrl: primaryImage,
          config: widget.config,
          onTap: widget.onTap,
        ),

        if (widget.config.showMultipleIndicator && widget.imageUrls.length > 1)
          ImageComponents.buildMultipleIndicator(
            imageCount: widget.imageUrls.length,
            config: widget.config,
          ),

        Positioned.fill(
          child: Container(
            decoration: BoxDecoration(
              borderRadius: widget.config.effectiveBorderRadius,
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.transparent,
                  AppColors.cardWhite.withValues(alpha: 0.1),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRecipeDetail() {

    return Stack(
      children: [
        ClipRRect(
          borderRadius: widget.config.effectiveBorderRadius,
          child: widget.imageUrls.length == 1
              ? _buildSingleImage(widget.imageUrls.first)
              : _buildImageCarousel(),
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
      ],
    );
  }

  Widget _buildSingleImage(String imageUrl) {
    Widget image = OptimizedImageLoader.recipeDetail(
      imageUrl: imageUrl,
      config: widget.config,
      onTap: null,
    );

    if (widget.heroTag != null) {
      image = Hero(
        tag: widget.heroTag!,
        child: image,
      );
    }

    if (widget.onTap != null || widget.onImageTap != null) {
      image = GestureDetector(
        onTap: () {
          if (widget.config.enableHapticFeedback) {
            HapticFeedback.lightImpact();
          }
          widget.onTap?.call();
          widget.onImageTap?.call(0);
        },
        child: image,
      );
    }

    return image;
  }

  Widget _buildImageCarousel() {
    return PageView.builder(
      controller: _pageController,
      onPageChanged: (index) {
        if (mounted) {
          setState(() {
            _currentIndex = index;
          });
        }
      },
      itemCount: widget.imageUrls.length,
      itemBuilder: (context, index) {
        return GestureDetector(
          onTap: () {
            if (widget.config.enableHapticFeedback) {
              HapticFeedback.lightImpact();
            }
            widget.onTap?.call();
            widget.onImageTap?.call(index);
          },
          child: OptimizedImageLoader.recipeDetail(
            imageUrl: widget.imageUrls[index],
            config: widget.config,
            onTap: null,
          ),
        );
      },
    );
  }

  Widget _buildEmptyState() {
    return ImageComponents.buildPlaceholder(
      config: widget.config,
      child: widget.onTap != null
          ? GestureDetector(
              onTap: widget.onTap,
              child: const Center(
                child: Icon(
                  Icons.add_photo_alternate_outlined,
                  size: 48,
                ),
              ),
            )
          : null,
    );
  }

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
}

class ImageCarouselWidget extends StatefulWidget {
  final List<String> imageUrls;
  final ImageConfig config;
  final Function(int)? onImageTap;
  final Function(int)? onPageChanged;
  final int initialIndex;

  const ImageCarouselWidget({
    super.key,
    required this.imageUrls,
    required this.config,
    this.onImageTap,
    this.onPageChanged,
    this.initialIndex = 0,
  });

  @override
  State<ImageCarouselWidget> createState() => _ImageCarouselWidgetState();
}

class _ImageCarouselWidgetState extends State<ImageCarouselWidget> {
  late PageController _pageController;
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dimensions = widget.config.getDimensions();

    return SizedBox(
      width: dimensions.width == double.infinity ? null : dimensions.width,
      height: dimensions.height,
      child: Stack(
        children: [
            ClipRRect(
            borderRadius: widget.config.effectiveBorderRadius,
            child: PageView.builder(
              controller: _pageController,
              onPageChanged: (index) {
                if (mounted) {
                  setState(() {
                    _currentIndex = index;
                  });
                }
                widget.onPageChanged?.call(index);
              },
              itemCount: widget.imageUrls.length,
              itemBuilder: (context, index) {
                return GestureDetector(
                  onTap: () {
                    if (widget.config.enableHapticFeedback) {
                      HapticFeedback.lightImpact();
                    }
                    widget.onImageTap?.call(index);
                  },
                  child: ImageComponents.buildOptimizedCachedImage(
                    imageUrl: widget.imageUrls[index],
                    config: widget.config,
                    fit: BoxFit.cover,
                    placeholder: ImageComponents.buildLoadingPlaceholder(
                      config: widget.config,
                    ),
                    errorWidget: ImageComponents.buildErrorPlaceholder(
                      config: widget.config,
                    ),
                  ),
                );
              },
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
        ],
      ),
    );
  }

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
}
