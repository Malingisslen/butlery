import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/core/responsive/breakpoints.dart';
import 'package:butlery/models/nutrition/nutrition_amount_choice.dart';
import 'package:butlery/services/nutrition/nutrition_calculator.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/viewmodels/nutrition_viewmodel.dart';
import 'package:butlery/widgets/common/buttons/action_buttons.dart';
import 'package:butlery/widgets/common/dialogs/butlery_dialog.dart';
import 'package:butlery/widgets/common/chips/butlery_action_chip.dart';
import 'package:butlery/widgets/common/sheets/butlery_sheet.dart';
import 'package:butlery/widgets/common/sheets/butlery_sheet_header.dart';
import 'package:butlery/widgets/styled/styled_input.dart';

/// Opens the amount sheet for [line]; completes with true when the
/// household's amount was saved, false when it was removed, null when the
/// sheet was dismissed.
Future<bool?> showNutritionAmountSheet(
  BuildContext context, {
  required NutritionViewModel viewModel,
  required NutritionLine line,
}) {
  viewModel.clearSaveError();
  return showButlerySheet<bool>(
    context: context,
    builder: (_) => NutritionAmountSheet(viewModel: viewModel, line: line),
  );
}

/// Enter how much of an ingredient the recipe uses. Saving asks whether the
/// amount is for this recipe only or for every recipe.
class NutritionAmountSheet extends StatefulWidget {
  const NutritionAmountSheet({
    super.key,
    required this.viewModel,
    required this.line,
  });

  final NutritionViewModel viewModel;
  final NutritionLine line;

  @override
  State<NutritionAmountSheet> createState() => _NutritionAmountSheetState();
}

class _NutritionAmountSheetState extends State<NutritionAmountSheet> {
  late final TextEditingController _controller;
  late String _unit;
  bool _invalid = false;

  NutritionViewModel get _vm => widget.viewModel;
  NutritionLine get _line => widget.line;

  bool get _hasOwnAmount =>
      _line.amountSource == NutritionAmountSource.household ||
      _line.amountSource == NutritionAmountSource.thisRecipe;

  @override
  void initState() {
    super.initState();
    final amount = _line.amount;
    _controller = TextEditingController(
      text: amount == null ? '' : _formatAmount(amount),
    );
    final units = _line.enterableUnits;
    _unit = units.contains(_line.amountUnit) ? _line.amountUnit! : units.first;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  // Up to two decimals, no trailing zeros, decimal comma as typed in Swedish.
  static String _formatAmount(double value) {
    final text = value
        .toStringAsFixed(2)
        .replaceFirst(RegExp(r'0+$'), '')
        .replaceFirst(RegExp(r'\.$'), '');
    return text.replaceAll('.', ',');
  }

  double? _parse() =>
      double.tryParse(_controller.text.trim().replaceAll(',', '.'));

  Future<void> _save() async {
    final amount = _parse();
    final valid =
        amount != null &&
        NutritionAmountChoice(amount: amount, unit: _unit).isValid;
    if (!valid) {
      setState(() => _invalid = true);
      return;
    }
    setState(() => _invalid = false);
    final thisRecipeOnly = await _askScope(amount);
    if (thisRecipeOnly == null || !mounted) return;
    final saved = await _vm.saveAmount(
      _line,
      amount,
      _unit,
      thisRecipeOnly: thisRecipeOnly,
    );
    if (!mounted || !saved) return;
    Navigator.of(context).pop(true);
  }

  Future<void> _remove() async {
    final removed = await _vm.clearAmount(_line);
    if (!mounted || !removed) return;
    Navigator.of(context).pop(false);
  }

  /// True for this recipe only, false for every recipe, null when dismissed.
  Future<bool?> _askScope(double amount) {
    final l10n = context.l10n;
    return showButleryDialog<bool>(
      context: context,
      builder: (dialogContext) => ButleryDialog(
        title: l10n.nutritionAmountScopeTitle(
          '${_formatAmount(amount)} $_unit',
          _line.name,
        ),
        message: l10n.nutritionAmountScopeBody(_line.name),
        actions: [
          ActionButtons.primaryButton(
            dialogContext,
            label: l10n.nutritionAmountScopeRecipe,
            onPressed: () => Navigator.of(dialogContext).pop(true),
          ),
          ActionButtons.outlinedButton(
            dialogContext,
            label: l10n.nutritionAmountScopeAll,
            onPressed: () => Navigator.of(dialogContext).pop(false),
          ),
          ActionButtons.textButton(
            dialogContext,
            label: l10n.commonCancel,
            onPressed: () => Navigator.of(dialogContext).pop(),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: Breakpoints.mobileLarge),
        child: Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.viewInsetsOf(context).bottom,
          ),
          child: ListenableBuilder(
            listenable: _vm,
            builder: (context, _) => SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ButlerySheetHeader(
                    title: l10n.nutritionAmountSheetTitle(_line.name),
                    closeLabel: l10n.a11yNutritionPickerClose,
                  ),
                  Padding(
                    padding: const EdgeInsets.all(AppDimensions.space16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        StyledInput(
                          label: l10n.nutritionAmountFieldLabel,
                          controller: _controller,
                          autofocus: true,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(
                              RegExp(r'[0-9.,]'),
                            ),
                          ],
                          onChanged: (_) {
                            if (_invalid) setState(() => _invalid = false);
                          },
                          errorText: _invalid
                              ? l10n.nutritionAmountInvalid
                              : null,
                        ),
                        const SizedBox(height: AppDimensions.space8),
                        Semantics(
                          container: true,
                          label: l10n.nutritionAmountUnitLabel,
                          child: Wrap(
                            spacing: AppDimensions.space4,
                            children: [
                              for (final unit in _line.enterableUnits)
                                ButleryChoiceChip(
                                  key: ValueKey('nutrition-unit-$unit'),
                                  label: unit,
                                  selected: unit == _unit,
                                  onSelected: (_) =>
                                      setState(() => _unit = unit),
                                ),
                            ],
                          ),
                        ),
                        if (_vm.saveError != null)
                          Padding(
                            padding: const EdgeInsets.only(
                              top: AppDimensions.space8,
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
                        const SizedBox(height: AppDimensions.space16),
                        ActionButtons.primaryButton(
                          context,
                          label: l10n.commonSave,
                          isExpanded: true,
                          onPressed: _vm.isSaving ? null : _save,
                        ),
                        if (_hasOwnAmount)
                          ActionButtons.textButton(
                            context,
                            label: l10n.nutritionAmountRemove,
                            isExpanded: true,
                            onPressed: _vm.isSaving ? null : _remove,
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
