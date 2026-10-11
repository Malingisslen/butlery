/// Domain types for "Fortsätt med Google / Apple" (BUT-916, BUT-549) that keep
/// firebase_auth and the provider SDKs out of views and viewmodels.
library;

/// A sign-in provider the app offers beside e-mail and password.
enum SignInProvider {
  google('google.com', 'google'),
  apple('apple.com', 'apple')
  ;

  const SignInProvider(this.providerId, this.analyticsMethod);

  /// Firebase's id for the provider, as on `UserInfo.providerId`.
  final String providerId;

  /// The `method` parameter analytics logs for a sign-in through it.
  final String analyticsMethod;

  static SignInProvider? fromProviderId(String? id) {
    for (final provider in values) {
      if (provider.providerId == id) return provider;
    }
    return null;
  }
}

/// How a provider sign-in ended, as AuthService reports it.
enum ProviderSignInOutcome {
  /// A user is signed in.
  signedIn,

  /// The provider answered; the account has two-step verification and the
  /// code is asked for next (`AuthService.pendingMfaChallenge`).
  mfaRequired,

  /// The address already has a password account. The password is asked for
  /// once, and the provider is linked after the sign-in (and its second
  /// factor) has gone through (`AuthService.pendingProviderLink`).
  linkNeedsPassword,

  /// The user closed the provider's sheet. Nothing is shown.
  cancelled,

  /// Something else went wrong; `AuthService.errorMessage` says what.
  failed,
}

/// What the provider handed the app itself, before Firebase saw it.
///
/// Held in memory only and never logged: [toString] prints no token.
class ProviderTokens {
  const ProviderTokens({
    required this.provider,
    required this.idToken,
    this.rawNonce,
    this.authorizationCode,
    this.givenName,
  });

  final SignInProvider provider;
  final String idToken;

  /// The nonce before hashing. Apple put its SHA-256 in [idToken]; Firebase
  /// and the backup-code server need the raw value.
  final String? rawNonce;

  /// Apple's one-time code, which revokes the app's Apple tokens when the
  /// account is deleted.
  final String? authorizationCode;

  /// The first name Apple shares on the first sign-in only.
  final String? givenName;

  @override
  String toString() => 'ProviderTokens(${provider.providerId})';
}

/// The account a provider sign-in found already registered with a password,
/// as the "Koppla ihop" step shows it.
class PendingProviderLink {
  const PendingProviderLink({required this.email, required this.provider});

  final String email;
  final SignInProvider provider;
}
