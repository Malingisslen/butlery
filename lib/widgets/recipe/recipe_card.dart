import 'package:flutter/material.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/widgets/common/icons/adaptive_icon.dart';
import 'package:butlery/models/recipe/recipe_completeness.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_shadows.dart';
import 'package:butlery/theme/butlery_colors_extension.dart';
import 'package:butlery/theme/components/input_themes.dart';
import 'package:butlery/widgets/common/hoverable_card.dart';
import 'package:butlery/widgets/image/simple_image_widget.dart';
import 'package:butlery/widgets/image/image_config.dart';
import 'package:butlery/widgets/tagging/tagging_widgets.dart';
import 'package:butlery/widgets/common/buttons/animated_pressable.dart';
import 'package:butlery/widgets/common/illustrations/vegetable_illustration.dart';
import 'package:butlery/services/tagging/tag_display_utils.dart';
import 'package:butlery/core/utils/time_format_utils.dart';
import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/repositories/interfaces/ratings_repository.dart';
import 'package:butlery/widgets/recipe/butlery_betyg_pill.dart';

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

  /// Pooled "Butlery-betyget" stats for this recipe's dish. When present and the
  /// pool clears the display floor (n>=5), the card shows the green community
  /// pill INSTEAD of the per-copy 'alla' aggregate (decision 9) and demotes the
  /// household/personal pill to neutral so there is one brand-green number. Null
  /// (flag off / below floor / not loaded) → unchanged per-copy display.
  final PooledStats? pooledStats;

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
    this.pooledStats,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    // UI Redesign: Left green border + bottom rust border. The selected state
    // uses its own green-outline decoration and is not affected by hover.
    final BoxDecoration restDecoration = isSelected
        ? BoxDecoration(
            color: cs.primary.withValues(alpha: AppDimensions.opacityVeryLight),
            borderRadius: BorderRadius.circular(AppDimensions.borderRadiusM),
            border: Border.all(
              color: cs.primary,
              width: 2,
            ),
          )
        : InputThemes.recipeCardDecoration;

    return RepaintBoundary(
      child: Semantics(
        label: context.l10n.recipeCardSemantics(recipe.title),
        button: onTap != null,
        child: HoverableCard(
          // Only interactive cards get a hover affordance — a card with no tap
          // handler shouldn't imply clickability under the cursor.
          enabled: onTap != null,
          margin:
              margin ??
              const EdgeInsets.symmetric(
                horizontal: AppDimensions.spacingMd,
                vertical: AppDimensions.borderWidthStandard,
              ),
          restDecoration: restDecoration,
          hoverDecoration: _hoverDecoration(restDecoration),
          child: Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(AppDimensions.borderRadiusM),
            child: InkWell(
              borderRadius: BorderRadius.circular(AppDimensions.borderRadiusM),
              onTap: onTap != null ? () => onTap!(recipe) : null,
              onLongPress: onLongPress != null
                  ? () => onLongPress!(recipe)
                  : null,
              child: Container(
                padding:
                    padding ??
                    const EdgeInsets.symmetric(
                      vertical: AppDimensions.spacingModerate,
                      horizontal: AppDimensions.spacingMd,
                    ),
                child: _buildCardContent(context),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Hover variant of [base]: a stronger lift (web/desktop only). Reuses the
  /// base decoration so border + corner treatment stay identical — only the
  /// shadow deepens, keeping the square design language intact.
  BoxDecoration _hoverDecoration(BoxDecoration base) {
    return base.copyWith(boxShadow: AppShadows.elevated);
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
        // BUT-1869: the spacer and the row are gated on what the row WILL
        // DRAW, not on the shape of the preference set.
        //
        // The first attempt asked `userPrefs?.isNotEmpty ?? true`, which is a
        // proxy — and the proxy is wrong for the dietary row in the COMMON
        // case, not an edge one: only FREE diets get a badge, so an ordinary
        // meat recipe against the default {vegetarisk, vegansk} has a
        // non-empty set and still draws nothing, leaving exactly the dead gap
        // this fix exists to remove. Filtering UNKNOWN out of the allergen row
        // (Malin's call, 2026-08-18) put the allergen half in the same
        // position: a tracked allergen set no longer guarantees a badge.
        //
        // Asking the row itself removes the whole class. `badgesFor` is the
        // same function the row calls to decide whether to collapse, so the
        // gate and the row can no longer disagree.
        if (showAllergenBadges && _allergenBadges.isNotEmpty) ...[
          const SizedBox(height: AppDimensions.spacingSm),
          CompactAllergenRow(
            tagResult: recipe.tagResult!,
            userPrefs: userAllergenPrefs,
            maxBadges: 4,
          ),
        ],
        if (_showUnassessedIndicator) ...[
          const SizedBox(height: AppDimensions.spacingSm),
          _buildUnassessedIndicator(context),
        ],
        // spacingSm, not spacingXs. The gap BETWEEN the two badge rows has to be
        // strictly greater than the `runSpacing` INSIDE either of them, or a
        // wrapped row is indistinguishable from the next row. Both rows use
        // `runSpacing: spacingXs`, so an inter-row gap of spacingXs collapses
        // the distinction the moment the allergen row wraps — which it does at
        // the 1.5-2x text scale this codebase designs for (BUT-547), not at 1x.
        // Raised on the Creative Director's condition, 2026-08-18.
        if (showDietaryBadges && _dietaryBadges.isNotEmpty) ...[
          const SizedBox(height: AppDimensions.spacingSm),
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
                    child: _buildTitle(
                      context,
                      style: AppTextStyles.titleMedium,
                    ),
                  ),
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
        // The image is the SLACK in this layout, not a fixed block.
        //
        // A grid tile's height is decided by the delegate's aspect ratio, so
        // unlike the detailed layout this Column cannot grow. A fixed 150px
        // image plus text that grows with the OS text scale therefore is not a
        // tight layout, it is an overflow: measured at 70px past the bottom at
        // 1x and 175px at 2x, on a 2-column phone, for every recipe including a
        // one-word title. In release that is silent clipping, which is why it
        // survived. Expanded lets the image give up its own height so the title,
        // the metadata and the allergen row keep theirs.
        if (showImage) ...[
          Expanded(child: _buildRecipeImage(context, width: double.infinity)),
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
        // BUT-1895: allergen information must not depend on which view toggle
        // happens to be saved. The badges were drawn in the detailed layout
        // only, and `MinaReceptRecipeCard` picks the GRID style the moment the
        // user turns grid view on — so on Mina recept the setting that shows
        // allergen status on recipe cards (`allergenDisplayOnCardsTitle`) was
        // honoured in list mode and silently ignored in grid mode, on the same
        // screen.
        //
        // The unassessed marker SHIPS with the row and is never left behind —
        // at runtime the two are mutually exclusive, since the marker is what a
        // card shows INSTEAD of the row when the user asked for allergen
        // information and there is nothing to say. On a screen of mostly-green
        // cards a silent card reads as "nothing flagged", and that inference is
        // exactly what the marker exists to block, so moving the row here
        // without it would reopen a fixed bug in a new place.
        //
        // The dietary row is deliberately NOT here — see BUT-1906.
        if (showAllergenBadges && _allergenBadges.isNotEmpty) ...[
          const SizedBox(height: AppDimensions.spacingXs),
          CompactAllergenRow(
            tagResult: recipe.tagResult!,
            userPrefs: userAllergenPrefs,
            maxBadges: 4,
          ),
        ],
        if (_showUnassessedIndicator) ...[
          const SizedBox(height: AppDimensions.spacingXs),
          _buildUnassessedIndicator(context),
        ],
      ],
    );
  }

  Widget _buildRecipeImage(
    BuildContext context, {
    double? size,
    double? width,
    double? height,
  }) {
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
                  borderRadius: BorderRadius.circular(
                    AppDimensions.borderRadiusS,
                  ),
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
            color: cs.onSurfaceVariant.withValues(
              alpha: AppDimensions.opacityMediumLight,
            ),
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
            // Colour convention (BUT-1213): green = personal favourite,
            // red stays reserved for social likes.
            color: isFav ? cs.primary : cs.onSurfaceVariant,
          ),
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
          tooltip: isFav
              ? context.l10n.favoritesRemove
              : context.l10n.favoritesAdd,
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

    // Rating pills: the household's private "familj" verdict is the default
    // (green); it supersedes the personal star (they match for a solo user).
    // The personal star remains as a fallback when there's no family verdict.
    // The public "alla" aggregate (rust) shows alongside when present.
    final familyAvg = recipe.core.familyAverage;
    final hasFamily =
        familyAvg != null && (recipe.core.familyRatingCount ?? 0) > 0;
    final allaAvg = recipe.core.averageRating;
    final hasAlla = allaAvg != null && allaAvg > 0;
    final hasPersonal = recipe.rating != null && recipe.rating! > 0;

    // Decision 9: when the pool clears the floor, the green Butlery-betyget pill
    // takes the community slot (replacing the per-copy 'alla' pill), and the
    // household/personal pill is demoted to neutral so only one green shows.
    final pooled = pooledStats;
    final showPool = pooled != null && pooled.meetsDisplayFloor;

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
        if (hasFamily)
          _buildFamilyPill(context, familyAvg, demoted: showPool)
        else if (hasPersonal)
          _buildRatingPill(context, demoted: showPool),
        if (showPool)
          ButleryBetygPill(stats: pooled)
        else if (hasAlla)
          _buildAllaPill(context, allaAvg),
        if (hasMatchPercent) _buildMatchBadge(context, matchPercent!),
      ],
    );
  }

  /// Swedish one-decimal with a decimal comma (e.g. 4.2 -> "4,2").

  /// Green "familj X,X" pill \u2014 the household's private verdict (the default).
  Widget _buildFamilyPill(
    BuildContext context,
    double avg, {
    bool demoted = false,
  }) {
    final cs = Theme.of(context).colorScheme;
    // Demoted (a green Butlery-betyget pill is also present): recede to a quiet
    // OUTLINED slate — transparent fill + hairline outline + secondary-text
    // colour — so only the community number reads as brand green. Uses the
    // onSurfaceVariant/outlineVariant roles, which carry a defined dark-theme
    // variant (a filled neutral pill would fail AA contrast in dark mode).
    final fg = demoted ? cs.onSurfaceVariant : cs.onPrimary;
    return Semantics(
      label: context.l10n.a11yFamilyRatingPill(formatRatingComma(avg)),
      child: Container(
        padding: AppDimensions.paddingSymmetric6x2,
        decoration: demoted
            ? BoxDecoration(border: Border.all(color: cs.outlineVariant))
            : BoxDecoration(color: cs.primary),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.groups_outlined, size: 12, color: fg),
            const SizedBox(width: 3),
            Text(
              context.l10n.recipeFamilyRatingPill(formatRatingComma(avg)),
              style: AppTextStyles.badge.copyWith(
                color: fg,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Rust "alla X,X" pill \u2014 the public aggregate from all users.
  Widget _buildAllaPill(BuildContext context, double avg) {
    final cs = Theme.of(context).colorScheme;
    return Semantics(
      label: context.l10n.a11yAllaRatingPill(formatRatingComma(avg)),
      child: Container(
        padding: AppDimensions.paddingSymmetric6x2,
        decoration: BoxDecoration(color: cs.secondary),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.star, size: 12, color: cs.surface),
            const SizedBox(width: 3),
            Text(
              context.l10n.recipeAllaRatingPill(formatRatingComma(avg)),
              style: AppTextStyles.badge.copyWith(
                color: cs.surface,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
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
            color: cs.primary.withValues(
              alpha: AppDimensions.opacityMediumLight,
            ),
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

  Widget _buildRatingPill(BuildContext context, {bool demoted = false}) {
    final cs = Theme.of(context).colorScheme;
    // Demoted when a green community pill is also shown \u2014 recede to the same
    // quiet OUTLINED slate as the family pill (AA-safe in both themes).
    final fg = demoted ? cs.onSurfaceVariant : cs.onPrimary;

    return Semantics(
      label: context.l10n.recipeRatingSemantics(
        recipe.rating!.toStringAsFixed(1),
      ),
      child: Container(
        padding: AppDimensions.paddingSymmetric6x2,
        decoration: demoted
            ? BoxDecoration(
                border: Border.all(color: cs.outlineVariant),
                borderRadius: BorderRadius.zero,
              )
            : BoxDecoration(color: cs.primary, borderRadius: BorderRadius.zero),
        child: Text(
          '\u2605 ${recipe.rating!.toStringAsFixed(1)}',
          style: AppTextStyles.badge.copyWith(
            color: fg,
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
          .map(
            (tag) => _buildTag(
              context,
              tag,
              isUserAdded: userAddedTags.contains(tag),
            ),
          )
          .toList(),
    );
  }

  Widget _buildTag(
    BuildContext context,
    String tag, {
    bool isUserAdded = false,
  }) {
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
              : cs.outlineVariant.withValues(
                  alpha: AppDimensions.opacityMediumLight,
                ),
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

  /// The allergen badges this card would draw, or empty.
  ///
  /// Asked by the build gate so the spacer and the row can never disagree —
  /// they are computed by the same function the row uses to decide whether to
  /// collapse. Empty whenever the recipe is untagged, so the `tagResult!`
  /// at the call site is guarded by this being non-empty.
  List<String> get _allergenBadges => recipe.tagResult == null
      ? const []
      : CompactAllergenRow.badgesFor(recipe.tagResult!, userAllergenPrefs);

  /// Whether to explain a badge-less card rather than leaving it silent.
  ///
  /// True only when the user ASKED for allergen information and none can be
  /// drawn. "Asked" is two separate things, and the second one is easy to miss:
  ///
  ///  · `showAllergenBadges` — the badges are switched on at all.
  ///  · a NON-EMPTY tracked set — an empty set is not "no opinion", it is the
  ///    user having untracked every allergen, which is the same choice as
  ///    switching the badges off and deserves the same silence.
  ///
  /// Without the second of those this fires on EVERY card, permanently, and
  /// tells someone who tracks no allergens that fully assessed recipes are
  /// unassessed. Measured, not reasoned: `badgesFor` does
  /// `userPrefs ?? _defaultAllergens`, so an EMPTY set checks zero allergens
  /// and returns `[]` for every recipe — while `ContentCard` still derives
  /// `showAllergenBadges: true` from it being non-null. And it is reachable
  /// from onboarding, not just from an unusual settings path: saving
  /// "vegan, no allergies" persists `{}` with `showOnCards` left on.
  ///
  /// The `!_showUntaggedIndicator` conjunct is DORMANT: it depends on
  /// `showAnalysisStatus`, which nothing in `lib/` sets true, so the untagged
  /// indicator never speaks today. It is kept because it is the right shape the
  /// day that flag is wired up — but do not read it as a promise that is
  /// currently being kept.
  bool get _showUnassessedIndicator =>
      _allergenBadgesRequested &&
      _allergenBadges.isEmpty &&
      !_showUntaggedIndicator;

  /// Did the user actually ask for allergen information on this card?
  ///
  /// Extracted because it has TWO consumers and only one of them used to carry
  /// the empty-set half — `_showUntaggedIndicator` reads
  /// `showAllergenBadges` raw. That sibling is dormant today (nothing sets
  /// `showAnalysisStatus`), so the bug was not live; but it is the same defect
  /// re-entering through the twin the moment that flag is wired up, which is
  /// this repo's most repeated shape. One question, asked once.
  bool get _allergenBadgesRequested =>
      showAllergenBadges && (userAllergenPrefs?.isNotEmpty ?? true);

  /// The dietary twin of [_allergenBadgesRequested], and it exists for the same
  /// reason rather than for symmetry: `recipe_card_widget.dart` can pass an
  /// EMPTY `trackedDietary`, which `ContentCard` then turns into
  /// `showDietaryBadges: true` — exactly as it does for allergens. Fixing one
  /// half and leaving the other raw is the shape this repo keeps paying for:
  /// a twin left behind.
  bool get _dietaryBadgesRequested =>
      showDietaryBadges && (userDietaryPrefs?.isNotEmpty ?? true);

  /// The dietary badges this card would draw, or empty. See [_allergenBadges].
  List<String> get _dietaryBadges => recipe.tagResult == null
      ? const []
      : CompactDietaryRow.badgesFor(recipe.tagResult!, userDietaryPrefs);

  /// Whether to show untagged indicator.
  /// Shows when tagResult is null or has failed status, and badges/analysis are enabled.
  bool get _showUntaggedIndicator {
    if (!showAnalysisStatus) return false;
    if (!_allergenBadgesRequested && !_dietaryBadgesRequested) return false;
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
    final displayCount = names.length > maxPersonalTags
        ? maxPersonalTags
        : names.length;
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

  /// "Allergener ej bedömda" — shown when the card WOULD have carried allergen
  /// badges and has nothing to say.
  ///
  /// Malin's call, 2026-08-18, on the Creative Director's condition. The
  /// problem it solves is an inference, not a missing feature: after UNKNOWN
  /// badges were filtered out, a silent card meant four different things —
  /// never analysed, analysis FAILED, analysed but everything uncertain, or
  /// genuinely nothing to report. On a list where most cards show green FREE
  /// badges, silence reads as "nothing flagged", i.e. safe. For an app whose
  /// premise is trustworthy allergen information that is the one inference the
  /// layout must never invite.
  ///
  /// Deliberately ONE neutral chip rather than restoring the per-allergen grey
  /// badges. Her decision, as recorded: a grey question mark reads as a verdict
  /// when it is the absence of one — and on a recipe the tagger settled NOTHING
  /// about, those four badges were not part of the row, they WERE the row (see
  /// `CompactAllergenRow.badgesFor`). One neutral marker states the absence
  /// once instead of spelling it four times.
  ///
  /// Do NOT write that the grey badges "crowded" or "crowded out" anything.
  /// That reason is unsupported — they sorted last and could displace nothing —
  /// and it was already retracted once in `badgesFor`'s own comment. It came
  /// back here through a paraphrase while this change was being written — so
  /// the paraphrase is not in the committed diff, and the warning stands on
  /// the mechanism above rather than on a trace you can go and find.
  ///
  /// Neutral `outline`, not `warning` — this is an absence of information, not
  /// a hazard, and colouring it as a hazard would be its own false claim.
  ///
  /// Not shown when the user has turned badges off: silence is then their own
  /// choice and needs no explanation.
  Widget _buildUnassessedIndicator(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Semantics(
      label: context.l10n.recipeAllergensUnassessedA11y,
      child: Container(
        padding: AppDimensions.paddingSymmetric4x8,
        decoration: BoxDecoration(
          color: cs.outline.withValues(alpha: AppDimensions.opacityVeryLight),
          borderRadius: BorderRadius.circular(AppDimensions.borderRadiusS),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.help_outline, size: 14, color: cs.outline),
            const SizedBox(width: AppDimensions.spacingXs),
            Text(
              context.l10n.recipeAllergensUnassessed,
              style: AppTextStyles.labelSmall.copyWith(color: cs.outline),
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
