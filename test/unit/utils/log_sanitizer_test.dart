/// Unit tests for LogSanitizer — PII masking for log output.
library;

import 'package:flutter_test/flutter_test.dart';
import '../../test_support/base_unit_test.dart';
import 'package:butlery/core/utils/log_sanitizer.dart';

void main() {
  group('LogSanitizer', () {
    setUp(() async => await BaseUnitTest.setupUnit());
    tearDown(() => BaseUnitTest.resetMocks());

    group('maskEmail', () {
      test('null returns "null"', () {
        expect(LogSanitizer.maskEmail(null), 'null');
      });

      test('empty returns "[empty]"', () {
        expect(LogSanitizer.maskEmail(''), '[empty]');
      });

      test('no @ returns "***@invalid"', () {
        expect(LogSanitizer.maskEmail('noemail'), '***@invalid');
      });

      test('short local part masks correctly', () {
        final result = LogSanitizer.maskEmail('ab@x.com');
        expect(result, contains('***'));
        expect(result, contains('.com'));
      });

      test('normal email masks local part keeping first 3 chars', () {
        final result = LogSanitizer.maskEmail('user@example.com');
        expect(result, startsWith('use'));
        expect(result, contains('***'));
        expect(result, endsWith('.com'));
      });
    });

    group('maskUserId', () {
      test('null returns "null"', () {
        expect(LogSanitizer.maskUserId(null), 'null');
      });

      test('empty returns "[empty]"', () {
        expect(LogSanitizer.maskUserId(''), '[empty]');
      });

      test('short id returned as-is', () {
        expect(LogSanitizer.maskUserId('abc12345'), 'abc12345');
      });

      test('long id truncated to 8 chars with ellipsis', () {
        expect(LogSanitizer.maskUserId('abcdefghijklmnop'), 'abcdefgh...');
      });
    });

    group('maskPhoneNumber', () {
      test('null returns "null"', () {
        expect(LogSanitizer.maskPhoneNumber(null), 'null');
      });

      test('empty returns "[empty]"', () {
        expect(LogSanitizer.maskPhoneNumber(''), '[empty]');
      });

      test('very short phone returns "***"', () {
        expect(LogSanitizer.maskPhoneNumber('123'), '***');
      });

      test('normal phone keeps first 4 and last 4', () {
        expect(LogSanitizer.maskPhoneNumber('+46701234567'), '+467***4567');
      });
    });

    group('maskDisplayName', () {
      test('null returns "null"', () {
        expect(LogSanitizer.maskDisplayName(null), 'null');
      });

      test('empty returns "[empty]"', () {
        expect(LogSanitizer.maskDisplayName(''), '[empty]');
      });

      test('very short name masks with X', () {
        final result = LogSanitizer.maskDisplayName('AB');
        expect(result, contains('***'));
      });

      test('normal name keeps first 2 chars', () {
        expect(LogSanitizer.maskDisplayName('Anna Svensson'), 'An***');
      });
    });

    group('extensions', () {
      test('maskedEmail delegates to maskEmail', () {
        expect('user@example.com'.maskedEmail,
            LogSanitizer.maskEmail('user@example.com'));
      });

      test('maskedUserId delegates to maskUserId', () {
        expect('abc'.maskedUserId, LogSanitizer.maskUserId('abc'));
      });

      test('maskedPhone delegates to maskPhoneNumber', () {
        expect('+46701234567'.maskedPhone,
            LogSanitizer.maskPhoneNumber('+46701234567'));
      });

      test('maskedName delegates to maskDisplayName', () {
        expect('Anna'.maskedName, LogSanitizer.maskDisplayName('Anna'));
      });

      test('null extension works', () {
        const String? val = null;
        expect(val.maskedEmail, 'null');
      });
    });
  });
}
