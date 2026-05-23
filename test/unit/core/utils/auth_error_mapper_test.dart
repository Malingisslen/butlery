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

void main() {
  final l = AppLocale.current;

  test('weak-password → errorWeakPassword', () {
    expect(mapAuthErrorToMessage(_err('weak-password')), l.errorWeakPassword);
  });

  test('email-already-in-use → errorEmailAlreadyInUse', () {
    expect(mapAuthErrorToMessage(_err('email-already-in-use')),
        l.errorEmailAlreadyInUse);
  });

  test('invalid-email → errorInvalidEmailAddress', () {
    expect(mapAuthErrorToMessage(_err('invalid-email')),
        l.errorInvalidEmailAddress);
  });

  test(
      'user-not-found / wrong-password / invalid-credential collapse to one msg',
      () {
    for (final code in [
      'user-not-found',
      'wrong-password',
      'invalid-credential'
    ]) {
      expect(mapAuthErrorToMessage(_err(code)), l.errorInvalidCredentials,
          reason: code);
    }
  });

  test('user-disabled → errorAccountDisabled', () {
    expect(
        mapAuthErrorToMessage(_err('user-disabled')), l.errorAccountDisabled);
  });

  test('too-many-requests → errorTooManyAttempts', () {
    expect(mapAuthErrorToMessage(_err('too-many-requests')),
        l.errorTooManyAttempts);
  });

  test('network-request-failed → errorNetwork', () {
    expect(
        mapAuthErrorToMessage(_err('network-request-failed')), l.errorNetwork);
  });

  test('invalid-verification-code → errorInvalidVerificationCode', () {
    expect(mapAuthErrorToMessage(_err('invalid-verification-code')),
        l.errorInvalidVerificationCode);
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
      expect(mapAuthErrorToMessage(_err(code)), l.errorSessionExpired,
          reason: code);
    }
  });

  test('quota-exceeded → errorTooManySmsAttempts', () {
    expect(mapAuthErrorToMessage(_err('quota-exceeded')),
        l.errorTooManySmsAttempts);
  });

  test('invalid-phone-number → errorInvalidPhoneNumber', () {
    expect(mapAuthErrorToMessage(_err('invalid-phone-number')),
        l.errorInvalidPhoneNumber);
  });

  test('missing-phone-number → errorPhoneNumberMissing', () {
    expect(mapAuthErrorToMessage(_err('missing-phone-number')),
        l.errorPhoneNumberMissing);
  });

  test('unknown code → errorAuthentication (catch-all)', () {
    expect(mapAuthErrorToMessage(_err('something-completely-new')),
        l.errorAuthentication);
  });
}
