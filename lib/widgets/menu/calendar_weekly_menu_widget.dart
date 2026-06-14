/// Calendar view for the weekly menu plan. Embedded in `VeckomenyView`
/// when the user toggles "Kalender". Renders the 7-day grid, overflow tray,
/// week-nav header, and all five UI states, with drag-drop between cells.
///
/// BUT-542: cell rendering + drag/drop machinery extracted to
/// `lib/widgets/menu/calendar/`. This file is the orchestrator only.
library;

import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/core/utils/iso_week_utils.dart';
import 'package:butlery/core/utils/snackbar_utils.dart';
import 'package:butlery/models/menu/weekly_menu_plan.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/viewmodels/menu/weekly_menu_plan_viewmodel.dart';
import 'package:butlery/widgets/common/dialogs/recipe_selection_dialogs.dart';
import 'package:butlery/widgets/common/loading_state_builder.dart';
import 'package:butlery/widgets/common/state_widget.dart';
import 'package:butlery/widgets/menu/calendar/calendar_cells.dart';
import 'package:butlery/widgets/menu/calendar/calendar_header.dart';
import 'package:butlery/widgets/menu/parsed_extraction_chips.dart';

/// Embeddable calendar widget. Reads `WeeklyMenuPlanViewModel` from the
/// surrounding `MultiProvider` (set up by `VeckomenyView`).
class CalendarWeeklyMenuWidget extends StatefulWidget {
  final VoidCallback? onRefinePrompt;

  const CalendarWeeklyMenuWidget({super.key, this.onRefinePrompt});

  @override
  State<CalendarWeeklyMenuWidget> createState() =>
      _CalendarWeeklyMenuWidgetState();
}

class _CalendarWeeklyMenuWidgetState extends State<CalendarWeeklyMenuWidget> {
  bool _initialLoadStarted = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialLoadStarted) return;
    _initialLoadStarted = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<WeeklyMenuPlanViewModel>().loadWeek(clock.now());
    });
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<WeeklyMenuPlanViewModel>();
    return LoadingStateBuilder<WeeklyMenuPlan>(
      isLoading: vm.isLoading,
      error: vm.error,
      data: vm.plan,
      loadingMessage: context.l10n.loadingGeneric,
      builder: (context, plan) => _buildSuccessContent(context, vm, plan),
      emptyBuilder: (context) => _buildEmptyHint(context),
    );
  }

  Widget _buildEmptyHint(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: AppDimensions.spacingXl),
          child: Icon(
            Icons.arrow_upward,
            size: 32,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
        StateWidget.empty(
          title: context.l10n.weeklyMenuEmptyTitle,
          subtitle: context.l10n.weeklyMenuEmptyHint,
          icon: Icons.event_note_outlined,
        ),
      ],
    );
  }

  Widget _buildSuccessContent(
    BuildContext context,
    WeeklyMenuPlanViewModel vm,
    WeeklyMenuPlan plan,
  ) {
    if (plan.isEmpty && !vm.hasOverflow) {
      return _buildEmptyHint(context);
    }

    // Extraction chips strip (BUT-359): show what the parser understood.
    final chipsWidget = ParsedExtractionChips(
      parsed: vm.lastParsedRequest,
      onRefinePrompt: widget.onRefinePrompt,
    );

    // Compute today's index once — avoids 7× clock.now() in DayCell.
    // -1 when the visible week isn't the current ISO week.
    final now = clock.now();
    final todayIndex = plan.weekStartDate == IsoWeekUtils.weekStartOf(now)
        ? now.weekday - 1
        : -1;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // BUT-1043: while multi-select is active the nav header is replaced
        // by the selection action bar (count + move + cancel).
        if (vm.selectionMode)
          SelectionActionBar(
            selectedCount: vm.selectedCount,
            onMove: () => _onMoveSelection(context, vm),
            onCancel: vm.clearSelection,
          )
        else
          WeekNavHeader(
            label: _formatWeekLabel(context, vm.currentWeekStart),
            onPrev: vm.previousWeek,
            onNext: vm.nextWeek,
            onClearWeek: vm.hasEntries || vm.hasOverflow
                ? () => _onClearWeek(context, vm)
                : null,
            // Copy + select are only meaningful when the week has entries.
            onCopyWeek: vm.hasEntries ? () => _onCopyWeek(context, vm) : null,
            onSelectMode: vm.hasEntries ? () => _onEnterSelection(vm) : null,
          ),
        chipsWidget,
        if (vm.hasOverflow) OverflowTray(overflow: vm.overflow),
        for (final day in DayOfWeek.values)
          DayCell(
            vm: vm,
            plan: plan,
            day: day,
            isToday: day.index == todayIndex,
            onTapEmptySlot: (d, s) => _onTapEmptySlot(context, vm, d, s),
            onTapRecipe: (id) => _navigateToRecipe(context, id),
          ),
      ],
    );
  }

  Future<void> _onClearWeek(
    BuildContext context,
    WeeklyMenuPlanViewModel vm,
  ) async {
    await vm.clearWeek();
    if (!context.mounted) return;
    SnackBarUtils.showSuccessWithAction(
      context,
      context.l10n.weeklyMenuClearedUndo,
      actionLabel: context.l10n.commonUndo,
      onAction: () => vm.undoClearWeek(),
      duration: const Duration(seconds: 7),
    );
  }

  /// BUT-1043: confirm, then copy the visible week's entries into next week
  /// via the additive `copyWeek` primitive. The result snackbar distinguishes
  /// "N copied", "nothing to copy" (count 0), and failure (null).
  Future<void> _onCopyWeek(
    BuildContext context,
    WeeklyMenuPlanViewModel vm,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(dialogContext.l10n.weeklyMenuCopyToNextConfirmTitle),
        content: Text(dialogContext.l10n.weeklyMenuCopyToNextConfirmBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(dialogContext.l10n.commonCancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(dialogContext.l10n.commonContinue),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    final copied = await vm.copyWeekToNext();
    if (!context.mounted) return;
    if (copied == null) {
      SnackBarUtils.showError(context, context.l10n.weeklyMenuCopyToNextFailed);
      return;
    }
    SnackBarUtils.showSuccess(
      context,
      context.l10n.weeklyMenuCopyToNextResult(copied),
    );
  }

  void _onEnterSelection(WeeklyMenuPlanViewModel vm) {
    vm.beginSelection();
  }

  /// BUT-1043: pick a (day, slot) target, then bulk-move every selected entry
  /// there in a single persisted write. No-op-safe: an empty pick or empty
  /// selection just returns.
  Future<void> _onMoveSelection(
    BuildContext context,
    WeeklyMenuPlanViewModel vm,
  ) async {
    if (vm.selectedCount == 0) return;
    final target = await _showMoveTargetSheet(context);
    if (target == null || !context.mounted) return;
    final moved = await vm.bulkMoveSelected(
      toDay: target.$1,
      toSlot: target.$2,
    );
    if (!context.mounted) return;
    if (moved == null) {
      SnackBarUtils.showError(context, context.l10n.weeklyMenuMoveFailed);
      return;
    }
    SnackBarUtils.showSuccess(
      context,
      context.l10n.weeklyMenuMovedResult(moved),
    );
  }

  /// Day + slot target picker for bulk-move. Returns null on dismiss.
  Future<(DayOfWeek, MealSlot)?> _showMoveTargetSheet(
    BuildContext context,
  ) async {
    return showModalBottomSheet<(DayOfWeek, MealSlot)>(
      context: context,
      builder: (sheetContext) {
        final cs = Theme.of(sheetContext).colorScheme;
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.all(AppDimensions.spacingMd),
                child: Text(
                  sheetContext.l10n.weeklyMenuMoveSheetTitle,
                  style: AppTextStyles.titleSmall.copyWith(
                    color: cs.onSurface,
                  ),
                ),
              ),
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (final day in DayOfWeek.values)
                        for (final slot in MealSlot.values)
                          Semantics(
                            button: true,
                            label: '${day.displayLabel} ${slot.displayLabel}',
                            child: ListTile(
                              dense: true,
                              leading: Icon(
                                slot.isMulti
                                    ? Icons.cake_outlined
                                    : Icons.restaurant_outlined,
                                color: cs.secondary,
                              ),
                              title: Text(
                                '${day.displayLabel} · ${slot.displayLabel}',
                              ),
                              onTap: () =>
                                  Navigator.of(sheetContext).pop((day, slot)),
                            ),
                          ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _onTapEmptySlot(
    BuildContext context,
    WeeklyMenuPlanViewModel vm,
    DayOfWeek day,
    MealSlot slot,
  ) async {
    final picked = await RecipeSelectionDialogs.showMenuRecipeSelector(
      context,
      categoryName: slot.displayLabel,
    );
    if (picked == null || picked.isEmpty || !context.mounted) return;
    // For lunch/middag take the first; for övrigt accept all and queue them.
    if (slot.isMulti) {
      for (final recipe in picked) {
        await vm.assignRecipe(day: day, slot: slot, recipe: recipe);
      }
    } else {
      await vm.assignRecipe(day: day, slot: slot, recipe: picked.first);
    }
  }

  Future<void> _navigateToRecipe(
    BuildContext context,
    String recipeId,
  ) async {
    final vm = context.read<WeeklyMenuPlanViewModel>();
    final recipe = vm.resolveForNavigation(recipeId);
    if (recipe != null && context.mounted) {
      await Navigator.of(context).pushNamed(
        '/recipe-detail',
        arguments: recipe,
      );
    }
  }

  String _formatWeekLabel(BuildContext context, DateTime weekStart) {
    final weekEnd = weekStart.add(const Duration(days: 6));
    return context.l10n.weeklyMenuWeekLabel(
      IsoWeekUtils.isoWeekNumber(weekStart),
      _formatDayMonth(weekStart),
      _formatDayMonth(weekEnd),
    );
  }

  static const List<String> _svMonths = [
    'jan',
    'feb',
    'mar',
    'apr',
    'maj',
    'jun',
    'jul',
    'aug',
    'sep',
    'okt',
    'nov',
    'dec',
  ];

  String _formatDayMonth(DateTime date) =>
      '${date.day} ${_svMonths[date.month - 1]}';
}
