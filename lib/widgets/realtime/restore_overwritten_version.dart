/// P5-U26b: "Återställ" for a version another person's save overwrote.
///
/// produktregler.md:104: for the week menu the 30 s snackbar comes first,
/// "därefter Återställ i 30 dagar"; produktregler.md:109 keeps every
/// overwritten version 30 days behind Återställ; flows-roles-budget.md:36 says
/// the overwritten version "nås i Återställ i 30 dagar". PQ-01 = A scopes it
/// to the week menu and the user's own recipe.
///
/// Interpretations, recorded here so the reader of the code sees them:
/// - No drawing places the entry (Skarmar v12 has no Återställ for an
///   overwritten version). It is a row in the surface's overflow menu, the
///   place CROSS_CUTTING_RULES.md §3 gives secondary actions, and the row is
///   there only while something can be restored, so no surface changes when
///   nothing is kept.
/// - The row says "Återställ min version", after the drawn "Behåll min
///   version" (Komponentark v1 conflict diff, app_sv.arb conflictDiffKeepMine).
/// - Restoring replaces what someone else saved, which is gone once the undo
///   window closes: BUT-954 class 2 (.claude/rules/ui-conventions.md:137),
///   a confirmation and then Ångra for 7 s through the undo primitive.
/// - The time reads as content-style-guide.md:20-36: "i dag 14:02", "i går",
///   then "9 juli" (with the year when it is not this year). "nu" and
///   "5 min sedan" are not used, because "Din version från nu" is not Swedish.
library;

import 'dart:async';

import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/core/utils/snackbar_utils.dart';
import 'package:butlery/l10n/app_localizations.dart';
import 'package:butlery/models/realtime/overwritten_version.dart';
import 'package:butlery/models/realtime/realtime_resource.dart';
import 'package:butlery/services/realtime/overwritten_version_service.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/widgets/common/dialogs/confirmation_dialogs.dart';

/// Holds the signed-in user's restorable versions for one surface, so an
/// overflow menu can decide synchronously whether to show the row.
///
/// Create it in `initState`, call [dispose] in `dispose`. Without a
/// registered [OverwrittenVersionService] it holds nothing.
class RestorableVersionsWatcher {
  RestorableVersionsWatcher({
    required ConflictEntity entity,
    String? resourceId,
    required VoidCallback onChanged,
  }) {
    final svc = ServiceLocator.tryGet<OverwrittenVersionService>();
    _sub = svc?.watch(entity: entity, resourceId: resourceId).listen(
      (versions) {
        _versions = versions;
        onChanged();
      },
      onError: (Object e) => AppLogger.error('Could not read kept versions', e),
    );
  }

  StreamSubscription<List<OverwrittenVersion>>? _sub;
  List<OverwrittenVersion> _versions = const [];

  /// The versions that can be restored right now. Filtered again on every
  /// read, so a version never outlives its 30 days on a screen left open.
  List<OverwrittenVersion> get versions =>
      OverwrittenVersionService.stillKept(_versions);

  void dispose() {
    unawaited(_sub?.cancel());
  }
}

/// The restore flow: pick a version (when there is more than one), confirm,
/// restore, and offer Ångra.
abstract final class RestoreOverwrittenVersion {
  /// Key of the row for the version with [id] in the picker.
  static Key pickerRowKey(String id) => ValueKey('restore-version-$id');

  /// When [at] was, as content-style-guide.md:20-36 writes it.
  static String whenLabel(AppLocalizations l, DateTime at, DateTime now) {
    final local = at.toLocal();
    final today = DateUtils.dateOnly(now.toLocal());
    final day = DateUtils.dateOnly(local);
    if (day == today) {
      return l.overwrittenWhenToday(DateFormat.Hm(l.localeName).format(local));
    }
    if (day == today.subtract(const Duration(days: 1))) {
      return l.overwrittenWhenYesterday;
    }
    return dateLabel(l, at, now);
  }

  /// A date as content-style-guide.md:25 writes it: "9 juli", with the year
  /// only when it is not this year.
  static String dateLabel(AppLocalizations l, DateTime at, DateTime now) {
    final local = at.toLocal();
    return local.year == now.toLocal().year
        ? DateFormat.MMMMd(l.localeName).format(local)
        : DateFormat.yMMMMd(l.localeName).format(local);
  }

  /// Runs the flow for [versions] (newest first). Does nothing when there is
  /// nothing to restore or no service.
  static Future<void> start(
    BuildContext context,
    List<OverwrittenVersion> versions,
  ) async {
    final svc = ServiceLocator.tryGet<OverwrittenVersionService>();
    if (svc == null || versions.isEmpty) return;
    final version = versions.length == 1
        ? versions.single
        : await _pick(context, versions);
    if (version == null || !context.mounted) return;

    final l = context.l10n;
    final now = clock.now();
    final when = whenLabel(l, version.overwrittenAt, now);
    final isWeek = version.entity == ConflictEntity.weekMenu;
    final confirmed = await ConfirmationDialogs.showConfirmationDialog(
      context,
      title: isWeek
          ? l.overwrittenConfirmTitleWeek
          : l.overwrittenConfirmTitleRecipe,
      message: isWeek
          ? l.overwrittenConfirmBodyWeek(when)
          : l.overwrittenConfirmBodyRecipe(when),
      confirmText: l.overwrittenRestoreAction,
      cancelText: l.commonCancel,
    );
    if (!confirmed || !context.mounted) return;
    await _restore(context, svc, version);
  }

  static Future<void> _restore(
    BuildContext context,
    OverwrittenVersionService svc,
    OverwrittenVersion version,
  ) async {
    final l = context.l10n;
    final undo = UndoSnackBar.capture(context);
    final OverwrittenVersionRestore receipt;
    try {
      receipt = await svc.restore(version);
    } catch (e) {
      AppLogger.error('Failed to restore an overwritten version', e);
      if (!context.mounted) return;
      final missing = e is OverwrittenVersionTargetMissing;
      SnackBarUtils.showFailure(
        context,
        what: l.overwrittenRestoreFailed,
        preserved: l.overwrittenKeptUntil(
          dateLabel(l, version.expiresAt, clock.now()),
        ),
        // A resource that no longer exists cannot take the version back, so
        // only a failure that can pass on a retry offers one.
        action: missing
            ? null
            : FailureAction.retry(
                () => unawaited(_restore(context, svc, version)),
              ),
      );
      return;
    }
    undo.showDeferred(
      l.overwrittenRestored,
      onUndo: () => unawaited(_undo(context, svc, receipt)),
      onCommit: () async {
        try {
          await svc.settle(receipt);
        } catch (e) {
          // The row stays until its TTL; the live version is already right.
          AppLogger.error('Could not forget a restored version', e);
        }
      },
    );
  }

  static Future<void> _undo(
    BuildContext context,
    OverwrittenVersionService svc,
    OverwrittenVersionRestore receipt,
  ) async {
    try {
      await svc.undo(receipt);
    } catch (e) {
      AppLogger.error('Failed to undo a restore', e);
      if (!context.mounted) return;
      final l = context.l10n;
      SnackBarUtils.showFailure(
        context,
        what: l.overwrittenUndoFailed,
        preserved: l.overwrittenUndoFailedKept,
        action: FailureAction.retry(
          () => unawaited(_undo(context, svc, receipt)),
        ),
      );
    }
  }

  /// Lets the user pick one of [versions]. Returns the version itself, never
  /// its position in the list.
  static Future<OverwrittenVersion?> _pick(
    BuildContext context,
    List<OverwrittenVersion> versions,
  ) {
    final l = context.l10n;
    final now = clock.now();
    return showDialog<OverwrittenVersion>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l.overwrittenPickTitle, style: AppTextStyles.titleLarge),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView(
            shrinkWrap: true,
            children: [
              for (final v in versions)
                ListTile(
                  key: pickerRowKey(v.id),
                  title: Text(
                    l.overwrittenVersionFrom(
                      whenLabel(l, v.overwrittenAt, now),
                    ),
                  ),
                  subtitle: Text(
                    v.overwrittenByName.isEmpty
                        ? l.overwrittenVersionByUnnamed(
                            dateLabel(l, v.expiresAt, now),
                          )
                        : l.overwrittenVersionBy(
                            v.overwrittenByName,
                            dateLabel(l, v.expiresAt, now),
                          ),
                  ),
                  onTap: () => Navigator.of(dialogContext).pop(v),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(l.commonCancel),
          ),
        ],
      ),
    );
  }
}
