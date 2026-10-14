import 'package:flutter/material.dart';
import 'package:butlery/widgets/common/icons/butlery_glyph.dart';
import 'package:butlery/widgets/common/icons/butlery_icons.dart';
import 'package:butlery/widgets/common/indicators/plate_line.dart';

import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/models/tagging/tag_decision.dart';
import 'package:butlery/models/tagging/tag_result.dart';
import 'package:butlery/models/tagging/tri_state.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/theme/app_mode_colors.dart';
import 'package:butlery/services/tagging/config/dietary_config.dart';
import 'package:butlery/widgets/common/feedback/inline_warning.dart';
import 'package:butlery/widgets/tagging/allergen_status_badge.dart';
import 'package:butlery/widgets/tagging/dietary_status_badge.dart';
import 'package:butlery/widgets/common/sheets/butlery_sheet.dart';
import 'package:butlery/widgets/common/buttons/butlery_text_button.dart';

/// Priority-ordered list of dietary keys used by both TagResultDisplay and CompactDietaryRow.
/// Derived from DietaryConfig to prevent key drift.
final _defaultDietaryOrder = DietaryConfig.allKeys;

/// The tracked allergens the tagger has not settled.
///
/// A recipe with no tag result has settled none of them. [emptyMeansAll]
/// mirrors the call sites: the detail view reads a null or empty set as
/// "every allergen", a card reads an empty set as "tracks nothing".
bool hasUncheckedAllergens(
  TagResult? tagResult,
  Set<String>? prefs, {
  required Set<String> fallback,
  required bool emptyMeansAll,
}) {
  if (prefs != null && prefs.isEmpty && !emptyMeansAll) return false;
  if (tagResult == null) return true;
  final keys = prefs != null && prefs.isNotEmpty
      ? prefs
      : emptyMeansAll
      ? tagResult.allergenStatus.keys.toSet()
      : fallback;
  // A result that settled no allergen at all has checked nothing.
  if (keys.isEmpty) return true;
  return keys.any((a) => tagResult.getAllergenStatus(a) == TriState.unknown);
}

/// Displays the full tag result from the tagging system.
///
/// Shows allergen status, dietary status, and coverage information.
/// Can be filtered by user preferences to only show relevant allergens.
class TagResultDisplay extends StatelessWidget {
  /// The tag result to display.
  final TagResult tagResult;

  /// Allergen keys the user wants to track (considers only these).
  /// Null — and, here, an EMPTY set — mean every allergen the tagger settled.
  /// That differs from [CompactAllergenRow], where an empty set means silence,
  /// and a card that emitted a spacer above that silence is what BUT-1869
  /// fixed. On BOTH allergen paths UNKNOWN is dropped, so a tracked allergen is
  /// no guarantee of a badge.
  final Set<String>? userAllergenPrefs;

  /// Dietary keys the user wants to track.
  /// If null, shows all dietary statuses with non-unknown status.
  final Set<String>? userDietaryPrefs;

  /// Whether to show coverage information.
  final bool showCoverage;

  /// Callback when unknown ingredients are tapped.
  final VoidCallback? onUnknownIngredientsTap;

  /// Callback to trigger retagging when version is outdated.
  final VoidCallback? onRetagRequested;

  /// Use compact mode for space-constrained layouts.
  final bool compact;

  /// Whether the tagging system is in degraded mode (config validation failed).
  final bool isDegraded;

  const TagResultDisplay({
    super.key,
    required this.tagResult,
    this.userAllergenPrefs,
    this.userDietaryPrefs,
    this.showCoverage = true,
    this.onUnknownIngredientsTap,
    this.onRetagRequested,
    this.compact = false,
    this.isDegraded = false,
  });

  bool get _hasUnchecked => hasUncheckedAllergens(
    tagResult,
    userAllergenPrefs,
    fallback: const {},
    emptyMeansAll: true,
  );

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Degraded mode warning when tag config validation failed
        if (isDegraded) ...[
          _buildDegradedWarning(context),
          const SizedBox(height: AppDimensions.space8),
        ],

        // Version mismatch indicator (if outdated)
        if (tagResult.needsRetagging && !tagResult.hasFailed) ...[
          _buildRetagIndicator(context),
          const SizedBox(height: AppDimensions.space8),
        ],

        // All badges inline in a single Wrap
        _buildInlineBadges(context),
        if (!compact && _hasUnchecked) ...[
          const SizedBox(height: AppDimensions.space4),
          Text(
            context.l10n.allergenUncheckedDetail,
            style: AppTextStyles.bodySmall.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],

        // Draft ingredient warning
        if (tagResult.hasDraftIngredients) ...[
          const SizedBox(height: AppDimensions.space8),
          _buildDraftWarning(context),
        ],

        // Coverage section
        if (showCoverage) ...[
          const SizedBox(height: AppDimensions.space12),
          _buildCoverageSection(context),
        ],

        const SizedBox(height: AppDimensions.space12),
        const Padding(
          padding: EdgeInsets.only(top: AppDimensions.space4),
          child: AllergenDisclaimer(),
        ),
      ],
    );
  }

  /// Renders allergen and dietary badges inline without card wrapper.
  Widget _buildInlineBadges(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final allergens = _getAllergensToShow();
    final diets = _getDietaryToShow();

    final unchecked = _hasUnchecked;

    if (allergens.isEmpty && diets.isEmpty && !unchecked) {
      return Text(
        context.l10n.tagResultNoAllergens,
        style: AppTextStyles.bodySmall.copyWith(
          color: cs.onSurfaceVariant,
          fontStyle: FontStyle.italic,
        ),
      );
    }

    return Wrap(
      spacing: AppDimensions.space4,
      runSpacing: AppDimensions.space4,
      children: [
        if (unchecked) AllergenUncheckedMark(compact: compact),
        // Allergen badges
        ...allergens.map((allergen) {
          final status = tagResult.getAllergenStatus(allergen);
          final decision = tagResult.getAllergenDecision(allergen);
          return AllergenStatusBadge(
            allergen: allergen,
            status: status,
            compact: compact,
            onInfoTap: decision != null && !compact
                ? () => _showDecisionSheet(context, decision)
                : null,
          );
        }),
        // Dietary badges
        ...diets.map((diet) {
          final status = tagResult.getDietaryStatus(diet);
          final decision = tagResult.getDietaryDecision(diet);
          return DietaryStatusBadge(
            diet: diet,
            status: status,
            compact: compact,
            onInfoTap: decision != null && !compact
                ? () => _showDecisionSheet(context, decision)
                : null,
          );
        }),
      ],
    );
  }

  static void _showDecisionSheet(BuildContext context, TagDecision decision) {
    final cs = Theme.of(context).colorScheme;
    showButlerySheet<void>(
      context: context,
      builder: (context) => Padding(
        padding: const EdgeInsets.all(AppDimensions.space16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              context.l10n.tagDecisionWhyTitle,
              style: AppTextStyles.titleMedium,
            ),
            const SizedBox(height: AppDimensions.space12),
            Text(
              context.l10n.tagDecisionReason,
              style: AppTextStyles.labelMedium.copyWith(
                color: cs.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: AppDimensions.space4),
            Text(
              decision.reason,
              style: AppTextStyles.bodyMedium,
            ),
            if (decision.triggeringIngredients != null &&
                decision.triggeringIngredients!.isNotEmpty) ...[
              const SizedBox(height: AppDimensions.space12),
              Text(
                context.l10n.tagDecisionIngredients,
                style: AppTextStyles.labelMedium.copyWith(
                  color: cs.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: AppDimensions.space4),
              ...decision.triggeringIngredients!.map(
                (ingredient) => Padding(
                  padding: const EdgeInsetsDirectional.only(
                    start: AppDimensions.space12,
                    bottom: AppDimensions.space4,
                  ),
                  child: Row(
                    children: [
                      Text('·  ', style: AppTextStyles.bodyMedium),
                      Text(ingredient, style: AppTextStyles.bodyMedium),
                    ],
                  ),
                ),
              ),
            ],
            const SizedBox(height: AppDimensions.space12),
          ],
        ),
      ),
    );
  }

  Widget _buildRetagIndicator(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final warningColor = AppModeColors.textWarning(cs.brightness);
    return Container(
      padding: const EdgeInsets.all(AppDimensions.space8),
      decoration: BoxDecoration(
        color: context.modeColors.surfaceTintWarning,
        borderRadius: BorderRadius.circular(AppDimensions.radiusControl),
      ),
      child: Row(
        children: [
          ButleryIcon(
            ButleryIcons.refreshCw,
            color: warningColor,
            size: AppDimensions.iconSize18,
          ),
          const SizedBox(width: AppDimensions.space4),
          Expanded(
            child: Text(
              context.l10n.tagResultOutdated,
              style: AppTextStyles.bodySmall.copyWith(
                color: warningColor,
              ),
            ),
          ),
          if (onRetagRequested != null)
            ButleryTextButton(
              onPressed: onRetagRequested,
              label: context.l10n.commonUpdate,
              dense: true,
            ),
        ],
      ),
    );
  }

  Widget _buildDraftWarning(BuildContext context) {
    return InlineWarning(
      icon: ButleryIcons.info,
      color: context.modeColors.warning,
      textColor: AppModeColors.textWarning(Theme.of(context).brightness),
      text: context.l10n.ingredientDataUnverified,
    );
  }

  Widget _buildDegradedWarning(BuildContext context) {
    return InlineWarning(
      icon: ButleryIcons.triangleAlert,
      color: Theme.of(context).colorScheme.error,
      text: context.l10n.taggingDegradedWarning,
    );
  }

  Widget _buildCoverageSection(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final coveragePercent = (tagResult.coverage * 100).round();
    final hasUnknowns = tagResult.hasUnknowns;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            ButleryIcon(
              ButleryIcons.barChart,
              color: cs.onSurface,
              size: compact ? AppDimensions.iconSizeS : AppDimensions.iconSizeM,
            ),
            const SizedBox(width: AppDimensions.space4),
            Text(
              context.l10n.tagResultCoverage,
              style: compact
                  ? AppTextStyles.titleSmall
                  : AppTextStyles.titleMedium,
            ),
          ],
        ),
        const SizedBox(height: AppDimensions.space4),
        Row(
          children: [
            Expanded(
              // Coverage as the determinate plate line (Komponentark v1:305;
              // B-18). The percentage beside it keeps its status colour, so
              // colour is never the only signal; the line is not read out
              // on its own.
              child: ExcludeSemantics(
                child: PlateLine(value: tagResult.coverage),
              ),
            ),
            const SizedBox(width: AppDimensions.space8),
            Text(
              '$coveragePercent%',
              style: AppTextStyles.bodyBold.copyWith(
                color: _getCoverageColor(context),
              ),
            ),
          ],
        ),
        if (hasUnknowns) ...[
          const SizedBox(height: AppDimensions.space4),
          Semantics(
            label: context.l10n.tagResultUnknownIngredientsA11y(
              tagResult.unknownIngredients.length,
            ),
            button: onUnknownIngredientsTap != null,
            child: GestureDetector(
              onTap: onUnknownIngredientsTap,
              child: Row(
                children: [
                  ButleryIcon(
                    ButleryIcons.triangleAlert,
                    size: AppDimensions.iconSizeS,
                    color: context.modeColors.warning,
                  ),
                  const SizedBox(width: AppDimensions.space4),
                  Expanded(
                    child: Text(
                      context.l10n.tagResultUnknownIngredients(
                        tagResult.unknownIngredients.length,
                      ),
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppModeColors.textWarning(
                          Theme.of(context).brightness,
                        ),
                      ),
                    ),
                  ),
                  if (onUnknownIngredientsTap != null)
                    ButleryIcon(
                      ButleryIcons.chevronRight,
                      size: AppDimensions.iconSize18,
                      color: context.modeColors.warning,
                    ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }

  Color _getCoverageColor(BuildContext context) {
    // Mostly-full bar should read as "positive" visually, so we grade
    // generously: 80%+ is green, 40%+ amber, rust-red only for genuinely
    // incomplete coverage. Previously 80–99% showed as amber and anything
    // below 80% rendered rust-red — a nearly-full red bar misleads.
    if (tagResult.coverage >= 0.8) return context.modeColors.success;
    if (tagResult.coverage >= 0.4) {
      return AppModeColors.textWarning(Theme.of(context).brightness);
    }
    return Theme.of(context).colorScheme.error;
  }

  List<String> _getAllergensToShow() {
    if (userAllergenPrefs != null && userAllergenPrefs!.isNotEmpty) {
      // UI Redesign: Filter out unknown status even from user prefs
      return userAllergenPrefs!.where((allergen) {
        return tagResult.getAllergenStatus(allergen) != TriState.unknown;
      }).toList();
    }

    // Show allergens with known status (not unknown)
    return tagResult.allergenStatus.entries
        .where((e) => e.value != TriState.unknown)
        .map((e) => e.key)
        .toList();
  }

  List<String> _getDietaryToShow() {
    if (userDietaryPrefs != null && userDietaryPrefs!.isNotEmpty) {
      return userDietaryPrefs!.toList();
    }

    return _defaultDietaryOrder.where((diet) {
      final status = tagResult.getDietaryStatus(diet);
      return status == TriState.free;
    }).toList();
  }
}

/// Compact row of allergen badges for recipe cards.
///
/// Draws CONTAINS and FREE, in that order — CONTAINS first because a warning
/// outranks reassurance. UNKNOWN is never drawn (see [badgesFor]).
///
/// Limited to maxBadges to fit on cards.
class CompactAllergenRow extends StatelessWidget {
  final TagResult tagResult;

  /// Only consider these allergens; null falls back to a default four. A badge
  /// is drawn only where the status is CONTAINS or FREE, so a non-empty set is
  /// no guarantee that this row draws anything — see [badgesFor].
  final Set<String>? userPrefs;

  /// Maximum number of badges to show.
  final int maxBadges;

  const CompactAllergenRow({
    super.key,
    required this.tagResult,
    this.userPrefs,
    this.maxBadges = 4,
  });

  @override
  Widget build(BuildContext context) {
    final badges = _getBadgesToShow();

    if (badges.isEmpty) return const SizedBox.shrink();

    return Semantics(
      label: context.l10n.a11yAllergenStatusRow,
      container: true,
      child: Wrap(
        spacing: AppDimensions.space4,
        runSpacing: AppDimensions.space4,
        children: badges.take(maxBadges).map((allergen) {
          final status = tagResult.getAllergenStatus(allergen);
          return AllergenStatusBadge(
            allergen: allergen,
            status: status,
            compact: true,
            showLabel: false,
          );
        }).toList(),
      ),
    );
  }

  /// What this row WOULD draw, without building it.
  ///
  /// Public and static so a caller can gate its own spacer on real content
  /// rather than guessing from the preference set. `RecipeCard` needs that:
  /// this row collapses to `SizedBox.shrink()` when it has nothing to say, and
  /// a spacer emitted beside a collapsed row is a visible dead gap (BUT-1869).
  static List<String> badgesFor(TagResult tagResult, Set<String>? userPrefs) {
    final allergensToCheck = userPrefs ?? _defaultAllergens;

    // SAFETY: CONTAINS first — a warning outranks everything else here.
    final containsAllergens = allergensToCheck.where((a) {
      return tagResult.getAllergenStatus(a) == TriState.contains;
    }).toList();

    // Then FREE — the good news.
    final freeAllergens = allergensToCheck.where((a) {
      return tagResult.getAllergenStatus(a) == TriState.free;
    }).toList();

    // UNKNOWN is deliberately NOT shown. Malin's call, 2026-06-22, recorded in
    // docs/architecture/ACCEPTED_DEVIATIONS.md, and re-confirmed 2026-08-18 when
    // BUT-1780 made this row live on every recipe card for the first time:
    // a grey question mark reads as a verdict when it is the absence of one.
    //
    // An earlier version of this comment also claimed the uncertain badges
    // "pushed out the real answers". That was FALSE and is worth recording so
    // nobody re-derives it: UNKNOWN sorted LAST and `.take(maxBadges)` runs
    // after the concatenation, so an uncertain badge could never displace a
    // CONTAINS or a FREE. The real cost is the opposite shape — on an UNTAGGED
    // recipe the tagger settled NOTHING about, every default allergen is UNKNOWN,
    // so four grey question marks were not part of the row, they WERE the row.
    //
    // `TagResultDisplay._getAllergensToShow` (the detail view) filters them out
    // on its no-prefs fallback branch from day one, and on its user-prefs
    // branch since the UI redesign (668a68b25) — so "has always filtered them"
    // would be false, and a user WITH prefs did see UNKNOWN there until that
    // commit. This row was still the odd one out, invisibly, because until
    // BUT-1780 it had no live construction site at all.
    //
    // Do NOT "restore" unknown badges to make an older ordering test pass —
    // `compact_tag_rows_test.dart`'s CONTAINS-before-FREE-before-UNKNOWN case
    // was rewritten deliberately in the same change.
    return [...containsAllergens, ...freeAllergens];
  }

  /// Whether any allergen this row checks is still unsettled. The row never
  /// draws those; the caller adds the one "Ej kontrollerat" badge.
  static bool hasUnchecked(TagResult? tagResult, Set<String>? userPrefs) =>
      hasUncheckedAllergens(
        tagResult,
        userPrefs,
        fallback: _defaultAllergens,
        emptyMeansAll: false,
      );

  List<String> _getBadgesToShow() => badgesFor(tagResult, userPrefs);

  static const _defaultAllergens = {
    'gluten',
    'mjölk',
    'nötter',
    'ägg',
  };
}

/// Compact row of dietary badges for recipe cards.
///
/// Shows only FREE status badges for positive dietary attributes
/// (e.g., "Vegansk", "Vegetarisk"). Limited to maxBadges to fit on cards.
class CompactDietaryRow extends StatelessWidget {
  final TagResult tagResult;

  /// Only consider these diets. Null falls back to every configured dietary
  /// key, not to a pair of them — and in either case a badge is drawn only
  /// where the status is FREE (BUT-1895).
  final Set<String>? userPrefs;

  /// Maximum number of badges to show.
  final int maxBadges;

  const CompactDietaryRow({
    super.key,
    required this.tagResult,
    this.userPrefs,
    this.maxBadges = 2,
  });

  @override
  Widget build(BuildContext context) {
    final badges = _getBadgesToShow();

    if (badges.isEmpty) return const SizedBox.shrink();

    return Semantics(
      label: context.l10n.a11yDietaryStatusRow,
      container: true,
      child: Wrap(
        spacing: AppDimensions.space4,
        runSpacing: AppDimensions.space4,
        children: badges.take(maxBadges).map((diet) {
          return DietaryStatusBadge(
            diet: diet,
            status: TriState.free,
            compact: true,
            showLabel: true,
          );
        }).toList(),
      ),
    );
  }

  /// What this row WOULD draw, without building it. See
  /// [CompactAllergenRow.badgesFor] — same contract, same reason.
  ///
  /// This one matters MORE than its allergen twin: a non-empty preference set
  /// is no guarantee of content here, because only FREE diets are shown.
  static List<String> badgesFor(TagResult tagResult, Set<String>? userPrefs) {
    final dietsToCheck = userPrefs ?? _defaultDietaryOrder;

    // Only FREE — the badge means "this recipe IS vegan/vegetarian", so
    // CONTAINS and UNKNOWN have nothing to say.
    return dietsToCheck.where((diet) {
      return tagResult.getDietaryStatus(diet) == TriState.free;
    }).toList();
  }

  List<String> _getBadgesToShow() => badgesFor(tagResult, userPrefs);
}

class AllergenDisclaimer extends StatelessWidget {
  const AllergenDisclaimer({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ButleryIcon(
          ButleryIcons.info,
          size: AppDimensions.iconSize14,
          color: cs.onSurfaceVariant,
        ),
        const SizedBox(width: AppDimensions.space4),
        Expanded(
          child: Text(
            context.l10n.allergenDisclaimer,
            style: AppTextStyles.bodySmall.copyWith(
              color: cs.onSurfaceVariant,
            ),
          ),
        ),
      ],
    );
  }
}
