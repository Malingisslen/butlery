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
import 'package:butlery/widgets/tagging/tagging_widgets.dart';
import 'package:butlery/widgets/recipe/recipe_initial_plate.dart';
import 'package:butlery/core/utils/time_format_utils.dart';
import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/repositories/interfaces/ratings_repository.dart';
import 'package:butlery/widgets/recipe/butlery_betyg_pill.dart';

/// One recipe in a list or a grid, drawn as Komponentark v1 "Receptkort ·
/// receptlistrad" (Malin chose the drawing as it stands, 2026-10-11).
///
/// The grid card is paper with an edge (the shared card surface) with the
/// photo on top, the title and one line of metadata. The list row has no
/// card surface: a thumbnail, the title, the metadata, the row chevron and a
/// hairline under it. Allergen information is the one addition to the
/// drawing, and only when the user turned it on for recipe cards.
class RecipeCard extends StatelessWidget {
  final Recipe recipe;
  final void Function(Recipe)? onTap;
  final void Function(Recipe)? onLongPress;

  /// Replaces the row chevron (list styles only).
  final Widget? trailing;
  final bool showImage;
  final bool showMetadata;
  final bool showAllergenBadges;
  final Set<String>? userAllergenPrefs;
  final bool showDietaryBadges;
  final Set<String>? userDietaryPrefs;
  final bool isSelected;
  final EdgeInsets? margin;
  final EdgeInsets? padding;
  final RecipeCardStyle style;
  final bool showMealType;
  final bool showAnalysisStatus;

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
    this.showAllergenBadges = false,
    this.userAllergenPrefs,
    this.showDietaryBadges = false,
    this.userDietaryPrefs,
    this.isSelected = false,
    this.margin,
    this.padding,
    this.style = RecipeCardStyle.detailed,
    this.showMealType = false,
    this.showAnalysisStatus = false,
    this.matchPercent,
    this.pooledStats,
  });

  /// Komponentark v1 "Bild saknas, bild misslyckas": a recipe without a photo
  /// gets a 36 dp initial plate, never an empty image box.
  static const double _initialPlateSize = 36;

  /// Komponentark v1: the list row is at least 64 dp with a 48 dp thumbnail.
  static const double _rowMinHeight = 64;
  static const double _thumbnailSize = 48;

  /// Komponentark v1: the grid card's photo is 16:9.
  static const double _gridPhotoAspectRatio = 16 / 9;

  /// The compact row draws no badge rows; it is a separate design call.
  bool get _isCompact => style == RecipeCardStyle.compact;

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

  /// The selected state is surface.selected with a real border, never a
  /// tint: #flerbar draws the chosen row on the raised surface with a 1.5 px
  /// ink border (Skarmar v12 etapp 9 #flerbar; Grafisk manual v6:209 "Vald =
  /// riktig border"). colorScheme surfaceContainerHighest is surface.raised
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
              // BUT-1895: allergen information must not depend on which view toggle
              // happens to be saved. The badges were drawn in the detailed layout
              // only, and `MinaReceptRecipeCard` picks the GRID style the moment the
              // user turns grid view on — so on Mina recept the setting that shows
              // allergen status on recipe cards (`allergenDisplayOnCardsTitle`) was
              // honoured in list mode and silently ignored in grid mode, on the same
              // screen.
              //
              // The unassessed marker SHIPS with the row and is never left behind.
              // On a screen of mostly-green
              // cards a silent card reads as "nothing flagged", and that inference is
              // exactly what the marker exists to block, so moving the row here
              // without it would reopen a fixed bug in a new place.
              //
              // The dietary row is NOT here, and that is now a decision rather than
              // a deferral (BUT-1906, Malin 2026-08-23). The allergen badges above
              // are icon-only and 28px wide; a dietary badge carries its WORD, and
              // the word does not fit. Measured on a 2-column tile: the row has 88
              // logical pixels on a 360dp phone and 68 on a 320dp one, while
              // "vegansk" needs 111 and "vegetarisk" needs 145 — at NORMAL text
              // size, growing to 188 and 255 at 2x. There is no text size and no
              // phone width where it fits.
              //
              // Icon-only was the alternative, and the badge does support it
              // (`showLabel: false`, which is how the allergen row is drawn). It is
              // useless here: the badge picks its icon from the STATUS, so vegansk
              // and vegetarisk both render the same green leaf. Dropping the word
              // without first giving each diet its own icon replaces the row with
              // two identical marks.
              //
              // Diet keeps its word in the DETAILED layout, which is full-width and
              // has the room. The compact layout draws neither badge row at all.
              if (showAllergenBadges && _allergenBadges.isNotEmpty) ...[
                const SizedBox(height: AppDimensions.space4),
                CompactAllergenRow(
                  tagResult: recipe.tagResult!,
                  userPrefs: userAllergenPrefs,
                  maxBadges: 4,
                ),
              ],
              if (_showUnassessedIndicator) ...[
                const SizedBox(height: AppDimensions.space4),
                _buildUnassessedIndicator(context),
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
                  if (!_isCompact &&
                      showAllergenBadges &&
                      _allergenBadges.isNotEmpty) ...[
                    const SizedBox(height: AppDimensions.space8),
                    CompactAllergenRow(
                      tagResult: recipe.tagResult!,
                      userPrefs: userAllergenPrefs,
                      maxBadges: 4,
                    ),
                  ],
                  if (!_isCompact && _showUnassessedIndicator) ...[
                    const SizedBox(height: AppDimensions.space8),
                    _buildUnassessedIndicator(context),
                  ],
                  // space8, not space4. The gap BETWEEN the two badge rows has to be
                  // strictly greater than the `runSpacing` INSIDE either of them, or a
                  // wrapped row is indistinguishable from the next row. Both rows use
                  // `runSpacing: space4`, so an inter-row gap of space4 collapses
                  // the distinction the moment the allergen row wraps — which it does at
                  // the 1.5-2x text scale this codebase designs for (BUT-547), not at 1x.
                  // Raised on the Creative Director's condition, 2026-08-18.
                  if (!_isCompact &&
                      showDietaryBadges &&
                      _dietaryBadges.isNotEmpty) ...[
                    const SizedBox(height: AppDimensions.space8),
                    CompactDietaryRow(
                      tagResult: recipe.tagResult!,
                      userPrefs: userDietaryPrefs,
                      maxBadges: 2,
                    ),
                  ],
                  if (!_isCompact && _showUntaggedIndicator) ...[
                    const SizedBox(height: AppDimensions.space8),
                    _buildUntaggedIndicator(context),
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

  /// "45 min · 4 port. · ★ 4,5": the metadata as one line of text, the
  /// rating a data marker in text.accent (Komponentark v1, saffranshierarkin
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

    final line = Text.rich(
      TextSpan(
        children: [
          TextSpan(text: parts.join(' · ')),
          if (rating != null) ...[
            if (parts.isNotEmpty) const TextSpan(text: ' · '),
            TextSpan(
              text: '★ ${rating.value}',
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

  /// The allergen badges this card would draw, or empty.
  ///
  /// Asked by the build gate so the spacer and the row can never disagree —
  /// they are computed by the same function the row uses to decide whether to
  /// collapse. Empty whenever the recipe is untagged, so the `tagResult!`
  /// at the call site is guarded by this being non-empty.
  List<String> get _allergenBadges => recipe.tagResult == null
      ? const []
      : CompactAllergenRow.badgesFor(recipe.tagResult!, userAllergenPrefs);

  /// Whether to say "Ej kontrollerat" on the card: the user asked for
  /// allergen information and at least one allergen they track is unsettled
  /// (or the recipe was never tagged). Silence there reads as "nothing
  /// flagged", the one inference the card must not invite. An empty tracked
  /// set is the user opting out, which [_allergenBadgesRequested] covers.
  bool get _showUnassessedIndicator =>
      _allergenBadgesRequested &&
      !_showUntaggedIndicator &&
      CompactAllergenRow.hasUnchecked(recipe.tagResult, userAllergenPrefs);

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

  /// Builds untagged indicator for recipes pending analysis.
  Widget _buildUntaggedIndicator(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tagResult = recipe.tagResult;
    final hasFailed = tagResult?.hasFailed ?? false;
    // B83-2: a notice is the mode's surface tint with no border; the text and
    // glyph take the matching on-colour, never the raw status colour.
    final modeColors = context.modeColors;
    final noticeFg = hasFailed
        ? cs.onErrorContainer
        : AppModeColors.textWarning(Theme.of(context).brightness);

    return Semantics(
      label: hasFailed
          ? context.l10n.recipeAnalysisFailedA11y
          : context.l10n.recipeAnalyzingA11y,
      child: Container(
        padding: AppDimensions.paddingSymmetric4x8,
        decoration: BoxDecoration(
          color: hasFailed
              ? modeColors.surfaceTintDanger
              : modeColors.surfaceTintWarning,
          borderRadius: BorderRadius.circular(AppDimensions.radiusControl),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ButleryIcon(
              hasFailed ? ButleryIcons.triangleAlert : ButleryIcons.hourglass,
              size: AppDimensions.iconSize14,
              color: noticeFg,
            ),
            const SizedBox(width: AppDimensions.space4),
            Flexible(
              child: Text(
                hasFailed
                    ? context.l10n.recipeAnalysisFailed
                    : context.l10n.recipeAnalyzing,
                style: AppTextStyles.labelSmall.copyWith(
                  color: noticeFg,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// "Ej kontrollerat": the card carries allergen badges for what the tagger
  /// settled and says in words that something is still unsettled, because
  /// silence on a list full of green badges reads as "nothing flagged".
  ///
  /// Neutral, not `warning`: this is an absence of information, not a hazard.
  ///
  /// Not shown when the user has turned badges off: silence is then their own
  /// choice and needs no explanation.
  Widget _buildUnassessedIndicator(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final secondary = AppModeColors.textSecondaryOnRaised(
      Theme.of(context).brightness,
    );
    return Semantics(
      label: context.l10n.allergenUncheckedA11y,
      excludeSemantics: true,
      child: ButleryOutlinedBox(
        padding: AppDimensions.paddingSymmetric4x8,
        color: _chipFill(cs),
        borderColor: cs.outlineVariant,
        radius: AppDimensions.radiusControl,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ButleryIcon(
              ButleryIcons.info,
              size: AppDimensions.iconSize14,
              color: secondary,
            ),
            const SizedBox(width: AppDimensions.space4),
            // Flexible, and allowed to WRAP rather than ellipsize. A grid tile
            // gives this chip 72 logical pixels on a 360dp phone while the
            // icon and the sentence need about 254, so unconstrained it
            // overflowed at every width and every text size — silently, since
            // a release build draws no stripes. Ellipsis is the wrong recovery
            // here: this is the marker that stops a quiet card being read as
            // "nothing flagged", and "Alle…" says less than nothing. The card
            // sizes to its content now, so it can afford the extra lines.
            Flexible(
              child: Text(
                context.l10n.allergenUncheckedLabel,
                style: AppTextStyles.labelSmall.copyWith(color: secondary),
              ),
            ),
          ],
        ),
      ),
    );
  }
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
