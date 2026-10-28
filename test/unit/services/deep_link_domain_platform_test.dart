/// A shared https link only opens the app when the phone's own link
/// verification names the host the app builds links on. butlery.app was never
/// ours, so no registration may claim it.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:butlery/services/deep_link_service.dart';

void main() {
  final host = Uri.parse(DeepLinkService.generateProfileLink('x')).host;

  test('shared links are built on butlery.se', () {
    expect(host, 'butlery.se');
  });

  test('Android verifies the shared-link host and not butlery.app', () {
    final manifest = File(
      'android/app/src/main/AndroidManifest.xml',
    ).readAsStringSync();
    expect(manifest, contains('android:host="$host"'));
    expect(manifest, isNot(contains('android:host="butlery.app"')));
  });

  test('both iOS builds claim the shared-link host and not butlery.app', () {
    for (final path in [
      'ios/Runner/Runner.entitlements',
      'ios/Runner/Release.entitlements',
    ]) {
      final entitlements = File(path).readAsStringSync();
      expect(entitlements, contains('applinks:$host<'), reason: path);
      expect(
        entitlements,
        isNot(contains('applinks:butlery.app<')),
        reason: path,
      );
    }
  });
}
