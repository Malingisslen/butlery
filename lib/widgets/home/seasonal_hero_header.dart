import 'package:flutter/material.dart';

import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/l10n/app_localizations.dart';
import 'package:butlery/models/seasonal/seasonal_month.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/widgets/common/illustrations/vegetable_illustration.dart';

/// Seasonal hero header for BUT-409.
///
/// Compact banner above the shelves: a small illustration, the month's
/// seasonal ingredients and how many of the user's recipes use them. It is
/// information only; nothing in the library filters by season, so it must not
/// look pressable. Show/hide decisions happen in the view.
class SeasonalHeroHeader extends StatelessWidget {
  const SeasonalHeroHeader({
    required this.month,
    required this.matchCount,
    super.key,
  });

  /// The month being surfaced (provides illustration, month key, ingredients).
  final SeasonalMonth month;

  /// Number of user recipes that match this month — rendered as "N recept".
  final int matchCount;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final l10n = context.l10n;
    final monthName = _localizedMonthName(l10n, month.monthKey);
    final title = l10n.seasonalHeroTitle(monthName);
    final ingredientsLine = _formatIngredients(month.ingredients);

    return MergeSemantics(
      child: Padding(
        padding: AppDimensions.responsiveContentPadding(context),
        child: Container(
          padding: const EdgeInsets.fromLTRB(
            AppDimensions.space16,
            AppDimensions.space8,
            AppDimensions.space8,
            AppDimensions.space8,
          ),
          decoration: BoxDecoration(
            border: Border(
              left: BorderSide(color: cs.outlineVariant, width: 3),
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              VegetableIllustration(type: month.vegetableType, size: 28),
              const SizedBox(width: AppDimensions.space8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      style: AppTextStyles.bodySmall.copyWith(
                        letterSpacing: 1.5,
                        color: cs.onPrimaryContainer,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: AppDimensions.space4),
                    Text(
                      ingredientsLine,
                      style: AppTextStyles.captionBase.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppDimensions.space8),
              Text(
                l10n.seasonalHeroRecipeCount(matchCount),
                style: AppTextStyles.labelSmall.copyWith(
                  color: cs.onSurfaceVariant,
                ),
              ),
            ],
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
