import 'package:butlery/app/butlery_app.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../infrastructure/mocks/production_mocks.dart';

// BUT-2305: a user who verified their email through the link stayed blocked
// from friends and chat until they signed out, because nothing reloaded the
// Firebase user after "Fortsätt ändå".
void main() {
  late MockAuthService auth;

  setUp(() {
    auth = MockAuthService();
    when(() => auth.reloadUser()).thenAnswer((_) async {});
    when(() => auth.refreshSession()).thenAnswer((_) async => true);
  });

  test('an unverified user is reloaded', () async {
    auth.setAuthState(currentUser: FakeUser(emailVerified: false));
    await refreshEmailVerification(auth);
    verify(() => auth.reloadUser()).called(1);
  });

  test('a reload that finds the address verified also refreshes the token, '
      'which is what the rules read', () async {
    auth.setAuthState(currentUser: FakeUser(emailVerified: false));
    when(() => auth.reloadUser()).thenAnswer((_) async {
      auth.setAuthState(currentUser: FakeUser(emailVerified: true));
    });
    await refreshEmailVerification(auth);
    verify(() => auth.refreshSession()).called(1);
  });

  test('a reload that finds it still unverified leaves the token', () async {
    auth.setAuthState(currentUser: FakeUser(emailVerified: false));
    await refreshEmailVerification(auth);
    verifyNever(() => auth.refreshSession());
  });

  test('a verified user costs no call', () async {
    auth.setAuthState(currentUser: FakeUser(emailVerified: true));
    await refreshEmailVerification(auth);
    verifyNever(() => auth.reloadUser());
    verifyNever(() => auth.refreshSession());
  });

  test('nobody signed in, or no auth service yet, does nothing', () async {
    auth.setAuthState();
    await refreshEmailVerification(auth);
    await refreshEmailVerification(null);
    verifyNever(() => auth.reloadUser());
  });
}
