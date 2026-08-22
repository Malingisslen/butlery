/// Unit tests for LogSanitizer + extension methods.
///
/// Pin the masking format — the values appear in production logs and in
/// GDPR exports, so the masking shape is a contract.
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/core/utils/log_sanitizer.dart';
import 'package:butlery/core/utils/logger.dart';

void main() {
  group('maskEmail', () {
    test('null → "null"', () {
      expect(LogSanitizer.maskEmail(null), 'null');
    });

    test('empty → "[empty]"', () {
      expect(LogSanitizer.maskEmail(''), '[empty]');
    });

    test('no "@" → "***@invalid"', () {
      expect(LogSanitizer.maskEmail('notanemail'), '***@invalid');
    });

    test('long local part: first 3 chars + *** + masked domain', () {
      expect(LogSanitizer.maskEmail('user@example.com'), 'use***@***.com');
    });

    test('short (<=3 char) local part: first char + **', () {
      expect(LogSanitizer.maskEmail('a@example.com'), 'a**@***.com');
      expect(LogSanitizer.maskEmail('ab@example.com'), 'a**@***.com');
      expect(LogSanitizer.maskEmail('abc@example.com'), 'a**@***.com');
    });

    test('domain with no dot → just "***"', () {
      expect(LogSanitizer.maskEmail('user@localhost'), 'use***@***');
    });
  });

  group('maskUserId', () {
    test('null → "null"', () {
      expect(LogSanitizer.maskUserId(null), 'null');
    });

    test('empty → "[empty]"', () {
      expect(LogSanitizer.maskUserId(''), '[empty]');
    });

    test('<=8 chars → returned as-is (no masking value)', () {
      expect(LogSanitizer.maskUserId('abc'), 'abc');
      expect(LogSanitizer.maskUserId('12345678'), '12345678');
    });

    test('>8 chars → first 8 + "..."', () {
      expect(LogSanitizer.maskUserId('abcdefghijk'), 'abcdefgh...');
    });
  });

  group('maskPhoneNumber', () {
    test('null/empty short paths', () {
      expect(LogSanitizer.maskPhoneNumber(null), 'null');
      expect(LogSanitizer.maskPhoneNumber(''), '[empty]');
    });

    test('<=4 chars → "***"', () {
      expect(LogSanitizer.maskPhoneNumber('1234'), '***');
    });

    test('first 4 + *** + last 4', () {
      expect(LogSanitizer.maskPhoneNumber('+46701234567'), '+467***4567');
    });
  });

  group('maskConversationId (BUT-1872)', () {
    // The two uids a real direct id is built from. What makes the fixture
    // realistic is the SHAPE, not the length: the bare-uid rule at the
    // Crashlytics chokepoint never gets to either half, because the composite
    // rule runs FIRST and consumes the whole id.
    //
    // That safety comes from the ORDER, not from the anchoring — see
    // [LogSanitizer.maskIdentifiers], which owns why the order is load-bearing
    // and what `\b` used to do here (BUT-1872 / BUT-1897). Locally: reverse the
    // two rules and rule 2 masks each 20-28 CHARACTER half separately, giving
    // `direct_aBcD***_zYxW***` for THESE two (the minted-shape fixture below is
    // a different pair and reverses to `direct_aBcD***_zZyY***` — the two-letter
    // difference is the fixture, not a typo). That is what the qualifier is for:
    // the short-half case below and the 40-char one are BOTH untouched by such
    // a reversal: the short halves fall below the {20,28} window and the 40-char
    // ones overshoot it, so rule 2 cannot match either way.
    //
    // But none of that makes THIS fixture a guard. Every test that uses THESE
    // TWO constants calls `maskConversationId` directly, never the chokepoint,
    // so a rule reorder cannot move any of them.
    //
    // The one test in THIS group that does reach the chokepoint is the
    // minted-shape case below, and its 28+28 fixture is the file's only reorder
    // guard — it compares the chokepoint against the helper. See
    // [LogSanitizer.maskIdentifiers], which names it. Do not trim that fixture
    // list to the cases that look interesting.
    const uidA = 'aBcDeFgHiJkLmNoPqRsT';
    const uidB = 'zYxWvUtSrQpOnMlKjIhG';
    const directId = 'direct_${uidA}_$uidB';

    test('null → "null"', () {
      expect(LogSanitizer.maskConversationId(null), 'null');
    });

    test('empty → "[empty]"', () {
      expect(LogSanitizer.maskConversationId(''), '[empty]');
    });

    test('a direct id reveals NEITHER uid', () {
      final masked = LogSanitizer.maskConversationId(directId);
      expect(masked, isNot(contains(uidA)));
      expect(masked, isNot(contains(uidB)));
      expect(masked, startsWith('direct_#'));
    });

    test('two different conversations do NOT collapse to the same string', () {
      // The reason it is hashed rather than blanked: nine failures on one
      // conversation must still be distinguishable from one failure on nine.
      //
      // Only the INEQUALITY is asserted. Calling the same pure function twice
      // and expecting the same answer is green for any implementation,
      // including `return 'direct_#'` — the stability that actually matters is
      // pinned by the literal below.
      expect(
        LogSanitizer.maskConversationId(directId),
        isNot(LogSanitizer.maskConversationId('direct_${uidB}_$uidA')),
      );
    });

    test('the masked value matches the Cloud Functions helper EXACTLY', () {
      // The doc comment on maskConversationId promises that one conversation
      // reads the same in a Crashlytics report and in a Cloud Functions log.
      // That promise spans two languages, so nothing but a pinned value can
      // hold it — neither compiler can see the other side.
      //
      // Produced 2026-08-19 by `logSafeConversationId` in
      // `functions/src/messaging/enforce-group-minor-membership.ts`, which
      // hashes through `hashUid` in `functions/src/shared/hash-uid.ts`
      // (sha256 hex, first 12 chars, over the WHOLE id). Reproduce with:
      //
      //   node -e "const c=require('crypto');console.log(c.createHash('sha256')
      //     .update('direct_aBcDeFgHiJkLmNoPqRsT_zYxWvUtSrQpOnMlKjIhG')
      //     .digest('hex').substring(0,12))"
      //
      // IF THIS FAILS, one of the two sides drifted. Fix the drift. Do NOT
      // re-baseline this literal to whatever Dart now prints — that "fixes"
      // the test and kills the contract in the same commit.
      expect(
        LogSanitizer.maskConversationId(directId),
        'direct_#12fc49f947ab',
      );
    });

    test('a group id is opaque already and passes through unchanged', () {
      // Both shapes: the 20-char auto-id `createChatGroup` actually mints
      // today, and a dashed uuid, which is what the doc comment said until
      // 2026-08-19 and what any legacy row still carries. Neither starts with
      // `direct_`, and that — not the shape — is what makes them safe here.
      for (final groupId in const <String>[
        'kPq7Rw2LmNc4Xy9Zt1Bv',
        '3f2a9c1e-7b4d-4a5e-9c8f-1d2e3a4b5c6d',
      ]) {
        expect(LogSanitizer.maskConversationId(groupId), groupId);
      }
    });

    test('the helper and the chokepoint agree on every id of the MINTED '
        'shape, at any half-length', () {
      // The two nets used to disagree: the chokepoint bounded each half to
      // 20-28 chars, so a direct id built from short ids was hashed HERE and
      // passed the chokepoint RAW. Nothing live fell in the gap — real
      // Firebase uids are 28 chars — but "safe only for well-formed input" is
      // not a property a safety net should have.
      //
      // The chokepoint now delegates its format to this helper and matches
      // unbounded halves, so the two agree for any `direct_<a>_<b>` — which
      // is the only shape anything mints (`ConversationMutationModule` joins
      // exactly two sorted uids). They still differ on `direct_abc` and
      // `direct_a_b_c`; those are deliberately NOT asserted here, because
      // making the regex match them would mean hashing arbitrary
      // underscore-joined text.
      for (final id in <String>[
        'direct_abc_def', // short: was the gap
        'direct_aBcDeFgHiJkLmNoPqRsTuVwXyZ12_zZyYxXwWvVuUtTsSrRqQpPoO3456',
        'direct_${'a' * 40}_${'b' * 40}', // longer than the old ceiling
      ]) {
        expect(
          AppLogger.sanitizeForCrashlyticsForTesting(id),
          LogSanitizer.maskConversationId(id),
          reason: 'the two nets must not disagree on $id',
        );
      }
    });

    test('the extension getter masks too', () {
      // Against the LITERAL, not against the static it delegates to —
      // comparing the two is green when both are broken the same way.
      expect(directId.maskedConversationId, 'direct_#12fc49f947ab');
    });
  });

  group('maskDisplayName', () {
    test('null/empty short paths', () {
      expect(LogSanitizer.maskDisplayName(null), 'null');
      expect(LogSanitizer.maskDisplayName(''), '[empty]');
    });

    test('<=2 chars → first char + "***"', () {
      expect(LogSanitizer.maskDisplayName('A'), 'A***');
      expect(LogSanitizer.maskDisplayName('Al'), 'A***');
    });

    test('>2 chars → first 2 + "***"', () {
      expect(LogSanitizer.maskDisplayName('Anna Svensson'), 'An***');
    });
  });

  group('LogSanitizationExtensions', () {
    test('extension getters delegate to LogSanitizer', () {
      // Use nullable receivers to exercise the extension's null path
      // (the maskedXxx getters are declared on `String?`).
      // ignore: unnecessary_nullable_for_final_variable_declarations
      final String? email = 'user@example.com';
      expect(email.maskedEmail, 'use***@***.com');

      // ignore: unnecessary_nullable_for_final_variable_declarations
      final String? uid = 'abcdefghijk';
      expect(uid.maskedUserId, 'abcdefgh...');

      // ignore: unnecessary_nullable_for_final_variable_declarations
      final String? phone = '+46701234567';
      expect(phone.maskedPhone, '+467***4567');

      // ignore: unnecessary_nullable_for_final_variable_declarations
      final String? name = 'Anna Svensson';
      expect(name.maskedName, 'An***');
    });

    test('null receiver handled at the extension level', () {
      const String? nothing = null;
      expect(nothing.maskedEmail, 'null');
      expect(nothing.maskedUserId, 'null');
    });
  });
}
