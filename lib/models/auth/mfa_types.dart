/// Domain types for MFA that hide firebase_auth from the view layer.
///
/// Views use these types instead of importing firebase_auth directly.
/// AuthService handles conversion between these and Firebase types.

/// Wraps a multi-factor resolver for sign-in challenges.
/// Views treat this as opaque; only AuthService unwraps it.
class MfaResolverInfo {
  final Object _resolver;

  const MfaResolverInfo({required Object resolver}) : _resolver = resolver;

  /// Used by AuthService to recover the Firebase resolver.
  T unwrap<T>() => _resolver as T;
}

/// What the user needs to add Butlery to an authenticator app, made by
/// AuthMfaService when enrollment starts. Views show [secretKey] and hand
/// the setup back; only AuthMfaService unwraps the Firebase secret.
class MfaTotpSetup {
  final Object _secret;

  /// The shared key, for typing into the app by hand. Never logged.
  final String secretKey;

  /// The otpauth:// address an authenticator app opens directly.
  final String otpauthUrl;

  const MfaTotpSetup({
    required Object secret,
    required this.secretKey,
    required this.otpauthUrl,
  }) : _secret = secret;

  T unwrap<T>() => _secret as T;
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

/// The number of one-time backup codes a user gets when two-step
/// verification is switched on (produktregler.md:748).
const int mfaBackupCodeCount = 10;

/// How a backup-code recovery ended.
enum MfaRecoveryOutcome {
  /// The second factor is gone; sign in again with the password.
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
