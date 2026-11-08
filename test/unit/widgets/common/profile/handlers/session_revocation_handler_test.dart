// BUT-2481: who gets the "Logga ut från alla enheter" row.

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:butlery/models/auth/provider_sign_in_types.dart';
import 'package:butlery/widgets/common/profile/handlers/session_revocation_handler.dart';

import '../../../../../infrastructure/mocks/production_mocks.dart'
    show MockAuthService;

class _MockUser extends Mock implements User {}

class _Auth extends MockAuthService {
  _Auth({required this.linked, bool anonymous = false}) {
    final user = _MockUser();
    when(() => user.isAnonymous).thenReturn(anonymous);
    setAuthState(currentUser: user, isAuthenticated: true);
  }

  final Set<SignInProvider> linked;

  @override
  bool isProviderLinked(SignInProvider provider) => linked.contains(provider);
}

void main() {
  test('no auth service: no row', () {
    expect(SessionRevocationHandler.providerFor(null), isNull);
  });

  test('a guest never gets the row, even with a provider linked', () {
    final auth = _Auth(linked: {SignInProvider.google}, anonymous: true);
    expect(SessionRevocationHandler.providerFor(auth), isNull);
  });

  test('a password-only account gets no row', () {
    expect(SessionRevocationHandler.providerFor(_Auth(linked: {})), isNull);
  });

  test('Google only gives Google', () {
    final auth = _Auth(linked: {SignInProvider.google});
    expect(SessionRevocationHandler.providerFor(auth), SignInProvider.google);
  });

  test('both linked: Apple wins', () {
    final auth = _Auth(
      linked: {SignInProvider.google, SignInProvider.apple},
    );
    expect(SessionRevocationHandler.providerFor(auth), SignInProvider.apple);
  });
}
