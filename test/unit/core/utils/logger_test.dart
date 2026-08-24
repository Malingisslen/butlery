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
    test(
      'error() in a zone without Firebase does not escape async errors',
      () async {
        final zoneErrors = <Object>[];

        await runZonedGuarded(
          () async {
            AppLogger.error('A test error', Exception('boom'));
            // Yield twice so any escaped microtask gets a chance to surface.
            await Future<void>.delayed(Duration.zero);
            await Future<void>.delayed(Duration.zero);
          },
          (error, _) {
            zoneErrors.add(error);
          },
        );

        expect(
          zoneErrors,
          isEmpty,
          reason:
              'BUT-1059 contract: Crashlytics async failures must be absorbed; '
              'no error should reach the zone-error handler.',
        );
      },
    );

    test(
      'error() with null error object also absorbs Crashlytics failures',
      () async {
        final zoneErrors = <Object>[];

        await runZonedGuarded(
          () async {
            AppLogger.error('Just a message, no error object');
            await Future<void>.delayed(Duration.zero);
          },
          (error, _) {
            zoneErrors.add(error);
          },
        );

        expect(zoneErrors, isEmpty);
      },
    );
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

    /// BUT-1872. The hole this group did not have a case for, and the reason
    /// it went unnoticed: a bare uid IS redacted by the rule above, so the
    /// safety net looked like it worked. But an UNDERSCORE is a word
    /// character, so the `\b` anchors never fire inside `direct_<a>_<b>` —
    /// the id a direct conversation derives from its two members. The whole
    /// 64-char token then fails the {20,28} length test and passes through
    /// untouched, with BOTH uids in clear text, on its way to Crashlytics.
    ///
    /// Measured before the fix: the composite string came out byte-identical
    /// to the input while a bare uid one word away became `aBcD***`.
    test('redacts a direct conversation id, which hides TWO uids', () {
      const uidA = 'aBcDeFgHiJkLmNoPqRsTuVwXyZ12';
      const uidB = 'zZyYxXwWvVuUtTsSrRqQpPoO3456';
      final output = AppLogger.sanitizeForCrashlyticsForTesting(
        'Failed to read conversation direct_${uidA}_$uidB',
      );

      expect(
        output.contains(uidA),
        isFalse,
        reason: 'the first uid must not survive; before the fix it did',
      );
      expect(output.contains(uidB), isFalse, reason: 'nor the second');
      expect(
        output,
        matches(RegExp(r'^Failed to read conversation direct_#[0-9a-f]{12}$')),
        reason:
            'hashed, not blanked — these are error logs, and one '
            'conversation failing nine times must stay distinguishable from '
            'nine conversations failing once',
      );
    });

    /// Both rules on ONE message, asserted by exact equality — the only shape
    /// that can catch the two of them interfering.
    ///
    /// Written after a review found the first attempt vacuous: it fed a
    /// direct id alone and asserted `isNot(contains('***'))`, which is green
    /// whenever the composite rule is DELETED as well, since the bare-uid rule
    /// provably cannot match inside `direct_a_b` in any order. It could not
    /// fail on the mutant it was named for.
    test(
      'a bare uid and a direct id in one message each get their own rule',
      () {
        const bare = 'qQwWeErRtTyYuUiIoOpP12345678';
        const uidA = 'aBcDeFgHiJkLmNoPqRsTuVwXyZ12';
        const uidB = 'zZyYxXwWvVuUtTsSrRqQpPoO3456';
        final output = AppLogger.sanitizeForCrashlyticsForTesting(
          'user $bare in conversation direct_${uidA}_$uidB',
        );

        expect(
          output,
          matches(
            RegExp(r'^user qQwW\*\*\* in conversation direct_#[0-9a-f]{12}$'),
          ),
          reason:
              'the bare uid gets the 4-char prefix, the composite id gets '
              'the hash, and neither rule consumes what the other one needs',
        );
      },
    );

    /// Guards the COMPOSITE rule against over-reaching: a group id carries no
    /// member identity, so the direct-id rule must not touch it.
    ///
    /// It does NOT claim group ids survive this function. A group conversation
    /// id minted since BUT-1838 is a 20-char Firestore auto-id, which the
    /// bare-token rule below masks to `abcd***` — the hyphens in this uuid
    /// fixture are what keep it whole, not any rule about groups. Only DIRECT
    /// ids read identically here and in the Cloud Functions log.
    test('the composite rule does not reach a group conversation id', () {
      const groupId = '7f3a91c2-4bde-4a11-9c33-1e2f0a8b5d77';
      expect(
        AppLogger.sanitizeForCrashlyticsForTesting('conversation $groupId'),
        equals('conversation $groupId'),
      );
    });

    /// The composite pattern has a left boundary, so the `direct_` buried
    /// inside an ordinary English word is not treated as the start of an id.
    /// Without it, `redirect_<a>_<b>` hashed a SUBSTRING — a value
    /// `LogSanitizer.maskConversationId` would never produce for that token.
    test('does not hash the direct_ inside a word like redirect_', () {
      const uidA = 'aBcDeFgHiJkLmNoPqRsTuVwXyZ12';
      const uidB = 'zZyYxXwWvVuUtTsSrRqQpPoO3456';
      final output = AppLogger.sanitizeForCrashlyticsForTesting(
        'redirect_${uidA}_$uidB',
      );

      expect(output, isNot(contains('#')));
    });

    /// Boundary: 19 chars is below the regex floor → must NOT redact.
    /// (Otherwise short ids like 19-char correlation ids would be scrubbed.)
    test('does NOT redact 19-char tokens (below the regex floor)', () {
      final input = 'short token: abcdefghij1234567890';
      // 'abcdefghij1234567890' is 20 chars — would redact. Use 19.
      final input19 = 'short token: abcdefghij123456789';
      final output = AppLogger.sanitizeForCrashlyticsForTesting(input19);

      expect(
        output,
        equals(input19),
        reason: '19 chars is below the 20-char floor; must pass through',
      );
      // Sanity: 20-char companion does redact, confirming boundary placement.
      expect(
        AppLogger.sanitizeForCrashlyticsForTesting(input),
        equals('short token: abcd***'),
      );
    });

    /// Boundary: 29 chars is above the regex ceiling → must NOT redact.
    /// (Long hashes / SHA-256 etc. shouldn't get partial-redacted, just
    /// passed through whole — different sanitizer's job if needed.)
    test('does NOT redact 29-char tokens (above the regex ceiling)', () {
      final input29 = 'long: abcdefghijklmnopqrstuvwxyz123';
      final output = AppLogger.sanitizeForCrashlyticsForTesting(input29);

      expect(
        output,
        equals(input29),
        reason: '29 chars is above the 28-char ceiling; must pass through',
      );
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
