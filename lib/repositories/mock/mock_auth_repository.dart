import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import '../interfaces/auth_repository.dart';

/// Simple [User] implementation used by [MockAuthRepository].
class FakeUser implements User {
  FakeUser({required this.uid, this.email, this.displayName});

  @override
  final String uid;
  @override
  final String? email;
  @override
  String? displayName;

  @override
  Future<void> updateDisplayName(String? displayName) async {
    this.displayName = displayName;
  }

  // The remaining [User] members are not needed for tests.
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

/// Simple [UserCredential] for tests.
class FakeUserCredential implements UserCredential {
  FakeUserCredential(this.user);

  @override
  final User? user;

  @override
  AdditionalUserInfo? get additionalUserInfo => null;

  @override
  AuthCredential? get credential => null;

  @override
  String? get operationType => null;

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

/// In-memory auth repository for unit tests.
class MockAuthRepository implements AuthRepository {
  final Map<String, String> _users = <String, String>{};
  FakeUser? _currentUser;
  final StreamController<User?> _controller =
      StreamController<User?>.broadcast();

  /// Add a user that can authenticate in tests.
  void addUser(String email, String password) {
    _users[email] = password;
  }

  @override
  Future<UserCredential> login(String email, String password) async {
    final stored = _users[email];
    if (stored != null && stored == password) {
      _currentUser = FakeUser(uid: email, email: email);
      _controller.add(_currentUser);
      return FakeUserCredential(_currentUser);
    }
    throw FirebaseAuthException(code: 'mock-error', message: 'Invalid login');
  }

  @override
  Future<void> logout() async {
    _currentUser = null;
    _controller.add(null);
  }

  @override
  User? getCurrentUser() => _currentUser;

  @override
  Stream<User?> authStateChanges() => _controller.stream;
}
