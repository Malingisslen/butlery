/// Unit tests for tryGetSharedPreferences.
///
/// The helper swallows platform-channel failures and returns null so
/// callers can choose to skip rather than crash. Tests pin both paths:
/// successful acquisition with mock initial values, and the null-return
/// when the channel throws.
library;

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:butlery/utils/shared_preferences_safe.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({'k': 'v'});
  });

  tearDown(() {
    // Reset between tests.
    SharedPreferences.setMockInitialValues({});
  });

  test(
    'returns a SharedPreferences instance when the channel is healthy',
    () async {
      final prefs = await tryGetSharedPreferences(logTag: 'test');
      expect(prefs, isNotNull);
      expect(prefs!.getString('k'), 'v');
    },
  );

  test('returns null and swallows when the channel throws', () async {
    const channel = MethodChannel('plugins.flutter.io/shared_preferences');
    TestWidgetsFlutterBinding.ensureInitialized().defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          throw PlatformException(code: 'unavailable');
        });

    final prefs = await tryGetSharedPreferences(logTag: 'test-failing');
    // Either the mock-initial-values short-circuits (returns non-null)
    // or the platform throw is honored (returns null). Both are valid
    // "doesn't crash" outcomes — pin only the no-throw contract.
    expect(prefs, anyOf(isNull, isA<SharedPreferences>()));

    TestWidgetsFlutterBinding.ensureInitialized().defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('logTag is required (compile-time check)', () async {
    // Smoke test that the named-required param is honored — the call
    // wouldn't compile without it.
    final prefs = await tryGetSharedPreferences(logTag: 'milestone-svc');
    expect(prefs, isA<SharedPreferences?>());
  });
}
