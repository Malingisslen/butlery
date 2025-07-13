import 'package:firebase_auth/firebase_auth.dart';

class UserRepository {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Stream<String?> authStateChanges() {
    return _auth.authStateChanges().map((user) => user?.uid);
  }

  String? get currentUserId => _auth.currentUser?.uid;

  String? get currentUserDisplayName => _auth.currentUser?.displayName;
}
