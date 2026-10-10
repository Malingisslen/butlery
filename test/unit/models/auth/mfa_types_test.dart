/// Unit tests for MFA domain types.
///
/// These types exist to hide firebase_auth from the view layer. Tests
/// verify the opaque-handle round-trip via `unwrap<T>()` and the
/// constructor field-preservation contract — no Firebase wiring needed.
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/models/auth/mfa_types.dart';

void main() {
  group('MfaResolverInfo', () {
    test('unwrap returns the original opaque resolver', () {
      final raw = Object();
      final info = MfaResolverInfo(resolver: raw);
      expect(info.unwrap<Object>(), same(raw));
    });
  });

  group('MfaTotpSetup', () {
    test('keeps the key and address and unwraps the opaque secret', () {
      final raw = Object();
      final setup = MfaTotpSetup(
        secret: raw,
        secretKey: 'ABCDEFGHIJKLMNOP',
        otpauthUrl: 'otpauth://totp/Butlery:anna?secret=ABCDEFGHIJKLMNOP',
      );
      expect(setup.secretKey, 'ABCDEFGHIJKLMNOP');
      expect(setup.otpauthUrl, startsWith('otpauth://totp/'));
      expect(setup.unwrap<Object>(), same(raw));
    });
  });

  group('MfaFactorInfo', () {
    test('unwrap returns the original opaque factor', () {
      final raw = Object();
      final info = MfaFactorInfo(factor: raw);
      expect(info.unwrap<Object>(), same(raw));
    });

    test('optional fields default to null and are preserved', () {
      final info1 = MfaFactorInfo(factor: Object());
      expect(info1.displayName, isNull);
      expect(info1.enrollmentTimestamp, isNull);

      final info2 = MfaFactorInfo(
        factor: Object(),
        displayName: 'iPhone backup',
        enrollmentTimestamp: 1700000000.0,
      );
      expect(info2.displayName, 'iPhone backup');
      expect(info2.enrollmentTimestamp, 1700000000.0);
    });
  });
}
