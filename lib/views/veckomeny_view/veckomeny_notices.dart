import 'dart:async';

import 'package:flutter/material.dart';
import 'package:butlery/widgets/common/buttons/action_buttons.dart';

import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/core/utils/snackbar_utils.dart';
import 'package:butlery/services/realtime/realtime_types.dart';
import 'package:butlery/services/realtime_sync_service.dart';
import 'package:butlery/services/shopping/menu_shopping_list_generator.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/viewmodels/menu/weekly_menu_plan_viewmodel.dart';
import 'package:butlery/viewmodels/menu_viewmodel.dart';
import 'package:butlery/widgets/common/feedback/partial_outcome.dart';
import 'package:butlery/widgets/common/state_widget.dart';
import 'package:butlery/widgets/menu/menu_view_helpers.dart';
import 'package:butlery/widgets/realtime/conflict_snackbar.dart';

/// Instead of looking complete, the result says
/// what it is. The way on is the view's own Generera, which stays.
class VeckomenyPartialResult extends StatelessWidget {
  const VeckomenyPartialResult({super.key, required this.outcome});

  final MenuPartialOutcome outcome;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return PartialOutcome(
      title: l.menuPartialTitle(outcome.found, outcome.requested),
      message: l.menuPartialBody,
      items: [
        for (final meal in outcome.missing)
          PartialOutcomeItem(
            id: 'meal-${meal.mealType}',
            label: MenuViewHelpers.capitalizeCategory(meal.mealType),
            reason: l.menuPartialMissing(
              meal.found,
              meal.requested,
              meal.missing,
            ),
          ),
      ],
    );
  }
}

/// The title "Inga
/// recept matchar", a line with the size of the library, the requirements
/// the prompt was read as, and two ways on.
///
/// Interpretations, recorded: the drawing's "Släpp ett krav" chips and its
/// "Planera utan tidsgräns" rewrite the prompt, which nothing in the app can
/// do yet, so the requirements are named as text and "Ändra beskrivningen"
/// moves focus to the prompt. "Lägg dagarna själv" opens the calendar. Both
/// are outlined, because the view's one primary action is Generera
/// The app has no cookbook illustration, so the
/// empty state's no-search-results illustration stands in.
class VeckomenyNoMatch extends StatelessWidget {
  const VeckomenyNoMatch({
    super.key,
    required this.outcome,
    required this.onEditPrompt,
    required this.onPlanYourself,
  });

  final MenuNoMatchOutcome outcome;
  final VoidCallback onEditPrompt;
  final VoidCallback onPlanYourself;

  static const Key editPromptKey = ValueKey<String>('veckomeny-nomatch-edit');
  static const Key planYourselfKey = ValueKey<String>(
    'veckomeny-nomatch-plan',
  );

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final cs = Theme.of(context).colorScheme;
    return StateWidget(
      type: StateType.empty,
      emptyVariant: EmptyStateVariant.noSearchResults,
      title: l.menuNoMatchTitle,
      subtitle: l.menuNoMatchBody(outcome.poolSize),
      customAction: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (outcome.constraints.isNotEmpty) ...[
            Text(
              l.menuNoMatchConstraints(outcome.constraints.join(', ')),
              textAlign: TextAlign.center,
              // text.secondary in both modes (onSurfaceVariant).
              style: AppTextStyles.captionBase.copyWith(
                color: cs.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: AppDimensions.space16),
          ],
          ActionButtons.outlinedButton(
            context,
            key: editPromptKey,
            label: l.menuNoMatchEditPrompt,
            onPressed: onEditPrompt,
          ),
          const SizedBox(height: AppDimensions.space8),
          ActionButtons.outlinedButton(
            context,
            key: planYourselfKey,
            label: l.menuNoMatchPlanYourself,
            onPressed: onPlanYourself,
          ),
        ],
      ),
    );
  }
}

/// P5-U26a: mounts P3-U08's week conflict snackbar on the week menu.
///
/// [ConflictSnackBar.showWeekSaved] owns the
/// text, the window, the action and the filter (only a week-menu conflict the
/// user's edit lost); this widget only listens to
/// [RealtimeSyncService.conflictStream] while the week menu is open. Without
/// a registered sync service it listens to nothing.
///
/// BUT-2215: it also listens to [weekConflicts], the week menu viewmodel's
/// refused saves of the user's own week, and shows
/// [ConflictSnackBar.showWeekSavedElsewhere] with [onKeepMine] behind
/// "Behåll min".
///
/// BUT-2345: it also says how many kept overflow-tray dishes a restore
/// removed because they no longer pass the household's allergen filter.
class VeckomenyConflictNotice extends StatefulWidget {
  const VeckomenyConflictNotice({
    super.key,
    required this.child,
    this.weekConflicts,
    this.onKeepMine,
    this.trayDroppedAsUnsafe,
  });

  final Widget child;
  final Stream<WeekConflict>? weekConflicts;
  final Future<bool> Function(WeekConflict conflict)? onKeepMine;
  final Stream<int>? trayDroppedAsUnsafe;

  @override
  State<VeckomenyConflictNotice> createState() =>
      _VeckomenyConflictNoticeState();
}

class _VeckomenyConflictNoticeState extends State<VeckomenyConflictNotice> {
  StreamSubscription<ConflictEvent>? _sub;
  StreamSubscription<WeekConflict>? _weekSub;
  StreamSubscription<int>? _traySub;

  @override
  void initState() {
    super.initState();
    final svc = ServiceLocator.tryGet<RealtimeSyncService>();
    _sub = svc?.conflictStream.listen((event) {
      if (!mounted) return;
      ConflictSnackBar.showWeekSaved(context, event);
    });
    _weekSub = widget.weekConflicts?.listen((conflict) {
      final keep = widget.onKeepMine;
      if (!mounted || keep == null) return;
      ConflictSnackBar.showWeekSavedElsewhere(
        context,
        onKeepMine: () => keep(conflict),
      );
    });
    _traySub = widget.trayDroppedAsUnsafe?.listen((count) {
      if (!mounted) return;
      SnackBarUtils.showInfo(
        context,
        context.l10n.weekMenuDraftDropped(count),
      );
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    _weekSub?.cancel();
    _traySub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// P5-U15 (veckogenerering ERROR): placing a generated menu failed.
///
/// Three parts: what happened ([what], the
/// one message of BUT-2132), what was kept, and Försök igen, which places the
/// same menu again. The week is said to be unchanged only when
/// [weekUnchanged] is true: the rollback may have been skipped, and a message
/// claims only an undo that happened.
///
/// The publish-first path may already have put the success toast on screen,
/// with an ÄNDRA that opens placement. A queued error would sit behind it for
/// its full duration, so it is hidden first: the last thing the user reads
/// must not be the one that is no longer true.
void showWeekPlacementFailure(
  BuildContext context, {
  required String what,
  required bool weekUnchanged,
  required VoidCallback onRetry,
}) {
  final l10n = context.l10n;
  SnackBarUtils.hide(context);
  SnackBarUtils.showFailure(
    context,
    what: what,
    preserved: weekUnchanged
        ? l10n.weekPlacementFailedWeekUnchanged
        : l10n.weekPlacementFailedMenuKept,
    action: FailureAction.retry(onRetry),
  );
}

/// P6-U02: the receipt after a merge, with Ångra.
void showShoppingMergeReceipt(
  BuildContext context,
  MenuShoppingMergeReceipt receipt, {
  required VoidCallback onUndo,
}) {
  final l10n = context.l10n;
  final message = receipt.concurrentChange
      ? l10n.shoppingMergeConcurrentChange(receipt.itemCount)
      : receipt.updatedList
      ? l10n.shoppingMergeSynced(receipt.listName)
      : l10n.shoppingMergeAdded(receipt.itemCount, receipt.listName);
  SnackBarUtils.showUndo(context, message, onUndo: onUndo);
}

/// P5-U16 (veckomeny ERROR): the week's shopping list could not be made.
///
/// Says the week is unchanged (making a list never writes the week) and
/// offers Försök igen, which runs the generation again.
void showWeekShoppingListFailure(
  BuildContext context, {
  required VoidCallback onRetry,
}) {
  final l10n = context.l10n;
  SnackBarUtils.showFailure(
    context,
    what: l10n.menuShoppingListGenerationFailed,
    preserved: l10n.menuShoppingListGenerationPreserved,
    action: FailureAction.retry(onRetry),
  );
}
