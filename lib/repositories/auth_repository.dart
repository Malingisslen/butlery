import "package:firebase_auth/firebase_auth.dart";
abstract class AuthRepository {
  FirebaseAuth get auth;
}

class FirebaseAuthRepository implements AuthRepository {
  @override
  final FirebaseAuth auth = FirebaseAuth.instance;
}
