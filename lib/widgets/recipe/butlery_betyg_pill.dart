import 'package:flutter/material.dart';
import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/repositories/interfaces/ratings_repository.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/theme/butlery_colors_extension.dart';

/// Swedish one-decimal rating with a decimal comma (4.2 -> "4,2"). Shared by
/// all three rating pills (community/pooled, family, household) so the format
/// can't drift between them. Deliberately NOT TextFormatting.formatFractional:
/// the pills always keep one decimal (4,0), whereas formatFractional drops it
/// for whole numbers.
String formatRatingComma(double v) => v.toStringAsFixed(1).replaceAll('.', ',');

/// Green filled "Butlery-betyget" community pill: `★ X,X · N betyg`.
///
/// The single source for the pooled community score pill — shown on the recipe
/// card (replacing the per-copy 'alla' pill once the pool clears the display
/// floor, decision 8/9) and on the recipe detail page's labelled pooled section.
/// Always carries the vote count; warm star on brand green (BUT-1519 dedupe).
class ButleryBetygPill extends StatelessWidget {
  final PooledStats stats;

  const ButleryBetygPill({super.key, required this.stats});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    // Callers only render the pill for floor-clearing pools, where average is
    // non-null. Assert to keep that invariant loud in dev (the recipe-detail
    // path used to fail-fast here); the 0-fallback keeps prod safe if it ever
    // slips past the guard.
    assert(
      stats.average != null,
      'ButleryBetygPill needs a floor-clearing pool (non-null average)',
    );
    final avg = formatRatingComma(stats.average ?? 0);
    return Semantics(
      label: context.l10n.a11yButleryBetygPill(avg, stats.count),
      child: Container(
        padding: AppDimensions.paddingSymmetric6x2,
        decoration: BoxDecoration(
          color: cs.primary,
          borderRadius: BorderRadius.zero,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Decorative star uses the app-wide starGold token (as every other
            // star pill does) — NOT the warning/status colour.
            Icon(Icons.star, size: 12, color: context.butleryColors.starGold),
            const SizedBox(width: 3),
            Text(
              '$avg · ${context.l10n.butleryBetygCount(stats.count)}',
              style: AppTextStyles.badge.copyWith(
                color: cs.onPrimary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
