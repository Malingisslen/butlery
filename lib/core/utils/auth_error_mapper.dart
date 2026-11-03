import 'package:firebase_auth/firebase_auth.dart';
import 'package:butlery/core/extensions/default_value_extensions.dart';
import 'package:butlery/core/l10n/app_locale.dart';

/// Maps Firebase auth error codes to localized user-facing messages.
/// Shared by AuthService and AuthMfaService to avoid duplication.
///
/// [passwordSignIn] is true for a sign-in with an existing password account,
/// where the guest list can only be refusing an unverified address.
String mapAuthErrorToMessage(
  FirebaseAuthException e, {
  bool passwordSignIn = false,
}) {
  final blocked = blockingRefusalMessage(e, passwordSignIn: passwordSignIn);
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
    // The reset mail's link settings were refused (BUT-2502); "log in again"
    // would send the person who forgot the password in a circle.
    'invalid-hosting-link-domain' ||
    'invalid-dynamic-link-domain' ||
    'unauthorized-continue-uri' ||
    'invalid-continue-uri' ||
    'missing-continue-uri' ||
    'missing-android-pkg-name' ||
    'missing-ios-bundle-id' => l.errorPasswordResetLinkFailed,
    _ => l.errorAuthentication,
  };
}

/// The guest-list blocking functions (BUT-2452) refuse with a marker in the
/// message. The platforms wrap that text differently and none of it has a
/// code of its own, so the marker is looked for anywhere in the error.
String? blockingRefusalMessage(
  FirebaseAuthException e, {
  bool passwordSignIn = false,
}) {
  final l = AppLocale.current;
  final text = '${e.message.orEmpty()} $e';
  if (text.contains('SIGNUP_GATE_UNAVAILABLE')) {
    return l.errorSignupGateUnavailable;
  }
  if (text.contains('SIGNUP_EMAIL_UNVERIFIED')) {
    return l.errorSignInEmailUnverified;
  }
  if (text.contains('SIGNUP_NOT_INVITED')) return l.errorSignupNotInvited;
  // Android hands over the code without the server's text, so the marker is
  // gone (BUT-2502). A password sign-in is refused only for an unverified
  // address. Anything else may be "not invited" or a gate that failed, and
  // the text has to be true for both (BUT-2471).
  if (e.code == 'blocking-function-error-response') {
    return passwordSignIn
        ? l.errorSignInEmailUnverified
        : l.errorSignupRefusedUnmarked;
  }
  return null;
}
