import 'package:flutter/material.dart';

import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/models/tagging/tag_decision.dart';
import 'package:butlery/models/tagging/tag_result.dart';
import 'package:butlery/models/tagging/tri_state.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/theme/butlery_colors_extension.dart';
import 'package:butlery/services/tagging/config/dietary_config.dart';
import 'package:butlery/widgets/common/feedback/inline_warning.dart';
import 'package:butlery/widgets/tagging/allergen_status_badge.dart';
import 'package:butlery/widgets/tagging/dietary_status_badge.dart';

/// Priority-ordered list of dietary keys used by both TagResultDisplay and CompactDietaryRow.
/// Derived from DietaryConfig to prevent key drift.
final _defaultDietaryOrder = DietaryConfig.allKeys;

/// Displays the full tag result from the tagging system.
///
/// Shows allergen status, dietary status, and coverage information.
/// Can be filtered by user preferences to only show relevant allergens.
class TagResultDisplay extends StatelessWidget {
  /// The tag result to display.
  final TagResult tagResult;

  /// Allergen keys the user wants to track (shows only these).
  /// If null, shows all allergens with non-unknown status.
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

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Degraded mode warning when tag config validation failed
        if (isDegraded) ...[
          _buildDegradedWarning(context),
          const SizedBox(height: AppDimensions.spacingM),
        ],

        // Version mismatch indicator (if outdated)
        if (tagResult.needsRetagging && !tagResult.hasFailed) ...[
          _buildRetagIndicator(context),
          const SizedBox(height: AppDimensions.spacingM),
        ],

        // All badges inline in a single Wrap
        _buildInlineBadges(context),

        // Draft ingredient warning
        if (tagResult.hasDraftIngredients) ...[
          const SizedBox(height: AppDimensions.spacingM),
          _buildDraftWarning(context),
        ],

        // Coverage section
        if (showCoverage) ...[
          const SizedBox(height: AppDimensions.spacingL),
          _buildCoverageSection(context),
        ],

        const SizedBox(height: AppDimensions.spacingL),
        const Padding(
          padding: EdgeInsets.only(top: AppDimensions.spacingS),
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

    if (allergens.isEmpty && diets.isEmpty) {
      return Text(
        context.l10n.tagResultNoAllergens,
        style: AppTextStyles.bodySmall.copyWith(
          color: cs.onSurfaceVariant,
          fontStyle: FontStyle.italic,
        ),
      );
    }

    return Wrap(
      spacing: AppDimensions.spacingS,
      runSpacing: AppDimensions.spacingS,
      children: [
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
    showModalBottomSheet(
      context: context,
      builder: (context) => Padding(
        padding: const EdgeInsets.all(AppDimensions.paddingL),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              context.l10n.tagDecisionWhyTitle,
              style: AppTextStyles.titleMedium,
            ),
            const SizedBox(height: AppDimensions.spacingL),
            Text(
              context.l10n.tagDecisionReason,
              style: AppTextStyles.labelMedium.copyWith(
                color: cs.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: AppDimensions.spacingXs),
            Text(
              decision.reason,
              style: AppTextStyles.bodyMedium,
            ),
            if (decision.triggeringIngredients != null &&
                decision.triggeringIngredients!.isNotEmpty) ...[
              const SizedBox(height: AppDimensions.spacingL),
              Text(
                context.l10n.tagDecisionIngredients,
                style: AppTextStyles.labelMedium.copyWith(
                  color: cs.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: AppDimensions.spacingXs),
              ...decision.triggeringIngredients!.map(
                (ingredient) => Padding(
                  padding: const EdgeInsets.only(
                    left: AppDimensions.paddingM,
                    bottom: AppDimensions.spacingXs,
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
            const SizedBox(height: AppDimensions.spacingL),
          ],
        ),
      ),
    );
  }

  Widget _buildRetagIndicator(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final warningColor = context.butleryColors.warning;
    return Container(
      padding: const EdgeInsets.all(AppDimensions.paddingS),
      decoration: BoxDecoration(
        color: warningColor.withValues(alpha: AppDimensions.opacityVeryLight),
        borderRadius: BorderRadius.circular(AppDimensions.borderRadiusS),
        border: Border.all(
            color: warningColor.withValues(
                alpha: AppDimensions.opacityMediumLight)),
      ),
      child: Row(
        children: [
          Icon(
            Icons.update,
            color: warningColor,
            size: AppDimensions.iconSize18,
          ),
          const SizedBox(width: AppDimensions.spacingS),
          Expanded(
            child: Text(
              context.l10n.tagResultOutdated,
              style: AppTextStyles.bodySmall.copyWith(
                color: warningColor,
              ),
            ),
          ),
          if (onRetagRequested != null)
            TextButton(
              onPressed: onRetagRequested,
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppDimensions.paddingS,
                ),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Text(
                context.l10n.commonUpdate,
                style: AppTextStyles.bodySmall.copyWith(
                  color: cs.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildDraftWarning(BuildContext context) {
    return InlineWarning(
      icon: Icons.info_outline,
      color: context.butleryColors.warning,
      text: context.l10n.ingredientDataUnverified,
    );
  }

  Widget _buildDegradedWarning(BuildContext context) {
    return InlineWarning(
      icon: Icons.warning_amber,
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
            Icon(
              Icons.analytics_outlined,
              color: cs.primary,
              size: compact
                  ? AppDimensions.iconSizeS
                  : AppDimensions.iconSizeAction,
            ),
            const SizedBox(width: AppDimensions.spacingS),
            Text(
              context.l10n.tagResultCoverage,
              style: compact
                  ? AppTextStyles.titleSmall
                  : AppTextStyles.titleMedium,
            ),
          ],
        ),
        const SizedBox(height: AppDimensions.spacingS),
        Row(
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius:
                    BorderRadius.circular(AppDimensions.borderRadiusS),
                child: LinearProgressIndicator(
                  value: tagResult.coverage,
                  backgroundColor: cs.outlineVariant,
                  color: _getCoverageColor(context),
                  minHeight: 8,
                ),
              ),
            ),
            const SizedBox(width: AppDimensions.spacingM),
            Text(
              '$coveragePercent%',
              style: AppTextStyles.bodyBold.copyWith(
                color: _getCoverageColor(context),
              ),
            ),
          ],
        ),
        if (hasUnknowns) ...[
          const SizedBox(height: AppDimensions.spacingS),
          Semantics(
            label: context.l10n.tagResultUnknownIngredientsA11y(
                tagResult.unknownIngredients.length),
            button: onUnknownIngredientsTap != null,
            child: GestureDetector(
              onTap: onUnknownIngredientsTap,
              child: Row(
                children: [
                  Icon(
                    Icons.warning_amber_rounded,
                    size: AppDimensions.iconSizeS,
                    color: context.butleryColors.warning,
                  ),
                  const SizedBox(width: AppDimensions.spacingXs),
                  Expanded(
                    child: Text(
                      context.l10n.tagResultUnknownIngredients(
                          tagResult.unknownIngredients.length),
                      style: AppTextStyles.bodySmall.copyWith(
                        color: context.butleryColors.warning,
                      ),
                    ),
                  ),
                  if (onUnknownIngredientsTap != null)
                    Icon(
                      Icons.chevron_right,
                      size: AppDimensions.iconSize18,
                      color: context.butleryColors.warning,
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
    if (tagResult.coverage >= 0.8) return context.butleryColors.success;
    if (tagResult.coverage >= 0.4) return context.butleryColors.warning;
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
/// Shows only FREE status badges for user's preferred allergens.
/// Limited to maxBadges to fit on cards.
class CompactAllergenRow extends StatelessWidget {
  final TagResult tagResult;

  /// Only show badges for these allergens.
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
        spacing: AppDimensions.spacingXs,
        runSpacing: AppDimensions.spacingXs,
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

  List<String> _getBadgesToShow() {
    final allergensToCheck = userPrefs ?? _defaultAllergens;

    // SAFETY: Show CONTAINS first (warnings are most important)
    final containsAllergens = allergensToCheck.where((a) {
      return tagResult.getAllergenStatus(a) == TriState.contains;
    }).toList();

    // Then FREE status (good news for the user)
    final freeAllergens = allergensToCheck.where((a) {
      return tagResult.getAllergenStatus(a) == TriState.free;
    }).toList();

    // Then UNKNOWN if space allows
    final unknownAllergens = allergensToCheck.where((a) {
      return tagResult.getAllergenStatus(a) == TriState.unknown;
    }).toList();

    // Priority: warnings first, then positive, then uncertain
    return [...containsAllergens, ...freeAllergens, ...unknownAllergens];
  }

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

  /// Only show badges for these diets. If null, shows vegetarisk/vegansk.
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
        spacing: AppDimensions.spacingXs,
        runSpacing: AppDimensions.spacingXs,
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

  List<String> _getBadgesToShow() {
    final dietsToCheck = userPrefs ?? _defaultDietaryOrder;

    // Only show FREE status (recipe IS vegan/vegetarian/etc)
    return dietsToCheck.where((diet) {
      return tagResult.getDietaryStatus(diet) == TriState.free;
    }).toList();
  }
}

class AllergenDisclaimer extends StatelessWidget {
  const AllergenDisclaimer({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          Icons.info_outline,
          size: AppDimensions.iconSize14,
          color: cs.onSurfaceVariant,
        ),
        const SizedBox(width: AppDimensions.spacingXs),
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
