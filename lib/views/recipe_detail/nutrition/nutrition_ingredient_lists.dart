import 'package:flutter/material.dart';

import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/services/nutrition/nutrition_calculator.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/widgets/common/icons/butlery_expansion_chevron.dart';

/// Ingredients that could not be counted, each with the reason in words and,
/// when no food matched, a way to pick one.
class NutritionMissingList extends StatelessWidget {
  const NutritionMissingList({
    super.key,
    required this.lines,
    required this.onPick,
  });

  final List<NutritionLine> lines;
  final void Function(NutritionLine line) onPick;

  @override
  Widget build(BuildContext context) {
    if (lines.isEmpty) return const SizedBox.shrink();
    final l10n = context.l10n;
    final cs = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          header: true,
          child: Text(
            l10n.nutritionMissingHeading,
            style: AppTextStyles.titleBold.copyWith(color: cs.onSurface),
          ),
        ),
        for (final line in lines)
          Padding(
            padding: const EdgeInsets.only(top: AppDimensions.spacingXs),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    l10n.nutritionMissingLine(
                      line.name,
                      line.status == NutritionLineStatus.noMatch
                          ? l10n.nutritionReasonNoMatch
                          : l10n.nutritionReasonNoAmount,
                    ),
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: cs.onSurface,
                    ),
                  ),
                ),
                if (line.status == NutritionLineStatus.noMatch &&
                    line.storageKey != null)
                  Semantics(
                    label: l10n.a11yNutritionPickFoodFor(line.name),
                    button: true,
                    excludeSemantics: true,
                    onTap: () => onPick(line),
                    child: TextButton(
                      style: TextButton.styleFrom(
                        minimumSize: const Size(
                          AppDimensions.minTouchTarget,
                          AppDimensions.minTouchTarget,
                        ),
                      ),
                      onPressed: () => onPick(line),
                      child: Text(l10n.nutritionPickFood),
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}

/// The counted ingredients with the food each was matched to, and a way for
/// the household to change that food.
class NutritionIngredientsSection extends StatelessWidget {
  const NutritionIngredientsSection({
    super.key,
    required this.lines,
    required this.onChange,
  });

  final List<NutritionLine> lines;
  final void Function(NutritionLine line) onChange;

  @override
  Widget build(BuildContext context) {
    final counted = lines
        .where((l) => l.status == NutritionLineStatus.counted)
        .toList();
    if (counted.isEmpty) return const SizedBox.shrink();
    final l10n = context.l10n;
    final cs = Theme.of(context).colorScheme;
    return ExpansionTile(
      tilePadding: EdgeInsets.zero,
      title: Text(
        l10n.nutritionIngredientsHeading,
        style: AppTextStyles.titleBold.copyWith(color: cs.onSurface),
      ),
      trailing: const ButleryExpansionChevron(),
      shape: const Border(),
      collapsedShape: const Border(),
      children: [
        for (final line in counted)
          Row(
            key: ValueKey('nutrition-line-${line.storageKey ?? line.name}'),
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      line.name,
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: cs.onSurface,
                      ),
                    ),
                    Text(
                      l10n.nutritionCountedAs(line.food!.name),
                      style: AppTextStyles.bodySmall.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              if (line.storageKey != null)
                Semantics(
                  label: l10n.a11yNutritionChangeFoodFor(line.name),
                  button: true,
                  excludeSemantics: true,
                  onTap: () => onChange(line),
                  child: TextButton(
                    style: TextButton.styleFrom(
                      minimumSize: const Size(
                        AppDimensions.minTouchTarget,
                        AppDimensions.minTouchTarget,
                      ),
                    ),
                    onPressed: () => onChange(line),
                    child: Text(l10n.nutritionChange),
                  ),
                ),
            ],
          ),
      ],
    );
  }
}
