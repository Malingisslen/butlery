/// Calendar view for the weekly menu plan. Embedded in `VeckomenyView`
/// when the user toggles "Kalender". Renders the 7-day grid, overflow tray,
/// week-nav header, and all five UI states, with drag-drop between cells.
library;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/core/utils/iso_week_utils.dart';
import 'package:butlery/models/menu/weekly_menu_plan.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/widgets/menu/parsed_extraction_chips.dart';
import 'package:butlery/theme/app_colors.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/viewmodels/menu/weekly_menu_plan_viewmodel.dart';
import 'package:butlery/widgets/common/dialogs/recipe_selection_dialogs.dart';
import 'package:butlery/widgets/common/loading_state_builder.dart';
import 'package:butlery/widgets/common/state_widget.dart';

const double _kSlotMinHeight = 80;
const double _kDragFeedbackWidth = 110;

/// Shared border pattern for assigned lunch/middag/övrigt cells — an accent
/// left border (color varies per slot), divider top/right, and a rust-light
/// bottom accent. Empty cells use a plain `Border.all` via the theme divider.
Border _accentedBorder(Color left) => Border(
      left: BorderSide(color: left, width: 3),
      top: const BorderSide(color: AppColors.creamDarker),
      right: const BorderSide(color: AppColors.creamDarker),
      bottom: const BorderSide(color: AppColors.rustLight, width: 2),
    );

/// Small-caps slot label used at the top of every cell.
Text _slotLabel(String text, Color color) => Text(
      text.toUpperCase(),
      style: AppTextStyles.labelSmall.copyWith(
        fontSize: 8,
        letterSpacing: 1,
        color: color,
      ),
    );

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
        const Padding(
          padding: EdgeInsets.only(top: AppDimensions.spacingXl),
          child: Icon(
            Icons.arrow_upward,
            size: 32,
            color: AppColors.forestGreen,
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

    // Compute today's index once — avoids 7× DateTime.now() in _buildDayRow.
    // -1 when the visible week isn't the current ISO week.
    final now = DateTime.now();
    final todayIndex = plan.weekStartDate == IsoWeekUtils.weekStartOf(now)
        ? now.weekday - 1
        : -1;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildWeekNavHeader(context, vm),
        chipsWidget,
        if (vm.hasOverflow) _buildOverflowTray(context, vm),
        for (final day in DayOfWeek.values)
          _buildDayRow(context, vm, plan, day, day.index == todayIndex),
      ],
    );
  }

  Widget _buildWeekNavHeader(
    BuildContext context,
    WeeklyMenuPlanViewModel vm,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimensions.spacingMd,
        vertical: AppDimensions.spacingSm,
      ),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        border: Border(
          bottom: BorderSide(color: Theme.of(context).dividerColor),
        ),
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left),
            color: AppColors.forestGreenDark,
            onPressed: vm.previousWeek,
            tooltip: context.l10n.weeklyMenuPrevWeek,
          ),
          Expanded(
            child: Text(
              _formatWeekLabel(context, vm.currentWeekStart),
              style: AppTextStyles.titleSmall.copyWith(
                color: AppColors.textDark,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            color: AppColors.forestGreenDark,
            onPressed: vm.nextWeek,
            tooltip: context.l10n.weeklyMenuNextWeek,
          ),
        ],
      ),
    );
  }

  Widget _buildOverflowTray(
    BuildContext context,
    WeeklyMenuPlanViewModel vm,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimensions.spacingMd,
        vertical: AppDimensions.spacingSm,
      ),
      decoration: const BoxDecoration(
        color: AppColors.warningContainer,
        border: Border(
          bottom: BorderSide(color: AppColors.warning, width: 2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.info_outline,
                  size: 14, color: AppColors.warning),
              const SizedBox(width: AppDimensions.spacingXs),
              Text(
                context.l10n.weeklyMenuOverflowTitle,
                style: AppTextStyles.labelSmall.copyWith(
                  color: AppColors.textDark,
                  letterSpacing: 1,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppDimensions.spacingXs),
          Wrap(
            spacing: AppDimensions.spacingXs,
            runSpacing: AppDimensions.spacingXs,
            children: [
              for (final recipe in vm.overflow)
                _buildOverflowChip(context, vm, recipe),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildOverflowChip(
    BuildContext context,
    WeeklyMenuPlanViewModel vm,
    Recipe recipe,
  ) {
    final chip = Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimensions.spacingSm,
        vertical: 4,
      ),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        border: const Border(
          left: BorderSide(color: AppColors.warning, width: 2),
          bottom: BorderSide(color: AppColors.rustLight, width: 2),
        ),
      ),
      child: Text(
        recipe.title.toLowerCase(),
        style: AppTextStyles.labelSmall.copyWith(color: AppColors.textDark),
      ),
    );
    return _wrapAsDraggable(_OverflowPayload(recipe), chip);
  }

  Widget _buildDayRow(
    BuildContext context,
    WeeklyMenuPlanViewModel vm,
    WeeklyMenuPlan plan,
    DayOfWeek day,
    bool isToday,
  ) {
    return Padding(
      padding: const EdgeInsets.only(
        top: AppDimensions.spacingSm,
        left: AppDimensions.spacingMd,
        right: AppDimensions.spacingMd,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildDayHeader(context, day, isToday),
          const SizedBox(height: AppDimensions.spacingXs),
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: _buildSingleSlotCell(
                    context,
                    vm,
                    plan,
                    day,
                    MealSlot.lunch,
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: _buildSingleSlotCell(
                    context,
                    vm,
                    plan,
                    day,
                    MealSlot.middag,
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  flex: 1,
                  child: _buildOvrigtCell(context, vm, plan, day),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDayHeader(BuildContext context, DayOfWeek day, bool isToday) {
    return Container(
      decoration: BoxDecoration(
        border: Border(
          left: BorderSide(
            color: isToday ? AppColors.forestGreen : AppColors.rust,
            width: 3,
          ),
        ),
      ),
      padding: const EdgeInsets.only(left: AppDimensions.spacingSm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          Text(
            day.displayLabel.toUpperCase(),
            style: AppTextStyles.labelMedium.copyWith(
              letterSpacing: 2,
              fontWeight: FontWeight.w700,
              color: isToday ? AppColors.forestGreenDark : AppColors.textDark,
            ),
          ),
          if (isToday) ...[
            const SizedBox(width: AppDimensions.spacingSm),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              color: AppColors.forestGreen.withValues(alpha: 0.12),
              child: Text(
                context.l10n.weeklyMenuTodayBadge,
                style: AppTextStyles.labelSmall.copyWith(
                  color: AppColors.forestGreenDark,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSingleSlotCell(
    BuildContext context,
    WeeklyMenuPlanViewModel vm,
    WeeklyMenuPlan plan,
    DayOfWeek day,
    MealSlot slot,
  ) {
    final entry = plan.entryAt(day, slot);
    final inner = entry == null
        ? _buildEmptySlot(context, vm, day, slot)
        : _buildAssignedSlot(context, vm, entry);
    return _wrapAsDropTarget(
      context: context,
      vm: vm,
      day: day,
      slot: slot,
      child: inner,
    );
  }

  Widget _buildEmptySlot(
    BuildContext context,
    WeeklyMenuPlanViewModel vm,
    DayOfWeek day,
    MealSlot slot,
  ) {
    // BUT-403: `menu-slot-{weekday}-{mealtype}` identifier. Uses the enum
    // `name` so the identifier is stable across locale changes.
    final identifier = 'menu-slot-${day.name}-${slot.name}';
    return Semantics(
      identifier: identifier,
      button: true,
      label: slot.displayLabel,
      child: GestureDetector(
        key: ValueKey('test-$identifier'),
        onTap: () => _onTapEmptySlot(context, vm, day, slot),
        child: Container(
          constraints: const BoxConstraints(minHeight: _kSlotMinHeight),
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            border: Border.all(color: Theme.of(context).dividerColor),
          ),
          child: Stack(
            children: [
              Positioned(
                top: 0,
                left: 0,
                child: _slotLabel(slot.displayLabel, AppColors.textLight),
              ),
              const Center(
                child: Text(
                  '+',
                  style: TextStyle(
                    fontSize: 24,
                    color: AppColors.creamDarker,
                    fontWeight: FontWeight.w300,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAssignedSlot(
    BuildContext context,
    WeeklyMenuPlanViewModel vm,
    WeeklyMenuPlanEntry entry,
  ) {
    final cell = GestureDetector(
      onTap: () => _navigateToRecipe(context, entry.recipeId),
      child: Container(
        constraints: const BoxConstraints(minHeight: _kSlotMinHeight),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          border: _accentedBorder(AppColors.forestGreen),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _slotLabel(entry.slot.displayLabel, AppColors.forestGreenDark),
            const SizedBox(height: 4),
            Container(
              height: 28,
              color: AppColors.cream,
              alignment: Alignment.center,
              child: const Icon(
                Icons.restaurant_outlined,
                size: 18,
                color: AppColors.greenMuted,
              ),
            ),
            const SizedBox(height: 4),
            Expanded(
              child: Text(
                entry.recipeTitle.toLowerCase(),
                style: AppTextStyles.labelSmall.copyWith(
                  fontSize: 9,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textDark,
                  height: 1.15,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
    return _wrapAsDraggable(_MovePayload(entry), cell);
  }

  Widget _buildOvrigtCell(
    BuildContext context,
    WeeklyMenuPlanViewModel vm,
    WeeklyMenuPlan plan,
    DayOfWeek day,
  ) {
    final entries = plan.entriesAt(day, MealSlot.ovrigt);
    final inner = entries.isEmpty
        ? _buildEmptySlot(context, vm, day, MealSlot.ovrigt)
        : Container(
            constraints: const BoxConstraints(minHeight: _kSlotMinHeight),
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.cardWhite,
              border: _accentedBorder(AppColors.rust),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _slotLabel(MealSlot.ovrigt.displayLabel, AppColors.rust),
                const SizedBox(height: 2),
                for (final entry in entries) ...[
                  _buildOvrigtEntry(context, entry),
                  const SizedBox(height: 3),
                ],
                GestureDetector(
                  onTap: () =>
                      _onTapEmptySlot(context, vm, day, MealSlot.ovrigt),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: AppColors.creamDarker,
                      ),
                    ),
                    child: Text(
                      context.l10n.weeklyMenuOvrigtAddMore,
                      textAlign: TextAlign.center,
                      style: AppTextStyles.labelSmall.copyWith(
                        fontSize: 9,
                        color: AppColors.rust,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
    return _wrapAsDropTarget(
      context: context,
      vm: vm,
      day: day,
      slot: MealSlot.ovrigt,
      child: inner,
    );
  }

  Widget _buildOvrigtEntry(
    BuildContext context,
    WeeklyMenuPlanEntry entry,
  ) {
    final chip = GestureDetector(
      onTap: () => _navigateToRecipe(context, entry.recipeId),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
        decoration: const BoxDecoration(
          color: AppColors.cream,
          border: Border(
            left: BorderSide(color: AppColors.rust, width: 2),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 16,
              height: 16,
              color: AppColors.cardWhite,
              alignment: Alignment.center,
              child: const Icon(
                Icons.cake_outlined,
                size: 11,
                color: AppColors.greenMuted,
              ),
            ),
            const SizedBox(width: 3),
            Expanded(
              child: Text(
                entry.recipeTitle.toLowerCase(),
                style: AppTextStyles.labelSmall.copyWith(
                  fontSize: 8,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textDark,
                  height: 1.1,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
    return _wrapAsDraggable(_MovePayload(entry), chip);
  }

  /// Wraps [child] as draggable. On web, uses a short delay (150ms)
  /// instead of the default 500ms so click-and-drag feels responsive.
  Widget _wrapAsDraggable(_CalendarDragPayload payload, Widget child) {
    // Simple label feedback avoids layout issues (Expanded in overlay)
    final label = payload is _MovePayload
        ? payload.entry.recipeTitle
        : payload is _OverflowPayload
            ? payload.recipe.title
            : '?';
    final feedback = Material(
      elevation: 4,
      borderRadius: BorderRadius.circular(AppDimensions.borderRadiusS),
      child: Container(
        width: _kDragFeedbackWidth,
        padding: const EdgeInsets.all(AppDimensions.spacingS),
        decoration: BoxDecoration(
          color: AppColors.cream,
          borderRadius: BorderRadius.circular(AppDimensions.borderRadiusS),
          border: Border.all(color: AppColors.forestGreen),
        ),
        child: Text(
          label.toLowerCase(),
          style: AppTextStyles.labelSmall.copyWith(
            color: AppColors.textDark,
            fontWeight: FontWeight.w600,
          ),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
    final ghost = Opacity(
      opacity: AppDimensions.opacityMediumLight,
      child: child,
    );

    return LongPressDraggable<_CalendarDragPayload>(
      data: payload,
      delay: kIsWeb
          ? const Duration(milliseconds: 150)
          : const Duration(milliseconds: 500),
      onDragStarted: kIsWeb ? null : HapticFeedback.selectionClick,
      feedback: feedback,
      childWhenDragging: ghost,
      child: child,
    );
  }

  /// Wraps any cell in a `DragTarget` that accepts both move (existing
  /// entry being relocated) and overflow (recipe being assigned from the
  /// overflow tray) payloads.
  Widget _wrapAsDropTarget({
    required BuildContext context,
    required WeeklyMenuPlanViewModel vm,
    required DayOfWeek day,
    required MealSlot slot,
    required Widget child,
  }) {
    return DragTarget<_CalendarDragPayload>(
      onWillAcceptWithDetails: (details) {
        final p = details.data;
        // Don't accept self-drop on the same (day, slot).
        if (p is _MovePayload && p.entry.day == day && p.entry.slot == slot) {
          return false;
        }
        return true;
      },
      onAcceptWithDetails: (details) async {
        HapticFeedback.lightImpact();
        final p = details.data;
        if (p is _MovePayload) {
          await vm.moveEntry(
            entryId: p.entry.id,
            toDay: day,
            toSlot: slot,
          );
        } else if (p is _OverflowPayload) {
          await vm.assignFromOverflow(
            recipe: p.recipe,
            day: day,
            slot: slot,
          );
        }
      },
      builder: (context, candidate, rejected) {
        if (candidate.isEmpty) return child;
        return DecoratedBox(
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.rust, width: 2),
            color: AppColors.rust.withValues(alpha: 0.06),
          ),
          child: child,
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

/// Sealed payload type for drag-and-drop in the calendar.
/// `_MovePayload` carries an existing entry being relocated; `_OverflowPayload`
/// carries a recipe being assigned from the overflow tray.
sealed class _CalendarDragPayload {}

class _MovePayload extends _CalendarDragPayload {
  final WeeklyMenuPlanEntry entry;
  _MovePayload(this.entry);
}

class _OverflowPayload extends _CalendarDragPayload {
  final Recipe recipe;
  _OverflowPayload(this.recipe);
}
