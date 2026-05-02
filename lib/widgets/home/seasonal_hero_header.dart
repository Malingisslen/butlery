import 'package:flutter/material.dart';

import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/l10n/app_localizations.dart';
import 'package:butlery/models/seasonal/seasonal_month.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/widgets/common/illustrations/vegetable_illustration.dart';

/// Seasonal hero header for BUT-409.
///
/// Compact section-header-styled banner at the top of `mina_recept_view`.
/// Visual match with the existing shelf section-headers (rust left border,
/// Josefin Sans title, small trailing chevron) but with a sublabel row of
/// seasonal ingredients and a 28px illustration to the left.
///
/// Tap invokes [onTap]; the view wires it to
/// `RecipeQueryViewModel.applySeasonalFilter(...)`, filtering the recipe
/// grid to whatever matches any of the month's ingredients. The header
/// itself owns no state — show/hide decisions happen in the view.
class SeasonalHeroHeader extends StatelessWidget {
  const SeasonalHeroHeader({
    required this.month,
    required this.matchCount,
    required this.onTap,
    super.key,
  });

  /// The month being surfaced (provides illustration, month key, ingredients).
  final SeasonalMonth month;

  /// Number of user recipes that match this month — rendered as "N recept".
  final int matchCount;

  /// Callback fired on tap. The view decides what to do (applies a filter).
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final l10n = context.l10n;
    final monthName = _localizedMonthName(l10n, month.monthKey);
    final title = l10n.seasonalHeroTitle(monthName);
    final ingredientsLine = _formatIngredients(month.ingredients);

    return Semantics(
      button: true,
      label: '$title, $ingredientsLine, '
          '${l10n.seasonalHeroRecipeCount(matchCount)}',
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: AppDimensions.responsiveContentPadding(context),
          child: Container(
            padding: const EdgeInsets.fromLTRB(
              AppDimensions.spacingMd,
              AppDimensions.spacingSm,
              AppDimensions.spacingSm,
              AppDimensions.spacingSm,
            ),
            decoration: BoxDecoration(
              border: Border(
                left: BorderSide(color: cs.secondary, width: 3),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                VegetableIllustration(
                  type: month.vegetableType,
                  size: 28,
                ),
                const SizedBox(width: AppDimensions.spacingSm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        title,
                        style: AppTextStyles.sectionHeader.copyWith(
                          fontSize: 13,
                          letterSpacing: 1.5,
                          color: cs.onPrimaryContainer,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: AppDimensions.spacingXxs),
                      Text(
                        ingredientsLine,
                        style: AppTextStyles.bodySmall.copyWith(
                          color: cs.onSurfaceVariant,
                          fontSize: 12,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AppDimensions.spacingSm),
                Text(
                  l10n.seasonalHeroRecipeCount(matchCount),
                  style: AppTextStyles.bodySmall.copyWith(
                    color: cs.onSurfaceVariant,
                    fontSize: 11,
                  ),
                ),
                Icon(
                  Icons.chevron_right,
                  color: cs.onSurfaceVariant,
                  size: 18,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _formatIngredients(List<String> ingredients) =>
      ingredients.join(' · ');

  String _localizedMonthName(AppLocalizations l10n, String monthKey) {
    switch (monthKey) {
      case 'january':
        return l10n.seasonalMonthJanuary;
      case 'february':
        return l10n.seasonalMonthFebruary;
      case 'march':
        return l10n.seasonalMonthMarch;
      case 'april':
        return l10n.seasonalMonthApril;
      case 'may':
        return l10n.seasonalMonthMay;
      case 'june':
        return l10n.seasonalMonthJune;
      case 'july':
        return l10n.seasonalMonthJuly;
      case 'august':
        return l10n.seasonalMonthAugust;
      case 'september':
        return l10n.seasonalMonthSeptember;
      case 'october':
        return l10n.seasonalMonthOctober;
      case 'november':
        return l10n.seasonalMonthNovember;
      case 'december':
        return l10n.seasonalMonthDecember;
      default:
        return monthKey; // fail-soft: show the raw key rather than crash
    }
  }
}
