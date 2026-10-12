// BUT-916: the name and address a linked provider holds are read from that
// provider's own entry in the user's provider data.

import 'package:butlery/repositories/firebase/firebase_auth_repository.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter_test/flutter_test.dart';

class _Info extends Fake implements UserInfo {
  _Info(this.providerId, this.displayName, this.email);

  @override
  final String providerId;

  @override
  final String? displayName;

  @override
  final String? email;
}

void main() {
  FirebaseAuthRepository repoWith(List<UserInfo> data) =>
      FirebaseAuthRepository(
        firebaseAuth: MockFirebaseAuth(
          mockUser: MockUser(uid: 'u', providerData: data),
          signedIn: true,
        ),
      );

  test('each provider returns its own entry, not its neighbour\'s', () {
    final repo = repoWith([
      _Info('google.com', 'Google Namn', 'g@example.com'),
      _Info('apple.com', 'Apple Namn', 'a@example.com'),
    ]);

    expect(repo.providerDisplayName('google.com'), 'Google Namn');
    expect(repo.providerDisplayName('apple.com'), 'Apple Namn');
    expect(repo.providerEmail('apple.com'), 'a@example.com');
  });

  test('a provider that is not linked, or holds no name, gives null', () {
    final repo = repoWith([_Info('google.com', null, 'g@example.com')]);

    expect(repo.providerDisplayName('google.com'), isNull);
    expect(repo.providerDisplayName('apple.com'), isNull);
  });
}
