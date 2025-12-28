import 'package:flutter/material.dart';

import 'package:butlery/models/tagging/tag_result.dart';
import 'package:butlery/models/tagging/tri_state.dart';
import 'package:butlery/theme/app_colors.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/widgets/tagging/allergen_status_badge.dart';
import 'package:butlery/widgets/tagging/dietary_status_badge.dart';

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

  const TagResultDisplay({
    super.key,
    required this.tagResult,
    this.userAllergenPrefs,
    this.userDietaryPrefs,
    this.showCoverage = true,
    this.onUnknownIngredientsTap,
    this.onRetagRequested,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(
          compact ? AppDimensions.paddingM : AppDimensions.paddingL),
      decoration: BoxDecoration(
        color: AppColors.cardWhite,
        borderRadius: BorderRadius.circular(AppDimensions.borderRadiusL),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Version mismatch indicator (if outdated)
          if (tagResult.needsRetagging && !tagResult.hasFailed) ...[
            _buildRetagIndicator(context),
            const SizedBox(height: AppDimensions.spacingM),
          ],

          // Allergens section
          _buildAllergenSection(context),

          // Dietary section
          if (_hasDietaryToShow()) ...[
            const SizedBox(height: AppDimensions.spacingL),
            _buildDietarySection(context),
          ],

          // Coverage section
          if (showCoverage) ...[
            const SizedBox(height: AppDimensions.spacingL),
            _buildCoverageSection(context),
          ],
        ],
      ),
    );
  }

  Widget _buildRetagIndicator(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppDimensions.paddingS),
      decoration: BoxDecoration(
        color: AppColors.warning.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppDimensions.borderRadiusS),
        border: Border.all(color: AppColors.warning.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.update,
            color: AppColors.warning,
            size: 18,
          ),
          const SizedBox(width: AppDimensions.spacingS),
          Expanded(
            child: Text(
              'Taggarna kan uppdateras',
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.warning,
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
                'Uppdatera',
                style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.primaryBlue,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildAllergenSection(BuildContext context) {
    final allergens = _getAllergensToShow();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.shield_outlined,
              color: AppColors.primaryBlue,
              size: compact
                  ? AppDimensions.iconSizeS
                  : AppDimensions.iconSizeAction,
            ),
            const SizedBox(width: AppDimensions.spacingS),
            Text(
              'Allergener',
              style: compact
                  ? AppTextStyles.titleSmall
                  : AppTextStyles.titleMedium,
            ),
          ],
        ),
        const SizedBox(height: AppDimensions.spacingM),
        if (allergens.isEmpty)
          Text(
            'Inga allergener att visa',
            style: AppTextStyles.bodySmall.copyWith(
              color: AppColors.textMedium,
              fontStyle: FontStyle.italic,
            ),
          )
        else
          Wrap(
            spacing: AppDimensions.spacingS,
            runSpacing: AppDimensions.spacingS,
            children: allergens.map((allergen) {
              final status = tagResult.getAllergenStatus(allergen);
              return AllergenStatusBadge(
                allergen: allergen,
                status: status,
                compact: compact,
              );
            }).toList(),
          ),
      ],
    );
  }

  Widget _buildDietarySection(BuildContext context) {
    final diets = _getDietaryToShow();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.restaurant_outlined,
              color: AppColors.primaryBlue,
              size: compact
                  ? AppDimensions.iconSizeS
                  : AppDimensions.iconSizeAction,
            ),
            const SizedBox(width: AppDimensions.spacingS),
            Text(
              'Specialkost',
              style: compact
                  ? AppTextStyles.titleSmall
                  : AppTextStyles.titleMedium,
            ),
          ],
        ),
        const SizedBox(height: AppDimensions.spacingM),
        Wrap(
          spacing: AppDimensions.spacingS,
          runSpacing: AppDimensions.spacingS,
          children: diets.map((diet) {
            final status = tagResult.getDietaryStatus(diet);
            return DietaryStatusBadge(
              diet: diet,
              status: status,
              compact: compact,
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildCoverageSection(BuildContext context) {
    final coveragePercent = (tagResult.coverage * 100).round();
    final hasUnknowns = tagResult.hasUnknowns;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.analytics_outlined,
              color: AppColors.primaryBlue,
              size: compact
                  ? AppDimensions.iconSizeS
                  : AppDimensions.iconSizeAction,
            ),
            const SizedBox(width: AppDimensions.spacingS),
            Text(
              'Täckning',
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
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: tagResult.coverage,
                  backgroundColor: AppColors.divider,
                  color: _getCoverageColor(),
                  minHeight: 8,
                ),
              ),
            ),
            const SizedBox(width: AppDimensions.spacingM),
            Text(
              '$coveragePercent%',
              style: AppTextStyles.bodyMedium.copyWith(
                fontWeight: FontWeight.w600,
                color: _getCoverageColor(),
              ),
            ),
          ],
        ),
        if (hasUnknowns) ...[
          const SizedBox(height: AppDimensions.spacingS),
          GestureDetector(
            onTap: onUnknownIngredientsTap,
            child: Row(
              children: [
                const Icon(
                  Icons.warning_amber_rounded,
                  size: 16,
                  color: AppColors.warning,
                ),
                const SizedBox(width: AppDimensions.spacingXs),
                Expanded(
                  child: Text(
                    '${tagResult.unknownIngredients.length} okända ingredienser',
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.warning,
                    ),
                  ),
                ),
                if (onUnknownIngredientsTap != null)
                  const Icon(
                    Icons.chevron_right,
                    size: 18,
                    color: AppColors.warning,
                  ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Color _getCoverageColor() {
    if (tagResult.coverage >= 1.0) return AppColors.success;
    if (tagResult.coverage >= 0.8) return AppColors.warning;
    return AppColors.error;
  }

  List<String> _getAllergensToShow() {
    if (userAllergenPrefs != null && userAllergenPrefs!.isNotEmpty) {
      return userAllergenPrefs!.toList();
    }

    // Show allergens with known status (not unknown)
    return tagResult.allergenStatus.entries
        .where((e) => e.value != TriState.unknown)
        .map((e) => e.key)
        .toList();
  }

  bool _hasDietaryToShow() {
    return _getDietaryToShow().isNotEmpty;
  }

  List<String> _getDietaryToShow() {
    if (userDietaryPrefs != null && userDietaryPrefs!.isNotEmpty) {
      return userDietaryPrefs!.toList();
    }

    // Default: show all dietary statuses that are FREE
    // Priority order: most common first
    const priorityOrder = [
      'vegetarisk',
      'vegansk',
      'pescetarian',
      'barnvänlig',
      'graviditetssäker',
      'halalanpassad',
      'kosheranpassad',
      'nötkötsfri',
    ];

    return priorityOrder.where((diet) {
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

    return Wrap(
      spacing: 4,
      runSpacing: 4,
      children: badges.take(maxBadges).map((allergen) {
        final status = tagResult.getAllergenStatus(allergen);
        return AllergenStatusBadge(
          allergen: allergen,
          status: status,
          compact: true,
          showLabel: false,
        );
      }).toList(),
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

    return Wrap(
      spacing: 4,
      runSpacing: 4,
      children: badges.take(maxBadges).map((diet) {
        return DietaryStatusBadge(
          diet: diet,
          status: TriState.free,
          compact: true,
          showLabel: true,
        );
      }).toList(),
    );
  }

  List<String> _getBadgesToShow() {
    final dietsToCheck = userPrefs ?? _defaultDiets;

    // Only show FREE status (recipe IS vegan/vegetarian/etc)
    return dietsToCheck.where((diet) {
      return tagResult.getDietaryStatus(diet) == TriState.free;
    }).toList();
  }

  // Priority order: most common first, all diets checked by default
  static const _defaultDiets = [
    'vegetarisk',
    'vegansk',
    'pescetarian',
    'barnvänlig',
    'graviditetssäker',
    'halalanpassad',
    'kosheranpassad',
    'nötkötsfri',
  ];
}
