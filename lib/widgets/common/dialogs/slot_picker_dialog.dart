// lib/widgets/common/dialogs/slot_picker_dialog.dart
//
// BUT-1029: reusable picker for choosing a (weekStart, day, slot) target
// in the weekly menu plan. Built as a bottom sheet to match the wave-16
// `_BulkTagPicker` design language (DraggableScrollableSheet, square
// chips, top handle bar).
//
// Returns `({DateTime weekStart, DayOfWeek day, MealSlot slot})` on tap,
// `null` on cancel / dismiss. Calling code is responsible for what to do
// with the choice (assign one recipe, bulk-add many recipes, etc.).
//
// Prereq for BUT-1013 (bulk add-to-menu on recipe-list selection).
//
// BUT-999 adds a multi-select mode (`showMultiSlotPickerDialog`): cells
// toggle checkbox-style and a pinned confirm button returns ALL selected
// (day, slot) targets for the visible week in one go. Single-select mode
// is untouched — one tap still pops immediately.

import 'package:flutter/material.dart';
import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/widgets/common/indicators/loading_indicator.dart';
import 'package:butlery/widgets/common/state_widget.dart';
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/core/utils/iso_week_utils.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/models/menu/weekly_menu_plan.dart';
import 'package:butlery/services/menu/weekly_menu_plan_service.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:clock/clock.dart';

/// Triple identifying a single placement target in the weekly plan.
typedef SlotSelection = ({DateTime weekStart, DayOfWeek day, MealSlot slot});

/// BUT-999: multi-select result — every chosen (day, slot) target within
/// one week. Targets always share [weekStart] so the service can persist
/// them with a single batched save.
typedef MultiSlotSelection = ({DateTime weekStart, List<SlotTarget> targets});

/// Imperative entry point for the slot picker. Returns the user's choice or
/// null if they cancelled.
Future<SlotSelection?> showSlotPickerDialog(BuildContext context) {
  return showModalBottomSheet<SlotSelection>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => const SlotPickerDialog(),
  );
}

/// BUT-999: multi-select entry point. Cells toggle on tap; the pinned
/// confirm button returns all selected targets at once. Returns null on
/// cancel / dismiss / empty selection.
Future<MultiSlotSelection?> showMultiSlotPickerDialog(BuildContext context) {
  return showModalBottomSheet<MultiSlotSelection>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => const SlotPickerDialog(multiSelect: true),
  );
}

class SlotPickerDialog extends StatefulWidget {
  /// When true, taps toggle selection and a confirm button pops with a
  /// [MultiSlotSelection]; when false (default), the first tap pops with a
  /// [SlotSelection] — the original BUT-1029 behavior.
  final bool multiSelect;

  const SlotPickerDialog({super.key, this.multiSelect = false});

  @override
  State<SlotPickerDialog> createState() => _SlotPickerDialogState();
}

class _SlotPickerDialogState extends State<SlotPickerDialog> {
  late final WeeklyMenuPlanService _planService;
  late DateTime _visibleWeekStart;
  WeeklyMenuPlan? _plan;
  bool _isLoading = true;
  bool _loadFailed = false;
  final Set<SlotTarget> _selected = {};

  @override
  void initState() {
    super.initState();
    _planService = ServiceLocator.get<WeeklyMenuPlanService>();
    _visibleWeekStart = IsoWeekUtils.weekStartOf(clock.now());
    _loadWeek();
  }

  Future<void> _loadWeek() async {
    setState(() {
      _isLoading = true;
      _loadFailed = false;
    });
    try {
      // BUT-1962: `getWeek` answered a failed read with an EMPTY plan, so this
      // dialog drew a week of free cells and invited the user to place on top
      // of a week it had never read. A refusal has to reach the body instead.
      final read = await _planService.readWeek(_visibleWeekStart);
      if (!mounted) return;
      setState(() {
        _loadFailed = read.readFailed;
        _plan = read.readFailed ? null : read.plan;
        _isLoading = false;
      });
    } catch (e) {
      AppLogger.error('SlotPickerDialog: could not load the week', e);
      if (!mounted) return;
      setState(() {
        _loadFailed = true;
        _isLoading = false;
      });
    }
  }

  void _goToNextWeek() {
    _visibleWeekStart = _visibleWeekStart.add(const Duration(days: 7));
    // A MultiSlotSelection spans exactly one week (single batched save), so
    // navigating away drops any picks made on the previous week.
    _selected.clear();
    _loadWeek();
  }

  void _goToPreviousWeek() {
    _visibleWeekStart = _visibleWeekStart.subtract(const Duration(days: 7));
    _selected.clear();
    _loadWeek();
  }

  void _selectSlot(DayOfWeek day, MealSlot slot) {
    if (widget.multiSelect) {
      setState(() {
        final target = (day: day, slot: slot);
        if (!_selected.remove(target)) _selected.add(target);
      });
      return;
    }
    Navigator.of(context).pop(
      (weekStart: _visibleWeekStart, day: day, slot: slot),
    );
  }

  void _confirmMultiSelection() {
    Navigator.of(context).pop(
      (weekStart: _visibleWeekStart, targets: _selected.toList()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      expand: false,
      builder: (sheetContext, scrollController) {
        final cs = Theme.of(context).colorScheme;
        return DecoratedBox(
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(AppDimensions.borderRadiusM),
            ),
          ),
          child: Column(
            children: [
              // Drag handle
              Container(
                margin: const EdgeInsets.only(top: AppDimensions.paddingM),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: cs.onSurfaceVariant,
                  borderRadius: BorderRadius.circular(
                    AppDimensions.borderRadius2,
                  ),
                ),
              ),
              _buildHeader(cs),
              const Divider(height: 1),
              Expanded(child: _buildBody(scrollController)),
              if (widget.multiSelect) _buildConfirmBar(),
            ],
          ),
        );
      },
    );
  }

  Widget _buildHeader(ColorScheme cs) {
    final weekLabel = _formatWeekLabel(_visibleWeekStart);
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppDimensions.spacingLg,
        AppDimensions.spacingLg,
        AppDimensions.spacingSm,
        AppDimensions.spacingMd,
      ),
      child: Row(
        children: [
          const Icon(Icons.calendar_today_outlined),
          const SizedBox(width: AppDimensions.spacingSm),
          Expanded(
            child: Text(
              context.l10n.slotPickerDialogTitle,
              style: AppTextStyles.titleLarge,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_left),
            tooltip: context.l10n.slotPickerPreviousWeek,
            onPressed: _isLoading ? null : _goToPreviousWeek,
          ),
          Text(weekLabel, style: AppTextStyles.bodyMedium),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            tooltip: context.l10n.slotPickerNextWeek,
            onPressed: _isLoading ? null : _goToNextWeek,
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(context.l10n.commonCancel),
          ),
        ],
      ),
    );
  }

  Widget _buildBody(ScrollController scrollController) {
    if (_isLoading) {
      return const Center(child: LoadingIndicator());
    }
    if (_loadFailed) {
      return StateWidget.error(
        message: weeklyPlanReadFailedMessage,
        onAction: _loadWeek,
      );
    }
    final plan = _plan!;
    return SingleChildScrollView(
      controller: scrollController,
      padding: const EdgeInsets.all(AppDimensions.spacingLg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final slot in MealSlot.values) ...[
            _buildSlotRow(plan, slot),
            const SizedBox(height: AppDimensions.spacingMd),
          ],
        ],
      ),
    );
  }

  Widget _buildSlotRow(WeeklyMenuPlan plan, MealSlot slot) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          slot.displayLabel,
          style: AppTextStyles.titleMedium.copyWith(color: cs.primary),
        ),
        const SizedBox(height: AppDimensions.spacingXs),
        Row(
          children: [
            for (final day in DayOfWeek.values) ...[
              Expanded(child: _buildCell(plan, day, slot)),
              if (day != DayOfWeek.sun)
                const SizedBox(width: AppDimensions.spacingXs),
            ],
          ],
        ),
      ],
    );
  }

  Widget _buildCell(WeeklyMenuPlan plan, DayOfWeek day, MealSlot slot) {
    final cs = Theme.of(context).colorScheme;
    final entries = plan.entriesAt(day, slot);
    final isOccupied = entries.isNotEmpty;
    final isSelected =
        widget.multiSelect && _selected.contains((day: day, slot: slot));
    return Semantics(
      label: context.l10n.a11ySlotPickerCell(
        day.displayLabel,
        slot.displayLabel,
      ),
      button: true,
      selected: widget.multiSelect ? isSelected : null,
      child: InkWell(
        onTap: () => _selectSlot(day, slot),
        child: Container(
          height: 64,
          padding: const EdgeInsets.all(AppDimensions.spacingXs),
          decoration: BoxDecoration(
            // Square per design language.
            borderRadius: BorderRadius.zero,
            border: Border.all(
              color: (isSelected || isOccupied)
                  ? cs.primary
                  : cs.outlineVariant,
              width: isSelected
                  ? 2
                  : isOccupied
                  ? 1.5
                  : 1,
            ),
            color: isSelected
                ? cs.primaryContainer.withValues(alpha: 0.6)
                : isOccupied
                ? cs.primaryContainer.withValues(alpha: 0.3)
                : cs.surface,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      day.displayLabel,
                      style: AppTextStyles.labelSmall.copyWith(
                        color: cs.onSurfaceVariant,
                        letterSpacing: 1,
                      ),
                    ),
                  ),
                  if (widget.multiSelect)
                    Icon(
                      isSelected
                          ? Icons.check_box
                          : Icons.check_box_outline_blank,
                      size: AppDimensions.iconSize18,
                      color: isSelected ? cs.primary : cs.onSurfaceVariant,
                    ),
                ],
              ),
              const SizedBox(height: 2),
              Expanded(
                child: isOccupied
                    ? Text(
                        entries.first.recipeTitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.labelSmall,
                      )
                    : widget.multiSelect
                    ? const SizedBox.shrink()
                    : Icon(
                        Icons.add,
                        size: AppDimensions.iconSize18,
                        color: cs.onSurfaceVariant,
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// BUT-999: pinned confirm bar for multi-select mode. Disabled until at
  /// least one target is picked; the label discloses the count.
  Widget _buildConfirmBar() {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppDimensions.spacingLg,
          AppDimensions.spacingSm,
          AppDimensions.spacingLg,
          AppDimensions.spacingMd,
        ),
        child: SizedBox(
          width: double.infinity,
          height: 48,
          child: FilledButton(
            onPressed: _selected.isEmpty ? null : _confirmMultiSelection,
            style: FilledButton.styleFrom(
              // Square per design language.
              shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.zero,
              ),
            ),
            child: Text(
              context.l10n.slotPickerConfirmCount(_selected.length),
            ),
          ),
        ),
      ),
    );
  }

  String _formatWeekLabel(DateTime weekStart) {
    final weekNumber = IsoWeekUtils.isoWeekNumber(weekStart);
    return context.l10n.slotPickerWeekLabel(weekNumber);
  }
}
