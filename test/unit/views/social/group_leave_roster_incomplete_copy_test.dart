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

import 'dart:convert';
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
      expect(branch, contains('context.l10n.groupRosterIncomplete'));
      expect(branch, isNot(contains('context.l10n.errorGeneric')));
    });

    test('the Swedish copy names the member read', () {
      expect(
        AppLocalizationsSv().groupRosterIncomplete,
        'Vi kunde inte läsa alla medlemmar. Försök igen.',
      );

      final arb =
          jsonDecode(File('lib/l10n/app_sv.arb').readAsStringSync())
              as Map<String, dynamic>;
      expect(
        arb['groupRosterIncomplete'],
        'Vi kunde inte läsa alla medlemmar. Försök igen.',
      );
    });

    test('the block dialog unavailable state uses the same key', () {
      final source = File(
        'lib/widgets/messaging/dialogs/block_group_member_dialog.dart',
      ).readAsStringSync().replaceAll(RegExp(r'//.*'), '');

      final start = source.indexOf('if (_failed) {');
      expect(start, greaterThan(-1), reason: 'the failed branch is gone');
      final end = source.indexOf('}', source.indexOf('onAction', start));
      final branch = source.substring(start, end);
      expect(branch, contains('context.l10n.groupRosterIncomplete'));
      expect(branch, isNot(contains('context.l10n.errorGeneric')));
    });

    test('a refused leave re-reads the roster before deciding', () {
      final source = File(
        'lib/views/social/group_detail_view.dart',
      ).readAsStringSync().replaceAll(RegExp(r'//.*'), '');

      final start = source.indexOf('Future<void> _leaveGroup(');
      final end = source.indexOf('if (decision.rosterIncomplete) {', start);
      expect(start, greaterThan(-1), reason: '_leaveGroup is gone');
      expect(end, greaterThan(start), reason: 'leave anchors out of order');

      final head = source.substring(start, end);
      expect(head, contains('_viewModel.isResolvingLeave) return;'));
      expect(
        head,
        contains('await _viewModel.resolveLeaveGroupRequirements()'),
      );
      expect(head, isNot(contains('checkLeaveGroupRequirements()')));
    });

    test('both leave controls are disabled while the roster is re-read', () {
      final view = File(
        'lib/views/social/group_detail_view.dart',
      ).readAsStringSync().replaceAll(RegExp(r'//.*'), '');
      expect(
        view.replaceAll(RegExp(r'\s+'), ' '),
        contains('onLeaveGroup: _viewModel.isResolvingLeave ? null'),
      );
      expect(view, contains('isResolvingLeave: _viewModel.isResolvingLeave'));

      final appBar = File(
        'lib/views/social/group_detail/group_detail_app_bar.dart',
      ).readAsStringSync().replaceAll(RegExp(r'//.*'), '');
      final item = appBar.indexOf("value: 'leave_group'");
      expect(item, greaterThan(-1), reason: 'the leave menu item is gone');
      final itemEnd = appBar.indexOf('child:', item);
      expect(
        appBar.substring(item, itemEnd),
        contains('enabled: !isResolvingLeave'),
      );
    });
  });
}
