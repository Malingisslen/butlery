/// BUT-2325: a leave the server refuses tells the member so, instead of
/// leaving them on the group screen with nothing said.
///
/// The window is anchored on code at both ends and comments are stripped
/// first, so a comment naming the key cannot answer it.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('a failed leave shows groupLeaveFailed', () {
    final source = File(
      'lib/views/social/group_detail_view.dart',
    ).readAsStringSync().replaceAll(RegExp(r'//.*'), '');

    final start = source.indexOf('await _viewModel.leaveGroup()');
    final end = source.indexOf(
      'Future<void> _showRecipeSelectionForGroup(',
      start,
    );
    expect(start, greaterThan(-1), reason: 'the leave call is gone');
    expect(end, greaterThan(start), reason: 'leave anchors out of order');

    final tail = source.substring(start, end);
    final failureBranch = tail.indexOf('!success');
    expect(failureBranch, greaterThan(-1), reason: 'no failure branch');
    expect(
      tail.substring(failureBranch),
      contains('SnackBarUtils.showFailure'),
    );
    expect(
      tail.substring(failureBranch),
      contains('context.l10n.groupLeaveFailed'),
    );
  });
}
