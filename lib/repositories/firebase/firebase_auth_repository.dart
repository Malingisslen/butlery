import 'package:firebase_auth/firebase_auth.dart';
import '../interfaces/auth_repository.dart';

/// Wrapper around [FirebaseAuth] to expose a minimal API used across services.
class FirebaseAuthRepository implements AuthRepository {
  final FirebaseAuth _firebaseAuth;

  FirebaseAuthRepository({FirebaseAuth? firebaseAuth})
      : _firebaseAuth = firebaseAuth ?? FirebaseAuth.instance;

  /// Stream of authentication state changes.
  @override
  Stream<User?> authStateChanges() => _firebaseAuth.authStateChanges();

  /// Currently signed in user.
  User? get currentUser => _firebaseAuth.currentUser;

  @override
  User? getCurrentUser() => _firebaseAuth.currentUser;

  /// Convenience getter for the current user id.
  String? get currentUserId => _firebaseAuth.currentUser?.uid;

  /// Sign in with email and password.
  Future<UserCredential> signIn({
    required String email,
    required String password,
  }) {
    return _firebaseAuth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
  }

  @override
  Future<UserCredential> login(String email, String password) =>
      signIn(email: email, password: password);

  /// Register a new account with email and password.
  Future<UserCredential> register({
    required String email,
    required String password,
  }) {
    return _firebaseAuth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
  }

  /// Send a password reset email to the given address.
  Future<void> sendPasswordResetEmail(String email) {
    return _firebaseAuth.sendPasswordResetEmail(email: email);
  }

  /// Sign out the current user.
  Future<void> signOut() => _firebaseAuth.signOut();

  @override
  Future<void> logout() => signOut();
}
