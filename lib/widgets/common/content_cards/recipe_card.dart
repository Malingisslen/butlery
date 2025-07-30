// lib/widgets/common/content_cards/recipe_card.dart

import 'package:flutter/material.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/theme/app_colors.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/widgets/image/simple_image_widget.dart';
import 'package:butlery/widgets/image/image_config.dart' as image_config;

/// Focused module for recipe card components
/// 
/// This module handles ONLY recipe card display responsibilities:
/// - Recipe card rendering with all recipe-specific data
/// - Recipe metadata display (portions, time, meal type)
/// - Recipe image handling and fallbacks
/// - Recipe tag display and formatting
/// - Recipe-specific styling and theming
/// 
/// ❌ DOES NOT CONTAIN: Friend cards, menu cards, shopping list cards, generic content logic
class RecipeCard extends StatelessWidget {
  final Recipe recipe;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final bool showImage;
  final bool showTags;
  final bool showMetadata;
  final EdgeInsets? margin;
  final EdgeInsets? padding;
  final RecipeCardStyle style;

  const RecipeCard({
    super.key,
    required this.recipe,
    this.onTap,
    this.onLongPress,
    this.showImage = true,
    this.showTags = true,  
    this.showMetadata = true,
    this.margin,
    this.padding,
    this.style = RecipeCardStyle.detailed,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin ?? const EdgeInsets.symmetric(vertical: 4, horizontal: 16),
      child: Material(
        elevation: 1, // Very subtle shadow
        borderRadius: BorderRadius.circular(AppDimensions.borderRadius10), // 8-12px subtle rounding
        color: Colors.white, // Pure white background
        child: InkWell(
          onTap: onTap,
          onLongPress: onLongPress,
          borderRadius: BorderRadius.circular(AppDimensions.borderRadius10),
          child: _buildContent(context),
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context) {
    switch (style) {
      case RecipeCardStyle.detailed:
        return _buildDetailedContent(context);
      case RecipeCardStyle.compact:
        return _buildCompactContent(context);
      case RecipeCardStyle.grid:
        return _buildGridContent(context);
    }
  }

  Widget _buildDetailedContent(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppDimensions.spacingM),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Circular icon placeholder on left
          _buildCircularIcon(context),
          
          const SizedBox(width: AppDimensions.spacingM),
          
          // Content column on right
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildTitleWithCategory(context),
                const SizedBox(height: AppDimensions.spacing6),
                _buildMetadataRow(context),
                if (recipe.rating != null) ...[
                  const SizedBox(height: AppDimensions.spacing6),
                  _buildRatingStars(context),
                ],
                if (recipe.description.isNotEmpty) ...[
                  const SizedBox(height: AppDimensions.spacingSm),
                  _buildRecipeDescription(context),
                ],
                if (showTags && recipe.tags?.isNotEmpty == true) ...[
                  const SizedBox(height: AppDimensions.spacingSm),
                  _buildSimpleTags(context),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompactContent(BuildContext context) {
    return Row(
      children: [
        if (showImage) ...[
          _buildRecipeImage(context, compact: true),
          const SizedBox(width: AppDimensions.spacingM),
        ],
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildRecipeHeader(context),
              if (showMetadata) ...[
                const SizedBox(height: AppDimensions.spacingXs),
                _buildRecipeMetadata(context),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildGridContent(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (showImage) ...[
          _buildRecipeImage(context, aspectRatio: 1.0),
          const SizedBox(height: AppDimensions.spacingS),
        ],
        _buildRecipeHeader(context),
        if (showMetadata) ...[
          const SizedBox(height: AppDimensions.spacingXs),
          _buildRecipeMetadata(context),
        ],
      ],
    );
  }

  Widget _buildRecipeImage(BuildContext context, {bool compact = false, double? aspectRatio}) {
    final height = compact ? 60.0 : (aspectRatio != null ? null : 200.0);
    final width = compact ? 60.0 : null;
    
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppDimensions.borderRadiusS),
      child: AspectRatio(
        aspectRatio: aspectRatio ?? (compact ? 1.0 : 16/9),
        child: SimpleImageWidget(
          imageUrl: recipe.primaryImageUrl,
          fit: BoxFit.cover,
          placeholder: Container(
            width: width,
            height: height,
            decoration: BoxDecoration(
              color: AppColors.backgroundTint,
              borderRadius: BorderRadius.circular(AppDimensions.borderRadiusS),
            ),
            child: Icon(
              Icons.restaurant,
              size: compact ? 24 : 48,
              color: AppColors.textMedium,
            ),
          ),
          config: image_config.ImageConfig(
            type: image_config.ImageType.recipeCard,
            size: compact ? image_config.ImageSize.small : image_config.ImageSize.medium,
          ),
        ),
      ),
    );
  }

  /// Builds circular icon placeholder for horizontal layout
  Widget _buildCircularIcon(BuildContext context) {
    return CircleAvatar(
      radius: 32, // 64px diameter
      backgroundColor: Colors.grey[450], // Medium grey background
      child: Icon(
        Icons.restaurant_menu,
        size: 28,
        color: Colors.grey[600], // Slightly darker grey
      ),
    );
  }

  /// Builds title row with category pill
  Widget _buildTitleWithCategory(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            recipe.title,
            style: AppTextStyles.titleMedium.copyWith(
              fontWeight: FontWeight.w600, // Semi-bold
              fontSize: 16,
              color: Colors.black,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        if (recipe.mealType.isNotEmpty) ...[
          const SizedBox(width: AppDimensions.spacingSm),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.primaryBlue, // Solid blue background
              borderRadius: BorderRadius.circular(AppDimensions.borderRadius20), // Fully rounded pill
            ),
            child: Text(
              recipe.mealType,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ],
    );
  }

  /// Builds metadata row with portions, time and optional link icon
  Widget _buildMetadataRow(BuildContext context) {
    final portionsText = recipe.portions != null
        ? '${recipe.portions} portioner'
        : '';
    final timeText = recipe.timeMinutes != null
        ? '${recipe.timeMinutes} minuter'
        : '';
    
    String metadataText = '';
    if (portionsText.isNotEmpty && timeText.isNotEmpty) {
      metadataText = '$portionsText | $timeText';
    } else if (portionsText.isNotEmpty) {
      metadataText = portionsText;
    } else if (timeText.isNotEmpty) {
      metadataText = timeText;
    }
    
    if (metadataText.isNotEmpty) {
      metadataText += ' tillägningstid';
    }

    return Row(
      children: [
        if (metadataText.isNotEmpty)
          Text(
            metadataText,
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey[600],
            ),
          ),
        if (recipe.sourceUrl != null && recipe.sourceUrl!.isNotEmpty) ...[
          const SizedBox(width: AppDimensions.spacingSm),
          Icon(
            Icons.link,
            size: 18,
            color: Colors.grey[500],
          ),
        ],
      ],
    );
  }

  /// Builds rating stars display
  Widget _buildRatingStars(BuildContext context) {
    if (recipe.rating == null) return const SizedBox.shrink();
    
    final rating = recipe.rating!;
    final fullStars = rating.floor();
    final hasHalfStar = (rating - fullStars) >= 0.5;
    
    return Row(
      children: List.generate(5, (index) {
        if (index < fullStars) {
          return const Icon(
            Icons.star,
            size: 16,
            color: Colors.amber,
          );
        } else if (index == fullStars && hasHalfStar) {
          return const Icon(
            Icons.star_half,
            size: 16,
            color: Colors.amber,
          );
        } else {
          return Icon(
            Icons.star_outline,
            size: 16,
            color: Colors.grey[400],
          );
        }
      }),
    );
  }

  /// Builds pill-shaped tags with background color
  Widget _buildSimpleTags(BuildContext context) {
    if (recipe.tags == null || recipe.tags!.isEmpty) {
      return const SizedBox.shrink();
    }

    return Wrap(
      spacing: 8,
      runSpacing: 4,
      children: recipe.tags!
          .take(3)
          .map((tag) => Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.backgroundBeige, // Same as scaffold background
                  borderRadius: BorderRadius.circular(AppDimensions.borderRadius12), // Pill shape
                ),
                child: Text(
                  tag,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
              ))
          .toList(),
    );
  }

  Widget _buildRecipeHeader(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            recipe.title,
            style: style == RecipeCardStyle.compact 
                ? AppTextStyles.bodyLarge
                : AppTextStyles.titleMedium,
            maxLines: style == RecipeCardStyle.compact ? 1 : 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        if (recipe.mealType.isNotEmpty) _buildMealTypeIndicator(context),
      ],
    );
  }

  Widget _buildRecipeDescription(BuildContext context) {
    return Text(
      recipe.description,
      style: const TextStyle(
        fontSize: 14,
        color: Colors.black87,
        height: 1.4, // Good line height
      ),
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
    );
  }

  Widget _buildRecipeMetadata(BuildContext context) {
    final portionsText = recipe.portions != null
        ? '${recipe.portions} portioner'
        : '? portioner';
    final timeText = recipe.timeMinutes != null
        ? '${recipe.timeMinutes} minuter'
        : '? minuter';

    return Text(
      '$portionsText | $timeText',
      style: AppTextStyles.recipeMeta,
    );
  }

  Widget _buildMealTypeIndicator(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimensions.paddingM,
        vertical: AppDimensions.spacingXs,
      ),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primary,
        borderRadius: BorderRadius.circular(AppDimensions.borderRadiusRound),
      ),
      child: Text(
        recipe.mealType,
        style: AppTextStyles.labelSmall.copyWith(
          color: Theme.of(context).colorScheme.onPrimary,
        ),
      ),
    );
  }


}

/// Recipe card display styles
enum RecipeCardStyle {
  detailed,  // Full visning med alla detaljer
  compact,   // Kompakt visning för listor
  grid,      // För grid-layout
}