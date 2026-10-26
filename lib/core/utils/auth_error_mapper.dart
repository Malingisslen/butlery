import 'package:firebase_auth/firebase_auth.dart';
import 'package:butlery/core/extensions/default_value_extensions.dart';
import 'package:butlery/core/l10n/app_locale.dart';

/// Maps Firebase auth error codes to localized user-facing messages.
/// Shared by AuthService and AuthMfaService to avoid duplication.
String mapAuthErrorToMessage(FirebaseAuthException e) {
  final blocked = blockingRefusalMessage(e);
  if (blocked != null) return blocked;
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

/// The guest-list blocking functions (BUT-2452) refuse with a marker in the
/// message. The platforms wrap that text differently and none of it has a
/// code of its own, so the marker is looked for anywhere in the error.
String? blockingRefusalMessage(FirebaseAuthException e) {
  final l = AppLocale.current;
  final text = '${e.message.orEmpty()} $e';
  if (text.contains('SIGNUP_GATE_UNAVAILABLE')) {
    return l.errorSignupGateUnavailable;
  }
  if (text.contains('SIGNUP_EMAIL_UNVERIFIED')) {
    return l.errorSignInEmailUnverified;
  }
  if (text.contains('SIGNUP_NOT_INVITED')) return l.errorSignupNotInvited;
  if (e.code == 'blocking-function-error-response') {
    return l.errorSignupNotInvited;
  }
  return null;
}
