// BUT-2469: the share sheet starts its target in a new task, so a share filter
// on MainActivity started a second copy of the whole app for every share.
// Shares must land on ShareReceiverActivity, which hands them to MainActivity.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String _activityBlock(String manifest, String name) {
  final start = manifest.indexOf('android:name="$name"');
  expect(start, isNot(-1), reason: '$name saknas i manifestet');
  final end = manifest.indexOf('</activity>', start);
  return manifest.substring(start, end);
}

void main() {
  final manifest = File(
    'android/app/src/main/AndroidManifest.xml',
  ).readAsStringSync();

  test('MainActivity takes no shares', () {
    final main = _activityBlock(manifest, '.MainActivity');
    expect(main, isNot(contains('android.intent.action.SEND')));
  });

  test('ShareReceiverActivity takes text and photo shares', () {
    final receiver = _activityBlock(manifest, '.ShareReceiverActivity');
    expect(receiver, contains('android.intent.action.SEND"'));
    expect(receiver, contains('android.intent.action.SEND_MULTIPLE'));
    expect(receiver, contains('android:mimeType="text/*"'));
    expect(receiver, contains('android:mimeType="image/*"'));
    expect(receiver, contains('android:excludeFromRecents="true"'));
    expect(receiver, contains('android:noHistory="true"'));
  });
}
