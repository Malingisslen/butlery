import 'package:firebase_auth/firebase_auth.dart';

/// Simple wrapper around [FirebaseAuth] to expose authentication state
/// without requiring consumers to import firebase packages.
class AuthRepository {
  final FirebaseAuth _auth;

  AuthRepository({FirebaseAuth? auth}) : _auth = auth ?? FirebaseAuth.instance;

  /// Stream of authentication state changes.
  Stream<User?> authStateChanges() => _auth.authStateChanges();

  /// Current authenticated user's id, or `null` if not logged in.
  String? get currentUserId => _auth.currentUser?.uid;
}
