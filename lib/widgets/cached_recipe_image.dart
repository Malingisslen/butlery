// lib/widgets/cached_recipe_image.dart

import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../theme/app_theme.dart';

/// Optimerad bildwidget för recept med caching och memory management
/// UPPDATERAD för att hantera flera bilder
class CachedRecipeImage extends StatelessWidget {
  final List<String>? imageUrls; // ÄNDRAT från String? till List<String>?
  final double size;
  final BorderRadius? borderRadius;
  final bool showMultipleIndicator; // NY parameter

  const CachedRecipeImage({
    super.key,
    required this.imageUrls,
    required this.size,
    this.borderRadius,
    this.showMultipleIndicator = true,
  });

  @override
  Widget build(BuildContext context) {
    if (imageUrls == null || imageUrls!.isEmpty) {
      return _buildPlaceholder(context);
    }

    final primaryImageUrl = imageUrls!.first;

    return Stack(
      children: [
        ClipRRect(
          borderRadius: borderRadius ?? AppTheme.roundRadius,
          child: CachedNetworkImage(
            imageUrl: primaryImageUrl,
            width: size,
            height: size,
            fit: BoxFit.cover,
            memCacheWidth: (size * 2).toInt(), // Optimera minnesanvändning
            memCacheHeight: (size * 2).toInt(),
            placeholder: (context, url) => _buildLoadingPlaceholder(context),
            errorWidget:
                (context, url, error) => _buildErrorPlaceholder(context),
            fadeInDuration: const Duration(milliseconds: 300),
            fadeOutDuration: const Duration(milliseconds: 300),
          ),
        ),

        // Visa indikator för flera bilder
        if (showMultipleIndicator && imageUrls!.length > 1)
          Positioned(
            top: 4,
            right: 4,
            child: Container(
              padding: EdgeInsets.symmetric(
                horizontal: AppTheme.spacingXs,
                vertical: 2,
              ),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.7),
                borderRadius: AppTheme.chipRadius,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.collections, size: 12, color: Colors.white),
                  SizedBox(width: 2),
                  Text(
                    '${imageUrls!.length}',
                    style: TextStyle(
                      fontSize: 11,
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

  Widget _buildPlaceholder(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: AppTheme.dividerColor,
        borderRadius: borderRadius ?? AppTheme.roundRadius,
      ),
      child: Icon(
        Icons.restaurant_menu,
        size: size * 0.4,
        color: AppTheme.textTertiary,
      ),
    );
  }

  Widget _buildLoadingPlaceholder(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: AppTheme.dividerColor,
        borderRadius: borderRadius ?? AppTheme.roundRadius,
      ),
      child: Center(
        child: SizedBox(
          width: size * 0.3,
          height: size * 0.3,
          child: AppTheme.smallLoadingIndicator(context),
        ),
      ),
    );
  }

  Widget _buildErrorPlaceholder(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: AppTheme.dividerColor,
        borderRadius: borderRadius ?? AppTheme.roundRadius,
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.broken_image,
            size: size * 0.3,
            color: AppTheme.textTertiary,
          ),
          if (size > 50)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                'Bild saknas',
                style: AppTheme.captionStyle.copyWith(
                  fontSize: size * 0.12,
                  color: AppTheme.textTertiary,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Variant för stora bilder (t.ex. i recipe detail view)
/// UPPDATERAD för att hantera flera bilder
class CachedRecipeHeroImage extends StatelessWidget {
  final List<String>? imageUrls; // ÄNDRAT från String? till List<String>?
  final double height;
  final double? width;

  const CachedRecipeHeroImage({
    super.key,
    required this.imageUrls,
    required this.height,
    this.width,
  });

  @override
  Widget build(BuildContext context) {
    if (imageUrls == null || imageUrls!.isEmpty) {
      return Container(
        height: height,
        width: width ?? double.infinity,
        color: AppTheme.dividerColor,
        child: Icon(
          Icons.restaurant_menu,
          size: height * 0.3,
          color: AppTheme.textTertiary,
        ),
      );
    }

    final primaryImageUrl = imageUrls!.first;

    return CachedNetworkImage(
      imageUrl: primaryImageUrl,
      height: height,
      width: width ?? double.infinity,
      fit: BoxFit.cover,
      placeholder:
          (context, url) => Container(
            height: height,
            width: width ?? double.infinity,
            color: AppTheme.dividerColor,
            child: Center(child: AppTheme.mediumLoadingIndicator()),
          ),
      errorWidget:
          (context, url, error) => Container(
            height: height,
            width: width ?? double.infinity,
            color: AppTheme.dividerColor,
            child: const Icon(Icons.broken_image, size: 48),
          ),
    );
  }
}

