import "package:firebase_auth/firebase_auth.dart";

abstract class AuthRepository {
  FirebaseAuth get auth;
  String? get currentUserId;
}

class FirebaseAuthRepository implements AuthRepository {
  @override
  final FirebaseAuth auth = FirebaseAuth.instance;

  @override
  String? get currentUserId => auth.currentUser?.uid;
}
