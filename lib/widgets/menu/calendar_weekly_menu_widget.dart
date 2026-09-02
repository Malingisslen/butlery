/// Calendar view for the weekly menu plan. Embedded in `VeckomenyView`
/// when the user toggles "Kalender". Renders the 7-day grid, overflow tray,
/// week-nav header, and the loading/error/empty/data states, with drag-drop
/// between cells.
///
/// BUT-542: cell rendering + drag/drop machinery extracted to
/// `lib/widgets/menu/calendar/`. This file is the orchestrator only.
library;

import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/core/utils/iso_week_utils.dart';
import 'package:butlery/core/utils/snackbar_utils.dart';
import 'package:butlery/models/household_roster_member.dart';
import 'package:butlery/models/menu/weekly_menu_plan.dart';
import 'package:butlery/repositories/interfaces/household_repository.dart';
import 'package:butlery/services/family/household_roster_service.dart';
import 'package:butlery/services/permission_service.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/viewmodels/menu/weekly_menu_plan_viewmodel.dart';
import 'package:butlery/views/family/who_is_eating_sheet.dart';
import 'package:butlery/widgets/common/dialogs/recipe_selection_dialogs.dart';
import 'package:butlery/widgets/common/loading_state_builder.dart';
import 'package:butlery/widgets/common/state_widget.dart';
import 'package:butlery/widgets/menu/calendar/calendar_cells.dart';
import 'package:butlery/widgets/menu/calendar/calendar_header.dart';
import 'package:butlery/widgets/menu/calendar/presence_overview.dart';
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

  // BUT-1611: household roster for the per-slot presence faces + overview.
  // Empty for a solo account, which hides all presence UI.
  List<HouseholdRosterMember> _roster = const [];
  bool _overviewExpanded = false;

  @override
  void initState() {
    super.initState();
    _loadRoster();
  }

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

  /// Read-only roster resolution (mirrors the generator's `getForUser` path —
  /// opening the menu must never CREATE a household). Any failure keeps the
  /// presence UI hidden; presence is an optional layer, never a blocker.
  Future<void> _loadRoster() async {
    try {
      final permission = ServiceLocator.tryGet<PermissionService>();
      final householdRepo = ServiceLocator.tryGet<HouseholdRepository>();
      final rosterService = ServiceLocator.tryGet<HouseholdRosterService>();
      final uid = permission?.currentUserId;
      if (uid == null || householdRepo == null || rosterService == null) return;
      final households = await householdRepo.getForUser(uid);
      if (households.isEmpty || !mounted) return;
      final roster = await rosterService.getRoster(households.first.id);
      if (!mounted) return;
      setState(() => _roster = roster);
    } catch (_) {
      // Solo / failed loads render nothing — presence stays invisible.
    }
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<WeeklyMenuPlanViewModel>();
    return LoadingStateBuilder<WeeklyMenuPlan>(
      isLoading: vm.isLoading,
      error: vm.error,
      data: vm.plan,
      loadingMessage: context.l10n.loadingGeneric,
      // The error state replaces the whole calendar, week navigation included,
      // so without this the message's "försök igen" names a control that is not
      // on screen (BUT-1939).
      // `currentWeekStart` answers the REQUESTED week even when its plan failed
      // to load, so this retries the week the user was on rather than today.
      onErrorRetry: () => vm.loadWeek(vm.currentWeekStart),
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
        // BUT-1611: "vem är hemma?" overview — only for a household with family,
        // and never while multi-select is active (that owns the header row).
        if (_roster.length > 1 && !vm.selectionMode)
          PresenceOverview(
            roster: _roster,
            plan: plan,
            expanded: _overviewExpanded,
            onToggleExpanded: () =>
                setState(() => _overviewExpanded = !_overviewExpanded),
          ),
        for (final day in DayOfWeek.values)
          DayCell(
            vm: vm,
            plan: plan,
            day: day,
            isToday: day.index == todayIndex,
            onTapEmptySlot: (d, s) => _onTapEmptySlot(context, vm, d, s),
            onTapRecipe: (id, {presentServings}) => _navigateToRecipe(
              context,
              id,
              presentServings: presentServings,
            ),
            roster: _roster,
            onTapPresence: (d, s) => _onTapPresence(context, vm, d, s),
          ),
      ],
    );
  }

  Future<void> _onClearWeek(
    BuildContext context,
    WeeklyMenuPlanViewModel vm,
  ) async {
    final cleared = await vm.clearWeek();
    if (!context.mounted || !cleared) return;
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
        // Stop at the first refusal: each further write clears the error the
        // user needs to read.
        if (!await vm.assignRecipe(day: day, slot: slot, recipe: recipe)) break;
      }
    } else {
      await vm.assignRecipe(day: day, slot: slot, recipe: picked.first);
    }
  }

  /// BUT-1611: tap a slot's presence faces → the seeded "vem är hemma?" sheet,
  /// then persist (one slot, or both on "Hela dagen"). Selecting the whole
  /// roster stores null (the "everyone" default) to keep the map sparse. When
  /// the week already has a generated menu, a discreet notice explains that
  /// placed dishes stay put — presence never reshuffles an existing menu.
  Future<void> _onTapPresence(
    BuildContext context,
    WeeklyMenuPlanViewModel vm,
    DayOfWeek day,
    MealSlot slot,
  ) async {
    final allIds = _roster.map((m) => m.memberId).toList();
    final seed = vm.presentMemberIdsFor(day, slot) ?? allIds;
    final slotLabel = context.l10n.menuPresenceSlotSubtitle(
      slot.displayLabel,
      day.displayLabel,
    );
    final result = await showWhoIsHomeSheet(
      context,
      slotLabel: slotLabel,
      seedMemberIds: seed,
    );
    if (result == null || result.skipped || !context.mounted) return;

    final hadMenu = vm.hasEntries;
    final picked = result.attendeeMemberIds;
    // Full roster selected = the "everyone" default → store null (unset).
    final everyone =
        picked.length == allIds.length && picked.toSet().containsAll(allIds);
    final toStore = everyone ? null : picked;

    // BUT-1982: gated on the outcome, the same way `_onClearWeek` is. A refused
    // save already paints the error state, so announcing success over it told
    // the user their attendance was stored when it was not.
    // No undo affordance here on purpose — that belongs to `clearWeek`, which
    // is a different recoverability class.
    final saved = result.applyToWholeDay
        ? await vm.setDayPresence(day, toStore)
        : await vm.setSlotPresence(day, slot, toStore);
    if (!context.mounted || !saved || !hadMenu) return;
    SnackBarUtils.showSuccess(
      context,
      context.l10n.menuPresenceAfterGenerateNotice,
    );
  }

  Future<void> _navigateToRecipe(
    BuildContext context,
    String recipeId, {
    int? presentServings,
  }) async {
    final vm = context.read<WeeklyMenuPlanViewModel>();
    final recipe = vm.resolveForNavigation(recipeId);
    if (recipe != null && context.mounted) {
      await Navigator.of(context).pushNamed(
        '/recipe-detail',
        // BUT-1613: carry the present count via the map form so recipe detail
        // can forward it to cooking mode. Bare-Recipe form kept when there's no
        // presence, so the 8+ other recipe-detail callers are untouched.
        arguments: presentServings == null
            ? recipe
            : {'recipe': recipe, 'presentServings': presentServings},
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
