import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

abstract class FriendsRepository {
  CollectionReference<Map<String, dynamic>> get friendRequestsRef;
  CollectionReference<Map<String, dynamic>> get profilesRef;
  CollectionReference<Map<String, dynamic>> userFriendsCollection(String userId);
  WriteBatch batch();
  Stream<User?> authStateChanges();
  User? get currentUser;
}
