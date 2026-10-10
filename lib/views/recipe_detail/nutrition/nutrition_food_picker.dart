import 'package:flutter/material.dart';

import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/services/nutrition/nutrition_calculator.dart';
import 'package:butlery/services/nutrition/nutrition_table.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/viewmodels/nutrition_viewmodel.dart';
import 'package:butlery/widgets/common/icons/butlery_glyph.dart';
import 'package:butlery/widgets/common/icons/butlery_icons.dart';

/// Opens the food picker for [line]; completes with true when the household's
/// choice was saved.
Future<bool?> showNutritionFoodPicker(
  BuildContext context, {
  required NutritionViewModel viewModel,
  required NutritionLine line,
}) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => NutritionFoodPicker(viewModel: viewModel, line: line),
  );
}

/// Search over Livsmedelsverket's foods to pick the one an ingredient means.
/// The pick is saved for the whole household.
class NutritionFoodPicker extends StatefulWidget {
  const NutritionFoodPicker({
    super.key,
    required this.viewModel,
    required this.line,
  });

  final NutritionViewModel viewModel;
  final NutritionLine line;

  @override
  State<NutritionFoodPicker> createState() => _NutritionFoodPickerState();
}

class _NutritionFoodPickerState extends State<NutritionFoodPicker> {
  final _controller = TextEditingController();

  NutritionViewModel get _vm => widget.viewModel;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  List<NutritionFood> _results(NutritionTable? table) =>
      table?.search(_controller.text) ?? const [];

  Future<void> _choose(int? foodId) async {
    final saved = foodId == null
        ? await _vm.clearFood(widget.line)
        : await _vm.pickFood(widget.line, foodId);
    if (!mounted || !saved) return;
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 600),
        child: Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.viewInsetsOf(context).bottom,
          ),
          child: ListenableBuilder(
            listenable: _vm,
            builder: (context, _) {
              final query = _controller.text.trim();
              final results = _results(_vm.table);
              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
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
                              l10n.nutritionPickerTitle(widget.line.name),
                              style: AppTextStyles.titleLarge.copyWith(
                                color: cs.onSurface,
                              ),
                            ),
                          ),
                        ),
                        IconButton(
                          tooltip: l10n.a11yNutritionPickerClose,
                          onPressed: () => Navigator.of(context).pop(),
                          icon: const ButleryIcon(ButleryIcons.x),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppDimensions.spacingMd,
                      vertical: AppDimensions.spacingSm,
                    ),
                    child: TextField(
                      controller: _controller,
                      autofocus: true,
                      textInputAction: TextInputAction.search,
                      onChanged: (_) => setState(() {}),
                      decoration: InputDecoration(
                        labelText: l10n.nutritionPickerSearchLabel,
                        helperText: l10n.nutritionPickerHint,
                        helperMaxLines: 2,
                      ),
                    ),
                  ),
                  if (_vm.saveError != null)
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppDimensions.spacingMd,
                      ),
                      child: Semantics(
                        liveRegion: true,
                        child: Text(
                          _vm.saveError!,
                          style: AppTextStyles.bodyMedium.copyWith(
                            color: cs.error,
                          ),
                        ),
                      ),
                    ),
                  if (widget.line.chosenByHousehold)
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppDimensions.spacingMd,
                      ),
                      child: TextButton(
                        style: TextButton.styleFrom(
                          minimumSize: const Size(
                            0,
                            AppDimensions.minTouchTarget,
                          ),
                        ),
                        onPressed: _vm.isSaving ? null : () => _choose(null),
                        child: Text(l10n.nutritionPickerClear),
                      ),
                    ),
                  if (query.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppDimensions.spacingMd,
                      ),
                      child: Semantics(
                        liveRegion: true,
                        child: Text(
                          results.isEmpty
                              ? l10n.nutritionPickerNoResults
                              : l10n.nutritionPickerResultCount(results.length),
                          style: AppTextStyles.bodyMedium.copyWith(
                            color: cs.onSurface,
                          ),
                        ),
                      ),
                    ),
                  Flexible(
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: results.length,
                      itemBuilder: (context, index) {
                        final food = results[index];
                        return ListTile(
                          key: ValueKey('nutrition-food-${food.id}'),
                          minTileHeight: AppDimensions.minTouchTarget,
                          title: Text(
                            food.name,
                            style: AppTextStyles.bodyMedium,
                          ),
                          enabled: !_vm.isSaving,
                          onTap: () => _choose(food.id),
                        );
                      },
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
