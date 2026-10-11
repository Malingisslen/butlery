import 'package:flutter/material.dart';

import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/viewmodels/nutrition_viewmodel.dart';
import 'package:butlery/views/recipe_detail/nutrition/nutrition_format.dart';

/// Kcal, protein, carbohydrates and fat under the recipe's title, with how
/// much of the recipe the numbers cover. Shown only when the user turned the
/// setting on; hidden while nothing could be counted.
class NutritionStrip extends StatelessWidget {
  const NutritionStrip({super.key, required this.viewModel});

  final NutritionViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    final summary = viewModel.summary;
    final values = viewModel.stripValues;
    if (summary == null || values == null || summary.countedLines == 0) {
      return const SizedBox.shrink();
    }
    final l10n = context.l10n;
    final cs = Theme.of(context).colorScheme;
    final basis = NutritionFormat.basisPhrase(context, viewModel.stripBasis);
    String grams(double v) => NutritionFormat.number(context, v);

    return Padding(
      padding: const EdgeInsets.only(top: AppDimensions.spacingSm),
      child: Column(
        key: const ValueKey('nutrition-strip'),
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: AppDimensions.spacingLg,
            runSpacing: AppDimensions.spacingSm,
            children: [
              _StripCell(
                value: NutritionFormat.number(context, values.kcal, kcal: true),
                label: l10n.nutritionStripKcal,
                semanticLabel: l10n.a11yNutritionStripKcal(
                  NutritionFormat.number(context, values.kcal, kcal: true),
                  basis,
                ),
              ),
              _StripCell(
                value: l10n.nutritionValueGrams(grams(values.protein)),
                label: l10n.nutritionStripProtein,
                semanticLabel: l10n.a11yNutritionStripGrams(
                  l10n.nutritionProtein,
                  grams(values.protein),
                  basis,
                ),
              ),
              _StripCell(
                value: l10n.nutritionValueGrams(grams(values.carbs)),
                label: l10n.nutritionStripCarbs,
                semanticLabel: l10n.a11yNutritionStripGrams(
                  l10n.nutritionCarbs,
                  grams(values.carbs),
                  basis,
                ),
              ),
              _StripCell(
                value: l10n.nutritionValueGrams(grams(values.fat)),
                label: l10n.nutritionStripFat,
                semanticLabel: l10n.a11yNutritionStripGrams(
                  l10n.nutritionFat,
                  grams(values.fat),
                  basis,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppDimensions.spacingXs),
          Text(
            l10n.nutritionCoverage(
              summary.countedLines,
              summary.countableLines,
            ),
            style: AppTextStyles.bodyMedium.copyWith(color: cs.onSurface),
          ),
        ],
      ),
    );
  }
}

class _StripCell extends StatelessWidget {
  const _StripCell({
    required this.value,
    required this.label,
    required this.semanticLabel,
  });

  final String value;
  final String label;
  final String semanticLabel;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Semantics(
      container: true,
      label: semanticLabel,
      excludeSemantics: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            value,
            style: AppTextStyles.titleBold.copyWith(color: cs.onSurface),
          ),
          Text(
            label,
            style: AppTextStyles.labelMedium.copyWith(
              color: cs.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
