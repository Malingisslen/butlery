/// P3-U08: the week menu's conflict notice.
///
/// produktregler.md:103: for a week menu the last save wins and the user sees
/// the snackbar "*Namn* sparade veckan" for 30 s. ux-beslut.json D-04 keeps
/// that 30 s window apart from the 7 s undo window: it belongs to conflict
/// handling and is never reused elsewhere, so it has its own constant here and
/// is not read from `undo_window.dart`.
///
/// The action rescues the overwritten version (produktregler.md:109, :1121:
/// the other version can be rescued with one tap). Its label is "Behåll min",
/// the only label drawn for this action (Skarmar v12 etapp 11, #vmbkonflikt).
/// It is not an undo, so it does not read `commonUndo`.
///
/// Built, not mounted: no view shows it until package 4 decides the channel
/// per surface.
library;

import 'package:flutter/material.dart';

import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/core/utils/snackbar_utils.dart';
import 'package:butlery/models/realtime/realtime_resource.dart';
import 'package:butlery/services/realtime/realtime_types.dart';
import 'package:butlery/services/realtime_sync_service.dart';

/// How long the week-menu conflict snackbar stays (produktregler.md:103,
/// ux-beslut.json D-04). Conflict handling only; never an undo window.
const Duration kConflictNoticeWindow = Duration(seconds: 30);

/// The week-menu conflict snackbar.
abstract final class ConflictSnackBar {
  /// Shows "{name} sparade veckan" with "Behåll min" for
  /// [kConflictNoticeWindow] when [event] is a week-menu conflict the user's
  /// edit lost. Returns null, and shows nothing, for any other event: a
  /// localWon changed nothing the user has to rescue, and other entities have
  /// their own notice.
  ///
  /// Persistence follows the undo primitive (`UndoSnackBar._persist`): it
  /// stays until acted on only under `MediaQuery.accessibleNavigation`, until
  /// PQ-05 is answered. The look is the primitive's plain look, so every
  /// snackbar keeps one look until PQ-09.
  static ScaffoldFeatureController<SnackBar, SnackBarClosedReason>?
  showWeekSaved(BuildContext context, ConflictEvent event) {
    if (event.chosenStrategy != ConflictResolutionStrategy.remoteWon ||
        event.entity != ConflictEntity.weekMenu) {
      return null;
    }
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) return null;

    final l = context.l10n;
    final name = event.remoteValue.lastEditedByDisplayName.trim();
    final message = name.isEmpty
        ? l.conflictWeekSavedUnnamed
        : l.conflictWeekSaved(name);
    final persist = MediaQuery.maybeAccessibleNavigationOf(context) ?? false;

    // Same queue rule as the undo primitive: this notice goes to the head of
    // the queue so its window starts now and its `closed` always completes.
    messenger
      ..clearSnackBars()
      ..removeCurrentSnackBar();
    return messenger.showSnackBar(
      SnackBar(
        content: Text(message),
        action: SnackBarAction(
          label: l.conflictKeepMine,
          onPressed: () => _keepMine(context, event),
        ),
        duration: kConflictNoticeWindow,
        persist: persist,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  /// Re-applies the overwritten local version, as "Behåll min version" does in
  /// ConflictDiffView, and says whether it worked.
  static Future<void> _keepMine(
    BuildContext context,
    ConflictEvent event,
  ) async {
    final svc = ServiceLocator.tryGet<RealtimeSyncService>();
    try {
      if (svc == null) {
        throw StateError('RealtimeSyncService is not registered');
      }
      await svc.recoverLocalVersion(event.localValue);
      if (!context.mounted) return;
      SnackBarUtils.showSuccess(context, context.l10n.conflictDiffKeptToast);
    } catch (e) {
      AppLogger.error('Failed to re-apply local week after conflict', e);
      if (!context.mounted) return;
      SnackBarUtils.showError(context, context.l10n.conflictDiffKeepFailed);
    }
  }
}
