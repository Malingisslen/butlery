/// The feedback "!" steps aside for a snackbar only when it and the app's
/// pages sit under `FeedbackAwareScaffoldMessenger`: without it
/// `openSnackBarsOf` returns null and the button covers snackbar actions
/// again. `feedback_fab_test.dart` proves the messenger and the button
/// against its own builder; no test mounts `ButleryApp`, which needs the app
/// bootstrap, so the wiring in its builder is asserted against the source.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('ButleryApp wraps the pages and the "!" in the counting messenger', () {
    final source = File('lib/app/butlery_app.dart')
        .readAsLinesSync()
        .where((line) => !line.trimLeft().startsWith('//'))
        .join(' ')
        .replaceAll(RegExp(r'\s+'), ' ');

    final messenger = source.indexOf('FeedbackAwareScaffoldMessenger(');
    expect(messenger, isNot(-1), reason: 'the messenger is gone');

    final boundary = source.indexOf('feedbackRepaintBoundaryKey', messenger);
    final fab = source.indexOf('const FeedbackFAB()', messenger);
    expect(boundary, isNot(-1), reason: 'the pages are outside the messenger');
    expect(fab, isNot(-1), reason: 'the "!" is outside the messenger');
  });
}
