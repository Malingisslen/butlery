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
