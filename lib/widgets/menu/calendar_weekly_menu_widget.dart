/// Calendar view for the weekly menu plan. Embedded in `VeckomenyView`
/// when the user toggles "Kalender". Renders the 7-day grid, overflow tray,
/// week-nav header, and all five UI states, with drag-drop between cells.
///
/// BUT-542: cell rendering + drag/drop machinery extracted to
/// `lib/widgets/menu/calendar/`. This file is the orchestrator only.
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/core/utils/iso_week_utils.dart';
import 'package:butlery/models/menu/weekly_menu_plan.dart';
import 'package:butlery/theme/app_dimensions.dart';
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
      context.read<WeeklyMenuPlanViewModel>().loadWeek(DateTime.now());
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

    // Compute today's index once — avoids 7× DateTime.now() in DayCell.
    // -1 when the visible week isn't the current ISO week.
    final now = DateTime.now();
    final todayIndex = plan.weekStartDate == IsoWeekUtils.weekStartOf(now)
        ? now.weekday - 1
        : -1;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        WeekNavHeader(
          label: _formatWeekLabel(context, vm.currentWeekStart),
          onPrev: vm.previousWeek,
          onNext: vm.nextWeek,
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
