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

    test('phoneHint defaults to null and is preserved when set', () {
      expect(MfaResolverInfo(resolver: Object()).phoneHint, isNull);
      expect(
        MfaResolverInfo(resolver: Object(), phoneHint: '+46…').phoneHint,
        '+46…',
      );
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

  group('MfaError', () {
    test('preserves code + optional message', () {
      const e = MfaError(code: 'invalid-code');
      expect(e.code, 'invalid-code');
      expect(e.message, isNull);

      const e2 = MfaError(code: 'expired', message: 'Code expired');
      expect(e2.code, 'expired');
      expect(e2.message, 'Code expired');
    });

    test('is const-constructible', () {
      const a = MfaError(code: 'x');
      const b = MfaError(code: 'x');
      // const-canonicalized references collapse to identical instances.
      expect(identical(a, b), isTrue);
    });
  });
}
