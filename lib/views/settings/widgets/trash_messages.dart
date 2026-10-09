import 'package:butlery/l10n/app_localizations.dart';
import 'package:butlery/services/trash/trash_service.dart';
import 'package:butlery/viewmodels/trash_viewmodel.dart';

/// The plain Swedish sentence for what a trash change did.
abstract final class TrashMessages {
  static String forResult(AppLocalizations l10n, TrashActionResult result) {
    final outcome = result.outcome;
    if (outcome.wasOffline) return l10n.trashOfflineNothingChanged;
    if (outcome.notRun != null) return l10n.trashFailedNothingChanged;
    if (outcome.isComplete) {
      return switch (result.action) {
        TrashAction.restore => l10n.trashRestoredAll(result.requested),
        TrashAction.deleteForever => l10n.trashDeletedAll(result.requested),
        TrashAction.emptyTrash => l10n.trashEmptied,
      };
    }
    return _partial(l10n, result);
  }

  static String _partial(AppLocalizations l10n, TrashActionResult result) {
    final outcome = result.outcome;
    final done = outcome.doneIds.length;
    final counts = <TrashFailure, int>{};
    for (final reason in outcome.failures.values) {
      counts.update(reason, (n) => n + 1, ifAbsent: () => 1);
    }
    final sentences = <String>[
      done == 0
          ? l10n.trashPartialNoneDone
          : l10n.trashPartialSummary(done, result.requested),
      for (final entry in counts.entries)
        switch (entry.key) {
          TrashFailure.offline => l10n.trashFailOffline(entry.value),
          TrashFailure.expired => l10n.trashFailExpired(entry.value),
          TrashFailure.gone => l10n.trashFailGone(entry.value),
          TrashFailure.failed => l10n.trashFailFailed(entry.value),
        },
    ];
    return sentences.join(' ');
  }
}
