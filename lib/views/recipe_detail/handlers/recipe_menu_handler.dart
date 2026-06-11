// lib/views/recipe_detail/handlers/recipe_menu_handler.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/core/utils/snackbar_utils.dart';
import 'package:butlery/services/menu/weekly_menu_plan_service.dart';
import 'package:butlery/viewmodels/recipe_detail_viewmodel.dart';
import 'package:butlery/widgets/common/dialogs/slot_picker_dialog.dart';

/// BUT-999: weekly-menu action handler for the recipe detail view.
///
/// Opens the multi-select slot picker, then places the current recipe on
/// every chosen (day, slot) target via
/// `WeeklyMenuPlanService.assignRecipeToTargets` — ONE batched save for N
/// targets. Picking a single target behaves like a plain single add.
class RecipeMenuHandler {
  static Future<void> addToMenu(BuildContext context) async {
    final recipe = context.read<RecipeDetailViewModel>().recipe;

    // Null = cancelled. A non-null selection always has >=1 target (the
    // confirm button is disabled at 0); the service short-circuits empty
    // lists anyway.
    final selection = await showMultiSlotPickerDialog(context);
    if (selection == null) return;
    if (!context.mounted) return;

    try {
      final service = ServiceLocator.get<WeeklyMenuPlanService>();
      final added = await service.assignRecipeToTargets(
        weekStart: selection.weekStart,
        recipe: recipe,
        targets: selection.targets,
      );
      if (!context.mounted) return;
      SnackBarUtils.showSuccess(
        context,
        context.l10n.recipeAddedToMenuSlots(added),
      );
    } catch (e) {
      AppLogger.error('Add-to-menu from recipe detail failed', e);
      if (!context.mounted) return;
      SnackBarUtils.showError(
        context,
        SnackBarUtils.userFriendlyMessage(context, e),
      );
    }
  }
}
