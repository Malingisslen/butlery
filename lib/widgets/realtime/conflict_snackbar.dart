/// P3-U08: the week menu's conflict notice.
///
/// The action rescues the overwritten version (
/// the other version can be rescued with one tap).
/// The window stays its own 30 s, never the 7 s undo one.
///
/// Mounted by the week menu (veckomeny_view.dart, package 5 phase A, P5-U26a).
library;

import 'package:butlery/core/extensions/default_value_extensions.dart';
import 'package:butlery/core/utils/stored_display_name.dart';
import 'package:flutter/material.dart';

import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/core/utils/captured_snackbars.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/core/utils/snackbar_utils.dart';
import 'package:butlery/models/realtime/realtime_resource.dart';
import 'package:butlery/services/realtime/realtime_types.dart';
import 'package:butlery/services/realtime_sync_service.dart';

/// Conflict handling only; never an undo window.
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
  /// PQ-05 is answered.
  static ScaffoldFeatureController<SnackBar, SnackBarClosedReason>?
  showWeekSaved(BuildContext context, ConflictEvent event) {
    if (event.chosenStrategy != ConflictResolutionStrategy.remoteWon ||
        event.entity != ConflictEntity.weekMenu) {
      return null;
    }
    final l = context.l10n;
    final name = knownStoredName(
      event.remoteValue.lastEditedByDisplayName,
    ).orEmpty();
    final message = name.isEmpty
        ? l.conflictWeekSavedUnnamed
        : l.conflictWeekSaved(name);
    return _show(context, message, () => _keepMine(context, event));
  }

  /// BUT-2215: "Veckan sparades på en annan enhet" with "Behåll min", for a
  /// save of the user's own week that lost to their other device. Same
  /// window, persistence and look as [showWeekSaved].
  ///
  /// [onKeepMine] writes the user's version back. It returns false when that
  /// save lost again (the caller then shows a new notice, so this one says
  /// nothing more), and throws when it failed.
  static ScaffoldFeatureController<SnackBar, SnackBarClosedReason>?
  showWeekSavedElsewhere(
    BuildContext context, {
    required Future<bool> Function() onKeepMine,
  }) {
    return _show(
      context,
      context.l10n.conflictWeekSavedElsewhere,
      () => _rescue(context, onKeepMine),
    );
  }

  static ScaffoldFeatureController<SnackBar, SnackBarClosedReason>? _show(
    BuildContext context,
    String message,
    VoidCallback onKeepMine,
  ) {
    final persist = MediaQuery.maybeAccessibleNavigationOf(context) ?? false;

    // Same queue rule as the undo primitive: this notice goes to the head of
    // the queue so its window starts now and its `closed` always completes.
    return CapturedSnackBars.capture(context).show(
      message,
      actionLabel: context.l10n.conflictWeekKeepMine,
      onAction: onKeepMine,
      duration: kConflictNoticeWindow,
      persist: persist,
      jumpQueue: true,
    );
  }

  /// Re-applies the overwritten local version, as "Behåll min version" does in
  /// ConflictDiffView, and says whether it worked.
  static Future<void> _keepMine(
    BuildContext context,
    ConflictEvent event,
  ) => _rescue(context, () async {
    final svc = ServiceLocator.tryGet<RealtimeSyncService>();
    if (svc == null) {
      throw StateError('RealtimeSyncService is not registered');
    }
    await svc.recoverLocalVersion(event.localValue);
    return true;
  });

  static Future<void> _rescue(
    BuildContext context,
    Future<bool> Function() keep,
  ) async {
    try {
      final kept = await keep();
      if (!kept || !context.mounted) return;
      SnackBarUtils.showSuccess(context, context.l10n.conflictDiffKeptToast);
    } catch (e) {
      AppLogger.error('Failed to re-apply local week after conflict', e);
      if (!context.mounted) return;
      SnackBarUtils.showFailure(
        context,
        what: context.l10n.conflictDiffKeepFailed,
      );
    }
  }
}
