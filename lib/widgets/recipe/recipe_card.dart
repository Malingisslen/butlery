import 'package:flutter/material.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/theme/app_colors.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/widgets/image/simple_image_widget.dart';
import 'package:butlery/widgets/image/image_config.dart';
import 'package:butlery/widgets/tagging/tagging_widgets.dart';
import 'package:butlery/services/tagging/tag_display_utils.dart';

/// Recipe card widget for displaying recipe information with comprehensive functionality.
/// This widget provides a complete recipe card implementation with support for:
/// - Recipe display with image, title, description, and metadata
/// - Interactive callbacks for tap, long press, and favorite toggle
/// - Context menu support for additional actions
/// - Accessibility features with semantic labels
/// - Customizable display options for different use cases
/// The widget follows the app's design system and provides consistent styling
/// across all recipe card instances while maintaining flexibility for different
/// contexts and user interactions.
class RecipeCard extends StatelessWidget {
  final Recipe recipe;
  final void Function(Recipe)? onTap;
  final void Function(Recipe)? onLongPress;
  final bool showContextMenu;
  final bool showImage;
  final bool showTags;
  final bool showMetadata;
  final bool showAllergenBadges;
  final Set<String>? userAllergenPrefs;
  final bool showDietaryBadges;
  final Set<String>? userDietaryPrefs;
  final bool isSelected;
  final EdgeInsets? margin;
  final EdgeInsets? padding;
  final RecipeCardStyle style;
  final bool showPersonalTags;
  final Map<String, String>? personalTagNames;
  final int maxPersonalTags;

  const RecipeCard({
    super.key,
    required this.recipe,
    this.onTap,
    this.onLongPress,
    this.showContextMenu = false,
    this.showImage = true,
    this.showTags = true,
    this.showMetadata = true,
    this.showAllergenBadges = true,
    this.userAllergenPrefs,
    this.showDietaryBadges = true,
    this.userDietaryPrefs,
    this.isSelected = false,
    this.margin,
    this.padding,
    this.style = RecipeCardStyle.detailed,
    this.showPersonalTags = true,
    this.personalTagNames,
    this.maxPersonalTags = 3,
  });

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: Semantics(
        label: 'Recipe: ${recipe.title}',
        child: Container(
          margin:
              margin ?? AppDimensions.paddingSymmetric16x4,
          child: Material(
            elevation: isSelected
                ? AppDimensions.elevationMedium
                : AppDimensions.elevationLow,
            borderRadius: BorderRadius.circular(AppDimensions.borderRadiusM),
            color: isSelected
                ? AppColors.primaryBlue.withValues(alpha: AppDimensions.opacityVeryLight)
                : null,
            child: InkWell(
              borderRadius: BorderRadius.circular(AppDimensions.borderRadiusM),
              onTap: onTap != null ? () => onTap!(recipe) : null,
              onLongPress:
                  onLongPress != null ? () => onLongPress!(recipe) : null,
              child: Container(
                padding:
                    padding ?? AppDimensions.paddingAll12,
                child: _buildCardContent(context),
              ),
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
        // Allergen badges
        if (showAllergenBadges && recipe.tagResult != null) ...[
          const SizedBox(height: AppDimensions.spacingSm),
          CompactAllergenRow(
            tagResult: recipe.tagResult!,
            userPrefs: userAllergenPrefs,
            maxBadges: 4,
          ),
        ],
        // Dietary badges (vegan, vegetarian, etc.)
        if (showDietaryBadges && recipe.tagResult != null) ...[
          const SizedBox(height: AppDimensions.spacingXs),
          CompactDietaryRow(
            tagResult: recipe.tagResult!,
            userPrefs: userDietaryPrefs,
            maxBadges: 2,
          ),
        ],
        // Personal tags (user-defined categories)
        if (showPersonalTags && _hasPersonalTags) ...[
          const SizedBox(height: AppDimensions.spacingSm),
          _buildPersonalTagsRow(context),
        ],
        // Untagged indicator when tagResult is null or failed
        if (_showUntaggedIndicator) ...[
          const SizedBox(height: AppDimensions.spacingSm),
          _buildUntaggedIndicator(context),
        ],
        // Tags (effective tags: auto-generated + user overrides)
        if (showTags && _hasEffectiveTags) ...[
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
                  Expanded(
                      child: _buildTitle(context,
                          style: AppTextStyles.titleMedium)),
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
        // Image
        if (showImage) ...[
          _buildRecipeImage(height: 150, width: double.infinity),
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
        color: AppColors.backgroundBeige,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppDimensions.borderRadiusS),
        child: hasImage
            ? SimpleImageWidget(
                imageUrl: imageUrls.first,
                fit: BoxFit.cover,
                // PERFORMANCE FIX: Use thumbnail config optimized for 80x80 display
                config: ImageConfig.thumbnail(
                  borderRadius:
                      BorderRadius.circular(AppDimensions.borderRadiusS),
                ),
              )
            : Icon(
                Icons.restaurant,
                size: (size ?? 80) * 0.4,
                color: AppColors.textMedium,
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
        color: AppColors.textMedium,
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
      padding: AppDimensions.paddingSymmetric4x8,
      decoration: BoxDecoration(
        color: AppColors.primaryBlue.withValues(alpha: AppDimensions.opacityVeryLight),
        borderRadius: BorderRadius.circular(AppDimensions.borderRadiusS),
      ),
      child: Text(
        recipe.mealType,
        style: AppTextStyles.badge.copyWith(
          color: AppColors.primaryBlue,
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
          size: AppDimensions.iconSizeS,
          color: AppColors.textMedium,
        ),
        const SizedBox(width: AppDimensions.spacingXs),
        Text(
          text,
          style: AppTextStyles.labelSmall.copyWith(
            color: AppColors.textMedium,
          ),
        ),
      ],
    );
  }

  Widget _buildTagsRow(BuildContext context) {
    final userAddedTags = recipe.tagOverrides?.addedTags ?? <String>{};
    return Wrap(
      spacing: AppDimensions.spacingXs,
      runSpacing: AppDimensions.spacingXs,
      children: _topEffectiveTags
          .map(
              (tag) => _buildTag(tag, isUserAdded: userAddedTags.contains(tag)))
          .toList(),
    );
  }

  Widget _buildTag(String tag, {bool isUserAdded = false}) {
    final displayName = TagDisplayUtils.getDisplayName(tag);
    return Container(
      padding: AppDimensions.paddingSymmetric4x2,
      decoration: BoxDecoration(
        color: isUserAdded
            ? AppColors.primaryBlue.withValues(alpha: AppDimensions.opacityVeryLight)
            : AppColors.backgroundBeige,
        borderRadius: BorderRadius.circular(AppDimensions.borderRadiusXs),
        border: Border.all(
          color: isUserAdded
              ? AppColors.primaryBlue.withValues(alpha: AppDimensions.opacityMediumLight)
              : AppColors.divider.withValues(alpha: AppDimensions.opacityMediumLight),
        ),
      ),
      child: Text(
        displayName,
        style: AppTextStyles.labelSmall.copyWith(
          color: isUserAdded ? AppColors.primaryBlue : AppColors.textMedium,
        ),
      ),
    );
  }

  /// Whether to show untagged indicator.
  /// Shows when tagResult is null or has failed status, and badges are enabled.
  bool get _showUntaggedIndicator {
    if (!showAllergenBadges && !showDietaryBadges) return false;
    final tagResult = recipe.tagResult;
    return tagResult == null || tagResult.hasFailed;
  }

  /// Whether there are effective tags to display.
  /// Checks auto-generated tags and user overrides.
  bool get _hasEffectiveTags {
    final autoTags = recipe.tagResult?.tags ?? <String>{};
    final userAddedTags = recipe.tagOverrides?.addedTags ?? <String>{};
    final removedTags = recipe.tagOverrides?.removedTags ?? <String>{};
    final effectiveTags = autoTags.union(userAddedTags).difference(removedTags);
    return effectiveTags.isNotEmpty;
  }

  /// Gets the top 5 effective tags with smart priority.
  List<String> get _topEffectiveTags {
    final autoTags = recipe.tagResult?.tags ?? <String>{};
    final userAddedTags = recipe.tagOverrides?.addedTags ?? <String>{};
    final removedTags = recipe.tagOverrides?.removedTags ?? <String>{};
    final effectiveTags = autoTags.union(userAddedTags).difference(removedTags);
    return TagDisplayUtils.getTopTags(effectiveTags, userAddedTags, limit: 5);
  }

  /// Whether there are personal tags to display.
  bool get _hasPersonalTags {
    final tagIds = recipe.personalTagIds;
    if (tagIds == null || tagIds.isEmpty) return false;
    if (personalTagNames == null || personalTagNames!.isEmpty) return false;
    return tagIds.any((id) => personalTagNames!.containsKey(id));
  }

  /// Gets resolved personal tag names for display.
  List<String> get _resolvedPersonalTagNames {
    final tagIds = recipe.personalTagIds ?? [];
    if (personalTagNames == null) return [];
    return tagIds
        .where((id) => personalTagNames!.containsKey(id))
        .map((id) => personalTagNames![id]!)
        .toList();
  }

  Widget _buildPersonalTagsRow(BuildContext context) {
    final names = _resolvedPersonalTagNames;
    final displayCount =
        names.length > maxPersonalTags ? maxPersonalTags : names.length;
    final overflow = names.length - displayCount;

    return Wrap(
      spacing: AppDimensions.spacingXs,
      runSpacing: AppDimensions.spacingXs,
      children: [
        ...names.take(displayCount).map(_buildPersonalTag),
        if (overflow > 0) _buildOverflowChip(overflow),
      ],
    );
  }

  Widget _buildPersonalTag(String name) {
    return Container(
      padding: AppDimensions.paddingSymmetric8x2,
      decoration: BoxDecoration(
        color: AppColors.primaryBlue.withValues(alpha: AppDimensions.opacityLightSubtle),
        borderRadius: BorderRadius.circular(AppDimensions.borderRadiusS),
        border: Border.all(
          color: AppColors.primaryBlue.withValues(alpha: AppDimensions.opacityMediumLight),
        ),
      ),
      child: Text(
        name,
        style: AppTextStyles.labelSmall.copyWith(
          color: AppColors.primaryBlue,
        ),
      ),
    );
  }

  Widget _buildOverflowChip(int count) {
    return Container(
      padding: AppDimensions.paddingSymmetric8x2,
      decoration: BoxDecoration(
        color: AppColors.primaryBlue.withValues(alpha: AppDimensions.opacityVeryLight),
        borderRadius: BorderRadius.circular(AppDimensions.borderRadiusS),
        border: Border.all(
          color: AppColors.primaryBlue.withValues(alpha: AppDimensions.opacityLight),
        ),
      ),
      child: Text(
        '+$count',
        style: AppTextStyles.labelSmall.copyWith(
          color: AppColors.primaryBlue.withValues(alpha: AppDimensions.opacityDark),
        ),
      ),
    );
  }

  /// Builds untagged indicator for recipes pending analysis.
  Widget _buildUntaggedIndicator(BuildContext context) {
    final tagResult = recipe.tagResult;
    final hasFailed = tagResult?.hasFailed ?? false;

    return Semantics(
      label: hasFailed
          ? 'Ingrediensanalys misslyckades'
          : 'Ingredienser analyseras',
      child: Container(
        padding: AppDimensions.paddingSymmetric4x8,
        decoration: BoxDecoration(
          color: (hasFailed ? AppColors.error : AppColors.warning)
              .withValues(alpha: AppDimensions.opacityVeryLight),
          borderRadius: BorderRadius.circular(AppDimensions.borderRadiusS),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              hasFailed ? Icons.error_outline : Icons.pending_outlined,
              size: 14,
              color: hasFailed ? AppColors.error : AppColors.warning,
            ),
            const SizedBox(width: AppDimensions.spacingXs),
            Text(
              hasFailed ? 'Analys misslyckades' : 'Analyseras...',
              style: AppTextStyles.labelSmall.copyWith(
                color: hasFailed ? AppColors.error : AppColors.warning,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContextMenuButton(BuildContext context) {
    return PopupMenuButton<String>(
      icon: const Icon(
        Icons.more_vert,
        color: AppColors.textMedium,
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
