// lib/widgets/cached_recipe_image.dart

import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../theme/app_theme.dart';

/// Optimerad bildwidget för recept med caching och memory management
class CachedRecipeImage extends StatelessWidget {
  final String? imageUrl;
  final double size;
  final BorderRadius? borderRadius;

  const CachedRecipeImage({
    super.key,
    required this.imageUrl,
    required this.size,
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    if (imageUrl == null || imageUrl!.isEmpty) {
      return _buildPlaceholder(context);
    }

    return ClipRRect(
      borderRadius: borderRadius ?? AppTheme.roundRadius,
      child: CachedNetworkImage(
        imageUrl: imageUrl!,
        width: size,
        height: size,
        fit: BoxFit.cover,
        memCacheWidth: (size * 2).toInt(), // Optimera minnesanvändning
        memCacheHeight: (size * 2).toInt(),
        placeholder: (context, url) => _buildLoadingPlaceholder(context),
        errorWidget: (context, url, error) => _buildErrorPlaceholder(context),
        fadeInDuration: const Duration(milliseconds: 300),
        fadeOutDuration: const Duration(milliseconds: 300),
      ),
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
class CachedRecipeHeroImage extends StatelessWidget {
  final String? imageUrl;
  final double height;
  final double? width;

  const CachedRecipeHeroImage({
    super.key,
    required this.imageUrl,
    required this.height,
    this.width,
  });

  @override
  Widget build(BuildContext context) {
    if (imageUrl == null || imageUrl!.isEmpty) {
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

    return CachedNetworkImage(
      imageUrl: imageUrl!,
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
