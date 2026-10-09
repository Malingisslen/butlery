/// BUT-907: every way a trash change can end gets its own sentence, so the
/// user is told the real reason a recipe was not restored or deleted.
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/l10n/app_localizations_sv.dart';
import 'package:butlery/services/trash/trash_service.dart';
import 'package:butlery/viewmodels/trash_viewmodel.dart';
import 'package:butlery/views/settings/widgets/trash_messages.dart';

void main() {
  final sv = AppLocalizationsSv();

  String say(
    TrashOutcome outcome, {
    TrashAction action = TrashAction.restore,
    int requested = 10,
  }) => TrashMessages.forResult(
    sv,
    TrashActionResult(action: action, requested: requested, outcome: outcome),
  );

  test('a complete change names the action', () {
    const done = TrashOutcome(doneIds: ['a', 'b']);
    expect(say(done, requested: 2), '2 recept återställda som privat');
    expect(
      say(done, action: TrashAction.deleteForever, requested: 2),
      '2 recept raderades för alltid',
    );
    expect(
      say(const TrashOutcome(), action: TrashAction.emptyTrash),
      'Papperskorgen är tömd',
    );
  });

  test('a change that never ran says nothing changed, and why', () {
    expect(
      say(TrashOutcome.notRun(['a'], TrashFailure.offline)),
      'Du är offline. Inget ändrades.',
    );
    expect(
      say(TrashOutcome.notRun(['a'], TrashFailure.failed)),
      'Något gick fel. Inget ändrades.',
    );
  });

  // A different count per reason, so two swapped arms cannot read alike.
  test('each failure reason has its own sentence', () {
    final cases = {
      TrashFailure.offline: '1 recept gjordes inte eftersom du är offline.',
      TrashFailure.expired: '2 recept hade redan gått ut.',
      TrashFailure.gone: '3 recept fanns inte kvar i papperskorgen.',
      TrashFailure.failed: '4 recept gick inte att klara. Försök igen.',
    };
    var n = 0;
    for (final MapEntry(key: reason, value: sentence) in cases.entries) {
      n++;
      final outcome = TrashOutcome(
        doneIds: const ['done'],
        failures: {for (var i = 0; i < n; i++) 'x$i': reason},
      );
      expect(say(outcome), '1 av 10 klara. $sentence', reason: '$reason');
    }
  });

  test('several reasons are joined after the summary', () {
    const outcome = TrashOutcome(
      doneIds: ['a'],
      failures: {'b': TrashFailure.expired, 'c': TrashFailure.gone},
    );
    expect(
      say(outcome, requested: 3),
      '1 av 3 klara. 1 recept hade redan gått ut. '
      '1 recept fanns inte kvar i papperskorgen.',
    );
  });

  test('when nothing was done the summary says so', () {
    const outcome = TrashOutcome(failures: {'a': TrashFailure.gone});
    expect(
      say(outcome, requested: 1),
      'Inget ändrades. 1 recept fanns inte kvar i papperskorgen.',
    );
  });
}
