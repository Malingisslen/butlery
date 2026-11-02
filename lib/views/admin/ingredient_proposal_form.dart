import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/core/utils/captured_snackbars.dart';
import 'package:butlery/l10n/app_localizations.dart';
import 'package:butlery/models/tagging/ingredient_column.dart';
import 'package:butlery/services/tagging/ingredient_change_validator.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/viewmodels/admin/ingredient_proposal_form_viewmodel.dart';
import 'package:butlery/views/admin/ingredient_proposal_labels.dart';
import 'package:butlery/widgets/common/buttons/action_buttons.dart';
import 'package:butlery/widgets/common/dialogs/confirmation_dialogs.dart';
import 'package:butlery/widgets/common/dialogs/dialog_cancel_button.dart';
import 'package:butlery/widgets/common/input/styled_input.dart';
import 'package:butlery/widgets/common/menus/butlery_menu.dart';
import 'package:butlery/widgets/common/sheets/butlery_sheet.dart';
import 'package:butlery/widgets/common/state_widget.dart';

/// Opens the "Föreslå ändring" form for [ingredientId]. Resolves to true when
/// a proposal was saved.
Future<bool?> showIngredientProposalForm(
  BuildContext context, {
  required String ingredientId,
  IngredientProposalFormViewModel? viewModel,
}) => showButlerySheet<bool>(
  context: context,
  maxHeightFraction: 0.95,
  builder: (_) => IngredientProposalForm(
    ingredientId: ingredientId,
    viewModel: viewModel,
  ),
);

class IngredientProposalForm extends StatefulWidget {
  const IngredientProposalForm({
    required this.ingredientId,
    this.viewModel,
    super.key,
  });

  final String ingredientId;

  /// Injected by tests.
  final IngredientProposalFormViewModel? viewModel;

  @override
  State<IngredientProposalForm> createState() => _IngredientProposalFormState();
}

class _IngredientProposalFormState extends State<IngredientProposalForm> {
  late final IngredientProposalFormViewModel _vm;
  final _note = TextEditingController();
  final Map<IngredientColumn, TextEditingController> _controllers = {};
  bool _controllersBuilt = false;

  @override
  void initState() {
    super.initState();
    _vm =
        widget.viewModel ??
        IngredientProposalFormViewModel(ingredientId: widget.ingredientId);
    _vm.load();
  }

  @override
  void dispose() {
    _note.dispose();
    for (final c in _controllers.values) {
      c.dispose();
    }
    _vm.dispose();
    super.dispose();
  }

  static String _asText(IngredientColumn column, Object? value) =>
      switch (column.kind) {
        IngredientColumnKind.list => (value as List).join('\n'),
        IngredientColumnKind.number => value == null ? '' : '$value',
        IngredientColumnKind.text => value as String,
      };

  void _buildControllers() {
    if (_controllersBuilt || _vm.current == null) return;
    _controllersBuilt = true;
    for (final c in IngredientColumn.values) {
      if (c.kind == IngredientColumnKind.text && _isDropdown(c)) continue;
      _controllers[c] = TextEditingController(
        text: _asText(c, _vm.valueOf(c)),
      );
    }
  }

  static bool _isDropdown(IngredientColumn c) =>
      c == IngredientColumn.status ||
      c == IngredientColumn.priceCategory ||
      c == IngredientColumn.carbonFootprintCategory;

  void _onText(IngredientColumn column, String raw) {
    switch (column.kind) {
      case IngredientColumnKind.list:
        _vm.setValue(column, [
          for (final line in raw.split('\n'))
            if (line.trim().isNotEmpty) line.trim(),
        ]);
      case IngredientColumnKind.number:
        final t = raw.trim().replaceAll(',', '.');
        _vm.setValue(
          column,
          t.isEmpty ? null : (double.tryParse(t) ?? double.nan),
        );
      case IngredientColumnKind.text:
        _vm.setValue(column, raw);
    }
  }

  Future<void> _save() async {
    final l10n = context.l10n;
    final navigator = Navigator.of(context);
    final snackBars = CapturedSnackBars.capture(context);
    if (_vm.needsAllergenConfirmation) {
      final ok = await ConfirmationDialogs.showConfirmationDialog(
        context,
        title: l10n.adminProposalAllergenConfirmTitle,
        message: l10n.adminProposalAllergenConfirmMessage,
        confirmText: l10n.adminProposalAllergenConfirm,
        cancelText: l10n.commonCancel,
      );
      if (!ok) return;
    }
    if (!await _vm.save(_note.text)) return;
    snackBars.showConfirmation(l10n.adminProposalSaved);
    navigator.pop(true);
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<IngredientProposalFormViewModel>.value(
      value: _vm,
      child: Consumer<IngredientProposalFormViewModel>(
        builder: (context, vm, _) {
          final l10n = context.l10n;
          if (vm.current == null) {
            if (vm.error != null) {
              return StateWidget.error(
                message: vm.error!,
                actionLabel: l10n.adminRefresh,
                onAction: vm.load,
              );
            }
            return StateWidget.loading(message: l10n.adminIngredientsLoading);
          }
          _buildControllers();
          return _body(context, vm, l10n);
        },
      ),
    );
  }

  Widget _body(
    BuildContext context,
    IngredientProposalFormViewModel vm,
    AppLocalizations l10n,
  ) {
    final validation = vm.validation;
    final noteOk = vm.noteIsValid(_note.text);
    final canSave =
        vm.hasChanges && validation.isValid && noteOk && !vm.isLoading;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppDimensions.space16,
        0,
        AppDimensions.space16,
        AppDimensions.space16 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            l10n.adminProposalFormTitle(vm.current!.swedish),
            style: AppTextStyles.headlineSmall,
          ),
          const SizedBox(height: AppDimensions.space8),
          Flexible(
            child: ListView(
              shrinkWrap: true,
              children: [
                for (final column in IngredientColumn.values)
                  _field(context, vm, l10n, validation, column),
                const SizedBox(height: AppDimensions.space8),
                StyledInput.multiline(
                  key: const ValueKey('proposal-note'),
                  controller: _note,
                  label: l10n.adminProposalNoteLabel,
                  helperText: l10n.adminProposalNoteHelp,
                  errorText: noteOk
                      ? null
                      : l10n.adminProposalNoteTooLong(
                          IngredientProposalFormViewModel.maxNoteLength,
                        ),
                  semanticLabel: l10n.adminProposalNoteLabel,
                  minLines: 2,
                  maxLines: 4,
                  onChanged: (_) => setState(() {}),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppDimensions.space8),
          if (vm.error != null)
            Padding(
              padding: const EdgeInsets.only(bottom: AppDimensions.space8),
              child: Text(
                vm.error!,
                style: AppTextStyles.bodySmall.copyWith(
                  color: Theme.of(context).colorScheme.error,
                ),
              ),
            ),
          if (!vm.hasChanges)
            Text(
              l10n.adminProposalNothingChanged,
              style: AppTextStyles.bodySmall,
            ),
          ActionButtons.primaryButton(
            context,
            key: const ValueKey('proposal-save'),
            label: l10n.adminProposalSave,
            isLoading: vm.isLoading,
            onPressed: canSave ? _save : null,
          ),
          const DialogCancelButton(),
        ],
      ),
    );
  }

  Widget _field(
    BuildContext context,
    IngredientProposalFormViewModel vm,
    AppLocalizations l10n,
    IngredientChangeValidation validation,
    IngredientColumn column,
  ) {
    final label = ingredientColumnLabel(l10n, column);
    final changed = vm.isChanged(column);
    final issues = validation.issues[column];
    final error = issues == null || issues.isEmpty
        ? null
        : ingredientIssueText(l10n, issues.first);
    final shownLabel = changed
        ? '$label · ${l10n.adminProposalChangedMark}'
        : label;
    final Widget input = _isDropdown(column)
        ? _dropdown(vm, column, shownLabel, error, l10n)
        : StyledInput(
            key: ValueKey('field-${column.csvName}'),
            controller: _controllers[column],
            label: shownLabel,
            semanticLabel: shownLabel,
            errorText: error,
            helperText: column.kind == IngredientColumnKind.list
                ? l10n.adminProposalListHelp
                : null,
            minLines: column.kind == IngredientColumnKind.list ? 2 : 1,
            maxLines: column.kind == IngredientColumnKind.list ? 6 : 1,
            keyboardType: column.kind == IngredientColumnKind.list
                ? TextInputType.multiline
                : null,
            onChanged: (v) => _onText(column, v),
          );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppDimensions.space4),
      child: input,
    );
  }

  Widget _dropdown(
    IngredientProposalFormViewModel vm,
    IngredientColumn column,
    String label,
    String? error,
    AppLocalizations l10n,
  ) {
    final options = switch (column) {
      IngredientColumn.status => kProposableStatuses,
      IngredientColumn.priceCategory => ['', ...kProposablePriceCategories],
      _ => ['', ...kProposableCarbonCategories],
    };
    final value = vm.valueOf(column) as String;
    return ButleryDropdown<String>(
      key: ValueKey('field-${column.csvName}'),
      label: label,
      semanticLabel: label,
      errorText: error,
      value: value,
      onChanged: (v) => vm.setValue(column, v),
      options: [
        for (final o in options)
          ButleryDropdownOption<String>(
            value: o,
            label: o.isEmpty ? l10n.adminProposalEmptyValue : o,
          ),
        // A stored value outside the vocabulary stays visible, flagged.
        if (!options.contains(value))
          ButleryDropdownOption<String>(
            value: value,
            label: value,
            error: true,
          ),
      ],
    );
  }
}
