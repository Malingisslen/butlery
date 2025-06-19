// lib/widgets/recipe_image_carousel.dart

import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../theme/app_theme.dart';

/// Widget för att visa flera bilder i en karusell
class RecipeImageCarousel extends StatefulWidget {
  final List<String> imageUrls;
  final double height;
  final VoidCallback? onTap;

  const RecipeImageCarousel({
    super.key,
    required this.imageUrls,
    required this.height,
    this.onTap,
  });

  @override
  State<RecipeImageCarousel> createState() => _RecipeImageCarouselState();
}

class _RecipeImageCarouselState extends State<RecipeImageCarousel> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.imageUrls.isEmpty) {
      return _buildPlaceholder(context);
    }

    // Om bara en bild, visa utan karusell-funktionalitet
    if (widget.imageUrls.length == 1) {
      return GestureDetector(
        onTap: widget.onTap,
        child: ClipRRect(
          borderRadius: AppTheme.largeRadius,
          child: CachedNetworkImage(
            imageUrl: widget.imageUrls.first,
            height: widget.height,
            width: double.infinity,
            fit: BoxFit.cover,
            placeholder: (context, url) => _buildLoadingPlaceholder(context),
            errorWidget:
                (context, url, error) => _buildErrorPlaceholder(context),
          ),
        ),
      );
    }

    // Flera bilder - visa karusell
    return Stack(
      children: [
        ClipRRect(
          borderRadius: AppTheme.largeRadius,
          child: SizedBox(
            height: widget.height,
            child: PageView.builder(
              controller: _pageController,
              onPageChanged: (index) {
                setState(() {
                  _currentPage = index;
                });
              },
              itemCount: widget.imageUrls.length,
              itemBuilder: (context, index) {
                return GestureDetector(
                  onTap: widget.onTap,
                  child: CachedNetworkImage(
                    imageUrl: widget.imageUrls[index],
                    height: widget.height,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    placeholder:
                        (context, url) => _buildLoadingPlaceholder(context),
                    errorWidget:
                        (context, url, error) =>
                            _buildErrorPlaceholder(context),
                  ),
                );
              },
            ),
          ),
        ),

        // Bildindikator
        Positioned(
          bottom: AppTheme.spacingSm,
          left: 0,
          right: 0,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(
              widget.imageUrls.length,
              (index) => Container(
                width: 8,
                height: 8,
                margin: EdgeInsets.symmetric(horizontal: AppTheme.spacingXxs),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color:
                      _currentPage == index
                          ? Colors.white
                          : Colors.white.withValues(
                            alpha: 0.5,
                          ), // Fixat: använder withValues istället för withOpacity
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(
                        alpha: 0.3,
                      ), // Fixat: använder withValues istället för withOpacity
                      blurRadius: 2,
                      offset: const Offset(0, 1),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),

        // Bildnummer
        Positioned(
          top: AppTheme.spacingSm,
          right: AppTheme.spacingSm,
          child: Container(
            padding: EdgeInsets.symmetric(
              horizontal: AppTheme.spacingSm,
              vertical: AppTheme.spacingXxs,
            ),
            decoration: BoxDecoration(
              color: Colors.black.withValues(
                alpha: 0.7,
              ), // Fixat: använder withValues istället för withOpacity
              borderRadius: AppTheme.chipRadius,
            ),
            child: Text(
              '${_currentPage + 1}/${widget.imageUrls.length}',
              style: TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPlaceholder(BuildContext context) {
    return Container(
      height: widget.height,
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppTheme.dividerColor,
        borderRadius: AppTheme.largeRadius,
      ),
      child: Icon(
        Icons.restaurant_menu,
        size: widget.height * 0.3,
        color: AppTheme.textTertiary,
      ),
    );
  }

  Widget _buildLoadingPlaceholder(BuildContext context) {
    return Container(
      height: widget.height,
      width: double.infinity,
      color: AppTheme.dividerColor,
      child: Center(child: AppTheme.mediumLoadingIndicator()),
    );
  }

  Widget _buildErrorPlaceholder(BuildContext context) {
    return Container(
      height: widget.height,
      width: double.infinity,
      color: AppTheme.dividerColor,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.broken_image,
            size: widget.height * 0.2,
            color: AppTheme.textTertiary,
          ),
          AppTheme.tinyGap,
          Text(
            'Bild saknas',
            style: AppTheme.captionStyle.copyWith(color: AppTheme.textTertiary),
          ),
        ],
      ),
    );
  }
}

/// Widget för att visa och hantera bilder i formulär
class RecipeImageManager extends StatelessWidget {
  final List<String> imageUrls;
  final Function(String) onAddImage;
  final Function(int) onRemoveImage;
  final Function(int) onSetPrimary;
  final VoidCallback onPickImage;
  final bool canAddMore;

  const RecipeImageManager({
    super.key,
    required this.imageUrls,
    required this.onAddImage,
    required this.onRemoveImage,
    required this.onSetPrimary,
    required this.onPickImage,
    required this.canAddMore,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Bilder', style: Theme.of(context).textTheme.headlineSmall),
        AppTheme.smallGap,

        // Befintliga bilder
        if (imageUrls.isNotEmpty) ...[
          SizedBox(
            height: 100,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: imageUrls.length,
              itemBuilder: (context, index) {
                return Container(
                  width: 100,
                  margin: EdgeInsets.only(right: AppTheme.spacingSm),
                  child: Stack(
                    children: [
                      // Bilden
                      ClipRRect(
                        borderRadius: AppTheme.mediumRadius,
                        child: CachedNetworkImage(
                          imageUrl: imageUrls[index],
                          width: 100,
                          height: 100,
                          fit: BoxFit.cover,
                          placeholder:
                              (context, url) => Container(
                                color: AppTheme.dividerColor,
                                child: Center(
                                  child: AppTheme.smallLoadingIndicator(
                                    context,
                                  ),
                                ),
                              ),
                          errorWidget:
                              (context, url, error) => Container(
                                color: AppTheme.dividerColor,
                                child: const Icon(Icons.broken_image),
                              ),
                        ),
                      ),

                      // Primärbild-markering
                      if (index == 0)
                        Positioned(
                          top: 4,
                          left: 4,
                          child: Container(
                            padding: EdgeInsets.all(AppTheme.spacingXxs),
                            decoration: BoxDecoration(
                              color: AppTheme.primaryColor,
                              borderRadius: AppTheme.chipRadius,
                            ),
                            child: Icon(
                              Icons.star,
                              size: 12,
                              color: Colors.white,
                            ),
                          ),
                        ),

                      // Ta bort-knapp
                      Positioned(
                        top: 4,
                        right: 4,
                        child: GestureDetector(
                          onTap: () => onRemoveImage(index),
                          child: Container(
                            padding: EdgeInsets.all(AppTheme.spacingXxs),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(
                                alpha: 0.7,
                              ), // Fixat: använder withValues istället för withOpacity
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.close,
                              size: 16,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),

                      // Sätt som primär-knapp (om inte redan primär)
                      if (index != 0)
                        Positioned(
                          bottom: 4,
                          right: 4,
                          child: GestureDetector(
                            onTap: () => onSetPrimary(index),
                            child: Container(
                              padding: EdgeInsets.all(AppTheme.spacingXxs),
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(
                                  alpha: 0.7,
                                ), // Fixat: använder withValues istället för withOpacity
                                borderRadius: AppTheme.chipRadius,
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.star_border,
                                    size: 12,
                                    color: Colors.white,
                                  ),
                                  SizedBox(width: 2),
                                  Text(
                                    'Primär',
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: Colors.white,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                );
              },
            ),
          ),
          AppTheme.smallGap,
        ],

        // Lägg till bild-knapp
        if (canAddMore)
          OutlinedButton.icon(
            onPressed: onPickImage,
            icon: const Icon(Icons.add_photo_alternate),
            label: Text(
              imageUrls.isEmpty
                  ? 'Lägg till bild'
                  : 'Lägg till fler bilder (${imageUrls.length}/5)',
            ),
            style: OutlinedButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.primary,
            ),
          ),

        if (!canAddMore)
          Text(
            'Max 5 bilder per recept',
            style: AppTheme.captionStyle.copyWith(color: AppTheme.textTertiary),
          ),
      ],
    );
  }
}
