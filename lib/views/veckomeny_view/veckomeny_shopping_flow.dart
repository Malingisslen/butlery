import 'package:clock/clock.dart';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:butlery/views/veckomeny_view/veckomeny_notices.dart';
import 'package:provider/provider.dart';

import 'package:butlery/core/constants/routes.dart';
import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/core/utils/snackbar_utils.dart';
import 'package:butlery/services/shopping/menu_shopping_list_generator.dart';
import 'package:butlery/viewmodels/menu/weekly_menu_plan_viewmodel.dart';
import 'package:butlery/viewmodels/menu_viewmodel.dart';
import 'package:butlery/widgets/menu/shopping_merge_sheet.dart';
import 'package:butlery/widgets/menu/veckomeny_selection_widgets.dart';

/// The week menu screen's shopping merge, from the footer button to Ångra.
mixin VeckomenyShoppingFlow<T extends StatefulWidget> on State<T> {
  VeckomenyViewMode get viewMode;

  /// P6-U02: flow 02. Calendar mode merges the visible week's plan; list mode
  /// merges the generated menu into the current week's list.
  ///
  /// Three outcomes stay apart:
  /// nothing to generate (a warning), failed (what happened, what is kept,
  /// Försök igen) and already running (silence). A confirmed merge opens the
  /// list and offers Ångra for 7 s.
  ///
  /// One flow at a time, from the tap until the sheet has closed and the
  /// write has finished (WeeklyMenuPlanViewModel.runShoppingFlow): a second
  /// tap during the week or pantry read opens no second sheet.
  Future<void> openShoppingMerge() =>
      context.read<WeeklyMenuPlanViewModel>().runShoppingFlow(runShoppingMerge);

  Future<void> runShoppingMerge() async {
    final planVm = context.read<WeeklyMenuPlanViewModel>();
    final menuVm = context.read<MenuViewModel>();
    final source = viewMode == VeckomenyViewMode.kalender
        ? await planVm.shoppingSource()
        : MenuShoppingListGenerator.sourceForMenu(menuVm.menu, clock.now());
    if (!mounted) return;
    if (source == null) {
      showWeekShoppingListFailure(
        context,
        onRetry: () => unawaited(openShoppingMerge()),
      );
      return;
    }
    if (source.isEmpty) {
      SnackBarUtils.showWarning(
        context,
        context.l10n.menuShoppingListGenerationEmpty,
      );
      return;
    }
    final pantry = await planVm.readPantryForShopping();
    if (!mounted) return;
    final merge = await showShoppingMergeSheet(
      context,
      source: source,
      pantry: pantry,
      retryPantry: planVm.readPantryForShopping,
      updatesList: planVm.shoppingListHasRowsFrom(source),
    );
    if (merge == null || !mounted) return;
    final receipt = await planVm.applyShoppingMerge(merge);
    if (!mounted) return;
    if (identical(receipt, shoppingMergeAlreadyRunning)) return;
    if (receipt == null) {
      showWeekShoppingListFailure(
        context,
        onRetry: () => unawaited(openShoppingMerge()),
      );
      return;
    }
    // The list itself is the confirmation (BUT-900); the receipt rides on
    // the root messenger above it. SnackbarRouteObserver clears snackbars on
    // every push, so the receipt is shown after the push.
    unawaited(Navigator.pushNamed(context, Routes.shoppingList));
    showShoppingMergeReceipt(
      context,
      receipt,
      onUndo: () => unawaited(undoShoppingMerge(planVm, receipt)),
    );
  }

  /// Ångra failed: says so, and that the rows are still on the list.
  Future<void> undoShoppingMerge(
    WeeklyMenuPlanViewModel planVm,
    MenuShoppingMergeReceipt receipt,
  ) async {
    final undone = await planVm.undoShoppingMerge(receipt);
    if (undone || !mounted) return;
    SnackBarUtils.showFailure(
      context,
      what: context.l10n.shoppingMergeUndoFailed,
      preserved: context.l10n.shoppingMergeUndoFailedKept,
    );
  }
}
