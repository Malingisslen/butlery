import 'package:firebase_auth/firebase_auth.dart';
import 'package:butlery/core/l10n/app_locale.dart';

/// Maps Firebase auth error codes to localized user-facing messages.
/// Shared by AuthService and AuthMfaService to avoid duplication.
String mapAuthErrorToMessage(FirebaseAuthException e) {
  final l = AppLocale.current;
  return switch (e.code) {
    'weak-password' => l.errorWeakPassword,
    'email-already-in-use' => l.errorEmailAlreadyInUse,
    'invalid-email' => l.errorInvalidEmailAddress,
    'user-not-found' ||
    'wrong-password' ||
    'invalid-credential' => l.errorInvalidCredentials,
    'user-disabled' => l.errorAccountDisabled,
    'too-many-requests' => l.errorTooManyAttempts,
    'network-request-failed' => l.errorNetwork,
    'invalid-verification-code' => l.errorInvalidVerificationCode,
    'session-expired' ||
    'user-token-expired' ||
    'invalid-user-token' ||
    'requires-recent-login' => l.errorSessionExpired,
    'quota-exceeded' => l.errorTooManySmsAttempts,
    'invalid-phone-number' => l.errorInvalidPhoneNumber,
    'missing-phone-number' => l.errorPhoneNumberMissing,
    _ => l.errorAuthentication,
  };
}
