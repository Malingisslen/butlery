/// BUT-2027: the refusal an owner sees when the member roster could not be read
/// in full says WHICH read failed, instead of the app-wide generic error.
///
/// The pins die alone:
///   - the ROUTING pin reads the source. The branch sits in the private
///     `_leaveGroup`, reached only from the loaded body of [GroupDetailView],
///     and the widget suite beside it never pumps the loaded body.
///     Reverting the call to `errorGeneric` reddens this pin and no other.
///   - the COPY pin reads the generated Swedish localization. Rewording the
///     ARB entry reddens that one and no other.
///
/// The source window is anchored on CODE at both ends, never on the copy: an
/// anchor that quotes a string is emptied by the next rewording and then
/// reddens against the production file rather than against itself. Comments are
/// stripped before the window is cut, so neither direction can be answered by a
/// comment that merely names a key.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/l10n/app_localizations_sv.dart';

void main() {
  group('BUT-2027 — the roster-incomplete refusal', () {
    test('the leave path shows the roster-specific copy, not errorGeneric', () {
      final source = File(
        'lib/views/social/group_detail_view.dart',
      ).readAsStringSync().replaceAll(RegExp(r'//.*'), '');

      const branchStart = 'if (decision.rosterIncomplete) {';
      const branchEnd = 'if (decision.groupIsEmpty) {';

      final start = source.indexOf(branchStart);
      final end = source.indexOf(branchEnd, start);
      expect(
        start,
        greaterThan(-1),
        reason: 'the rosterIncomplete branch is gone — BUT-2027 regressed',
      );
      expect(end, greaterThan(start), reason: 'branch anchors out of order');

      final branch = source.substring(start, end);
      expect(branch, contains('context.l10n.groupLeaveRosterIncomplete'));
      expect(branch, isNot(contains('context.l10n.errorGeneric')));
    });

    test('the Swedish copy names the member read', () {
      expect(
        AppLocalizationsSv().groupLeaveRosterIncomplete,
        'Vi kunde inte läsa alla medlemmar. Försök igen.',
      );
    });
  });
}
