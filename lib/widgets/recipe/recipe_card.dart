import 'package:flutter/material.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/widgets/common/icons/adaptive_icon.dart';
import 'package:butlery/models/recipe/recipe_completeness.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/butlery_colors_extension.dart';
import 'package:butlery/theme/components/input_themes.dart';
import 'package:butlery/widgets/image/simple_image_widget.dart';
import 'package:butlery/widgets/image/image_config.dart';
import 'package:butlery/widgets/tagging/tagging_widgets.dart';
import 'package:butlery/widgets/common/buttons/animated_pressable.dart';
import 'package:butlery/widgets/common/illustrations/vegetable_illustration.dart';
import 'package:butlery/services/tagging/tag_display_utils.dart';
import 'package:butlery/core/utils/time_format_utils.dart';
import 'package:butlery/core/extensions/localization_extension.dart';

/// Recipe card widget for displaying recipe information with comprehensive functionality.
///
/// **UI Redesign:** Uses left green border + bottom rust border styling.
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
  final bool showMealType;
  final bool showAnalysisStatus;
  final void Function(Recipe)? onFavoriteToggle;

  /// Pantry match percentage (0.0..1.0). When non-null, renders a small
  /// badge in the card showing how much of the recipe the user's pantry
  /// already covers. Only used when the "Laga med vad jag har" filter is
  /// active in the recipe list.
  final double? matchPercent;

  const RecipeCard({
    super.key,
    required this.recipe,
    this.onTap,
    this.onLongPress,
    this.onFavoriteToggle,
    this.showContextMenu = false,
    this.showImage = true,
    this.showTags = false, // UI Redesign: Clean list cards by default
    this.showMetadata = true,
    this.showAllergenBadges = false, // UI Redesign: Clean list cards by default
    this.userAllergenPrefs,
    this.showDietaryBadges = false, // UI Redesign: Clean list cards by default
    this.userDietaryPrefs,
    this.isSelected = false,
    this.margin,
    this.padding,
    this.style = RecipeCardStyle.detailed,
    this.showPersonalTags = false, // UI Redesign: Clean list cards by default
    this.personalTagNames,
    this.maxPersonalTags = 3,
    this.showMealType = false, // UI Redesign: Clean list cards by default
    this.showAnalysisStatus =
        false, // UI Redesign: Hide analysis status in list
    this.matchPercent,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return RepaintBoundary(
      child: Semantics(
        label: context.l10n.recipeCardSemantics(recipe.title),
        button: onTap != null,
        child: Container(
          margin: margin ??
              const EdgeInsets.symmetric(
                  horizontal: AppDimensions.spacingMd,
                  vertical: AppDimensions.borderWidthStandard),
          // UI Redesign: Left green border + bottom rust border
          decoration: isSelected
              ? BoxDecoration(
                  color: cs.primary
                      .withValues(alpha: AppDimensions.opacityVeryLight),
                  borderRadius:
                      BorderRadius.circular(AppDimensions.borderRadiusM),
                  border: Border.all(
                    color: cs.primary,
                    width: 2,
                  ),
                )
              : InputThemes.recipeCardDecoration,
          child: Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(AppDimensions.borderRadiusM),
            child: InkWell(
              borderRadius: BorderRadius.circular(AppDimensions.borderRadiusM),
              onTap: onTap != null ? () => onTap!(recipe) : null,
              onLongPress:
                  onLongPress != null ? () => onLongPress!(recipe) : null,
              child: Container(
                padding: padding ??
                    const EdgeInsets.symmetric(
                        vertical: AppDimensions.spacingModerate,
                        horizontal: AppDimensions.spacingMd),
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
    final hasDescription = recipe.description.isNotEmpty;
    final hasMetadata = showMetadata && _hasAnyMetadata;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Header with image and action buttons
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Recipe image
            if (showImage) ...[
              _buildRecipeImage(context),
              const SizedBox(width: AppDimensions.spacingMd),
            ],
            // Content area — expands to fit text naturally
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Title and action buttons row
                  Row(
                    children: [
                      Expanded(child: _buildTitle(context)),
                      _buildVisibilityIcon(context),
                      if (onFavoriteToggle != null)
                        _buildFavoriteButton(context),
                      if (showContextMenu) _buildContextMenuButton(context),
                    ],
                  ),
                  if (hasDescription || hasMetadata)
                    const SizedBox(height: AppDimensions.spacingSm),
                  // Description
                  if (hasDescription) ...[
                    _buildDescription(context),
                    if (hasMetadata)
                      const SizedBox(height: AppDimensions.spacingSm),
                  ],
                  // Metadata row inside text column per mockup
                  if (hasMetadata) _buildMetadataRow(context),
                ],
              ),
            ),
          ],
        ),
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
        // Completeness indicator for incomplete recipes
        if (recipe.completenessScore case final score
            when score < incompleteThreshold) ...[
          const SizedBox(height: AppDimensions.spacingSm),
          _buildCompletenessIndicator(context, score),
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
          _buildRecipeImage(context, size: 60),
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
                  _buildVisibilityIcon(context),
                  if (onFavoriteToggle != null) _buildFavoriteButton(context),
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
          _buildRecipeImage(context, height: 150, width: double.infinity),
          const SizedBox(height: AppDimensions.spacingSm),
        ],
        // Title + favorite
        Row(
          children: [
            Expanded(child: _buildTitle(context)),
            _buildVisibilityIcon(context),
            if (onFavoriteToggle != null) _buildFavoriteButton(context),
          ],
        ),
        if (showMetadata) ...[
          const SizedBox(height: AppDimensions.spacingXs),
          _buildMetadataRow(context, compact: true),
        ],
      ],
    );
  }

  Widget _buildRecipeImage(BuildContext context,
      {double? size, double? width, double? height}) {
    final thumbnailOrImage = recipe.displayThumbnailUrl;
    final hasImage = thumbnailOrImage != null;
    final imageSize = size ?? 64.0;

    return Container(
      width: width ?? imageSize,
      height: height ?? imageSize,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppDimensions.borderRadiusS),
        color: Theme.of(context).colorScheme.surface,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppDimensions.borderRadiusS),
        child: hasImage
            ? SimpleImageWidget(
                imageUrl: thumbnailOrImage,
                fit: BoxFit.cover,
                // PERFORMANCE FIX: Use thumbnail config for 64x64 display
                config: ImageConfig.thumbnail(
                  borderRadius:
                      BorderRadius.circular(AppDimensions.borderRadiusS),
                  heroTag: ImageConfig.recipeHeroTag(recipe.id),
                ),
              )
            : Hero(
                tag: ImageConfig.recipeHeroTag(recipe.id),
                child: VegetableIllustration(
                  type: VegetableIllustration.randomForRecipe(recipe.id),
                  size: imageSize * 0.7,
                  opacity: 0.8,
                ),
              ),
      ),
    );
  }

  Widget _buildTitle(BuildContext context, {TextStyle? style}) {
    return Text(
      recipe.title,
      style: style ?? AppTextStyles.recipeCardTitle,
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
    );
  }

  /// BUT-909: small visibility icon (lock / world / friends) shown beside the
  /// title so the user can tell a recipe's audience without opening the detail
  /// view. Collaborative wins over `isPublic` — a collab recipe is always
  /// scoped to its members regardless of the public flag.
  Widget _buildVisibilityIcon(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final (IconData icon, String label) = switch (recipe) {
      Recipe(isCollaborative: true) => (
          Icons.people_outline,
          context.l10n.recipeVisibilityCollaborative,
        ),
      Recipe(isPublic: true) => (
          Icons.public,
          context.l10n.recipeVisibilityPublic,
        ),
      _ => (
          Icons.lock_outline,
          context.l10n.recipeVisibilityPrivate,
        ),
    };
    return Padding(
      padding: const EdgeInsetsDirectional.only(start: AppDimensions.spacingXs),
      child: Tooltip(
        message: label,
        child: Semantics(
          label: label,
          excludeSemantics: true,
          child: Icon(
            icon,
            size: AppDimensions.iconSizeS,
            color: cs.onSurfaceVariant
                .withValues(alpha: AppDimensions.opacityMediumLight),
          ),
        ),
      ),
    );
  }

  Widget _buildFavoriteButton(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isFav = recipe.isFavorite;
    return AnimatedPressable(
      pressedScale: 0.85,
      child: SizedBox(
        width: 32,
        height: 32,
        child: IconButton(
          onPressed: () => onFavoriteToggle?.call(recipe),
          icon: Icon(
            isFav
                ? AdaptiveIcons.favouriteFilled
                : AdaptiveIcons.favouriteOutline,
            size: 20,
            color: isFav ? cs.error : cs.onSurfaceVariant,
          ),
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
          tooltip:
              isFav ? context.l10n.favoritesRemove : context.l10n.favoritesAdd,
        ),
      ),
    );
  }

  Widget _buildDescription(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Text(
      recipe.description,
      style: AppTextStyles.recipeCardDescription.copyWith(
        color: cs.onSurfaceVariant,
      ),
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
    );
  }

  Widget _buildMetadataRow(BuildContext context, {bool compact = false}) {
    // UI Redesign: Text+dots format with optional rating pill
    final parts = <String>[];

    // Meal type - only if showMealType is true
    if (showMealType && recipe.mealType.isNotEmpty) {
      parts.add(recipe.mealType);
    }

    // Time with smart formatting
    if (recipe.timeMinutes != null && recipe.timeMinutes! > 0) {
      parts.add(TimeFormatUtils.formatCookingTime(recipe.timeMinutes!));
    }

    // Portions
    if (recipe.portions != null && recipe.portions! > 0) {
      parts.add('${recipe.portions} ${context.l10n.recipePortionAbbreviation}');
    }

    final hasRating = recipe.rating != null && recipe.rating! > 0;

    final hasMatchPercent = matchPercent != null;

    // Wrap (not Row) so the rating + match badges flow to a new line
    // instead of overflowing at 2x text scaling (BUT-547 / WCAG 1.4.4).
    // At default scale this lays out identically to a Row.
    return Wrap(
      spacing: AppDimensions.spacingSm,
      runSpacing: AppDimensions.spacingXs,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        if (parts.isNotEmpty)
          Text(
            parts.join(' \u00B7 '),
            style: AppTextStyles.recipeMeta,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        if (hasRating) _buildRatingPill(context),
        if (hasMatchPercent) _buildMatchBadge(context, matchPercent!),
      ],
    );
  }

  Widget _buildMatchBadge(BuildContext context, double percent) {
    final cs = Theme.of(context).colorScheme;
    final pct = (percent * 100).round().clamp(0, 100);
    return Semantics(
      label: context.l10n.recipeCardPantryMatchA11y(pct),
      child: Container(
        padding: AppDimensions.paddingSymmetric6x2,
        decoration: BoxDecoration(
          color: cs.primary.withValues(alpha: AppDimensions.opacityVeryLight),
          border: Border.all(
            color:
                cs.primary.withValues(alpha: AppDimensions.opacityMediumLight),
          ),
        ),
        child: Text(
          '$pct%',
          style: AppTextStyles.badge.copyWith(
            color: cs.primary,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }

  Widget _buildRatingPill(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Semantics(
      label:
          context.l10n.recipeRatingSemantics(recipe.rating!.toStringAsFixed(1)),
      child: Container(
        padding: AppDimensions.paddingSymmetric6x2,
        decoration: BoxDecoration(
          color: cs.primary,
          borderRadius: BorderRadius.zero,
        ),
        child: Text(
          '\u2605 ${recipe.rating!.toStringAsFixed(1)}',
          style: AppTextStyles.badge.copyWith(
            color: cs.onPrimary,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Widget _buildTagsRow(BuildContext context) {
    final userAddedTags = recipe.tagOverrides?.addedTags ?? <String>{};
    return Wrap(
      spacing: AppDimensions.spacingXs,
      runSpacing: AppDimensions.spacingXs,
      children: _topEffectiveTags
          .map((tag) =>
              _buildTag(context, tag, isUserAdded: userAddedTags.contains(tag)))
          .toList(),
    );
  }

  Widget _buildTag(BuildContext context, String tag,
      {bool isUserAdded = false}) {
    final cs = Theme.of(context).colorScheme;
    final displayName = TagDisplayUtils.getDisplayName(tag);
    return Container(
      padding: AppDimensions.paddingSymmetric4x2,
      decoration: BoxDecoration(
        color: isUserAdded
            ? cs.primary.withValues(alpha: AppDimensions.opacityVeryLight)
            : cs.surface,
        borderRadius: BorderRadius.circular(AppDimensions.borderRadiusXs),
        border: Border.all(
          color: isUserAdded
              ? cs.primary.withValues(alpha: AppDimensions.opacityMediumLight)
              : cs.outlineVariant
                  .withValues(alpha: AppDimensions.opacityMediumLight),
        ),
      ),
      child: Text(
        displayName,
        style: AppTextStyles.labelSmall.copyWith(
          color: isUserAdded ? cs.primary : cs.onSurfaceVariant,
        ),
      ),
    );
  }

  /// Whether the recipe has any metadata to display.
  bool get _hasAnyMetadata {
    if (showMealType && recipe.mealType.isNotEmpty) return true;
    if (recipe.portions != null && recipe.portions! > 0) return true;
    if (recipe.timeMinutes != null && recipe.timeMinutes! > 0) return true;
    if (recipe.rating != null && recipe.rating! > 0) return true;
    return false;
  }

  /// Whether to show untagged indicator.
  /// Shows when tagResult is null or has failed status, and badges/analysis are enabled.
  bool get _showUntaggedIndicator {
    if (!showAnalysisStatus) return false;
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
        ...names
            .take(displayCount)
            .map((name) => _buildPersonalTag(context, name)),
        if (overflow > 0) _buildOverflowChip(context, overflow),
      ],
    );
  }

  Widget _buildPersonalTag(BuildContext context, String name) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      padding: AppDimensions.paddingSymmetric8x2,
      decoration: BoxDecoration(
        color: cs.primary.withValues(alpha: AppDimensions.opacityLightSubtle),
        borderRadius: BorderRadius.circular(AppDimensions.borderRadiusS),
        border: Border.all(
          color: cs.primary.withValues(alpha: AppDimensions.opacityMediumLight),
        ),
      ),
      child: Text(
        name,
        style: AppTextStyles.labelSmall.copyWith(
          color: cs.primary,
        ),
      ),
    );
  }

  Widget _buildOverflowChip(BuildContext context, int count) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      padding: AppDimensions.paddingSymmetric8x2,
      decoration: BoxDecoration(
        color: cs.primary.withValues(alpha: AppDimensions.opacityVeryLight),
        borderRadius: BorderRadius.circular(AppDimensions.borderRadiusS),
        border: Border.all(
          color: cs.primary.withValues(alpha: AppDimensions.opacityLight),
        ),
      ),
      child: Text(
        '+$count',
        style: AppTextStyles.labelSmall.copyWith(
          color: cs.primary.withValues(alpha: AppDimensions.opacityDark),
        ),
      ),
    );
  }

  /// Builds untagged indicator for recipes pending analysis.
  Widget _buildUntaggedIndicator(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tagResult = recipe.tagResult;
    final hasFailed = tagResult?.hasFailed ?? false;

    return Semantics(
      label: hasFailed
          ? context.l10n.recipeAnalysisFailedA11y
          : context.l10n.recipeAnalyzingA11y,
      child: Container(
        padding: AppDimensions.paddingSymmetric4x8,
        decoration: BoxDecoration(
          color: (hasFailed ? cs.error : context.butleryColors.warning)
              .withValues(alpha: AppDimensions.opacityVeryLight),
          borderRadius: BorderRadius.circular(AppDimensions.borderRadiusS),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              hasFailed ? Icons.error_outline : Icons.pending_outlined,
              size: 14,
              color: hasFailed ? cs.error : context.butleryColors.warning,
            ),
            const SizedBox(width: AppDimensions.spacingXs),
            Text(
              hasFailed
                  ? context.l10n.recipeAnalysisFailed
                  : context.l10n.recipeAnalyzing,
              style: AppTextStyles.labelSmall.copyWith(
                color: hasFailed ? cs.error : context.butleryColors.warning,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCompletenessIndicator(BuildContext context, double rawScore) {
    final cs = Theme.of(context).colorScheme;
    final score = (rawScore * 100).round();
    return Semantics(
      label: context.l10n.recipeCompletenessA11y(score),
      child: Container(
        padding: AppDimensions.paddingSymmetric4x8,
        decoration: BoxDecoration(
          color: cs.outline.withValues(alpha: AppDimensions.opacityVeryLight),
          borderRadius: BorderRadius.circular(AppDimensions.borderRadiusS),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.pie_chart_outline, size: 14, color: cs.outline),
            const SizedBox(width: AppDimensions.spacingXs),
            Text(
              context.l10n.recipeCompleteness(score),
              style: AppTextStyles.labelSmall.copyWith(color: cs.outline),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContextMenuButton(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return PopupMenuButton<String>(
      icon: Icon(
        Icons.more_vert,
        color: cs.onSurfaceVariant,
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
        PopupMenuItem(
          value: 'edit',
          child: ListTile(
            leading: const Icon(Icons.edit),
            title: Text(context.l10n.commonEdit),
            contentPadding: EdgeInsets.zero,
          ),
        ),
        PopupMenuItem(
          value: 'share',
          child: ListTile(
            leading: const Icon(Icons.share),
            title: Text(context.l10n.commonShare),
            contentPadding: EdgeInsets.zero,
          ),
        ),
        PopupMenuItem(
          value: 'delete',
          child: ListTile(
            leading: const Icon(Icons.delete),
            title: Text(context.l10n.commonDelete),
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
