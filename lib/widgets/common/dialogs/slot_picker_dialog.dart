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

import 'package:flutter/material.dart';
import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/core/utils/iso_week_utils.dart';
import 'package:butlery/models/menu/weekly_menu_plan.dart';
import 'package:butlery/services/menu/weekly_menu_plan_service.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:clock/clock.dart';

/// Triple identifying a single placement target in the weekly plan.
typedef SlotSelection = ({DateTime weekStart, DayOfWeek day, MealSlot slot});

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

class SlotPickerDialog extends StatefulWidget {
  const SlotPickerDialog({super.key});

  @override
  State<SlotPickerDialog> createState() => _SlotPickerDialogState();
}

class _SlotPickerDialogState extends State<SlotPickerDialog> {
  late final WeeklyMenuPlanService _planService;
  late DateTime _visibleWeekStart;
  WeeklyMenuPlan? _plan;
  bool _isLoading = true;
  String? _error;

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
      _error = null;
    });
    try {
      final plan = await _planService.getWeek(_visibleWeekStart);
      if (!mounted) return;
      setState(() {
        _plan = plan;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  void _goToNextWeek() {
    _visibleWeekStart = _visibleWeekStart.add(const Duration(days: 7));
    _loadWeek();
  }

  void _goToPreviousWeek() {
    _visibleWeekStart = _visibleWeekStart.subtract(const Duration(days: 7));
    _loadWeek();
  }

  void _selectSlot(DayOfWeek day, MealSlot slot) {
    Navigator.of(context).pop(
      (weekStart: _visibleWeekStart, day: day, slot: slot),
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
                  borderRadius:
                      BorderRadius.circular(AppDimensions.borderRadius2),
                ),
              ),
              _buildHeader(cs),
              const Divider(height: 1),
              Expanded(child: _buildBody(scrollController)),
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
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppDimensions.spacingLg),
          child: Text(
            _error!,
            style: AppTextStyles.bodyMedium,
            textAlign: TextAlign.center,
          ),
        ),
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
    return InkWell(
      onTap: () => _selectSlot(day, slot),
      child: Container(
        height: 64,
        padding: const EdgeInsets.all(AppDimensions.spacingXs),
        decoration: BoxDecoration(
          // Square per design language.
          borderRadius: BorderRadius.zero,
          border: Border.all(
            color: isOccupied ? cs.primary : cs.outlineVariant,
            width: isOccupied ? 1.5 : 1,
          ),
          color: isOccupied
              ? cs.primaryContainer.withValues(alpha: 0.3)
              : cs.surface,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              day.displayLabel,
              style: AppTextStyles.labelSmall.copyWith(
                color: cs.onSurfaceVariant,
                letterSpacing: 1,
              ),
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
                  : Icon(Icons.add,
                      size: AppDimensions.iconSize18,
                      color: cs.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }

  String _formatWeekLabel(DateTime weekStart) {
    final weekNumber = IsoWeekUtils.isoWeekNumber(weekStart);
    return context.l10n.slotPickerWeekLabel(weekNumber);
  }
}
