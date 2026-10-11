import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/models/auth/provider_sign_in_types.dart';

/// How a provider's sheet is shown on this platform.
enum ProviderFlow {
  /// The provider's own SDK runs first and hands the app its tokens
  /// ([ProviderSignInPlatform.obtainTokens]); Firebase gets a credential.
  native,

  /// Firebase runs the provider's sheet itself (a popup on the web,
  /// `AppleAuthProvider` on Android). The app never sees the tokens, so a
  /// backup code cannot be proved through the provider there.
  firebase,

  /// Not offered here (the desktop builds): the buttons are hidden.
  unavailable,
}

/// The provider sheet failed for a reason other than the user closing it.
class ProviderSheetException implements Exception {
  const ProviderSheetException(this.reason);

  /// For the log only; never shown, never a token.
  final String reason;

  @override
  String toString() => 'ProviderSheetException($reason)';
}

/// The provider SDKs behind one seam, so the sign-in logic runs in tests
/// without Google's or Apple's plugins. Firebase is not called from here:
/// `AuthRepository` owns that.
abstract class ProviderSignInPlatform {
  ProviderFlow flowFor(SignInProvider provider);

  /// Runs the provider's own sheet and returns its tokens, or null when the
  /// user closed it. Throws [ProviderSheetException] on any other failure.
  /// Only for a [ProviderFlow.native] provider.
  Future<ProviderTokens?> obtainTokens(SignInProvider provider);

  /// Forgets the Google account chosen in the account picker, so the next
  /// "Fortsätt med Google" asks again. Never throws.
  Future<void> signOutGoogle();
}

/// The real SDKs: `google_sign_in` 7 on Android and iOS, `sign_in_with_apple`
/// on iOS. The web and Apple on Android go through Firebase's own flow.
class DeviceProviderSignInPlatform implements ProviderSignInPlatform {
  DeviceProviderSignInPlatform({GoogleSignIn? googleSignIn})
    : _google = googleSignIn ?? GoogleSignIn.instance;

  final GoogleSignIn _google;
  Future<void>? _googleReady;

  /// The web OAuth client the Google id token must be issued for, so that
  /// Firebase accepts it. Empty means the SDK's own default: on Android
  /// `default_web_client_id` from google-services.json, on iOS the
  /// CLIENT_ID of GoogleService-Info.plist.
  static const String _serverClientId = String.fromEnvironment(
    'GOOGLE_SERVER_CLIENT_ID',
  );

  @override
  ProviderFlow flowFor(SignInProvider provider) {
    if (kIsWeb) return ProviderFlow.firebase;
    return switch (defaultTargetPlatform) {
      TargetPlatform.iOS => ProviderFlow.native,
      TargetPlatform.android =>
        provider == SignInProvider.google
            ? ProviderFlow.native
            : ProviderFlow.firebase,
      _ => ProviderFlow.unavailable,
    };
  }

  /// `initialize` may run once per process; a failed attempt is retried.
  Future<void> _initializeGoogle() async {
    try {
      await (_googleReady ??= _google.initialize(
        serverClientId: _serverClientId.isEmpty ? null : _serverClientId,
      ));
    } catch (_) {
      _googleReady = null;
      rethrow;
    }
  }

  @override
  Future<ProviderTokens?> obtainTokens(SignInProvider provider) =>
      switch (provider) {
        SignInProvider.google => _googleTokens(),
        SignInProvider.apple => _appleTokens(),
      };

  Future<ProviderTokens?> _googleTokens() async {
    try {
      await _initializeGoogle();
      final account = await _google.authenticate(
        scopeHint: const ['email', 'profile'],
      );
      final idToken = account.authentication.idToken;
      if (idToken == null) {
        throw const ProviderSheetException('google: no id token');
      }
      return ProviderTokens(provider: SignInProvider.google, idToken: idToken);
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled) return null;
      throw ProviderSheetException('google: ${e.code.name}');
    }
  }

  Future<ProviderTokens?> _appleTokens() async {
    // Apple embeds the SHA-256 of the nonce in its token; Firebase and the
    // backup-code server get the raw value to compare.
    final rawNonce = _randomNonce();
    try {
      final credential = await SignInWithApple.getAppleIDCredential(
        scopes: const [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
        nonce: sha256.convert(utf8.encode(rawNonce)).toString(),
      );
      final idToken = credential.identityToken;
      if (idToken == null) {
        throw const ProviderSheetException('apple: no identity token');
      }
      return ProviderTokens(
        provider: SignInProvider.apple,
        idToken: idToken,
        rawNonce: rawNonce,
        authorizationCode: credential.authorizationCode,
        givenName: credential.givenName,
      );
    } on SignInWithAppleAuthorizationException catch (e) {
      if (e.code == AuthorizationErrorCode.canceled) return null;
      throw ProviderSheetException('apple: ${e.code.name}');
    }
  }

  static String _randomNonce([int length = 32]) {
    const charset =
        '0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._';
    final random = Random.secure();
    return List.generate(
      length,
      (_) => charset[random.nextInt(charset.length)],
    ).join();
  }

  @override
  Future<void> signOutGoogle() async {
    if (flowFor(SignInProvider.google) != ProviderFlow.native) return;
    try {
      await _initializeGoogle();
      await _google.signOut();
    } catch (e) {
      AppLogger.warning('Google sign-out failed: ${e.runtimeType}');
    }
  }
}
