import 'package:butlery/theme/span_styles.dart';
import 'package:flutter/material.dart';
import 'package:butlery/widgets/common/surfaces/butlery_outlined_box.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_mode_colors.dart';
import 'package:butlery/widgets/common/butlery_control_focus.dart';
import 'package:butlery/widgets/common/hoverable_card.dart';
import 'package:butlery/widgets/common/icons/butlery_glyph.dart';
import 'package:butlery/widgets/common/icons/butlery_icons.dart';
import 'package:butlery/widgets/common/list/butlery_list.dart';
import 'package:butlery/widgets/image/simple_image_widget.dart';
import 'package:butlery/widgets/image/image_config.dart';
import 'package:butlery/widgets/common/cards/styled_card.dart';
import 'package:butlery/widgets/recipe/recipe_initial_plate.dart';
import 'package:butlery/core/utils/time_format_utils.dart';
import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/repositories/interfaces/ratings_repository.dart';
import 'package:butlery/widgets/recipe/butlery_betyg_pill.dart';

/// One recipe in a list or a grid
///
/// The grid card is paper with an edge (the shared card surface) with the
/// photo on top, the title and one line of metadata. The list row has no
/// card surface: a thumbnail, the title, the metadata, the row chevron and a
/// hairline under it.
class RecipeCard extends StatelessWidget {
  final Recipe recipe;
  final void Function(Recipe)? onTap;
  final void Function(Recipe)? onLongPress;

  /// Replaces the row chevron (list styles only).
  final Widget? trailing;
  final bool showImage;
  final bool showMetadata;
  final bool isSelected;
  final EdgeInsets? margin;
  final EdgeInsets? padding;
  final RecipeCardStyle style;
  final bool showMealType;

  /// Pantry match percentage (0.0..1.0). When non-null, renders a small
  /// badge in the card showing how much of the recipe the user's pantry
  /// already covers. Only used when the "Laga med vad jag har" filter is
  /// active in the recipe list.
  final double? matchPercent;

  /// Pooled "Butlery-betyget" stats for this recipe's dish. The card's one
  /// rating number falls back to it when the household and the user have
  /// not rated the dish and the pool clears the display floor (n>=5).
  final PooledStats? pooledStats;

  const RecipeCard({
    super.key,
    required this.recipe,
    this.onTap,
    this.onLongPress,
    this.trailing,
    this.showImage = true,
    this.showMetadata = true,
    this.isSelected = false,
    this.margin,
    this.padding,
    this.style = RecipeCardStyle.detailed,
    this.showMealType = false,
    this.matchPercent,
    this.pooledStats,
  });

  static const double _initialPlateSize = 36;

  static const double _rowMinHeight = 64;
  static const double _thumbnailSize = 48;

  static const double _gridPhotoAspectRatio = 16 / 9;

  bool get _hasPhoto => showImage && recipe.displayThumbnailUrl != null;

  @override
  Widget build(BuildContext context) {
    final grid = style == RecipeCardStyle.grid;
    final rest = _restDecoration(context, grid: grid);
    final radius = BorderRadius.circular(
      grid || isSelected ? AppDimensions.radiusCard : 0,
    );

    return RepaintBoundary(
      child: Semantics(
        button: onTap != null,
        selected: isSelected,
        child: HoverableCard(
          // Only interactive cards get a hover affordance — a card with no tap
          // handler shouldn't imply clickability under the cursor.
          enabled: onTap != null,
          margin: margin ?? EdgeInsets.zero,
          restDecoration: rest,
          hoverDecoration: rest.copyWith(
            color: StyledCard.pressFillOf(context),
          ),
          child: Material(
            color: Colors.transparent,
            borderRadius: radius,
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              borderRadius: radius,
              // The ring carries focus; no saffron focus tint under it.
              focusColor: Colors.transparent,
              overlayColor: StyledCard.inkOverlayOf(context),
              onTap: onTap != null ? () => onTap!(recipe) : null,
              onLongPress: onLongPress != null
                  ? () => onLongPress!(recipe)
                  : null,
              // The canonical focus ring around the whole card when the
              // card itself has keyboard focus, never saffron.
              child: ButleryAncestorFocusRing(
                borderRadius: radius,
                child: grid
                    ? _buildGridLayout(context)
                    : _buildRowLayout(context),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// colorScheme surfaceContainerHighest is surface.raised
  /// and onSurface is text.primary: ink on light, paper on dark.
  BoxDecoration _restDecoration(BuildContext context, {required bool grid}) {
    final cs = Theme.of(context).colorScheme;
    if (isSelected) {
      return ButleryOutlinedBox.decoration(
        color: cs.surfaceContainerHighest,
        radius: AppDimensions.radiusCard,
        borderColor: cs.onSurface,
        borderWidth: AppDimensions.borderWidthOutlinedEdge,
      );
    }
    if (grid) return StyledCard.decorationOf(context);
    return BoxDecoration(
      color: cs.surface,
      border: Border(bottom: BorderSide(color: cs.outlineVariant)),
    );
  }

  Widget _buildGridLayout(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      // The tile sizes to this Column (BUT-1911): its caller lays the grid
      // out as rows of cards whose height comes from the tallest card in the
      // row, so nothing here is the slack.
      mainAxisSize: MainAxisSize.min,
      children: [
        if (_hasPhoto)
          AspectRatio(
            aspectRatio: _gridPhotoAspectRatio,
            child: _buildPhoto(context),
          ),
        Padding(
          padding:
              padding ??
              const EdgeInsets.fromLTRB(
                AppDimensions.space12,
                AppDimensions.space8,
                AppDimensions.space12,
                AppDimensions.space12,
              ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (!_hasPhoto) ...[
                const SizedBox(height: AppDimensions.space4),
                _buildInitialPlate(),
                const SizedBox(height: AppDimensions.space8),
              ],
              _buildTitle(context, reserveTwoLines: true),
              if (showMetadata && _hasAnyMetadata) ...[
                const SizedBox(height: AppDimensions.space4),
                _buildMetadataRow(context),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildRowLayout(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: _rowMinHeight),
      child: Padding(
        padding:
            padding ??
            // The same inset at rest and chosen, so a row does not move when
            // it is selected and its box and border appear around it.
            const EdgeInsets.symmetric(
              vertical: AppDimensions.space8,
              horizontal: AppDimensions.space12,
            ),
        child: Row(
          children: [
            if (showImage) ...[
              SizedBox(
                width: _thumbnailSize,
                height: _thumbnailSize,
                child: Center(
                  child: _hasPhoto
                      ? SizedBox(
                          width: _thumbnailSize,
                          height: _thumbnailSize,
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(
                              AppDimensions.radiusControl,
                            ),
                            child: _buildPhoto(context),
                          ),
                        )
                      : _buildInitialPlate(),
                ),
              ),
              const SizedBox(width: AppDimensions.space12),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildTitle(context),
                  if (showMetadata && _hasAnyMetadata) ...[
                    const SizedBox(height: AppDimensions.space4),
                    _buildMetadataRow(context),
                  ],
                ],
              ),
            ),
            if (trailing != null)
              trailing!
            else if (onTap != null) ...[
              const SizedBox(width: AppDimensions.space8),
              const ButleryChevron(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildPhoto(BuildContext context) {
    return SimpleImageWidget(
      imageUrl: recipe.displayThumbnailUrl,
      fit: BoxFit.cover,
      config: ImageConfig.thumbnail(
        heroTag: ImageConfig.recipeHeroTag(recipe.id),
      ),
    );
  }

  Widget _buildInitialPlate() {
    return SizedBox(
      width: _initialPlateSize,
      height: _initialPlateSize,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppDimensions.radiusControl),
        child: RecipeInitialPlate(
          title: recipe.title,
          letterSize: _initialPlateSize * 0.42,
        ),
      ),
    );
  }

  /// [reserveTwoLines] keeps the cards of one grid row the same height: the
  /// list stretches nothing past its swipe wrapper, so a one-line title would
  /// otherwise leave its card shorter than its neighbour's.
  Widget _buildTitle(BuildContext context, {bool reserveTwoLines = false}) {
    final style = AppTextStyles.recipeCardTitle.copyWith(
      color: Theme.of(context).colorScheme.onSurface,
    );
    final title = Text(
      recipe.title,
      style: style,
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
    );
    if (!reserveTwoLines) return title;
    final lineHeight = MediaQuery.textScalerOf(
      context,
    ).scale((style.fontSize ?? 15) * (style.height ?? 1.2));
    return ConstrainedBox(
      constraints: BoxConstraints(minHeight: lineHeight * 2),
      child: title,
    );
  }

  /// The metadata as one line of text, the
  /// rating a star and a data marker in text.accent (saffranshierarkin
  /// punkt 4), not a badge.
  Widget _buildMetadataRow(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final parts = <String>[
      if (showMealType && recipe.mealType.isNotEmpty) recipe.mealType,
      if (recipe.timeMinutes case final minutes? when minutes > 0)
        TimeFormatUtils.formatCookingTime(minutes),
      if (recipe.portions case final portions? when portions > 0)
        '$portions ${context.l10n.recipePortionAbbreviation}',
    ];
    final rating = _rating(context);
    final secondary = AppModeColors.textSecondaryOnRaised(brightness);
    // text.accent is bound to surface.base; a chosen card is surface.raised,
    // where text.accent.onRaised takes over.
    final accent = isSelected
        ? context.modeColors.onWarningContainer
        : context.modeColors.textAccent;

    final text = Text.rich(
      TextSpan(
        children: [
          TextSpan(text: parts.join(' · ')),
          if (rating != null) ...[
            if (parts.isNotEmpty) const TextSpan(text: ' · '),
            // A drawn star: the ★ character is missing from the app font and
            // showed as a bullet.
            WidgetSpan(
              alignment: PlaceholderAlignment.middle,
              child: Padding(
                padding: const EdgeInsetsDirectional.only(
                  end: AppDimensions.space4,
                ),
                child: ButleryIcon(
                  ButleryIcons.star,
                  size: AppDimensions.ratingStarSize,
                  color: context.modeColors.starGold,
                ),
              ),
            ),
            TextSpan(
              text: rating.value,
              style: SpanStyles.colour(accent),
              semanticsLabel: rating.semantics,
            ),
          ],
        ],
      ),
      style: AppTextStyles.captionText.copyWith(color: secondary),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
    // The drawn star splits the text's own semantics at the placeholder, so
    // the line is announced as one sentence from here.
    final line = rating == null
        ? text
        : Semantics(
            label: [...parts, rating.semantics].join(' \u00B7 '),
            excludeSemantics: true,
            child: text,
          );

    if (matchPercent == null) return line;
    // Wrap so the badge flows to a new line instead of overflowing at 2x
    // text scaling (BUT-547 / WCAG 1.4.4).
    return Wrap(
      spacing: AppDimensions.space8,
      runSpacing: AppDimensions.space4,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [line, _buildMatchBadge(context, matchPercent!)],
    );
  }

  /// The card's one rating number: the household's verdict, else the
  /// user's own, else the Butlery-betyget pool once it clears its floor,
  /// else the public aggregate. Null when there is none.
  ({String value, String semantics})? _rating(BuildContext context) {
    final l10n = context.l10n;
    final familyAvg = recipe.core.familyAverage;
    if (familyAvg != null && (recipe.core.familyRatingCount ?? 0) > 0) {
      final v = formatRatingComma(familyAvg);
      return (value: v, semantics: l10n.a11yFamilyRatingPill(v));
    }
    if (recipe.rating case final own? when own > 0) {
      return (
        value: formatRatingComma(own),
        semantics: l10n.recipeRatingSemantics(own.toStringAsFixed(1)),
      );
    }
    final pooled = pooledStats;
    if (pooled != null && pooled.meetsDisplayFloor) {
      final v = formatRatingComma(pooled.average!);
      return (value: v, semantics: l10n.a11yButleryBetygPill(v, pooled.count));
    }
    if (recipe.core.averageRating case final alla? when alla > 0) {
      final v = formatRatingComma(alla);
      return (value: v, semantics: l10n.a11yAllaRatingPill(v));
    }
    return null;
  }

  Widget _buildMatchBadge(BuildContext context, double percent) {
    final cs = Theme.of(context).colorScheme;
    final pct = (percent * 100).round().clamp(0, 100);
    return Semantics(
      label: context.l10n.recipeCardPantryMatchA11y(pct),
      excludeSemantics: true,
      child: Container(
        padding: AppDimensions.badgePadding,
        decoration: BoxDecoration(
          color: _chipFill(cs),
          border: Border.all(color: cs.outlineVariant),
        ),
        child: Text(
          '$pct%',
          style: AppTextStyles.badge.copyWith(color: cs.onSurface),
        ),
      ),
    );
  }

  // The card rests on surface.base; a chip fills to surface.raised there, and
  // to surface.base once the card itself is the raised (selected) surface.
  Color _chipFill(ColorScheme cs) =>
      isSelected ? cs.surface : cs.surfaceContainerHighest;

  /// Whether the recipe has any metadata to display.
  bool get _hasAnyMetadata {
    if (showMealType && recipe.mealType.isNotEmpty) return true;
    if (recipe.portions != null && recipe.portions! > 0) return true;
    if (recipe.timeMinutes != null && recipe.timeMinutes! > 0) return true;
    if (matchPercent != null) return true;
    return _hasAnyRating;
  }

  bool get _hasAnyRating =>
      (recipe.core.familyAverage != null &&
          (recipe.core.familyRatingCount ?? 0) > 0) ||
      (recipe.rating ?? 0) > 0 ||
      (pooledStats?.meetsDisplayFloor ?? false) ||
      (recipe.core.averageRating ?? 0) > 0;
}

/// Enum for different recipe card display styles
enum RecipeCardStyle {
  /// A list row with the smaller type set
  compact,

  /// A list row: thumbnail, title, metadata, chevron
  detailed,

  /// A grid card: photo on top, title, metadata
  grid,
}
