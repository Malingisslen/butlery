import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/core/utils/iso_week_utils.dart';
import 'package:butlery/core/utils/snackbar_utils.dart';
import 'package:butlery/models/menu/week_template_entry.dart';
import 'package:butlery/models/menu/weekly_menu_plan.dart';
import 'package:butlery/services/menu/week_template_apply.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/viewmodels/menu/week_template_viewmodel.dart';
import 'package:butlery/viewmodels/menu/weekly_menu_plan_viewmodel.dart';
import 'package:butlery/widgets/common/buttons/action_buttons.dart';
import 'package:butlery/widgets/common/chips/butlery_filter_chip.dart';
import 'package:butlery/widgets/common/dialogs/butlery_dialog.dart';
import 'package:butlery/widgets/common/dialogs/dialog_cancel_button.dart';
import 'package:butlery/widgets/common/indicators/status_pill.dart';
import 'package:butlery/widgets/common/sheets/butlery_sheet.dart';
import 'package:butlery/widgets/common/state_widget.dart';
import 'package:flutter/material.dart';

/// How many weeks, from the one the calendar shows, the template can be put on.
const int kTemplateTargetWeeks = 5;

/// BUT-2522: the preview of a saved week template, with the week to put it
/// on. The receipt and its "Ångra" are shown on [context] after the sheet
/// closes. The apply is held here rather than handed back by the sheet, so a
/// sheet dragged away mid-save still ends in a receipt.
Future<void> showWeekTemplatePreview(
  BuildContext context, {
  required WeeklyMenuPlanViewModel calendar,
  required String name,
  required List<WeekTemplateEntry> entries,
  @visibleForTesting
  WeekTemplateViewModel Function(WeeklyMenuPlanViewModel calendar)?
  createViewModel,
}) async {
  final create = createViewModel ?? WeekTemplateViewModel.fromLocator;
  final vm = create(calendar);
  Future<WeekTemplateApplyResult?>? applying;
  await showButlerySheet<void>(
    context: context,
    builder: (_) => WeekTemplatePreviewSheet(
      viewModel: vm,
      name: name,
      entries: entries,
      onApply: (mode) => applying = vm.apply(mode),
    ),
  );
  final WeekTemplateApplyResult? applied;
  try {
    applied = await applying;
  } finally {
    vm.dispose();
  }
  if (applied == null || !context.mounted) return;
  final result = applied;
  final l = context.l10n;
  final week = IsoWeekUtils.isoWeekNumber(result.plan.weekStartDate);
  final placed = l.weekTemplateApplied(result.addedEntryIds.length, week);
  final message = result.missingCount == 0
      ? placed
      : '$placed. ${l.weekTemplateAppliedMissing(result.missingCount)}';
  if (!result.changed) {
    SnackBarUtils.showSuccess(context, message);
    return;
  }
  final rootContext = Navigator.of(context, rootNavigator: true).context;
  SnackBarUtils.showUndo(
    context,
    message,
    onUndo: () async {
      final undoVm = create(calendar);
      final ok = await undoVm.undo(result);
      undoVm.dispose();
      final target = context.mounted ? context : rootContext;
      if (ok || !target.mounted) return;
      SnackBarUtils.showFailure(
        target,
        what: target.l10n.weekTemplateUndoFailed,
      );
    },
  );
}

class WeekTemplatePreviewSheet extends StatefulWidget {
  const WeekTemplatePreviewSheet({
    super.key,
    required this.viewModel,
    required this.name,
    required this.entries,
    required this.onApply,
  });

  final WeekTemplateViewModel viewModel;
  final String name;
  final List<WeekTemplateEntry> entries;
  final Future<WeekTemplateApplyResult?> Function(WeekTemplateApplyMode mode)
  onApply;

  @override
  State<WeekTemplatePreviewSheet> createState() =>
      _WeekTemplatePreviewSheetState();
}

class _WeekTemplatePreviewSheetState extends State<WeekTemplatePreviewSheet> {
  late final List<DateTime> _weeks;
  bool _applying = false;

  WeekTemplateViewModel get _vm => widget.viewModel;

  @override
  void initState() {
    super.initState();
    final first = _vm.visibleWeekStart;
    _weeks = [
      for (var i = 0; i < kTemplateTargetWeeks; i++)
        DateTime(first.year, first.month, first.day + 7 * i),
    ];
    _vm.preview(widget.entries, first);
  }

  Future<void> _apply() async {
    var mode = WeekTemplateApplyMode.fillEmpty;
    if (_vm.needsChoice) {
      final chosen = await _askMode();
      if (chosen == null || !mounted) return;
      mode = chosen;
    }
    setState(() => _applying = true);
    final result = await widget.onApply(mode);
    if (!mounted) return;
    if (result == null) {
      setState(() => _applying = false);
      SnackBarUtils.showFailure(
        context,
        what: context.l10n.weekTemplateApplyFailed,
      );
      return;
    }
    Navigator.of(context).pop();
  }

  Future<WeekTemplateApplyMode?> _askMode() {
    final week = IsoWeekUtils.isoWeekNumber(_vm.targetWeek!);
    return showButleryDialog<WeekTemplateApplyMode>(
      context: context,
      builder: (dialogContext) {
        final l = dialogContext.l10n;
        return ButleryDialog(
          title: l.weekTemplateOverlapTitle(week),
          message: l.weekTemplateOverlapBody,
          actionsOverflowDirection: VerticalDirection.down,
          actions: [
            const DialogCancelButton(),
            ButleryDialogPrimary(
              key: const ValueKey('week-template-replace'),
              label: l.weekTemplateReplaceAll,
              onPressed: () => Navigator.of(
                dialogContext,
              ).pop(WeekTemplateApplyMode.replace),
            ),
            ButleryDialogPrimary(
              key: const ValueKey('week-template-fill'),
              label: l.weekTemplateFillEmpty,
              onPressed: () => Navigator.of(
                dialogContext,
              ).pop(WeekTemplateApplyMode.fillEmpty),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return PopScope(
      canPop: !_applying,
      child: ListenableBuilder(
        listenable: _vm,
        builder: (context, _) {
          final target = _vm.targetWeek;
          return Padding(
            padding: const EdgeInsets.fromLTRB(
              AppDimensions.space16,
              0,
              AppDimensions.space16,
              AppDimensions.space16,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(widget.name, style: AppTextStyles.headlineSmall),
                const SizedBox(height: AppDimensions.space4),
                Text(
                  l.weekTemplatePreviewOverline.toUpperCase(),
                  style: AppTextStyles.overline,
                ),
                const SizedBox(height: AppDimensions.space12),
                Wrap(
                  spacing: AppDimensions.space8,
                  runSpacing: AppDimensions.space8,
                  children: [
                    for (final week in _weeks)
                      ButleryFilterChip(
                        label: l.weekTemplateWeekChip(
                          IsoWeekUtils.isoWeekNumber(week),
                        ),
                        selected: target == week,
                        onSelected: _applying
                            ? null
                            : (_) => _vm.preview(widget.entries, week),
                      ),
                  ],
                ),
                const SizedBox(height: AppDimensions.space12),
                Flexible(child: _body(context)),
                const SizedBox(height: AppDimensions.space16),
                if (target != null)
                  ActionButtons.primaryButton(
                    context,
                    key: const ValueKey('week-template-apply'),
                    label: l.weekTemplateApplyButton(
                      IsoWeekUtils.isoWeekNumber(target),
                    ),
                    isExpanded: true,
                    isLoading: _applying,
                    onPressed: _vm.isLoading || _vm.previewFailed || _applying
                        ? null
                        : _apply,
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _body(BuildContext context) {
    if (_vm.previewFailed) {
      return StateWidget.error(
        message: context.l10n.weekTemplatePreviewFailed,
        actionLabel: context.l10n.commonRetry,
        onAction: () => _vm.preview(widget.entries, _vm.targetWeek!),
      );
    }
    if (_vm.isLoading) {
      return StateWidget.loading(
        message: context.l10n.weekTemplatePreviewLoading,
      );
    }
    return ListView(
      shrinkWrap: true,
      children: [for (final row in _vm.rows) TemplatePreviewRowView(row: row)],
    );
  }
}

/// One dish of the preview: where it lands, and what stops it being plain.
class TemplatePreviewRowView extends StatelessWidget {
  const TemplatePreviewRowView({super.key, required this.row});

  final TemplatePreviewRow row;

  static String _capitalised(String s) =>
      s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final cs = Theme.of(context).colorScheme;
    final entry = row.dish.entry;
    final day = _capitalised(entry.day.displayLabel);
    final line = entry.slot == MealSlot.middag
        ? l.weekTemplateDishLine(day, row.dish.title)
        : l.weekTemplateDishLineWithMeal(
            day,
            entry.slot.displayLabel,
            row.dish.title,
          );
    final finding = row.finding;
    final pills = <String>[
      if (row.isMissing) l.weekTemplateMissing,
      if (finding != null && finding.containsAllergens.isNotEmpty) ...[
        l.weekTemplateContains(finding.containsAllergens.join(', ')),
        l.weekTemplateNotForEveryone,
      ],
      if (!row.isMissing && row.isUnchecked) l.weekTemplateUnchecked,
      if (finding?.disliked ?? false) l.weekTemplateDisliked,
    ];
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppDimensions.space8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            line,
            style: AppTextStyles.bodyLarge.copyWith(
              color: row.isMissing ? cs.onSurfaceVariant : cs.onSurface,
            ),
          ),
          if (row.isMissing)
            Text(
              l.weekTemplateMissingHint,
              style: AppTextStyles.bodySmall.copyWith(
                color: cs.onSurfaceVariant,
              ),
            ),
          if (pills.isNotEmpty) ...[
            const SizedBox(height: AppDimensions.space4),
            Wrap(
              spacing: AppDimensions.space4,
              runSpacing: AppDimensions.space4,
              children: [for (final p in pills) StatusPill(label: p)],
            ),
          ],
        ],
      ),
    );
  }
}
