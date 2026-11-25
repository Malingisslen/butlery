/// Opening a lunch place's lunchbox sheet and acting on its answer
/// (BUT-2486). Lives beside the calendar orchestrator so the orchestrator
/// only wires it.
library;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:butlery/core/extensions/default_value_extensions.dart';
import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/core/utils/snackbar_utils.dart';
import 'package:butlery/models/household_roster_member.dart';
import 'package:butlery/models/menu/weekly_menu_plan.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/viewmodels/menu/weekly_lunchboxes.dart';
import 'package:butlery/viewmodels/menu/weekly_menu_plan_viewmodel.dart';
import 'package:butlery/widgets/common/dialogs/recipe_selection_dialogs.dart';
import 'package:butlery/widgets/menu/calendar/lunchbox_sheet.dart';
import 'package:butlery/widgets/menu/calendar/lunchbox_stock_section.dart';
import 'package:butlery/widgets/menu/manual_add_confirm.dart';

/// Shows [day]'s lunchbox sheet and saves or removes the box it answers
/// with. A dish picked by hand gets the same allergy and dislike question as
/// a dish placed by hand; leftovers from the week's own middag already had
/// it when the middag was placed.
Future<void> openLunchboxFlow(
  BuildContext context, {
  required WeeklyMenuPlanViewModel vm,
  required DayOfWeek day,
  required List<HouseholdRosterMember> roster,
}) async {
  final plan = vm.plan;
  if (plan == null) return;
  final locale = Localizations.localeOf(context).toString();
  final date = plan.weekStartDate.add(Duration(days: day.index));
  final leftoversDay = WeeklyLunchboxes.leftoversDayFor(day);
  final middag = leftoversDay == null
      ? null
      : plan.entryAt(leftoversDay, MealSlot.middag);
  final previous = vm.lunchboxAt(day);
  final result = await showLunchboxSheet(
    context,
    day: day,
    dayName: DateFormat.EEEE(locale).format(date),
    current: previous,
    currentTitle: vm.lunchboxTitle(day),
    leftoversTitle: middag == null ? null : vm.entryTitle(middag),
    suggestions: vm.lunchboxSuggestions,
    roster: roster,
    pickRecipe: _pickRecipe,
    stockBoxes: startLunchboxStockLoad(),
  );
  if (!context.mounted) return;
  switch (result) {
    case LunchboxSheetSave(:final box):
      if (!box.followsMiddag) {
        final recipe = vm.resolveForNavigation(box.recipeId.orEmpty());
        if (recipe != null && !await confirmManualAdd(context, [recipe])) {
          return;
        }
      }
      await vm.setLunchbox(day, box);
    case LunchboxSheetRemove():
      if (previous == null || !await vm.clearLunchbox(day)) return;
      if (!context.mounted) return;
      SnackBarUtils.showUndo(
        context,
        context.l10n.lunchboxRemovedUndo,
        onUndo: () => vm.setLunchbox(day, previous),
      );
    case null:
      break;
  }
}

Future<Recipe?> _pickRecipe(BuildContext context) async {
  final picked = await RecipeSelectionDialogs.showMenuRecipeSelector(
    context,
    categoryName: MealSlot.lunch.displayLabel,
  );
  return picked == null || picked.isEmpty ? null : picked.first;
}
