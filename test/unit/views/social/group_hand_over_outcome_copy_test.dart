/// BUT-2321: each way a group handover can end tells the owner something
/// different. The view's group body needs half a dozen services to build, so
/// this pins the outcome-to-text mapping on the source instead.
///
/// The outcome window runs from the handover call to the next leave
/// confirmation, and the owner window from the owner branch to the handover
/// call; all are code anchors, with comments stripped first so a comment
/// cannot answer them.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  late String window;
  late String ownerBranch;

  setUpAll(() {
    final source = File(
      'lib/views/social/group_detail_view.dart',
    ).readAsStringSync().replaceAll(RegExp(r'//.*'), '');

    final start = source.indexOf('await _viewModel.handOverGroup(newOwner)');
    expect(start, greaterThan(-1), reason: 'the handover call is gone');
    final end = source.indexOf(
      'CommonDialogActions.showLeaveGroupConfirmation(',
      start,
    );
    expect(end, greaterThan(start), reason: 'handover anchors out of order');
    window = source.substring(start, end);

    final branch = source.indexOf('if (decision.requiresOwnershipTransfer)');
    expect(branch, greaterThan(-1), reason: 'the owner branch is gone');
    expect(branch, lessThan(start), reason: 'owner anchors out of order');
    ownerBranch = source.substring(branch, start);
  });

  test('the owner picks a new owner, then confirms, before any handover', () {
    final pick = ownerBranch.indexOf('OwnershipTransferDialog.show(');
    final noPick = ownerBranch.indexOf(
      'if (newOwner == null || !mounted) return;',
    );
    final confirm = ownerBranch.indexOf(
      'CommonDialogActions.showLeaveGroupConfirmation(',
    );
    final declined = ownerBranch.indexOf(
      'if (shouldLeave != true || !mounted) return;',
    );
    expect(pick, greaterThan(-1), reason: 'no new-owner picker');
    expect(noPick, greaterThan(pick), reason: 'a cancelled pick goes on');
    expect(confirm, greaterThan(noPick), reason: 'no confirmation after pick');
    expect(declined, greaterThan(confirm), reason: 'a declined leave goes on');
    expect(ownerBranch, isNot(contains('handOverGroup')));
  });

  String arm(String outcome) {
    final open = window.indexOf('case GroupHandOverOutcome.$outcome:');
    expect(open, greaterThan(-1), reason: '$outcome has no case');
    final next = window.indexOf(
      'case GroupHandOverOutcome.',
      open + 'case GroupHandOverOutcome.'.length,
    );
    return next == -1 ? window.substring(open) : window.substring(open, next);
  }

  test('done reports success and leaves the screen', () {
    final done = arm('done');
    expect(done, contains('SnackBarUtils.showSuccess'));
    expect(done, contains('context.l10n.groupOwnershipTransferredAndLeft'));
    expect(done, contains('Navigator.pushReplacementNamed'));
    expect(done, contains("'/friends'"));
    expect(done, contains("{'tabIndex': 1}"));
    expect(done, isNot(contains('showFailure')));
  });

  test('a new owner outside the household names that person', () {
    final arm0 = arm('newOwnerNotInHousehold');
    expect(arm0, contains('SnackBarUtils.showFailure'));
    expect(arm0, contains('context.l10n.groupHandOverNotInHousehold('));
    expect(arm0, contains('newOwner.displayName'));
    expect(arm0, isNot(contains('Navigator')));
  });

  test('unavailable says the group cannot be handed over now', () {
    final unavailable = arm('unavailable');
    expect(unavailable, contains('SnackBarUtils.showFailure'));
    expect(unavailable, contains('context.l10n.groupHandOverUnavailable'));
    expect(unavailable, isNot(contains('Navigator')));
  });

  test('failed says ownership could not be transferred', () {
    final failed = arm('failed');
    expect(failed, contains('SnackBarUtils.showFailure'));
    expect(failed, contains('context.l10n.groupCouldNotTransferOwnership'));
    expect(failed, isNot(contains('Navigator')));
  });
}
