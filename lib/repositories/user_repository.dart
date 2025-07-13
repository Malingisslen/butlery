import "package:cloud_firestore/cloud_firestore.dart";
import "package:firebase_auth/firebase_auth.dart";
abstract class UserRepository {
  CollectionReference<Map<String, dynamic>> get profilesRef;
  Stream<User?> authStateChanges();
  User? get currentUser;
}
