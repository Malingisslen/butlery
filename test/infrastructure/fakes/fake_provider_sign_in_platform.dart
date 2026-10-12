import 'dart:convert';

import 'package:butlery/models/auth/provider_sign_in_types.dart';
import 'package:butlery/services/auth/provider_sign_in_platform.dart';

/// A provider platform with scripted sheets, for ProviderSignInService and
/// AuthService tests (BUT-916). Each `obtainTokens` call takes the next
/// scripted answer for that provider; null means the user closed the sheet.
class FakeProviderSignInPlatform implements ProviderSignInPlatform {
  FakeProviderSignInPlatform({
    this.googleFlow = ProviderFlow.native,
    this.appleFlow = ProviderFlow.native,
  });

  ProviderFlow googleFlow;
  ProviderFlow appleFlow;

  final Map<SignInProvider, List<ProviderTokens?>> _sheets = {};
  final List<SignInProvider> sheetsOpened = [];
  int googleSignOuts = 0;

  void answer(SignInProvider provider, ProviderTokens? tokens) =>
      (_sheets[provider] ??= []).add(tokens);

  @override
  ProviderFlow flowFor(SignInProvider provider) => switch (provider) {
    SignInProvider.google => googleFlow,
    SignInProvider.apple => appleFlow,
  };

  @override
  Future<ProviderTokens?> obtainTokens(SignInProvider provider) async {
    sheetsOpened.add(provider);
    final queue = _sheets[provider];
    if (queue == null || queue.isEmpty) return null;
    return queue.removeAt(0);
  }

  @override
  Future<void> signOutGoogle() async => googleSignOuts++;
}

/// An unsigned JWT carrying [claims], enough for the client's own reading of
/// `email_verified` (Firebase checks the signature, not the app).
String fakeIdToken(Map<String, Object?> claims) {
  String part(Map<String, Object?> map) =>
      base64Url.encode(utf8.encode(jsonEncode(map))).replaceAll('=', '');
  return '${part({'alg': 'none'})}.${part(claims)}.c2ln';
}

ProviderTokens googleTokens({
  String email = 'anna@example.com',
  bool verified = true,
}) => ProviderTokens(
  provider: SignInProvider.google,
  idToken: fakeIdToken({'email': email, 'email_verified': verified}),
);

ProviderTokens appleTokens({
  String email = 'anna@example.com',
  String? authorizationCode = 'apple-code',
  String? givenName,
}) => ProviderTokens(
  provider: SignInProvider.apple,
  idToken: fakeIdToken({'email': email, 'email_verified': 'true'}),
  rawNonce: 'raw-nonce',
  authorizationCode: authorizationCode,
  givenName: givenName,
);
