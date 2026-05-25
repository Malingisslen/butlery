/// Unit tests for AppLogger.
///
/// Pins two contracts that BUT-1059 introduced + that no other test
/// currently exercises directly:
///
/// 1. **Async-error absorption** — `AppLogger.error(...)` must not surface
///    unhandled async errors when Crashlytics isn't initialized. Without
///    BUT-1059's `_safeCrashlytics` helper, `Crashlytics.instance.log()`'s
///    Future would reject with `MissingPluginException` and escape the sync
///    try/catch as an unhandled zone error.
/// 2. **PII redaction** — `_sanitizeForCrashlytics` redacts 20-28 char
///    alphanumeric tokens (Firebase UIDs and similar) to `xxxx***` before
///    they reach Crashlytics. Tested via the
///    `sanitizeForCrashlyticsForTesting` `@visibleForTesting` wrapper so
///    no Crashlytics scaffolding is required.
library;

import 'dart:async';

import 'package:butlery/core/utils/logger.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AppLogger.error — async absorption (BUT-1059)', () {
    /// Crashlytics-channel errors are absorbed inside `_safeCrashlytics` so
    /// the surrounding zone's `onError` handler never sees them. Pre-fix,
    /// the Future from `Crashlytics.instance.log()` would reject across an
    /// async gap and escape the sync try/catch.
    test('error() in a zone without Firebase does not escape async errors',
        () async {
      final zoneErrors = <Object>[];

      await runZonedGuarded(() async {
        AppLogger.error('A test error', Exception('boom'));
        // Yield twice so any escaped microtask gets a chance to surface.
        await Future<void>.delayed(Duration.zero);
        await Future<void>.delayed(Duration.zero);
      }, (error, _) {
        zoneErrors.add(error);
      });

      expect(zoneErrors, isEmpty,
          reason:
              'BUT-1059 contract: Crashlytics async failures must be absorbed; '
              'no error should reach the zone-error handler.');
    });

    test('error() with null error object also absorbs Crashlytics failures',
        () async {
      final zoneErrors = <Object>[];

      await runZonedGuarded(() async {
        AppLogger.error('Just a message, no error object');
        await Future<void>.delayed(Duration.zero);
      }, (error, _) {
        zoneErrors.add(error);
      });

      expect(zoneErrors, isEmpty);
    });
  });

  group('sanitizeForCrashlyticsForTesting — PII redaction', () {
    /// 20-char token: minimum length covered by the redaction regex.
    /// Firebase UIDs are 28 chars; some other tokens are shorter but
    /// still PII-relevant (push tokens, doc ids).
    test('redacts a 20-char alphanumeric token to first-4 + ***', () {
      final input = 'User abcd1234efgh5678ijkl performed action';
      final output = AppLogger.sanitizeForCrashlyticsForTesting(input);

      expect(output, equals('User abcd*** performed action'));
    });

    /// 28-char token: Firebase UID length. The canonical case the regex
    /// was designed for.
    test('redacts a 28-char Firebase-UID-style token', () {
      final input = 'uid=abcdefghijklmnopqrstuvwxyz12 logged in';
      final output = AppLogger.sanitizeForCrashlyticsForTesting(input);

      expect(output, equals('uid=abcd*** logged in'));
    });

    /// Boundary: 19 chars is below the regex floor → must NOT redact.
    /// (Otherwise short ids like 19-char correlation ids would be scrubbed.)
    test('does NOT redact 19-char tokens (below the regex floor)', () {
      final input = 'short token: abcdefghij1234567890';
      // 'abcdefghij1234567890' is 20 chars — would redact. Use 19.
      final input19 = 'short token: abcdefghij123456789';
      final output = AppLogger.sanitizeForCrashlyticsForTesting(input19);

      expect(output, equals(input19),
          reason: '19 chars is below the 20-char floor; must pass through');
      // Sanity: 20-char companion does redact, confirming boundary placement.
      expect(AppLogger.sanitizeForCrashlyticsForTesting(input),
          equals('short token: abcd***'));
    });

    /// Boundary: 29 chars is above the regex ceiling → must NOT redact.
    /// (Long hashes / SHA-256 etc. shouldn't get partial-redacted, just
    /// passed through whole — different sanitizer's job if needed.)
    test('does NOT redact 29-char tokens (above the regex ceiling)', () {
      final input29 = 'long: abcdefghijklmnopqrstuvwxyz123';
      final output = AppLogger.sanitizeForCrashlyticsForTesting(input29);

      expect(output, equals(input29),
          reason: '29 chars is above the 28-char ceiling; must pass through');
    });

    /// Multiple tokens in a single message must ALL be redacted, not just
    /// the first. `replaceAllMapped` does this — pin it so a future
    /// refactor to `replaceFirst` would fail-loud.
    test('redacts all matching tokens in a single message', () {
      final input = 'from=abcd1234efgh5678ijkl to=mnop9012qrst3456uvwx';
      final output = AppLogger.sanitizeForCrashlyticsForTesting(input);

      expect(output, equals('from=abcd*** to=mnop***'));
    });

    /// Empty / short messages with no candidate token pass through unchanged.
    test('passes through short messages with no candidate tokens', () {
      const input = 'short message no ids here';
      expect(AppLogger.sanitizeForCrashlyticsForTesting(input), equals(input));
      expect(AppLogger.sanitizeForCrashlyticsForTesting(''), equals(''));
    });
  });
}
