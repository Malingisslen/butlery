import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';

import 'package:butlery/core/extensions/default_value_extensions.dart';
import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/services/nutrition/nutrient_values.dart';
import 'package:butlery/services/nutrition/nutrition_calculator.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/viewmodels/nutrition_viewmodel.dart';
import 'package:butlery/views/recipe_detail/nutrition/nutrition_food_picker.dart';
import 'package:butlery/views/recipe_detail/nutrition/nutrition_format.dart';
import 'package:butlery/views/recipe_detail/nutrition/nutrition_ingredient_lists.dart';
import 'package:butlery/widgets/common/icons/butlery_glyph.dart';
import 'package:butlery/widgets/common/icons/butlery_icons.dart';
import 'package:butlery/widgets/common/state_widget.dart';

Future<void> showNutritionSheet(
  BuildContext context, {
  required NutritionViewModel viewModel,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => NutritionSheet(viewModel: viewModel),
  );
}

/// The full nutrition table for a recipe, per portion or for the whole recipe.
class NutritionSheet extends StatefulWidget {
  const NutritionSheet({super.key, required this.viewModel});

  final NutritionViewModel viewModel;

  @override
  State<NutritionSheet> createState() => _NutritionSheetState();
}

class _NutritionSheetState extends State<NutritionSheet> {
  bool _showSaved = false;

  NutritionViewModel get _vm => widget.viewModel;

  void _announceBasis(NutritionBasis basis) {
    final l10n = context.l10n;
    final message = basis == NutritionBasis.perPortion
        ? l10n.a11yNutritionBasisPerPortion
        : (_vm.summary?.basePortions ?? 0) > 0
        ? l10n.a11yNutritionBasisWhole(_vm.currentPortions)
        : l10n.a11yNutritionBasisWholeNoPortions;
    SemanticsService.sendAnnouncement(
      View.of(context),
      message,
      Directionality.of(context),
    );
  }

  Future<void> _pick(NutritionLine line) async {
    final saved = await showNutritionFoodPicker(
      context,
      viewModel: _vm,
      line: line,
    );
    if (!mounted || saved != true) return;
    setState(() => _showSaved = true);
    SemanticsService.sendAnnouncement(
      View.of(context),
      context.l10n.nutritionPickerSaved,
      Directionality.of(context),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 600),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsetsDirectional.only(
                start: AppDimensions.spacingMd,
                end: AppDimensions.spacingXs,
                top: AppDimensions.spacingSm,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Semantics(
                      header: true,
                      child: Text(
                        l10n.nutritionSheetTitle,
                        style: AppTextStyles.titleLarge.copyWith(
                          color: cs.onSurface,
                        ),
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: l10n.a11yNutritionClose,
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const ButleryIcon(ButleryIcons.x),
                  ),
                ],
              ),
            ),
            Flexible(
              child: ListenableBuilder(
                listenable: _vm,
                builder: (context, _) => _body(context),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _body(BuildContext context) {
    final l10n = context.l10n;
    final cs = Theme.of(context).colorScheme;
    final summary = _vm.summary;
    final values = _vm.values;
    if (summary == null || values == null) {
      return Padding(
        padding: const EdgeInsets.all(AppDimensions.spacingLg),
        child: _vm.hasError
            ? Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(_vm.error!, textAlign: TextAlign.center),
                  TextButton(
                    onPressed: _vm.load,
                    child: Text(l10n.commonRetry),
                  ),
                ],
              )
            : SizedBox(
                height: 200,
                child: StateWidget.loading(message: l10n.nutritionLoading),
              ),
      );
    }
    final basis = _vm.basis;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppDimensions.spacingMd),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SegmentedButton<NutritionBasis>(
            style: SegmentedButton.styleFrom(
              minimumSize: const Size(0, AppDimensions.minTouchTarget),
            ),
            segments: [
              ButtonSegment(
                value: NutritionBasis.perPortion,
                label: Text(l10n.nutritionBasisPerPortion),
                enabled: _vm.hasPerPortion,
              ),
              ButtonSegment(
                value: NutritionBasis.wholeRecipe,
                label: Text(l10n.nutritionBasisWhole),
              ),
            ],
            selected: {basis},
            showSelectedIcon: false,
            onSelectionChanged: (selection) {
              _vm.setBasis(selection.first);
              _announceBasis(selection.first);
            },
          ),
          if (!_vm.hasPerPortion)
            Padding(
              padding: const EdgeInsets.only(top: AppDimensions.spacingSm),
              child: Text(
                l10n.nutritionNoPortions,
                style: AppTextStyles.bodyMedium.copyWith(color: cs.onSurface),
              ),
            ),
          const SizedBox(height: AppDimensions.spacingSm),
          ..._tableRows(context, values),
          const SizedBox(height: AppDimensions.spacingSm),
          Text(
            l10n.nutritionCoverage(
              summary.countedLines,
              summary.countableLines,
            ),
            style: AppTextStyles.bodyMedium.copyWith(color: cs.onSurface),
          ),
          if (_showSaved)
            Padding(
              padding: const EdgeInsets.only(top: AppDimensions.spacingSm),
              child: Semantics(
                liveRegion: true,
                child: Text(
                  l10n.nutritionPickerSaved,
                  style: AppTextStyles.bodyMedium.copyWith(color: cs.onSurface),
                ),
              ),
            ),
          const SizedBox(height: AppDimensions.spacingMd),
          NutritionMissingList(lines: summary.missing, onPick: _pick),
          NutritionIngredientsSection(lines: summary.lines, onChange: _pick),
          const SizedBox(height: AppDimensions.spacingSm),
          Text(
            l10n.nutritionSource((_vm.table?.version).orEmpty()),
            style: AppTextStyles.bodySmall.copyWith(
              color: cs.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _tableRows(BuildContext context, NutrientValues v) {
    final l10n = context.l10n;
    String g(double x) => l10n.nutritionValueGrams(
      NutritionFormat.number(context, x),
    );
    String spoken(double x) => NutritionFormat.spokenGrams(context, x);
    return [
      _NutrientRow(
        label: l10n.nutritionEnergy,
        value: l10n.nutritionValueKcal(
          NutritionFormat.number(context, v.kcal, kcal: true),
        ),
        spoken: NutritionFormat.spokenKcal(context, v),
      ),
      _NutrientRow(
        label: l10n.nutritionFat,
        value: g(v.fat),
        spoken: spoken(v.fat),
      ),
      _NutrientRow(
        label: l10n.nutritionSaturatedFat,
        value: g(v.satFat),
        spoken: spoken(v.satFat),
        subItem: true,
      ),
      _NutrientRow(
        label: l10n.nutritionCarbs,
        value: g(v.carbs),
        spoken: spoken(v.carbs),
      ),
      _NutrientRow(
        label: l10n.nutritionSugars,
        value: g(v.sugar),
        spoken: spoken(v.sugar),
        subItem: true,
      ),
      _NutrientRow(
        label: l10n.nutritionFiber,
        value: g(v.fiber),
        spoken: spoken(v.fiber),
      ),
      _NutrientRow(
        label: l10n.nutritionProtein,
        value: g(v.protein),
        spoken: spoken(v.protein),
      ),
      _NutrientRow(
        label: l10n.nutritionSalt,
        value: g(v.salt),
        spoken: spoken(v.salt),
      ),
    ];
  }
}

class _NutrientRow extends StatelessWidget {
  const _NutrientRow({
    required this.label,
    required this.value,
    required this.spoken,
    this.subItem = false,
  });

  final String label;
  final String value;
  final String spoken;
  final bool subItem;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final style = subItem
        ? AppTextStyles.bodyMedium.copyWith(color: cs.onSurfaceVariant)
        : AppTextStyles.bodyMedium.copyWith(
            color: cs.onSurface,
            fontWeight: FontWeight.w600,
          );
    return Semantics(
      container: true,
      label: '$label $spoken',
      excludeSemantics: true,
      child: Container(
        padding: EdgeInsetsDirectional.only(
          start: subItem ? AppDimensions.spacingMd : 0,
          top: AppDimensions.spacingSm,
          bottom: AppDimensions.spacingSm,
        ),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: cs.outlineVariant)),
        ),
        child: Row(
          children: [
            Expanded(child: Text(label, style: style)),
            Text(value, style: style),
          ],
        ),
      ),
    );
  }
}
