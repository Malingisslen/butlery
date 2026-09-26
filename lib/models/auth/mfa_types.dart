/// Domain types for MFA that hide firebase_auth from the view layer.
///
/// Views use these types instead of importing firebase_auth directly.
/// AuthService handles conversion between these and Firebase types.

/// Wraps a multi-factor resolver for sign-in challenges.
/// Views treat this as opaque; only AuthService unwraps it.
class MfaResolverInfo {
  final Object _resolver;
  final String? phoneHint;

  const MfaResolverInfo({
    required Object resolver,
    this.phoneHint,
  }) : _resolver = resolver;

  /// Used by AuthService to recover the Firebase resolver.
  T unwrap<T>() => _resolver as T;
}

/// Domain representation of an enrolled MFA factor.
class MfaFactorInfo {
  final Object _factor;
  final String? displayName;
  final double? enrollmentTimestamp;

  const MfaFactorInfo({
    required Object factor,
    this.displayName,
    this.enrollmentTimestamp,
  }) : _factor = factor;

  T unwrap<T>() => _factor as T;
}

/// Lightweight error type for MFA callbacks, replacing FirebaseAuthException in view layer.
class MfaError {
  final String code;
  final String? message;

  const MfaError({required this.code, this.message});
}

/// The number of one-time backup codes a user gets when two-step
/// verification is switched on (produktregler.md:748).
const int mfaBackupCodeCount = 10;

/// How a backup-code recovery ended.
enum MfaRecoveryOutcome {
  /// The phone factor is gone; sign in again with the password.
  recovered,

  /// The password or the code did not match, or the account has no second
  /// factor, or its code lock is on. Deliberately one outcome: the server
  /// gives the same answer for all of them, so it confirms no password.
  rejected,

  /// Too many attempts from this device or network; try again later.
  locked,

  /// The server could not be reached or is not set up.
  unavailable,
}

/// The last two digits of a masked phone hint, for "•• 47"
/// (Skarmar v12 etapp 3 #authmfa). Null when the hint has fewer than two
/// digits. Firebase already masks the number in a resolver's hints; the app
/// never knows the whole number.
String? maskedPhoneTail(String? hint) {
  if (hint == null) return null;
  final digits = hint.replaceAll(RegExp(r'[^0-9]'), '');
  if (digits.length < 2) return null;
  return digits.substring(digits.length - 2);
}
