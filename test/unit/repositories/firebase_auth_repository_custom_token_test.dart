// BUT-2481: after "logga ut från alla enheter" this device signs in with a
// server-minted custom token for the SAME account. The app must not see that
// as a sign-out.

import 'package:butlery/repositories/firebase/firebase_auth_repository.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('swapping to a custom token for the same uid emits no signed-out '
      'state and keeps the user', () async {
    final repo = FirebaseAuthRepository(
      firebaseAuth: MockFirebaseAuth(
        mockUser: MockUser(uid: 'anna'),
        signedIn: true,
      ),
    );
    final seen = <User?>[];
    final sub = repo.authStateChanges().listen(seen.add);
    await Future<void>.delayed(Duration.zero);

    await repo.signInWithCustomToken('opaque-token');
    await Future<void>.delayed(Duration.zero);
    await sub.cancel();

    expect(seen, isNotEmpty);
    expect(seen.where((u) => u == null), isEmpty);
    expect(seen.every((u) => u?.uid == 'anna'), isTrue);
    expect(repo.currentUserId, 'anna');
    // The stream is distinct by uid, so the app's listener fires once.
    expect(seen.length, 1);
  });

  test(
    'a refused custom token reaches the caller instead of being swallowed',
    () async {
      final repo = FirebaseAuthRepository(
        firebaseAuth: _RefusingAuth(mockUser: MockUser(uid: 'anna')),
      );

      await expectLater(
        repo.signInWithCustomToken('bad'),
        throwsA(isA<FirebaseAuthException>()),
      );
    },
  );
}

class _RefusingAuth extends MockFirebaseAuth {
  _RefusingAuth({super.mockUser}) : super(signedIn: true);

  @override
  Future<UserCredential> signInWithCustomToken(String token) =>
      Future.error(FirebaseAuthException(code: 'invalid-custom-token'));
}
