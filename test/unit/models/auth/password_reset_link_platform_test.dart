/// BUT-2170: the phone only hands the reset link to the app when the native
/// registration names the same host and path the parser expects. If either
/// side drifts, the link silently opens Firebase's page instead.
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:butlery/models/auth/password_reset_link.dart';

const _linksPath = '/__/auth/links';

void main() {
  test('Android claims the link domain and the links path', () {
    final manifest = File(
      'android/app/src/main/AndroidManifest.xml',
    ).readAsStringSync();
    expect(
      manifest,
      contains('android:host="${PasswordResetLink.linkDomain}"'),
    );
    expect(manifest, contains('android:pathPrefix="$_linksPath"'));
    final filter = RegExp(
      r'<intent-filter[^>]*>(?:(?!</intent-filter>)[\s\S])*'
      '${RegExp.escape(PasswordResetLink.linkDomain)}',
    ).firstMatch(manifest)!.group(0)!;
    expect(filter, contains('android:autoVerify="true"'));
  });

  test('both iOS builds claim the link domain', () {
    for (final path in [
      'ios/Runner/Runner.entitlements',
      'ios/Runner/Release.entitlements',
    ]) {
      expect(
        File(path).readAsStringSync(),
        contains('applinks:${PasswordResetLink.linkDomain}'),
        reason: path,
      );
    }
  });

  test('the association files carry no placeholder', () {
    for (final path in [
      'web/.well-known/apple-app-site-association',
      'web/.well-known/assetlinks.json',
    ]) {
      expect(
        File(path).readAsStringSync(),
        isNot(contains('REPLACE_ME')),
        reason: path,
      );
    }
  });

  test('the association files name the app and the links path', () {
    final aasa =
        jsonDecode(
              File(
                'web/.well-known/apple-app-site-association',
              ).readAsStringSync(),
            )
            as Map<String, dynamic>;
    final details = (aasa['applinks'] as Map)['details'] as List;
    final apps = details.cast<Map<String, dynamic>>();
    final ours = apps.where(
      (d) =>
          (d['appID'] as String).endsWith('.${PasswordResetLink.iOSBundleId}'),
    );
    expect(ours, isNotEmpty);
    expect(ours.first['paths'] as List, contains(_linksPath));

    final assetLinks =
        jsonDecode(
              File('web/.well-known/assetlinks.json').readAsStringSync(),
            )
            as List;
    final target =
        (assetLinks.single as Map<String, dynamic>)['target']
            as Map<String, dynamic>;
    expect(target['package_name'], PasswordResetLink.androidPackageName);
  });
}
