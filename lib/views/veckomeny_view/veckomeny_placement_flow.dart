import 'package:clock/clock.dart';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:butlery/views/veckomeny_view/veckomeny_notices.dart';
import 'package:butlery/widgets/common/dialogs/butlery_dialog.dart';
import 'package:provider/provider.dart';

import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/core/utils/snackbar_utils.dart';
import 'package:butlery/viewmodels/menu/menu_placement_viewmodel.dart'
    show PlacementSaveResult;
import 'package:butlery/viewmodels/menu/weekly_menu_plan_viewmodel.dart';
import 'package:butlery/viewmodels/menu_viewmodel.dart';
import 'package:butlery/views/menu_placement_view.dart';
import 'package:butlery/widgets/menu/veckomeny_selection_widgets.dart';

/// The generate, place and reveal steps of the week menu screen.
mixin VeckomenyPlacementFlow<T extends StatefulWidget> on State<T> {
  VeckomenyViewMode get viewMode;
  TextEditingController get promptController;
  FocusNode get promptFocusNode;
  Future<void> setViewMode(VeckomenyViewMode mode);
  void markRevealing();

  Future<void> generateMenu() async {
    final menuVm = context.read<MenuViewModel>();
    final calendarVm = context.read<WeeklyMenuPlanViewModel>();

    // P6-U01: offline, generation is switched off.
    // The button is already off with its reason; this keeps a stale tap from
    // starting anything.
    if (!VeckomenyConnectivity.isOnlineNow()) return;

    // The menu is placed in the current week, so its who's-home weighs the
    // dishes, not that of a week the user browsed to.
    await calendarVm.loadWeek(clock.now());
    if (!mounted) return;

    // If we're in calendar mode and the visible week already has entries,
    // confirm before overwriting.
    if (viewMode == VeckomenyViewMode.kalender && calendarVm.hasEntries) {
      final confirmed = await confirmOverwrite();
      if (!confirmed || !mounted) return;
    }

    // BUT-2157: a cancelled run places nothing, so the week stays as it was.
    final end = await menuVm.generateMenu(promptController.text);
    if (!mounted || end != MenuGenerationEnd.completed) return;

    // P6-U01: "Inga recept matchar" is drawn in Lista
    // so a calendar-mode generation that matched nothing
    // goes there to say so. The week is untouched.
    if (viewMode == VeckomenyViewMode.kalender &&
        menuVm.noMatchOutcome != null) {
      await setViewMode(VeckomenyViewMode.lista);
      return;
    }

    // P6-U01: offline during generation. The flow's "avbrutet, tidigare
    // vecka orörd": nothing is placed, the saved
    // week stays as it was, and the suggestion waits in Lista.
    if (viewMode == VeckomenyViewMode.kalender &&
        menuVm.hasMenu &&
        !VeckomenyConnectivity.isOnlineNow()) {
      await setViewMode(VeckomenyViewMode.lista);
      if (!mounted) return;
      SnackBarUtils.showInfo(
        context,
        context.l10n.menuGenerateOfflineStopped,
        showCloseButton: true,
      );
      return;
    }

    if (menuVm.hasMenu && !menuVm.hasError) {
      markRevealing();
    }

    if (viewMode == VeckomenyViewMode.kalender && menuVm.hasMenu) {
      // Overwrite was already confirmed above.
      //
      // BUT-2129: announced at the publish, not at the ack. Reading the return
      // value left this path silent offline — the save never acks, so the
      // confirmation never arrived over a week the user could already see.
      await applyGeneratedToCalendar(
        skipConfirm: true,
        onPublished: (placed) {
          // BUT-2157: once the suggestion is in the week it is no longer a
          // draft.
          unawaited(menuVm.markDraftSaved());
          if (!mounted) return;
          if (placed > 0) showAutoPlacedToast(placed);
        },
      );
    }
  }

  /// BUT-2157: "Avbryt planeringen" puts the earlier screen back and hands
  /// focus to the prompt, the way on from there.
  void cancelPlanning() {
    context.read<MenuViewModel>().cancelGeneration();
    // The prompt is switched off while planning; it takes focus once the
    // rebuild has switched it on again.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) promptFocusNode.requestFocus();
    });
  }

  /// BUT-1241: auto-distribute the generated menu onto the CURRENT week —
  /// the same week the calendar opens on. Confirms overwrite when the week already has
  /// entries, threads the parsed day pins, and surfaces failures here
  /// (lista mode never renders the calendar VM's error state). Returns the
  /// placed count, or null when cancelled / failed / nothing to place.
  Future<int?> applyGeneratedToCalendar({
    bool skipConfirm = false,
    void Function(int placed)? onPublished,
  }) async {
    final menuVm = context.read<MenuViewModel>();
    final calendarVm = context.read<WeeklyMenuPlanViewModel>();
    if (!menuVm.hasMenu) return null;
    await calendarVm.loadWeek(clock.now());
    if (!mounted) return null;
    if (!skipConfirm && calendarVm.hasEntries) {
      final confirmed = await confirmOverwrite();
      if (!confirmed || !mounted) return null;
    }
    final parsed = await menuVm.parsedRequestForLastPrompt();
    if (!mounted) return null;
    final placed = await calendarVm.applyGeneratedMenu(
      menuVm.menu,
      replaceExisting: true,
      parsedRequest: parsed,
      onPublished: onPublished,
    );
    if (placed == null && mounted) {
      final error = calendarVm.error;
      if (error != null) {
        showWeekPlacementFailure(
          context,
          what: error,
          weekUnchanged: calendarVm.lastApplyLeftWeekUnchanged,
          // The retry asks again whenever the week holds entries. The first
          // confirmation covered the week as it was then; by now the user may
          // have changed it (the rollback is skipped when they moved on), or
          // an empty week may have been filled. Overwriting always asks
          // (content-style-guide.md, "Behåll min vecka / Skriv över").
          onRetry: () => unawaited(
            applyGeneratedToCalendar(onPublished: onPublished),
          ),
        );
      }
    }
    return placed;
  }

  /// Footer primary action: auto-place, switch to kalender, offer ÄNDRA.
  ///
  /// BUT-2124: both happen at PUBLISH, not at the save's ack. Offline the ack
  /// never comes, so the old order left the user in list mode watching a
  /// spinner while the week sat finished underneath it.
  Future<void> onPlaceAutomatically() async {
    final menuVm = context.read<MenuViewModel>();
    await applyGeneratedToCalendar(
      onPublished: (placed) {
        unawaited(menuVm.markDraftSaved());
        if (!mounted) return;
        unawaited(setViewMode(VeckomenyViewMode.kalender));
        // placed == 0 (everything overflowed) skips the toast — the calendar's
        // overflow tray explains the outcome better than a "0 placed" snackbar.
        if (placed > 0) showAutoPlacedToast(placed);
      },
    );
  }

  void showAutoPlacedToast(int placed) {
    UndoSnackBar.capture(context).showReceipt(
      context.l10n.menuAutoPlacedToast(placed),
      actionLabel: context.l10n.menuAutoPlacedChangeAction,
      onAction: () => unawaited(openPlacement(redoAuto: true)),
    );
  }

  /// Opens the manual placement mode (BUT-1241). [redoAuto] is the ÄNDRA
  /// path: the working week starts empty because the saved plan holds the
  /// auto layout being redone (same replace semantics the auto path used).
  Future<void> openPlacement({required bool redoAuto}) async {
    if (!mounted) return;
    final menuVm = context.read<MenuViewModel>();
    final calendarVm = context.read<WeeklyMenuPlanViewModel>();
    if (!menuVm.hasMenu) return;
    final parsed = await menuVm.parsedRequestForLastPrompt();
    if (!mounted) return;
    final result = await Navigator.of(context).push<PlacementSaveResult>(
      MaterialPageRoute(
        builder: (_) => MenuPlacementView(
          generated: menuVm.menu,
          weekStart: calendarVm.currentWeekStart,
          parsedRequest: parsed,
          startFromEmptyWeek: redoAuto,
        ),
      ),
    );
    if (result == null || !mounted) return;
    unawaited(menuVm.markDraftSaved());
    // Adopt the just-persisted plan instead of re-reading it from
    // Firestore; the session ids give manual placements the same NY-badge
    // treatment as auto-distribution.
    calendarVm.adoptPlan(
      result.plan,
      recentlyPlacedEntryIds: result.sessionEntryIds,
    );
    await setViewMode(VeckomenyViewMode.kalender);
    if (!mounted) return;
    SnackBarUtils.showSuccess(
      context,
      context.l10n.menuPlacementSaved(result.placed),
    );
  }

  Future<bool> confirmOverwrite() async {
    final result = await showButleryDialog<bool>(
      context: context,
      builder: (context) => ButleryDialog.confirm(
        title: context.l10n.weeklyMenuOverwriteConfirm,
        primaryLabel: context.l10n.commonContinue,
      ),
    );
    return result ?? false;
  }
}
