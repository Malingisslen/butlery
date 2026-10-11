import 'package:flutter/material.dart';

import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/l10n/app_localizations.dart';
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
    required this.onEnterAmount,
  });

  final List<NutritionLine> lines;
  final void Function(NutritionLine line) onPick;
  final void Function(NutritionLine line) onEnterAmount;

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
                if (line.status == NutritionLineStatus.noAmount &&
                    line.storageKey != null &&
                    line.food != null)
                  Semantics(
                    label: l10n.a11yNutritionEnterAmountFor(line.name),
                    button: true,
                    excludeSemantics: true,
                    onTap: () => onEnterAmount(line),
                    child: TextButton(
                      style: TextButton.styleFrom(
                        minimumSize: const Size(
                          AppDimensions.minTouchTarget,
                          AppDimensions.minTouchTarget,
                        ),
                      ),
                      onPressed: () => onEnterAmount(line),
                      child: Text(l10n.nutritionEnterAmount),
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
/// the household to change that food. An estimated line is marked as such and
/// offers a change of its amount instead.
class NutritionIngredientsSection extends StatelessWidget {
  const NutritionIngredientsSection({
    super.key,
    required this.lines,
    required this.onChange,
    required this.onChangeAmount,
  });

  final List<NutritionLine> lines;
  final void Function(NutritionLine line) onChange;
  final void Function(NutritionLine line) onChangeAmount;

  @override
  Widget build(BuildContext context) {
    final counted = lines.where((l) => l.isCounted).toList();
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
                      _countedAs(l10n, line),
                      style: AppTextStyles.bodySmall.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                    if (line.status == NutritionLineStatus.estimated)
                      Semantics(
                        label: l10n.a11yNutritionEstimatedBadge,
                        excludeSemantics: true,
                        child: Text(
                          l10n.nutritionEstimatedBadge,
                          style: AppTextStyles.labelLarge.copyWith(
                            color: cs.onSurface,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              if (line.storageKey != null)
                _ChangeButton(
                  semanticLabel: line.status == NutritionLineStatus.estimated
                      ? l10n.a11yNutritionChangeAmountFor(line.name)
                      : l10n.a11yNutritionChangeFoodFor(line.name),
                  onPressed: () => line.status == NutritionLineStatus.estimated
                      ? onChangeAmount(line)
                      : onChange(line),
                ),
            ],
          ),
      ],
    );
  }
}

String _countedAs(AppLocalizations l10n, NutritionLine line) {
  final own =
      line.amountSource == NutritionAmountSource.household ||
      line.amountSource == NutritionAmountSource.thisRecipe;
  return own
      ? l10n.nutritionCountedAsOwn(line.food!.name)
      : l10n.nutritionCountedAs(line.food!.name);
}

class _ChangeButton extends StatelessWidget {
  const _ChangeButton({required this.semanticLabel, required this.onPressed});

  final String semanticLabel;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: semanticLabel,
      button: true,
      excludeSemantics: true,
      onTap: onPressed,
      child: TextButton(
        style: TextButton.styleFrom(
          minimumSize: const Size(
            AppDimensions.minTouchTarget,
            AppDimensions.minTouchTarget,
          ),
        ),
        onPressed: onPressed,
        child: Text(context.l10n.nutritionChange),
      ),
    );
  }
}
