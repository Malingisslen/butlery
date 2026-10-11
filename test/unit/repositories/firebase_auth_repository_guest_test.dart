// BUT-920: the two repository calls guest mode is built on. A guest is a
// Firebase anonymous user; linking an e-mail keeps its uid.

import 'package:butlery/repositories/firebase/firebase_auth_repository.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockAuth extends Mock implements FirebaseAuth {}

class _MockUser extends Mock implements User {}

class _MockCredential extends Mock implements UserCredential {}

void main() {
  late _MockAuth auth;

  setUpAll(() {
    registerFallbackValue(
      EmailAuthProvider.credential(email: 'x@y.se', password: 'p'),
    );
  });

  setUp(() {
    auth = _MockAuth();
    when(() => auth.currentUser).thenReturn(null);
  });

  test(
    'signInAnonymously signs in through Firebase',
    () async {
      final guest = _MockUser();
      when(() => guest.uid).thenReturn('guest-1');
      final credential = _MockCredential();
      when(() => credential.user).thenReturn(guest);
      when(() => auth.signInAnonymously()).thenAnswer((_) async => credential);
      final repository = FirebaseAuthRepository(firebaseAuth: auth);

      final result = await repository.signInAnonymously();

      expect(result.user, same(guest));
      verify(() => auth.signInAnonymously()).called(1);
    },
  );

  test(
    'linkEmailPassword links an e-mail credential to the signed-in user',
    () async {
      final guest = _MockUser();
      when(() => guest.uid).thenReturn('guest-1');
      final credential = _MockCredential();
      when(() => credential.user).thenReturn(guest);
      when(
        () => guest.linkWithCredential(any()),
      ).thenAnswer((_) async => credential);
      final repository = FirebaseAuthRepository(firebaseAuth: auth);
      when(() => auth.currentUser).thenReturn(guest);

      await repository.linkEmailPassword('ny@exempel.se', 'Hemligt123!');

      final linked =
          verify(() => guest.linkWithCredential(captureAny())).captured.single
              as AuthCredential;
      expect(linked.providerId, EmailAuthProvider.PROVIDER_ID);
    },
  );

  test('linkEmailPassword refuses when nobody is signed in', () async {
    final repository = FirebaseAuthRepository(firebaseAuth: auth);

    await expectLater(
      repository.linkEmailPassword('ny@exempel.se', 'Hemligt123!'),
      throwsA(isA<Exception>()),
    );
  });
}
