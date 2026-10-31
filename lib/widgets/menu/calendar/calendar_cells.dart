/// The week table: a header row naming the meals, then one row per day with
/// lunch, middag and övrigt as cells.
///
/// Extracted from `calendar_weekly_menu_widget.dart` (BUT-542). The cells
/// themselves are in `calendar_slot_cells.dart` and their marks in
/// `calendar_markers.dart`; every callback is injected.
/// Week-nav header + overflow tray live in `calendar_header.dart`.
library;

import 'package:flutter/material.dart';

import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/models/household_roster_member.dart';
import 'package:butlery/models/menu/weekly_menu_plan.dart';
import 'package:butlery/viewmodels/menu/weekly_menu_plan_viewmodel.dart';
import 'package:butlery/widgets/menu/calendar/calendar_drag.dart';
import 'package:butlery/widgets/menu/calendar/calendar_markers.dart';
import 'package:butlery/widgets/menu/calendar/calendar_slot_cells.dart';
import 'package:butlery/widgets/menu/calendar/calendar_week_grid.dart';

export 'package:butlery/widgets/menu/calendar/calendar_slot_cells.dart'
    show PresenceTapCallback, RecipeNavCallback, SlotTapCallback;

class CalendarWeekTable extends StatelessWidget {
  const CalendarWeekTable({
    super.key,
    required this.vm,
    required this.plan,
    required this.todayIndex,
    required this.roster,
    required this.onTapEmptySlot,
    required this.onTapRecipe,
    required this.onTapOvrigt,
    required this.onTapPresence,
  });

  final WeeklyMenuPlanViewModel vm;
  final WeeklyMenuPlan plan;

  /// -1 when the visible week is not the current one.
  final int todayIndex;

  /// Empty for a solo account, which hides all presence UI.
  final List<HouseholdRosterMember> roster;
  final SlotTapCallback onTapEmptySlot;
  final RecipeNavCallback onTapRecipe;
  final void Function(DayOfWeek day) onTapOvrigt;
  final PresenceTapCallback onTapPresence;

  bool get _family => roster.length > 1;

  @override
  Widget build(BuildContext context) {
    final entries = plan.entries;
    final showPresence =
        _family &&
        DayOfWeek.values.any(
          (d) =>
              kPresenceSlots.any((s) => plan.presentMemberIdsFor(d, s) != null),
        );
    return CalendarWeekGrid(
      weekStart: plan.weekStartDate,
      todayIndex: todayIndex,
      cellBuilder: (context, day, slot) => _DayCells(
        vm: vm,
        plan: plan,
        day: day,
        family: _family,
        roster: roster,
        onTapEmptySlot: onTapEmptySlot,
        onTapRecipe: onTapRecipe,
        onTapOvrigt: onTapOvrigt,
        onTapPresence: onTapPresence,
      ).cell(context, slot),
      footer: CalendarLegend(
        showNew: entries.any((e) => vm.isRecentlyPlaced(e.id)),
        showAllergen: entries.any((e) => vm.isAllergenUnsafe(e.id)),
        showPresence: showPresence,
      ),
    );
  }
}

/// The cells of one day, built from the plan and the view model.
class _DayCells {
  const _DayCells({
    required this.vm,
    required this.plan,
    required this.day,
    required this.family,
    required this.roster,
    required this.onTapEmptySlot,
    required this.onTapRecipe,
    required this.onTapOvrigt,
    required this.onTapPresence,
  });

  final WeeklyMenuPlanViewModel vm;
  final WeeklyMenuPlan plan;
  final DayOfWeek day;
  final bool family;
  final List<HouseholdRosterMember> roster;
  final SlotTapCallback onTapEmptySlot;
  final RecipeNavCallback onTapRecipe;
  final void Function(DayOfWeek day) onTapOvrigt;
  final PresenceTapCallback onTapPresence;

  Widget cell(BuildContext context, MealSlot slot) =>
      slot == MealSlot.ovrigt ? _ovrigtCell(context) : _mealCell(context, slot);

  /// Members home for this meal, or null when it is everyone (or a solo
  /// account), so only a deviation is marked.
  int? _presentCount(MealSlot slot) {
    if (!family) return null;
    final ids = plan.presentMemberIdsFor(day, slot);
    if (ids == null) return null;
    return roster.where((m) => ids.contains(m.memberId)).length;
  }

  Widget _mealCell(BuildContext context, MealSlot slot) {
    final entry = plan.entryAt(day, slot);
    if (entry == null) {
      return wrapAsDropTarget(
        context: context,
        vm: vm,
        day: day,
        slot: slot,
        child: CalendarEmptyCell(
          day: day,
          slot: slot,
          onTap: onTapEmptySlot,
          // Presence can be set before a dish exists, but a tap on the plus
          // adds a dish, so who is home is a long press here.
          onLongPress: family && !vm.selectionMode
              ? () => onTapPresence(day, slot)
              : null,
        ),
      );
    }
    final present = _presentCount(slot);
    final order = vm.placementOrderOf(entry.id);
    final selecting = vm.selectionMode;
    final l10n = context.l10n;
    return wrapAsDropTarget(
      context: context,
      vm: vm,
      day: day,
      slot: slot,
      child: CalendarDishCell(
        title: vm.entryTitle(entry),
        marks: CalendarCellMarks(
          isNew: vm.isRecentlyPlaced(entry.id),
          allergenUnsafe: vm.isAllergenUnsafe(entry.id),
          presentCount: present,
          placementOrder: order,
        ),
        semanticsLabel: selecting
            ? l10n.a11yWeeklyMenuSelectEntry
            : family
            ? l10n.a11yMenuSlotPresence(slot.displayLabel, day.displayLabel)
            : l10n.a11yMenuPlanRecipeOpen,
        semanticsValue: order == null
            ? null
            : l10n.a11yWeeklyMenuPlacementOrder(order),
        selectionMode: selecting,
        selected: vm.isSelected(entry.id),
        onTap: () {
          if (selecting) {
            vm.toggleSelection(entry.id);
          } else if (family) {
            onTapPresence(day, slot);
          } else {
            onTapRecipe(entry.recipeId);
          }
        },
        dragPayload: MovePayload(entry, title: vm.entryTitle(entry)),
      ),
    );
  }

  Widget _ovrigtCell(BuildContext context) {
    final entries = plan.entriesAt(day, MealSlot.ovrigt);
    if (entries.isEmpty) {
      return wrapAsDropTarget(
        context: context,
        vm: vm,
        day: day,
        slot: MealSlot.ovrigt,
        child: CalendarEmptyCell(
          day: day,
          slot: MealSlot.ovrigt,
          onTap: onTapEmptySlot,
        ),
      );
    }
    final selecting = vm.selectionMode;
    final allSelected = entries.every((e) => vm.isSelected(e.id));
    final order = entries
        .map((e) => vm.placementOrderOf(e.id))
        .whereType<int>()
        .firstOrNull;
    final l10n = context.l10n;
    return wrapAsDropTarget(
      context: context,
      vm: vm,
      day: day,
      slot: MealSlot.ovrigt,
      child: CalendarDishCell(
        title: vm.entryTitle(entries.first),
        extraCount: entries.length - 1,
        marks: CalendarCellMarks(
          isNew: entries.any((e) => vm.isRecentlyPlaced(e.id)),
          allergenUnsafe: entries.any((e) => vm.isAllergenUnsafe(e.id)),
          placementOrder: order,
        ),
        semanticsLabel: selecting
            ? l10n.a11yWeeklyMenuSelectEntry
            : l10n.a11yWeeklyMenuOpenOvrigt(day.displayLabel),
        semanticsValue: order == null
            ? null
            : l10n.a11yWeeklyMenuPlacementOrder(order),
        selectionMode: selecting,
        selected: allSelected,
        onTap: () {
          if (!selecting) return onTapOvrigt(day);
          // One tap chooses or clears every dish in the place.
          for (final e in entries) {
            if (vm.isSelected(e.id) == allSelected) vm.toggleSelection(e.id);
          }
        },
        dragPayload: entries.length == 1
            ? MovePayload(entries.first, title: vm.entryTitle(entries.first))
            : null,
      ),
    );
  }
}
