// BUT-1029: reusable picker for choosing a (weekStart, day, slot) target
// in the weekly menu plan. Built as a bottom sheet to match the wave-16
// `_BulkTagPicker` design language (DraggableScrollableSheet, square
// chips, top handle bar).
//
// BUT-999 adds a multi-select mode (`showMultiSlotPickerDialog`): cells
// toggle checkbox-style and a pinned confirm button returns ALL selected
// (day, slot) targets for the visible week in one go.

import 'package:flutter/material.dart';
import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/widgets/common/icons/butlery_glyph.dart';
import 'package:butlery/widgets/common/icons/butlery_icons.dart';
import 'package:butlery/widgets/common/state_widget.dart';
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/core/utils/iso_week_utils.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/models/menu/weekly_menu_plan.dart';
import 'package:butlery/services/menu/weekly_menu_plan_service.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/widgets/common/press_fill.dart';
import 'package:butlery/widgets/common/dialogs/slot_spill_panel.dart';
import 'package:clock/clock.dart';

/// BUT-2153: what happens to the recipes the week cannot hold: nothing to
/// decide, the rest from Monday of the next week, or only what fits.
enum SlotSpill { none, nextWeek, dropRest }

/// A single placement target in the weekly plan, plus the choice for any
/// recipes that do not fit from it.
typedef SlotSelection = ({
  DateTime weekStart,
  DayOfWeek day,
  MealSlot slot,
  SlotSpill spill,
});

/// BUT-999: multi-select result — every chosen (day, slot) target within
/// one week. Targets always share [weekStart] so the service can persist
/// them with a single batched save.
typedef MultiSlotSelection = ({DateTime weekStart, List<SlotTarget> targets});

/// Imperative entry point for the slot picker. Returns the user's choice or
/// null if they cancelled. [recipeTitles] are the recipes about to be placed,
/// in order; with them the picker asks before a week overflows.
Future<SlotSelection?> showSlotPickerDialog(
  BuildContext context, {
  List<String> recipeTitles = const [],
}) {
  return showModalBottomSheet<SlotSelection>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => SlotPickerDialog(recipeTitles: recipeTitles),
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

  /// Single-select only: the recipes to be placed from the tapped cell.
  final List<String> recipeTitles;

  const SlotPickerDialog({
    super.key,
    this.multiSelect = false,
    this.recipeTitles = const [],
  });

  /// The days a run starting at [day] fills, in order: free cells from
  /// [day] to Sunday, the way `WeeklyMenuPlanService.bulkAssignRecipes`
  /// walks them.
  static List<DayOfWeek> freeDaysFrom(
    WeeklyMenuPlan plan,
    DayOfWeek day,
    MealSlot slot,
  ) => [
    for (final d in DayOfWeek.values)
      if (d.index >= day.index && plan.entriesAt(d, slot).isEmpty) d,
  ];

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
  SlotTarget? _spillStart;

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
    _spillStart = null;
    _loadWeek();
  }

  void _goToPreviousWeek() {
    _visibleWeekStart = _visibleWeekStart.subtract(const Duration(days: 7));
    _selected.clear();
    _spillStart = null;
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
    final plan = _plan;
    final fits = plan == null
        ? 0
        : SlotPickerDialog.freeDaysFrom(plan, day, slot).length;
    if (!slot.isMulti && widget.recipeTitles.length > fits) {
      setState(() => _spillStart = (day: day, slot: slot));
      return;
    }
    _popSingle(day, slot, SlotSpill.none);
  }

  void _popSingle(DayOfWeek day, MealSlot slot, SlotSpill spill) {
    Navigator.of(context).pop(
      (weekStart: _visibleWeekStart, day: day, slot: slot, spill: spill),
    );
  }

  Widget _buildSpillPanel(SlotTarget start, double sheetHeight) {
    final placed = SlotPickerDialog.freeDaysFrom(
      _plan!,
      start.day,
      start.slot,
    ).length;
    return SlotSpillPanel(
      maxHeight: sheetHeight * 0.55,
      placed: placed,
      titles: widget.recipeTitles,
      weekNumber: IsoWeekUtils.isoWeekNumber(_visibleWeekStart),
      nextWeekNumber: IsoWeekUtils.isoWeekNumber(
        _visibleWeekStart.add(const Duration(days: 7)),
      ),
      onNextWeek: () => _popSingle(start.day, start.slot, SlotSpill.nextWeek),
      onChooseMore: () => setState(() => _spillStart = null),
      onPlaceOnly: () => _popSingle(start.day, start.slot, SlotSpill.dropRest),
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
      builder: (sheetContext, scrollController) => LayoutBuilder(
        builder: (context, box) {
          final cs = Theme.of(context).colorScheme;
          return DecoratedBox(
            decoration: BoxDecoration(
              color: Theme.of(context).scaffoldBackgroundColor,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(AppDimensions.radiusCard),
              ),
            ),
            child: Column(
              children: [
                Container(
                  margin: const EdgeInsets.only(top: AppDimensions.paddingM),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: cs.onSurfaceVariant,
                    borderRadius: BorderRadius.circular(
                      AppDimensions.radiusKnob,
                    ),
                  ),
                ),
                _buildHeader(cs),
                const Divider(height: 1),
                Expanded(child: _buildBody(scrollController)),
                if (widget.multiSelect) _buildConfirmBar(),
                if (_spillStart case final start? when _plan != null)
                  _buildSpillPanel(start, box.maxHeight),
              ],
            ),
          );
        },
      ),
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
      // The week stepper has its own row: beside the title on a 360 dp phone
      // it squeezed the title to a column of single words.
      child: Column(
        children: [
          Row(
            children: [
              const ButleryIcon(ButleryIcons.calendar),
              const SizedBox(width: AppDimensions.spacingSm),
              Expanded(
                child: Text(
                  context.l10n.slotPickerDialogTitle,
                  style: AppTextStyles.titleLarge,
                ),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text(context.l10n.commonCancel),
              ),
            ],
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                icon: const ButleryIcon(ButleryIcons.chevronLeft),
                tooltip: context.l10n.slotPickerPreviousWeek,
                onPressed: _isLoading ? null : _goToPreviousWeek,
              ),
              Text(weekLabel, style: AppTextStyles.bodyMedium),
              IconButton(
                icon: const ButleryIcon(ButleryIcons.chevronRight),
                tooltip: context.l10n.slotPickerNextWeek,
                onPressed: _isLoading ? null : _goToNextWeek,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBody(ScrollController scrollController) {
    if (_isLoading) {
      // The plate line with what is being fetched, never a spinner
      // (produktregler.md:163, B-18; beslutslogg.md:25).
      return StateWidget.loading(message: context.l10n.loadingWeeklyMenu);
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
          style: AppTextStyles.titleMedium.copyWith(color: cs.onSurface),
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
    // BUT-2153: the order is shown, so the result is not a guess that only
    // shows up in the weekly menu.
    final spillStart = _spillStart;
    final order = spillStart != null && spillStart.slot == slot
        ? SlotPickerDialog.freeDaysFrom(plan, spillStart.day, slot).indexOf(day)
        : -1;
    return Semantics(
      label: context.l10n.a11ySlotPickerCell(slot.displayLabel),
      button: true,
      selected: widget.multiSelect ? isSelected : null,
      child: Material(
        type: MaterialType.transparency,
        child: PressFill(
          surface: (isSelected || isOccupied)
              ? PressSurface.raised
              : PressSurface.base,
          child: InkWell(
            onTap: () => _selectSlot(day, slot),
            child: Ink(
              height: 64,
              decoration: BoxDecoration(
                // Square per design language.
                borderRadius: BorderRadius.zero,
                color: (isSelected || isOccupied)
                    ? cs.primaryContainer
                    : cs.surface,
              ),
              child: Container(
                padding: const EdgeInsets.all(AppDimensions.spacingXs),
                decoration: BoxDecoration(
                  // A chosen slot is surface.selected with a 1.5 px text.primary
                  // border; an occupied one surface.raised with border.control.
                  // Never a tint.
                  // primaryContainer / onSurface / outline carry the tokens in
                  // both schemes.
                  border: Border.all(
                    color: isSelected
                        ? cs.onSurface
                        : isOccupied
                        ? cs.outline
                        : cs.outlineVariant,
                    width: isSelected ? 1.5 : 1,
                  ),
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
                          ButleryIcon(
                            isSelected
                                ? ButleryIcons.checkSquare
                                : ButleryIcons.square,
                            size: AppDimensions.iconSize18,
                            color: isSelected
                                ? cs.onSurface
                                : cs.onSurfaceVariant,
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
                          : order >= 0 && order < widget.recipeTitles.length
                          ? Text(
                              '${order + 1}',
                              style: AppTextStyles.titleMedium,
                            )
                          : widget.multiSelect
                          ? const SizedBox.shrink()
                          : ButleryIcon(
                              ButleryIcons.plus,
                              size: AppDimensions.iconSize18,
                              color: cs.onSurfaceVariant,
                            ),
                    ),
                  ],
                ),
              ),
            ),
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
