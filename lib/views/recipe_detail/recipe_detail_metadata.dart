// lib/views/recipe_detail/recipe_detail_metadata.dart

import 'package:flutter/material.dart';
import 'package:butlery/viewmodels/recipe_detail_viewmodel.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/butlery_colors_extension.dart';
import 'package:butlery/core/utils/snackbar_utils.dart';
import 'package:butlery/core/utils/time_format_utils.dart';
import 'package:butlery/core/utils/common_dialog_actions.dart';
import 'package:butlery/utils/text/text_formatting.dart';
import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/widgets/common/star_rating_row.dart';
import 'package:butlery/widgets/recipe/butlery_betyg_pill.dart';
import 'package:butlery/views/recipe_detail/handlers/recipe_management_handler.dart';
import 'package:butlery/repositories/interfaces/ratings_repository.dart';
import 'package:butlery/services/rating/canonical_pool_key.dart';
import 'package:butlery/services/feature_flags/feature_flag_service.dart';
import 'package:butlery/services/analytics_service.dart';
import 'package:butlery/services/analytics/analytics_events.dart';

/// Recipe detail metadata widget — inline row with time, portions, rating,
/// and "Lagat idag" chip. Source URL is shown as subtitle in the parent view.
class RecipeDetailMetadata extends StatefulWidget {
  final RecipeDetailViewModel viewModel;
  final int currentPortions;
  final bool isScaled;

  const RecipeDetailMetadata({
    super.key,
    required this.viewModel,
    required this.currentPortions,
    required this.isScaled,
  });

  @override
  State<RecipeDetailMetadata> createState() => _RecipeDetailMetadataState();
}

class _RecipeDetailMetadataState extends State<RecipeDetailMetadata> {
  bool _hasUserRating = false;
  bool _checkedUserRating = false;

  /// Pooled "Butlery-betyget" display gate, cached once (RC flag). When off the
  /// pooled section never fetches or renders (decision 11 kill switch).
  bool _pooledEnabled = false;

  /// The community pooled stats for this dish, once fetched. Null until loaded,
  /// or when below the display floor / missing / errored — the detail page then
  /// shows only the existing per-copy star row (never a blank pill).
  PooledStats? _pooledStats;

  /// The resolved dish poolKey, cached once in [_loadPooledStats] so the
  /// contribution log doesn't re-hash the ingredient list on every rate tap.
  String? _poolKey;

  @override
  void initState() {
    super.initState();
    _checkUserRating();
    _pooledEnabled =
        ServiceLocator.tryGet<FeatureFlagService>()?.isEnabled(
          FeatureFlags.enablePooledRatings,
        ) ??
        false;
    if (_pooledEnabled) _loadPooledStats();
  }

  /// Resolve the dish poolKey (stored hint, or computed on-the-fly for older
  /// recipes with no hint) and read the server-authoritative aggregate. Mirrors
  /// [_checkUserRating]'s fire-and-forget + mounted-guard shape. Fail-soft: any
  /// error or a below-floor pool leaves [_pooledStats] null (per-copy fallback).
  /// Fires `pool_rating_shown` once, only when a floor-clearing score is shown —
  /// this is the single detail-open stats read (decision 15).
  Future<void> _loadPooledStats() async {
    final poolKey = _resolvePoolKey();
    if (poolKey == null || poolKey.isEmpty) return;
    _poolKey = poolKey; // reused by _logPoolContribution (no second hash)

    try {
      final stats = await ServiceLocator.get<RatingsRepository>()
          .getPooledStats(poolKey);
      if (!mounted || stats == null || !stats.meetsDisplayFloor) return;
      setState(() => _pooledStats = stats);
      AnalyticsService.tryLog(
        AnalyticsEvents.poolRatingShown,
        parameters: {'pool_key': poolKey, 'count': stats.count},
      );
    } catch (_) {
      // Non-critical — the per-copy star row already covers the fallback.
    }
  }

  Future<void> _checkUserRating() async {
    final recipe = widget.viewModel.recipe;
    if (recipe.isPersonal || (recipe.rating ?? 0) <= 0) return;

    try {
      final userRating = await widget.viewModel.recipeService.social
          .getUserRating(recipe.id);
      if (mounted) {
        setState(() {
          _hasUserRating = userRating != null;
          _checkedUserRating = true;
        });
      }
    } catch (_) {
      // Non-critical — just won't show the remove button
    }
  }

  @override
  Widget build(BuildContext context) {
    return _buildMetadata(context);
  }

  Widget _buildMetadata(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final recipe = widget.viewModel.recipe;

    final metadataWidgets = <Widget>[];

    // Time with clock icon
    if ((recipe.timeMinutes ?? 0) > 0) {
      metadataWidgets.add(
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.access_time,
              size: AppDimensions.iconSizeS,
              color: cs.primary,
            ),
            const SizedBox(width: AppDimensions.spacingXs),
            Text(
              TimeFormatUtils.formatCookingTime(recipe.timeMinutes!),
              style: AppTextStyles.bodySmall.copyWith(
                color: widget.isScaled ? cs.primary : cs.onSurface,
                fontWeight: widget.isScaled ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ],
        ),
      );
    }

    // Portions with person icon
    if (widget.currentPortions > 0) {
      metadataWidgets.add(
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.person_outline,
              size: AppDimensions.iconSizeS,
              color: cs.primary,
            ),
            const SizedBox(width: AppDimensions.spacingXs),
            Text(
              '${widget.currentPortions} ${widget.currentPortions == 1 ? context.l10n.recipePortionSingular : context.l10n.recipePortionAbbreviation}',
              style: AppTextStyles.bodySmall.copyWith(
                color: widget.isScaled ? cs.primary : cs.onSurface,
                fontWeight: widget.isScaled ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ],
        ),
      );
    }

    // Star rating row — always visible, tappable to set rating
    metadataWidgets.add(
      Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          StarRatingRow(
            rating: recipe.rating ?? 0,
            onRatingChanged: (value) => _rateRecipe(context, value),
            semanticsLabel: (star) => context.l10n.ratingStarLabel(star),
          ),
          if ((recipe.rating ?? 0) > 0) ...[
            const SizedBox(width: AppDimensions.spacingXs),
            Text(
              // sv-SE decimal comma (4.5 → "4,5"); whole ratings drop the decimal.
              TextFormatting.formatFractional(recipe.rating!),
              style: AppTextStyles.bodySmall.copyWith(color: cs.onSurface),
            ),
            // Remove own rating — only when the user has rated
            if (_checkedUserRating && _hasUserRating) ...[
              const SizedBox(width: AppDimensions.spacingXs),
              Semantics(
                label: context.l10n.a11yRemoveOwnRating,
                button: true,
                child: GestureDetector(
                  onTap: () => _removeMyRating(context),
                  child: Icon(
                    Icons.close,
                    size: 14,
                    color: cs.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ],
        ],
      ),
    );

    // "Lagat idag" chip — disabled after first tap per calendar day.
    // BUT-403: `btn-mark-cooked` identifier for browser a11y tree queries.
    final cookedToday = widget.viewModel.wasCookedToday;
    final cookCount = widget.viewModel.recipe.cookCount;
    metadataWidgets.add(
      Semantics(
        identifier: 'btn-mark-cooked',
        button: true,
        enabled: !cookedToday,
        label: context.l10n.recipeCookedToday,
        child: OutlinedButton.icon(
          key: const ValueKey('test-recipe-detail-mark-cooked'),
          onPressed: cookedToday ? null : () => _markAsCooked(context),
          icon: Icon(
            cookedToday ? Icons.check_circle : Icons.check_circle_outline,
            size: 14,
          ),
          label: Text(
            cookCount > 0
                ? '${context.l10n.recipeCookedToday} ($cookCount)'
                : context.l10n.recipeCookedToday,
            style: AppTextStyles.labelSmall,
          ),
          style: OutlinedButton.styleFrom(
            foregroundColor: context.butleryColors.success,
            disabledForegroundColor: context.butleryColors.success.withValues(
              alpha: 0.5,
            ),
            side: BorderSide(
              color: cookedToday
                  ? context.butleryColors.success.withValues(alpha: 0.3)
                  : context.butleryColors.success,
              width: 0.5,
            ),
            padding: const EdgeInsets.symmetric(
              horizontal: AppDimensions.spacingSm,
              vertical: AppDimensions.spacingXxs,
            ),
            minimumSize: Size.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.zero,
            ),
          ),
        ),
      ),
    );

    // Manual "Betygsätt som familj" entry — the second trigger for family
    // rating (the first is the auto-chain after "Lagat idag"). Square outlined
    // button mirroring the cook chip's treatment.
    metadataWidgets.add(
      Semantics(
        button: true,
        label: context.l10n.familyRatingManualButton,
        child: OutlinedButton.icon(
          onPressed: () => RecipeManagementHandler.rateAsFamily(context),
          icon: const Icon(Icons.groups_outlined, size: 14),
          label: Text(
            context.l10n.familyRatingManualButton,
            style: AppTextStyles.labelSmall,
          ),
          style: OutlinedButton.styleFrom(
            foregroundColor: context.butleryColors.starGold,
            side: BorderSide(
              color: context.butleryColors.starGold,
              width: 0.5,
            ),
            padding: const EdgeInsets.symmetric(
              horizontal: AppDimensions.spacingSm,
              vertical: AppDimensions.spacingXxs,
            ),
            minimumSize: Size.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.zero,
            ),
          ),
        ),
      ),
    );

    final metadataRow = Wrap(
      spacing: AppDimensions.spacingMd,
      runSpacing: AppDimensions.spacingSm,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: metadataWidgets,
    );

    // Community pooled score leads (tinted green), the household's own number
    // follows as context — both labelled, per the approved design. Absent below
    // the floor / flag-off / loading, leaving the per-copy star row untouched.
    final pooled = _buildPooledSection(context);
    if (pooled == null) return metadataRow;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        pooled,
        const SizedBox(height: AppDimensions.spacingMd),
        metadataRow,
      ],
    );
  }

  /// Swedish one-decimal with a decimal comma (4.3 -> "4,3"). Deliberately NOT
  /// TextFormatting.formatFractional: the pills always keep one decimal (4,0),
  /// whereas formatFractional drops it for whole numbers.

  /// The two labelled pooled pills. Community (green, with count) leads; the
  /// household's own rating (quiet slate) follows as context. Returns null when
  /// there is no floor-clearing community score to show.
  Widget? _buildPooledSection(BuildContext context) {
    final stats = _pooledStats;
    if (stats == null) return null;

    final recipe = widget.viewModel.recipe;
    // "alla i ditt kök" = the household's OWN verdict (the family rating), shown
    // only when the household has actually rated together. Deliberately NOT a
    // fall-back to the all-users average or the user's single star — the label
    // would misrepresent those, and the per-copy star row already carries the
    // personal number.
    final household = recipe.core.familyAverage;
    final hasHousehold =
        household != null && (recipe.core.familyRatingCount ?? 0) > 0;

    return Wrap(
      spacing: AppDimensions.spacingLg,
      runSpacing: AppDimensions.spacingSm,
      crossAxisAlignment: WrapCrossAlignment.start,
      children: [
        _buildLabelledPill(
          context,
          label: context.l10n.pooledCommunityLabel,
          // meetsDisplayFloor (checked in _loadPooledStats before this renders)
          // guarantees average is non-null here.
          pill: ButleryBetygPill(stats: stats),
        ),
        if (hasHousehold)
          _buildLabelledPill(
            context,
            label: context.l10n.pooledHouseholdLabel,
            pill: _buildHouseholdPill(context, household),
          ),
      ],
    );
  }

  Widget _buildLabelledPill(
    BuildContext context, {
    required String label,
    required Widget pill,
  }) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: AppTextStyles.labelSmall.copyWith(
            color: cs.onSurfaceVariant,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: AppDimensions.spacingXxs),
        pill,
      ],
    );
  }

  /// Quiet slate household pill `★ X,X` (no count) — the OUTLINED neutral
  /// treatment (transparent fill + hairline outline + secondary text) that the
  /// card uses for its demoted per-copy pill, so it stays AA-safe in dark mode
  /// while ceding brand green to the community number.
  Widget _buildHouseholdPill(BuildContext context, double avg) {
    final cs = Theme.of(context).colorScheme;
    return Semantics(
      label: context.l10n.a11yPooledHouseholdPill(formatRatingComma(avg)),
      child: Container(
        padding: AppDimensions.paddingSymmetric6x2,
        decoration: BoxDecoration(
          border: Border.all(color: cs.outlineVariant),
          borderRadius: BorderRadius.zero,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.star, size: 12, color: cs.onSurfaceVariant),
            const SizedBox(width: 3),
            Text(
              formatRatingComma(avg),
              style: AppTextStyles.badge.copyWith(
                color: cs.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Resolve this dish's pool key: the stored hint, or a fail-closed on-the-fly
  /// compute for older hint-less recipes. GUARDED — `CanonicalPoolKey.compute`
  /// is pure but treated as able-to-throw (the recipe write path guards this
  /// exact call identically), so a throw can never propagate into a rating
  /// flow's error handling and surface a false "rating failed". Returns null
  /// when the dish doesn't key (it simply doesn't pool).
  String? _resolvePoolKey() {
    final recipe = widget.viewModel.recipe;
    final hint = recipe.core.ratingPoolKey;
    if (hint != null && hint.isNotEmpty) return hint;
    try {
      return CanonicalPoolKey.compute(
        title: recipe.core.title,
        ingredients: recipe.core.ingredients,
      );
    } catch (_) {
      return null;
    }
  }

  /// Fire `pool_rating_contributed` if this dish resolves to a poolKey. Reuses
  /// the key cached by [_loadPooledStats]; no-ops when the dish fails to key.
  void _logPoolContribution() {
    final poolKey = _poolKey ?? _resolvePoolKey();
    if (poolKey == null || poolKey.isEmpty) return;
    AnalyticsService.tryLog(
      AnalyticsEvents.poolRatingContributed,
      parameters: {'pool_key': poolKey},
    );
  }

  Future<void> _rateRecipe(BuildContext context, double rating) async {
    try {
      final success = await widget.viewModel.rateRecipe(rating);
      if (!context.mounted) return;
      if (success) {
        // Only track user rating state for shared/collaborative recipes
        // (personal recipes store rating directly, no social rating record)
        if (!widget.viewModel.recipe.isPersonal) {
          setState(() {
            _hasUserRating = true;
            _checkedUserRating = true;
          });
        }
        // BUT-1360: offline the rating is queued locally — surface that instead
        // of the silent success the path previously showed.
        SnackBarUtils.showPendingSyncIfOffline(context);
        // Client-side intent signal: the user rated a dish that can pool. The
        // server mirror CF remains the authority for the actual pool event; this
        // only measures contribution volume (decision 15). Flag-gated.
        if (_pooledEnabled) _logPoolContribution();
      }
    } catch (e) {
      if (!context.mounted) return;
      // BUT-1360: a thrown exception is a real failure (permission/validation/
      // profile-resolution), NOT a queued offline write — offline state doesn't
      // prove otherwise. Always surface the real error so the rating isn't lost
      // silently; the pending-sync hint belongs only on the success branch.
      SnackBarUtils.showError(context, context.l10n.ratingError);
    }
  }

  Future<void> _removeMyRating(BuildContext context) async {
    final confirmed = await CommonDialogActions.showActionConfirmation(
      context: context,
      title: context.l10n.ratingRemoveTitle,
      message: context.l10n.ratingRemoveMessage,
      confirmText: context.l10n.commonDelete,
      icon: Icons.star_border,
      isDangerous: true,
    );
    if (confirmed != true || !context.mounted) return;

    try {
      final success = await widget.viewModel.removeMyRating();
      if (!context.mounted) return;
      if (success) {
        setState(() {
          _hasUserRating = false;
        });
        SnackBarUtils.showSuccess(context, context.l10n.ratingRemoved);
      }
    } catch (e) {
      if (!context.mounted) return;
      SnackBarUtils.showError(context, context.l10n.ratingRemoveError);
    }
  }

  Future<void> _markAsCooked(BuildContext context) async {
    // Delegate to the shared handler so the "vem åt?" picker and the family
    // rating chain fire here too — this is the live "Lagat idag" button, and
    // the handler is the single implementation of the cook flow.
    await RecipeManagementHandler.markAsCooked(context);
  }
}
