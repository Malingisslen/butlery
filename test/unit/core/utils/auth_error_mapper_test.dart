/// Unit tests for mapAuthErrorToMessage.
///
/// FirebaseAuthException codes → localized Swedish copy via AppLocale.
/// Each known code branch is pinned, plus the catch-all that falls back
/// to the generic auth error message.
library;

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/core/l10n/app_locale.dart';
import 'package:butlery/core/utils/auth_error_mapper.dart';

FirebaseAuthException _err(String code) => FirebaseAuthException(code: code);

/// Some platform wrappers carry the server's text only in `toString()`.
class _WrappedError extends FirebaseAuthException {
  _WrappedError(this.raw) : super(code: 'internal-error');
  final String raw;
  @override
  String toString() => raw;
}

void main() {
  final l = AppLocale.current;

  test('weak-password → errorWeakPassword', () {
    expect(mapAuthErrorToMessage(_err('weak-password')), l.errorWeakPassword);
  });

  test('email-already-in-use → errorEmailAlreadyInUse', () {
    expect(
      mapAuthErrorToMessage(_err('email-already-in-use')),
      l.errorEmailAlreadyInUse,
    );
  });

  test('invalid-email → errorInvalidEmailAddress', () {
    expect(
      mapAuthErrorToMessage(_err('invalid-email')),
      l.errorInvalidEmailAddress,
    );
  });

  test(
    'user-not-found / wrong-password / invalid-credential collapse to one msg',
    () {
      for (final code in [
        'user-not-found',
        'wrong-password',
        'invalid-credential',
      ]) {
        expect(
          mapAuthErrorToMessage(_err(code)),
          l.errorInvalidCredentials,
          reason: code,
        );
      }
    },
  );

  test('user-disabled → errorAccountDisabled', () {
    expect(
      mapAuthErrorToMessage(_err('user-disabled')),
      l.errorAccountDisabled,
    );
  });

  test('too-many-requests → errorTooManyAttempts', () {
    expect(
      mapAuthErrorToMessage(_err('too-many-requests')),
      l.errorTooManyAttempts,
    );
  });

  test('network-request-failed → errorNetwork', () {
    expect(
      mapAuthErrorToMessage(_err('network-request-failed')),
      l.errorNetwork,
    );
  });

  test('invalid-verification-code → errorInvalidVerificationCode', () {
    expect(
      mapAuthErrorToMessage(_err('invalid-verification-code')),
      l.errorInvalidVerificationCode,
    );
  });

  test(
    'session-expired / user-token-expired / invalid-user-token / requires-recent-login collapse to one msg',
    () {
      for (final code in [
        'session-expired',
        'user-token-expired',
        'invalid-user-token',
        'requires-recent-login',
      ]) {
        expect(
          mapAuthErrorToMessage(_err(code)),
          l.errorSessionExpired,
          reason: code,
        );
      }
    },
  );

  test('quota-exceeded → errorTooManySmsAttempts', () {
    expect(
      mapAuthErrorToMessage(_err('quota-exceeded')),
      l.errorTooManySmsAttempts,
    );
  });

  test('invalid-phone-number → errorInvalidPhoneNumber', () {
    expect(
      mapAuthErrorToMessage(_err('invalid-phone-number')),
      l.errorInvalidPhoneNumber,
    );
  });

  test('missing-phone-number → errorPhoneNumberMissing', () {
    expect(
      mapAuthErrorToMessage(_err('missing-phone-number')),
      l.errorPhoneNumberMissing,
    );
  });

  test('unknown code → errorAuthentication (catch-all)', () {
    expect(
      mapAuthErrorToMessage(_err('something-completely-new')),
      l.errorAuthentication,
    );
  });
  group('guest-list refusals (BUT-2452)', () {
    for (final code in ['internal-error', 'blocking-function-error-response']) {
      test('$code with SIGNUP_NOT_INVITED → errorSignupNotInvited', () {
        final e = FirebaseAuthException(
          code: code,
          message:
              'SIGNUP_NOT_INVITED: Butlery är bara öppet för inbjudna just nu.',
        );
        expect(mapAuthErrorToMessage(e), l.errorSignupNotInvited);
      });

      test('$code with SIGNUP_GATE_UNAVAILABLE → errorSignupGateUnavailable', () {
        final e = FirebaseAuthException(
          code: code,
          message:
              'HTTP Cloud Function returned an error: SIGNUP_GATE_UNAVAILABLE: x',
        );
        expect(mapAuthErrorToMessage(e), l.errorSignupGateUnavailable);
      });

      test(
        '$code with SIGNUP_EMAIL_UNVERIFIED → errorSignInEmailUnverified',
        () {
          final e = FirebaseAuthException(
            code: code,
            message: 'SIGNUP_EMAIL_UNVERIFIED: x',
          );
          expect(mapAuthErrorToMessage(e), l.errorSignInEmailUnverified);
        },
      );
    }

    test(
      'blocking-function-error-response with a null message → try again, '
      'not "not invited" (BUT-2471)',
      () {
        expect(
          mapAuthErrorToMessage(_err('blocking-function-error-response')),
          l.errorSignupGateUnavailable,
        );
      },
    );

    test('internal-error with a null message stays the generic error', () {
      expect(
        mapAuthErrorToMessage(_err('internal-error')),
        l.errorAuthentication,
      );
    });

    test('marker found only in toString()', () {
      final e = _WrappedError('PlatformException(SIGNUP_NOT_INVITED: ...)');
      expect(e.message, isNull);
      expect(mapAuthErrorToMessage(e), l.errorSignupNotInvited);
    });
  });
}
