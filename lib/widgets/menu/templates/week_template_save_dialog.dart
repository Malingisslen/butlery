import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/core/utils/snackbar_utils.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/theme/field_text_style.dart';
import 'package:butlery/viewmodels/menu/week_template_viewmodel.dart';
import 'package:butlery/viewmodels/menu/weekly_menu_plan_viewmodel.dart';
import 'package:butlery/widgets/common/dialogs/butlery_dialog.dart';
import 'package:butlery/widgets/common/dialogs/dialog_cancel_button.dart';
import 'package:butlery/widgets/common/input/field_error_line.dart';
import 'package:butlery/widgets/common/input/labeled_field.dart';
import 'package:flutter/material.dart';

/// BUT-2522: "Spara som mall" for the week the calendar shows. Part 1 saves
/// the whole week; the choice of days or meals comes with part 2.
Future<void> showSaveWeekTemplateDialog(
  BuildContext context,
  WeeklyMenuPlanViewModel calendar, {
  WeekTemplateViewModel? viewModel,
}) async {
  final vm = viewModel ?? WeekTemplateViewModel.fromLocator(calendar);
  final savedName = await showButleryDialog<String>(
    context: context,
    builder: (_) => WeekTemplateSaveDialog(viewModel: vm),
  );
  if (viewModel == null) vm.dispose();
  if (savedName == null || !context.mounted) return;
  SnackBarUtils.showSuccess(context, context.l10n.weekTemplateSaved(savedName));
}

class WeekTemplateSaveDialog extends StatefulWidget {
  const WeekTemplateSaveDialog({super.key, required this.viewModel});

  final WeekTemplateViewModel viewModel;

  @override
  State<WeekTemplateSaveDialog> createState() => _WeekTemplateSaveDialogState();
}

class _WeekTemplateSaveDialogState extends State<WeekTemplateSaveDialog> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    final name = _name.text.trim();
    final ok = await widget.viewModel.saveVisibleWeek(name);
    if (!mounted) return;
    if (ok) {
      Navigator.of(context).pop(name);
      return;
    }
    setState(() {
      _saving = false;
      _error = context.l10n.weekTemplateSaveFailed;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final cs = Theme.of(context).colorScheme;
    final vm = widget.viewModel;
    return PopScope(
      canPop: !_saving,
      child: ButleryDialog(
        title: l.weekTemplateSaveTitle,
        content: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              LabeledField(
                label: l.menuNameLabel,
                child: TextFormField(
                  key: const ValueKey('week-template-name'),
                  controller: _name,
                  autofocus: true,
                  enabled: !_saving,
                  maxLength: 50,
                  style: fieldTextStyle(context, enabled: !_saving),
                  errorBuilder: FieldErrorLine.builder,
                  validator: (v) => (v?.trim().isEmpty ?? true)
                      ? l.weekTemplateNameRequired
                      : null,
                  onFieldSubmitted: (_) => _save(),
                ),
              ),
              const SizedBox(height: AppDimensions.space16),
              Text(l.weekTemplateWholeWeek, style: AppTextStyles.bodyLargeBold),
              Text(
                l.weekTemplateWholeWeekSummary(
                  vm.visibleWeekDayCount,
                  vm.visibleWeekEntries.length,
                ),
                style: AppTextStyles.bodySmall.copyWith(
                  color: cs.onSurfaceVariant,
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: AppDimensions.space12),
                Text(
                  _error!,
                  style: AppTextStyles.bodySmall.copyWith(color: cs.error),
                ),
              ],
            ],
          ),
        ),
        actions: [
          DialogCancelButton(enabled: !_saving),
          ButleryDialogPrimary(
            label: l.weekTemplateSaveButton,
            busy: _saving,
            onPressed: _saving ? null : _save,
          ),
        ],
      ),
    );
  }
}
