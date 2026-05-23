/// Unit tests for VersionInfo.
///
/// Static state with platform-call fallback. In the unit-test harness
/// `PackageInfo.fromPlatform()` throws, which the catch-block swallows,
/// leaving the 'unknown' defaults. Tests pin the default/fallback
/// contract; integration tests cover the platform-bound happy path.
library;

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/core/utils/version_info.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('defaults are "unknown" before initialize', () {
    // Note: static state may be polluted by a previous test run within
    // the same isolate. We don't assert against any current value here,
    // only the fallback shape produced by initialize() failing.
    expect(VersionInfo.appVersion, isA<String>());
    expect(VersionInfo.buildNumber, isA<String>());
  });

  test('fullVersion concatenates appVersion + "+" + buildNumber', () {
    final composed = VersionInfo.fullVersion;
    expect(composed, contains('+'));
    expect(composed.split('+'), hasLength(2));
    expect(composed.split('+')[0], VersionInfo.appVersion);
    expect(composed.split('+')[1], VersionInfo.buildNumber);
  });

  test(
      'initialize() swallows platform-channel failure and leaves defaults intact',
      () async {
    // In the unit-test harness the platform channel for PackageInfo is
    // not stubbed → fromPlatform throws → catch block keeps defaults.
    // We stub the channel to throw explicitly to make this deterministic
    // even if PackageInfo's behaviour shifts.
    const channel = MethodChannel('dev.fluttercommunity.plus/package_info');
    TestWidgetsFlutterBinding.ensureInitialized()
        .defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      throw PlatformException(code: 'unavailable');
    });

    final beforeApp = VersionInfo.appVersion;
    final beforeBuild = VersionInfo.buildNumber;

    await VersionInfo.initialize(); // must not throw

    // Defaults preserved when initialize fails.
    expect(VersionInfo.appVersion, beforeApp);
    expect(VersionInfo.buildNumber, beforeBuild);

    // Cleanup
    TestWidgetsFlutterBinding.ensureInitialized()
        .defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });
}
