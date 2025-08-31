import 'package:flutter/material.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/theme/app_colors.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/widgets/image/simple_image_widget.dart';
import 'package:butlery/widgets/image/image_config.dart';

/// Recipe card widget for displaying recipe information with comprehensive functionality.
///
/// This widget provides a complete recipe card implementation with support for:
/// - Recipe display with image, title, description, and metadata
/// - Interactive callbacks for tap, long press, and favorite toggle
/// - Context menu support for additional actions
/// - Accessibility features with semantic labels
/// - Customizable display options for different use cases
///
/// The widget follows the app's design system and provides consistent styling
/// across all recipe card instances while maintaining flexibility for different
/// contexts and user interactions.
class RecipeCard extends StatelessWidget {
  final Recipe recipe;
  final void Function(Recipe)? onTap;
  final void Function(Recipe)? onLongPress;
  final void Function(Recipe)? onFavoriteToggle;
  final bool showFavoriteButton;
  final bool showContextMenu;
  final bool showImage;
  final bool showTags;
  final bool showMetadata;
  final bool isSelected;
  final EdgeInsets? margin;
  final EdgeInsets? padding;
  final RecipeCardStyle style;

  const RecipeCard({
    super.key,
    required this.recipe,
    this.onTap,
    this.onLongPress,
    this.onFavoriteToggle,
    this.showFavoriteButton = true,
    this.showContextMenu = false,
    this.showImage = true,
    this.showTags = true,
    this.showMetadata = true,
    this.isSelected = false,
    this.margin,
    this.padding,
    this.style = RecipeCardStyle.detailed,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Recipe: ${recipe.title}',
      child: Container(
        margin: margin ?? const EdgeInsets.symmetric(vertical: 4, horizontal: 16),
        child: Material(
          elevation: isSelected ? 4 : 1,
          borderRadius: BorderRadius.circular(AppDimensions.borderRadiusM),
          color: isSelected ? AppColors.primary.withValues(alpha: 0.1) : null,
          child: InkWell(
            borderRadius: BorderRadius.circular(AppDimensions.borderRadiusM),
            onTap: onTap != null ? () => onTap!(recipe) : null,
            onLongPress: onLongPress != null ? () => onLongPress!(recipe) : null,
            child: Container(
              padding: padding ?? const EdgeInsets.all(AppDimensions.paddingM),
              child: _buildCardContent(context),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCardContent(BuildContext context) {
    switch (style) {
      case RecipeCardStyle.compact:
        return _buildCompactLayout(context);
      case RecipeCardStyle.detailed:
        return _buildDetailedLayout(context);
      case RecipeCardStyle.grid:
        return _buildGridLayout(context);
    }
  }

  Widget _buildDetailedLayout(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header with image and action buttons
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Recipe image
            if (showImage) ...[
              _buildRecipeImage(),
              const SizedBox(width: AppDimensions.spacingMd),
            ],
            // Content area
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title and action buttons row
                  Row(
                    children: [
                      Expanded(child: _buildTitle(context)),
                      if (showFavoriteButton) _buildFavoriteButton(),
                      if (showContextMenu) _buildContextMenuButton(context),
                    ],
                  ),
                  const SizedBox(height: AppDimensions.spacingSm),
                  // Description
                  if (recipe.description.isNotEmpty) ...[
                    _buildDescription(context),
                    const SizedBox(height: AppDimensions.spacingSm),
                  ],
                ],
              ),
            ),
          ],
        ),
        // Metadata row
        if (showMetadata) ...[
          const SizedBox(height: AppDimensions.spacingSm),
          _buildMetadataRow(context),
        ],
        // Tags
        if (showTags && (recipe.tags?.isNotEmpty ?? false)) ...[
          const SizedBox(height: AppDimensions.spacingSm),
          _buildTagsRow(context),
        ],
      ],
    );
  }

  Widget _buildCompactLayout(BuildContext context) {
    return Row(
      children: [
        if (showImage) ...[
          _buildRecipeImage(size: 60),
          const SizedBox(width: AppDimensions.spacingMd),
        ],
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(child: _buildTitle(context, style: AppTextStyles.titleMedium)),
                  if (showFavoriteButton) _buildFavoriteButton(),
                ],
              ),
              if (showMetadata) ...[
                const SizedBox(height: AppDimensions.spacingXs),
                _buildMetadataRow(context, compact: true),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildGridLayout(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Image with overlay actions
        if (showImage) ...[
          Stack(
            children: [
              _buildRecipeImage(height: 150, width: double.infinity),
              if (showFavoriteButton)
                Positioned(
                  top: 8,
                  right: 8,
                  child: _buildFavoriteButton(background: true),
                ),
            ],
          ),
          const SizedBox(height: AppDimensions.spacingSm),
        ],
        // Title
        _buildTitle(context),
        if (showMetadata) ...[
          const SizedBox(height: AppDimensions.spacingXs),
          _buildMetadataRow(context, compact: true),
        ],
      ],
    );
  }

  Widget _buildRecipeImage({double? size, double? width, double? height}) {
    final imageUrls = recipe.imageUrls;
    final hasImage = imageUrls.isNotEmpty;

    return Container(
      width: width ?? size ?? 80,
      height: height ?? size ?? 80,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppDimensions.borderRadiusS),
        color: AppColors.surface,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppDimensions.borderRadiusS),
        child: hasImage
            ? SimpleImageWidget(
                imageUrl: imageUrls.first,
                fit: BoxFit.cover,
                // PERFORMANCE FIX: Use thumbnail config optimized for 80x80 display
                config: ImageConfig.thumbnail(
                  borderRadius: BorderRadius.circular(AppDimensions.borderRadiusS),
                ),
              )
            : Icon(
                Icons.restaurant,
                size: (size ?? 80) * 0.4,
                color: AppColors.textSecondary,
              ),
      ),
    );
  }

  Widget _buildTitle(BuildContext context, {TextStyle? style}) {
    return Text(
      recipe.title,
      style: style ?? AppTextStyles.titleLarge,
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
    );
  }

  Widget _buildDescription(BuildContext context) {
    return Text(
      recipe.description,
      style: AppTextStyles.bodyMedium.copyWith(
        color: AppColors.textSecondary,
      ),
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
    );
  }

  Widget _buildMetadataRow(BuildContext context, {bool compact = false}) {
    final items = <Widget>[];

    // Meal type badge
    if (recipe.mealType.isNotEmpty) {
      items.add(_buildMealTypeBadge());
    }

    // Portions
    if (recipe.portions != null && recipe.portions! > 0) {
      items.add(_buildMetadataItem(
        Icons.people,
        '${recipe.portions} portioner',
      ));
    }

    // Time
    if (recipe.timeMinutes != null && recipe.timeMinutes! > 0) {
      items.add(_buildMetadataItem(
        Icons.access_time,
        '${recipe.timeMinutes} min',
      ));
    }

    // Rating
    if (recipe.rating != null && recipe.rating! > 0) {
      items.add(_buildMetadataItem(
        Icons.star,
        recipe.rating!.toStringAsFixed(1),
      ));
    }

    return Wrap(
      spacing: compact ? AppDimensions.spacingSm : AppDimensions.spacingMd,
      runSpacing: AppDimensions.spacingXs,
      children: items,
    );
  }

  Widget _buildMealTypeBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimensions.spacingSm,
        vertical: AppDimensions.spacingXs,
      ),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppDimensions.borderRadiusS),
      ),
      child: Text(
        recipe.mealType,
        style: AppTextStyles.labelSmall.copyWith(
          color: AppColors.primary,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildMetadataItem(IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          icon,
          size: 16,
          color: AppColors.textSecondary,
        ),
        const SizedBox(width: AppDimensions.spacingXs),
        Text(
          text,
          style: AppTextStyles.labelSmall.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }

  Widget _buildTagsRow(BuildContext context) {
    return Wrap(
      spacing: AppDimensions.spacingXs,
      runSpacing: AppDimensions.spacingXs,
      children: (recipe.tags ?? []).take(3).map((tag) => _buildTag(tag)).toList(),
    );
  }

  Widget _buildTag(String tag) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimensions.spacingXs,
        vertical: 2,
      ),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppDimensions.borderRadiusXs),
        border: Border.all(
          color: AppColors.divider.withValues(alpha: 0.3),
        ),
      ),
      child: Text(
        tag,
        style: AppTextStyles.labelSmall.copyWith(
          color: AppColors.textSecondary,
        ),
      ),
    );
  }

  Widget _buildFavoriteButton({bool background = false}) {
    return DecoratedBox(
      decoration: background
          ? BoxDecoration(
              color: AppColors.surface.withValues(alpha: 0.9),
              shape: BoxShape.circle,
            )
          : const BoxDecoration(),
      child: IconButton(
        icon: const Icon(
          Icons.favorite_border,
          color: AppColors.textSecondary,
        ),
        onPressed: onFavoriteToggle != null ? () => onFavoriteToggle!(recipe) : null,
        tooltip: 'Lägg till i favoriter',
        // Ensure minimum touch target size for accessibility
        constraints: const BoxConstraints(
          minWidth: 48,
          minHeight: 48,
        ),
      ),
    );
  }

  Widget _buildContextMenuButton(BuildContext context) {
    return PopupMenuButton<String>(
      icon: const Icon(
        Icons.more_vert,
        color: AppColors.textSecondary,
      ),
      // Ensure minimum touch target size for accessibility
      constraints: const BoxConstraints(
        minWidth: 48,
        minHeight: 48,
      ),
      onSelected: (value) {
        // Handle context menu actions
        switch (value) {
          case 'edit':
            // Handle edit
            break;
          case 'share':
            // Handle share
            break;
          case 'delete':
            // Handle delete
            break;
        }
      },
      itemBuilder: (context) => [
        const PopupMenuItem(
          value: 'edit',
          child: ListTile(
            leading: Icon(Icons.edit),
            title: Text('Redigera'),
            contentPadding: EdgeInsets.zero,
          ),
        ),
        const PopupMenuItem(
          value: 'share',
          child: ListTile(
            leading: Icon(Icons.share),
            title: Text('Dela'),
            contentPadding: EdgeInsets.zero,
          ),
        ),
        const PopupMenuItem(
          value: 'delete',
          child: ListTile(
            leading: Icon(Icons.delete),
            title: Text('Ta bort'),
            contentPadding: EdgeInsets.zero,
          ),
        ),
      ],
    );
  }
}

/// Enum for different recipe card display styles
enum RecipeCardStyle {
  /// Compact single-row layout
  compact,
  /// Detailed multi-row layout with full information
  detailed,
  /// Grid layout optimized for grid views
  grid,
}