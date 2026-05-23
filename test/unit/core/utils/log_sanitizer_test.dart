/// Unit tests for LogSanitizer + extension methods.
///
/// Pin the masking format — the values appear in production logs and in
/// GDPR exports, so the masking shape is a contract.
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/core/utils/log_sanitizer.dart';

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
